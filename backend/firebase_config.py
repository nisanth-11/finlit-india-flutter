import json
import os
import firebase_admin
from firebase_admin import credentials, firestore

firebase_credentials_json = os.environ.get("FIREBASE_CREDENTIALS_JSON")
if firebase_credentials_json:
    cred = credentials.Certificate(json.loads(firebase_credentials_json))
else:
    cred = credentials.Certificate("serviceAccountKey.json")

firebase_admin.initialize_app(cred)

db = firestore.client()