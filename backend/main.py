from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from datetime import datetime, timedelta
from pydantic import BaseModel
from firebase_config import db

# Shop item -> price in coins.
SHOP_PRICES = {
    "streak_freeze": 200,
    "double_coin": 50,
    "quiz_shield": 100,
}

# Shop item -> the user-document field holding its owned count.
SHOP_COUNT_FIELDS = {
    "streak_freeze": "streak_freeze_count",
    "double_coin": "double_coin_count",
    "quiz_shield": "quiz_shield_count",
}

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
    streak_freeze_count = data.get("streak_freeze_count", 0)
    double_coin_active_until = data.get("double_coin_active_until")

    now = datetime.now()
    today_str = now.strftime("%Y-%m-%d")

    updates = {}

    # Double Coin power-up: while active, every reward is doubled.
    if double_coin_active_until:
        try:
            active_until = datetime.fromisoformat(double_coin_active_until)
            if active_until > now:
                coins_earned *= 2
        except (ValueError, TypeError):
            pass

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
                # Streak Freeze power-up: consume one freeze to preserve the
                # streak instead of resetting it back to 1.
                if streak_freeze_count > 0:
                    updates["streak_freeze_count"] = streak_freeze_count - 1
                else:
                    streak = 1
        else:
            streak = 1

    updates.update({
        "streak_count": streak,
        "coins": coins + coins_earned,
        "last_active_date": today_str
    })
    user_ref.update(updates)
    return coins_earned


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
    # True when the lesson was already completed with a perfect score and is
    # being replayed. When set, the coin reward is halved (golden replay).
    is_replay: bool = False

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
        "last_active_date": None,
        "streak_freeze_count": 0,
        "double_coin_count": 0,
        "quiz_shield_count": 0,
        "double_coin_active_until": None
    }

    doc_ref = users_ref.add(new_user)

    return {
        "user_id": doc_ref[1].id,
        "user": new_user
    }

@app.post("/auth/login")
def login(u: User):
    users_ref = db.collection("users")
    existing = users_ref.where("phone", "==", u.phone).get()

    if not existing:
        raise HTTPException(status_code=404, detail="User not found")

    doc = existing[0]
    return {
        "user_id": doc.id,
        "user": doc.to_dict()
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
        "coins": data.get("coins", 0)
    }

# SHOP
class ShopBuyInput(BaseModel):
    user_id: str
    item: str

class ShopActivateInput(BaseModel):
    user_id: str

@app.post("/shop/buy")
def shop_buy(data: ShopBuyInput):
    if data.item not in SHOP_PRICES:
        raise HTTPException(status_code=400, detail="Invalid item")

    user_ref = db.collection("users").document(data.user_id)
    user_doc = user_ref.get()
    if not user_doc.exists:
        raise HTTPException(status_code=404)

    user = user_doc.to_dict()
    coins = user.get("coins", 0)
    price = SHOP_PRICES[data.item]

    if coins < price:
        raise HTTPException(status_code=400, detail="Not enough coins")

    count_field = SHOP_COUNT_FIELDS[data.item]
    remaining_coins = coins - price
    user_ref.update({
        "coins": remaining_coins,
        count_field: user.get(count_field, 0) + 1,
    })

    return {
        "message": "Purchased",
        "item": data.item,
        "remaining_coins": remaining_coins,
    }

@app.get("/shop/items/{user_id}")
def shop_items(user_id: str):
    user_doc = db.collection("users").document(user_id).get()
    if not user_doc.exists:
        raise HTTPException(status_code=404)
    user = user_doc.to_dict()
    return {
        "streak_freeze_count": user.get("streak_freeze_count", 0),
        "double_coin_count": user.get("double_coin_count", 0),
        "quiz_shield_count": user.get("quiz_shield_count", 0),
        "double_coin_active_until": user.get("double_coin_active_until"),
    }

@app.post("/shop/activate/double_coin")
def shop_activate_double_coin(data: ShopActivateInput):
    user_ref = db.collection("users").document(data.user_id)
    user_doc = user_ref.get()
    if not user_doc.exists:
        raise HTTPException(status_code=404)

    user = user_doc.to_dict()
    if user.get("double_coin_count", 0) <= 0:
        raise HTTPException(status_code=400, detail="No double coin available")

    active_until = (datetime.now() + timedelta(days=7)).isoformat()
    user_ref.update({
        "double_coin_active_until": active_until,
        "double_coin_count": user.get("double_coin_count", 0) - 1,
    })

    return {"active_until": active_until}

@app.post("/shop/use/{item}")
def shop_use(item: str, data: ShopActivateInput):
    if item not in SHOP_COUNT_FIELDS:
        raise HTTPException(status_code=400, detail="Invalid item")

    user_ref = db.collection("users").document(data.user_id)
    user_doc = user_ref.get()
    if not user_doc.exists:
        raise HTTPException(status_code=404)

    user = user_doc.to_dict()
    count_field = SHOP_COUNT_FIELDS[item]
    count = user.get(count_field, 0)
    if count <= 0:
        raise HTTPException(status_code=400, detail="None available")

    user_ref.update({count_field: count - 1})
    return {"message": "Used", "item": item, "remaining": count - 1}

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
    progress_ref = db.collection("users") \
        .document(u.user_id) \
        .collection("progress") \
        .document(u.lesson_id)

    progress_ref.set({
        "is_completed": u.is_completed,
        "completed_at": datetime.now()
    })
    # Coins are only awarded through /quiz/result; saving progress never grants
    # a completion bonus.
    bonus_coins = 0
    _update_streak_and_coins(u.user_id, bonus_coins)
    return {"progress": u, "bonus_coins_earned": bonus_coins}

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
            "correctIndex": q.get("correct_option") - 1
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
        # Frontend sends 0-based indices; correct_option in Firestore is 1-based
        if data.answers[i] == questions[i]["correct_option"] - 1:
            score += 1

    total = len(questions)
    percentage = int((score / total) * 100)

    lesson_doc = db.collection("lessons").document(data.lesson_id).get()
    coins_reward = lesson_doc.to_dict().get("coinsReward", 10) if lesson_doc.exists else 10

    if data.is_replay:
        # Golden replay: lesson was already completed with a perfect score,
        # so award a reduced reward (50% for perfect, 35% for one wrong).
        if score == total:
            coins_earned = int(coins_reward * 0.5)
        elif score == total - 1:
            coins_earned = int(coins_reward * 0.35)
        else:
            coins_earned = 0
    else:
        if score == total:
            coins_earned = coins_reward
        elif score == total - 1:
            coins_earned = int(coins_reward * 0.7)
        else:
            coins_earned = 0

    result = {
        "lesson_id": data.lesson_id,
        "score": percentage,
        "completed_at": datetime.now()
    }

    db.collection("users") \
        .document(data.user_id) \
        .collection("quiz_results") \
        .add(result)

    actual_coins = _update_streak_and_coins(data.user_id, coins_earned)

    return {"result": result, "coins_earned": actual_coins}

@app.get("/quiz/results/{user_id}")
def get_quiz_results(user_id: str):
    results_ref = db.collection("users") \
        .document(user_id) \
        .collection("quiz_results") \
        .stream()

    return {
        "results": [
            {
                "lesson_id": doc.to_dict().get("lesson_id"),
                "score": doc.to_dict().get("score", 0),
            }
            for doc in results_ref
        ]
    }

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