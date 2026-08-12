from fastapi import FastAPI, HTTPException
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

@app.get("/quiz/{lesson_id}")
def get_questions(lesson_id: str):
    questions_ref = (
        db.collection("lessons").document(lesson_id).collection("questions").stream()
    )
    questions = [
        {
            "id": doc.id,
            **doc.to_dict()
        }
        for doc in questions_ref
    ]
    if not questions:
        raise HTTPException(status_code=404)
    return {"questions": questions}