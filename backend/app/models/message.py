from sqlalchemy import Column, Integer, String, LargeBinary, DateTime
from datetime import datetime, timedelta
from app.infra.postgres import Base

class Message(Base):
    __tablename__ = "messages"
    
    id = Column(Integer, primary_key=True)
    
    # Changed from recipient_id (String) to recipient_hash (LargeBinary)
    # This matches the 'recipient_hash' keyword argument in your store_message function
    recipient_hash = Column(LargeBinary, index=True, nullable=False) 
    
    # Stores the ID of the sender (e.g., "wahida")
    sender_id = Column(String, nullable=False, default="anonymous")
    
    # Changed from Text to LargeBinary
    # Encrypted data often contains non-UTF8 characters that will crash a Text column
    ciphertext = Column(LargeBinary, nullable=False) 
    
    expires_at = Column(
        DateTime, 
        nullable=False, 
        # Default is 7 days from now; store_message logic can still override this
        default=lambda: datetime.utcnow() + timedelta(days=7)
    )
    
    created_at = Column(DateTime, default=datetime.utcnow)