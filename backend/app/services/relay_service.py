# app/services/relay_service.py

from app.infra.postgres import db_session
from app.models.message_model import Message

def store_message(sender: str, recipient: str, payload: bytes):
    with db_session() as session:
        msg = Message(
            sender_id=sender,
            recipient_id=recipient,
            payload=payload
        )
        session.add(msg)


def fetch_messages(user_id: str):
    with db_session() as session:
        messages = (
            session.query(Message)
            .filter(Message.recipient_id == user_id)
            .all()
        )

        return [
            {
                "sender": m.sender_id,
                "payload": m.payload.hex()
            }
            for m in messages
        ]
