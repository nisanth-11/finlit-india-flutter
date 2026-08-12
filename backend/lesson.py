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

@app.get("/lessons")
def view_lesson():
    lessons = db.collection("lessons").stream()
    return {
        "lesson_data": [
            {
                "id": lesson.id,
                "title": lesson.to_dict().get("title"),
                "description": lesson.to_dict().get("description"),
                "order_index": lesson.to_dict().get("order_index")
            }
            for lesson in lessons
        ]
    }

@app.get("/lessons/{lesson_id}")
def get_lesson(lesson_id: str):
    lesson_ref = db.collection("lessons").document(lesson_id)
    lesson = lesson_ref.get()
    if not lesson.exists:
        raise HTTPException(status_code=404)
    return {
        "lesson": {
            "id": lesson.id,
            **lesson.to_dict()
        }
    }