from fastapi import FastAPI
from fastapi import HTTPException
from fastapi.middleware.cors import CORSMiddleware
from datetime import datetime   
from pydantic import BaseModel
from firebase_config import db   

app=FastAPI()

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

class Profile(BaseModel):
    user_id: str 
    name: str
    language: str


class User(BaseModel):
    phone: str 

@app.post("/auth/register")
def register(u: User):
    users_ref = db.collection("users")
    existing = users_ref.where("phone", "==", u.phone).get()
    if existing:
        raise HTTPException(status_code=400)
    new_user = {
        "phone": u.phone,
        "name": None,
        "language": None,
        "created_at": datetime.now()
    }
    doc_ref = users_ref.document()
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
    return {"message": "Profile updated successfully"}