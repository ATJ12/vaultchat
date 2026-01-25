from sqlalchemy import Column, Integer, LargeBinary, DateTime
from datetime import datetime, timedelta
from app.infra.postgres import Base

class Message(Base):
    __tablename__ = "messages"

    id = Column(Integer, primary_key=True)
    recipient_hash = Column(LargeBinary, index=True, nullable=False)
    ciphertext = Column(LargeBinary, nullable=False)
    expires_at = Column(
        DateTime,
        nullable=False,
        default=lambda: datetime.utcnow() + timedelta(days=7)
    )
