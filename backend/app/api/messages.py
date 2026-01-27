from datetime import datetime
from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from app.infra.postgres import get_db
from app.core.message import store_message, fetch_messages
from app.core.user import get_public_key
import traceback
import base64

router = APIRouter(prefix="/messages")

@router.post("/send")
def send_message(payload: dict, db: Session = Depends(get_db)):
    try:
        recipient_id = payload.get("recipient")
        ciphertext = payload.get("ciphertext") or payload.get("encryptedMessage")
        sender_id = payload.get("senderId", "anonymous")
        
        if not recipient_id or not ciphertext:
            raise HTTPException(status_code=400, detail="Missing recipient or content")

        # 1. Get recipient's public key (returns bytes from core.user)
        pub_key = get_public_key(db, recipient_id)
        if not pub_key:
            raise HTTPException(status_code=404, detail=f"User not found: {recipient_id}")

        # 2. Ensure ciphertext is converted to bytes for the LargeBinary column
        if isinstance(ciphertext, str):
            ciphertext_bytes = ciphertext.encode('utf-8')
        else:
            ciphertext_bytes = ciphertext

        # 3. Store message
        store_message(db, pub_key, ciphertext_bytes, sender_id)
        
        return {"status": "sent"}
        
    except Exception as e:
        print(f"❌ ERROR in send_message: {str(e)}")
        print(traceback.format_exc())
        # If the error is already an HTTPException, re-raise it
        if isinstance(e, HTTPException):
            raise e
        raise HTTPException(status_code=500, detail=str(e))

@router.get("/receive/{user_id}")
def receive_messages_endpoint(user_id: str, db: Session = Depends(get_db)):
    try:
        # 1. Get user's public key
        pub_key = get_public_key(db, user_id)
        if not pub_key:
            raise HTTPException(status_code=404, detail=f"User not found: {user_id}")

        # 2. Fetch messages (this also deletes them from DB)
        messages = fetch_messages(db, pub_key)
        
        # 3. Format result for JSON
        result = []
        for m in messages:
            # We must decode bytes back to string to send in JSON
            # Using base64 is safest if the ciphertext contains raw binary data
            try:
                display_text = m.ciphertext.decode('utf-8')
            except UnicodeDecodeError:
                display_text = base64.b64encode(m.ciphertext).decode('utf-8')

            result.append({
                "id": m.id,
                "ciphertext": display_text,
                "senderId": m.sender_id,
                "recipientId": user_id,
                "timestamp": m.created_at.isoformat() if m.created_at else datetime.utcnow().isoformat()
            })
        
        return result
        
    except Exception as e:
        print(f"❌ ERROR in receive_messages: {str(e)}")
        print(traceback.format_exc())
        if isinstance(e, HTTPException):
            raise e
        raise HTTPException(status_code=500, detail=str(e))