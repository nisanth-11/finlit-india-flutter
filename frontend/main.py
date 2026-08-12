from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from datetime import datetime
from pydantic import BaseModel
from firebase_config import db

app = FastAPI()

def _update_streak_and_coins(user_id: str, coins_earned: int = 0):
    user_ref = db.collection("users").document(user_id)
    user_doc = user_ref.get()
    if not user_doc.exists:
        return
    
    data = user_doc.to_dict()
    streak = data.get("streak_count", 0)
    coins = data.get("coins", 0)
    last_active = data.get("last_active_date")

    now = datetime.now()
    today_str = now.strftime("%Y-%m-%d")

    if last_active == today_str:
        # Already active today, just add coins
        pass
    else:
        if last_active:
            last_date = datetime.strptime(last_active, "%Y-%m-%d").date()
            delta = (now.date() - last_date).days
            if delta == 1:
                streak += 1
            else:
                streak = 1
        else:
            streak = 1
    
    user_ref.update({
        "streak_count": streak,
        "coins": coins + coins_earned,
        "last_active_date": today_str
    })


app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# BASEMODEL
class User(BaseModel):
    phone: str

class Profile(BaseModel):
    user_id: str
    name: str
    language: str

class Progress(BaseModel):
    user_id: str
    lesson_id: str
    is_completed: bool

class QuizResultInput(BaseModel):
    user_id: str
    lesson_id: str
    answers: list[int]

# AUTH
@app.post("/auth/register")
def register(u: User):
    users_ref = db.collection("users")
    existing = users_ref.where("phone", "==", u.phone).get()

    if existing:
        raise HTTPException(status_code=400, detail="User exists")

    new_user = {
        "phone": u.phone,
        "name": None,
        "language": None,
        "created_at": datetime.now(),
        "streak_count": 0,
        "coins": 0,
        "gems": 0,
        "last_active_date": None
    }

    doc_ref = users_ref.add(new_user)

    return {
        "user_id": doc_ref[1].id,
        "user": new_user
    }

@app.post("/auth/profile")
def update_profile(p: Profile):
    user_ref = db.collection("users").document(p.user_id)

    if not user_ref.get().exists:
        raise HTTPException(status_code=404)

    user_ref.update({
        "name": p.name,
        "language": p.language
    })

    return {"message": "Profile updated"}

@app.get("/user/{user_id}")
def get_user(user_id: str):
    user_ref = db.collection("users").document(user_id).get()
    if not user_ref.exists:
        raise HTTPException(status_code=404)
    data = user_ref.to_dict()
    return {
        "streak_count": data.get("streak_count", 0),
        "coins": data.get("coins", 0),
        "gems": data.get("gems", 0)
    }

# LESSONS
@app.get("/lessons")
def view_lesson():
    lessons = db.collection("lessons").stream()

    return [
        {
            "id": lesson.id,
            "title": lesson.to_dict().get("title"),
            "description": lesson.to_dict().get("description"),
            "content": lesson.to_dict().get("content"),
            "moduleNumber": lesson.to_dict().get("moduleNumber"),
            "sectionName": lesson.to_dict().get("sectionName"),
            "coinsReward": lesson.to_dict().get("coinsReward"),
            "order_index": lesson.to_dict().get("order_index")
        }
        for lesson in lessons
    ]

@app.get("/lessons/{lesson_id}")
def get_lesson(lesson_id: str):
    lesson = db.collection("lessons").document(lesson_id).get()

    if not lesson.exists:
        raise HTTPException(status_code=404)

    return {
        "lesson": {
            "id": lesson.id,
            **lesson.to_dict()
        }
    }

# PROGRESS
@app.post("/progress")
def save_progress(u: Progress):
    db.collection("users") \
        .document(u.user_id) \
        .collection("progress") \
        .document(u.lesson_id) \
        .set({
            "is_completed": u.is_completed,
            "completed_at": datetime.now()
        })
    _update_streak_and_coins(u.user_id, 0)
    return {"progress": u}

@app.get("/progress/{user_id}")
def check_progress(user_id: str):
    progress_docs = db.collection("users") \
        .document(user_id) \
        .collection("progress") \
        .stream()

    return {
        "progress": [
            {
                "lesson_id": doc.id,
                **doc.to_dict()
            }
            for doc in progress_docs
        ]
    }

# QUIZ
@app.get("/quiz/{lesson_id}")
def get_questions(lesson_id: str):
    questions_ref = db.collection("lessons") \
        .document(lesson_id) \
        .collection("questions") \
        .stream()
    return [
        {
            "id": doc.id,
            "question": q.get("question"),
            "options": [
                q.get("option_1"),
                q.get("option_2"),
                q.get("option_3"),
                q.get("option_4"),
            ],
            "correctIndex": q.get("correct_option")
        }
        for doc in questions_ref
        for q in [doc.to_dict()]
    ]

@app.post("/quiz/result")
def submit_quiz(data: QuizResultInput):
    questions_ref = db.collection("lessons") \
        .document(data.lesson_id) \
        .collection("questions") \
        .stream()

    questions = [doc.to_dict() for doc in questions_ref]

    if not questions:
        raise HTTPException(status_code=404)

    if len(data.answers) != len(questions):
        raise HTTPException(status_code=400)

    score = 0

    for i in range(len(questions)):
        if data.answers[i] == questions[i]["correct_option"]:
            score += 1

    percentage = int((score / len(questions)) * 100)

    lesson_doc = db.collection("lessons").document(data.lesson_id).get()
    coins_reward = 0
    if lesson_doc.exists:
        coins_reward = lesson_doc.to_dict().get("coinsReward", 0)
    coins_earned = int((coins_reward * score) / len(questions))

    result = {
        "lesson_id": data.lesson_id,
        "score": percentage,
        "completed_at": datetime.now()
    }

    db.collection("users") \
        .document(data.user_id) \
        .collection("quiz_results") \
        .add(result)
        
    _update_streak_and_coins(data.user_id, coins_earned)

    return {"result": result, "coins_earned": coins_earned}

class BudgetInput(BaseModel):
    user_id: str
    totalIncome: float
    food: float
    rent: float
    education: float
    transport: float
    savings: float

# BUDGET
@app.post("/budget")
def save_budget(data: BudgetInput):
    budget_data = {
        "totalIncome": data.totalIncome,
        "food": data.food,
        "rent": data.rent,
        "education": data.education,
        "transport": data.transport,
        "savings": data.savings,
        "lastUpdated": datetime.now()
    }
    db.collection("users") \
        .document(data.user_id) \
        .collection("budget") \
        .document("current") \
        .set(budget_data)
    return {"message": "Budget saved", "budget": budget_data}

@app.get("/budget/{user_id}")
def get_budget(user_id: str):
    doc = db.collection("users") \
        .document(user_id) \
        .collection("budget") \
        .document("current") \
        .get()
    
    if not doc.exists:
        raise HTTPException(status_code=404, detail="Budget not found")
        
    return doc.to_dict()