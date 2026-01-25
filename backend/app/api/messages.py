from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from pydantic import BaseModel
from app.infra.postgres import get_db
from app.core.message import store_message, fetch_messages
from app.core.user import get_public_key
import base64

router = APIRouter(prefix="/messages")

class MessageSendSchema(BaseModel):
    recipient: str
    ciphertext: str

@router.post("/send")
def send_message(payload: MessageSendSchema, db: Session = Depends(get_db)):
    recipient_key = get_public_key(db, payload.recipient)
    if recipient_key is None:
        raise HTTPException(status_code=404, detail="Recipient not found")
    
    ciphertext_bytes = base64.b64decode(payload.ciphertext)
    store_message(db, recipient_key, ciphertext_bytes)
    
    return {"status": "sent"}

@router.get("/receive/{user_id}")
def receive_messages_endpoint(user_id: str, db: Session = Depends(get_db)):
    recipient_key = get_public_key(db, user_id)
    if recipient_key is None:
        raise HTTPException(status_code=404, detail="User not found")
    
    messages = fetch_messages(db, recipient_key)
    
    return [
        {"ciphertext": base64.b64encode(bytes(m.ciphertext)).decode()}
        for m in messages
    ]