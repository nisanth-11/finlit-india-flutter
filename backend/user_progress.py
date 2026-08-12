from fastapi import FastAPI
from datetime import datetime
from pydantic import BaseModel
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

class Progress(BaseModel):
    user_id: str
    lesson_id: str
    is_completed: bool

@app.post("/progress")
def save_progress(u: Progress):
    db.collection("users").document(u.user_id).collection("progress").document(u.lesson_id).set(
        {
          "is_completed": u.is_completed,
          "completed_at": datetime.now()
        })
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