# app/models/message.py

from sqlalchemy import Column, Integer, LargeBinary, DateTime
from app.infra.postgres import Base
from datetime import datetime

class Message(Base):
    __tablename__ = "messages"

    id = Column(Integer, primary_key=True, index=True)
    recipient_hash = Column(LargeBinary, nullable=False, index=True)
    ciphertext = Column(LargeBinary, nullable=False)
    expires_at = Column(DateTime, nullable=False, index=True)
    created_at = Column(DateTime, default=datetime.utcnow)