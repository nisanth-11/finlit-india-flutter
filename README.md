# FinLit India

A gamified financial literacy app: short lessons, quizzes and a roadmap you progress through, aimed at making money basics approachable for Indian users.

Built as a team project during my exchange semester at THWS Würzburg-Schweinfurt, Germany.

## Stack

| Part | Stack |
|---|---|
| `frontend/` | Flutter, Dart |
| `backend/` | FastAPI, Pydantic, Firebase Admin (Firestore) |
| CI | GitHub Actions workflow that builds the Android APK |

## Features

- Learning roadmap with lessons and quizzes
- Progress and quiz results stored per user
- Budget screen, in-app shop, profile and settings
- Guided dialogues and tutorials
- Translations for multiple languages
- Unit, widget and integration tests

## Project structure

```
backend/
  main.py             FastAPI app
  lesson.py, question.py, quiz_result.py, user.py, user_progress.py
  seed_questions.py   seeds the question bank
frontend/lib/
  screens/    roadmap, lesson, quiz, budget, shop, profile, settings, registration
  services/   API client, dialogues, translations
  models/     lesson, user, dialogue
```

## Run it locally

You need the Flutter SDK, Python 3 and a Firebase project with Firestore.

```bash
# backend
cd backend
pip install -r requirements.txt
uvicorn main:app --reload

# app
cd frontend
flutter pub get
flutter run
```

## Related repos

- [finlit-india](https://github.com/nisanth-11/finlit-india): standalone copy of the backend
- [finlit-v](https://github.com/nisanth-11/finlit-v): native iOS (SwiftUI) version
- [finlit-india-download](https://github.com/nisanth-11/finlit-india-download): landing and download page
