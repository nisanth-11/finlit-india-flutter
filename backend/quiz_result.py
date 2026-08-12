from fastapi import FastAPI, HTTPException
from pydantic import BaseModel
from datetime import datetime
from firebase_config import db
from fastapi.middleware.cors import CORSMiddleware

app = FastAPI()

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

class QuizResultInput(BaseModel):
    user_id: str
    lesson_id: str
    answers: list[int]

@app.post("/quiz/result")
def submit_quiz(data: QuizResultInput):
    questions_ref = (
        db.collection("lessons").document(data.lesson_id).collection("questions").stream()
    )
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
    result = {
        "lesson_id": data.lesson_id,
        "score": percentage,
        "completed_at": datetime.now()
    }
    db.collection("users").document(data.user_id).collection("quiz_results").add(result)
    return {"result": result}