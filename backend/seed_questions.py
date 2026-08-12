"""
One-off maintenance script:
1. Fixes the existing correct_option values for lesson_1/lesson_2 questions,
   which were stored 1-indexed instead of 0-indexed (off-by-one scoring bug).
2. Adds 2 new questions per lesson so each lesson has 5 total.

Run once from frontend/backend/:
    python seed_questions.py
"""

from firebase_config import db

# --- Fixes for existing questions (correct_option was off by one) ---
FIXES = {
    "lesson_1": {
        "question_1": 1,  # "To track income and expenses"
        "question_2": 2,  # "Paying rent or electricity bill"
        "question_3": 0,  # "To know where your money is going"
    },
    "lesson_2": {
        "question_1": 1,  # "It helps in emergencies"
        "question_2": 1,  # "Regularly, even small amounts"
        "question_3": 1,  # "In a bank account"
    },
}

# --- New questions to add (2 per lesson) ---
NEW_QUESTIONS = {
    "lesson_1": [
        {
            "question": "Which of these is a fixed expense in a monthly budget?",
            "option_1": "Rent",
            "option_2": "Eating out occasionally",
            "option_3": "An impulse purchase",
            "option_4": "A festival gift",
            "correct_option": 0,
        },
        {
            "question": "What should you do if your expenses are higher than your income?",
            "option_1": "Ignore it and keep spending",
            "option_2": "Cut unnecessary expenses or increase income",
            "option_3": "Take a loan for daily expenses",
            "option_4": "Stop checking your budget",
            "correct_option": 1,
        },
    ],
    "lesson_2": [
        {
            "question": "What is an emergency fund?",
            "option_1": "Money saved for unexpected expenses",
            "option_2": "Money spent on entertainment",
            "option_3": "A type of loan",
            "option_4": "Money given to friends",
            "correct_option": 0,
        },
        {
            "question": "Which habit helps you save money faster?",
            "option_1": "Spending first, saving whatever is left",
            "option_2": "Saving a fixed amount first, then spending the rest",
            "option_3": "Borrowing money to save",
            "option_4": "Saving only once a year",
            "correct_option": 1,
        },
    ],
}


def main():
    for lesson_id, question_fixes in FIXES.items():
        for question_id, correct_option in question_fixes.items():
            ref = (
                db.collection("lessons")
                .document(lesson_id)
                .collection("questions")
                .document(question_id)
            )
            ref.update({"correct_option": correct_option})
            print(f"Fixed {lesson_id}/{question_id} -> correct_option={correct_option}")

    for lesson_id, questions in NEW_QUESTIONS.items():
        questions_ref = db.collection("lessons").document(lesson_id).collection("questions")
        for q in questions:
            new_ref = questions_ref.document()
            new_ref.set(q)
            print(f"Added {lesson_id}/{new_ref.id}: {q['question']}")


if __name__ == "__main__":
    main()
