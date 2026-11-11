

import firebase_admin
from firebase_admin import credentials



def init_firebase():
    try:
        firebase_admin.get_app()
    except ValueError:
        cred = credentials.Certificate('secret/firebase-service-account.json')
        firebase_admin.initialize_app(cred)