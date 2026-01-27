from sqlalchemy.orm import Session
from app.models.message import Message
from datetime import datetime, timedelta
import hashlib
import random

def hash_recipient(public_key: bytes) -> bytes:
    """Hash recipient public key (must be bytes)"""
    if isinstance(public_key, str):
        public_key = public_key.encode('utf-8')
    if not isinstance(public_key, bytes):
        raise TypeError("public_key must be bytes or a string that can be encoded")
    return hashlib.sha256(public_key).digest()

def store_message(
    db: Session,
    recipient_public_key: bytes,
    ciphertext: bytes,
    sender_id: str = "anonymous"
):
    """Store an encrypted message for a recipient"""
    # Defensive check: ensure ciphertext is bytes for LargeBinary column
    if isinstance(ciphertext, str):
        ciphertext = ciphertext.encode('utf-8')
        
    recipient_hash = hash_recipient(recipient_public_key)

    expires_at = datetime.utcnow() + timedelta(
        days=7,
        minutes=random.randint(-60, 60)  # timing blur for privacy
    )

    message = Message(
        recipient_hash=recipient_hash,
        ciphertext=ciphertext,
        sender_id=sender_id,
        expires_at=expires_at
    )

    db.add(message)
    db.commit()
    db.refresh(message)
    return message

def fetch_messages(db: Session, recipient_public_key: bytes):
    """Fetch and delete messages for a recipient"""
    recipient_hash = hash_recipient(recipient_public_key)

    messages = db.query(Message).filter(
        Message.recipient_hash == recipient_hash,
        Message.expires_at > datetime.utcnow()
    ).all()

    # Delete messages after fetching (read-once policy)
    for msg in messages:
        db.delete(msg)

    db.commit()
    return messages