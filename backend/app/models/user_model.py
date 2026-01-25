# app/models/user.py - Match existing table

from sqlalchemy import Column, String, LargeBinary, DateTime
from datetime import datetime
from app.infra.postgres import Base

class User(Base):
    __tablename__ = "users"
    
    # Use 'id' to match existing table
    id = Column(String(100), primary_key=True, index=True)
    public_key = Column(LargeBinary, nullable=False)
    created_at = Column(DateTime, default=datetime.utcnow, nullable=False)
    updated_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)