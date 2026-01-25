# app/core/user.py

from sqlalchemy.orm import Session
from app.models.user import User
import hashlib

def hash_user_id(user_id: str) -> bytes:
    """Hash user ID for privacy"""
    return hashlib.sha256(user_id.encode()).digest()

def register_user(db: Session, user_id: str, public_key: bytes):
    """Register a new user with their public key"""
    user_id_hash = hash_user_id(user_id)
    
    # Check if user already exists
    existing = db.query(User).filter(User.user_id_hash == user_id_hash).first()
    if existing:
        # Update public key if user exists
        existing.public_key = public_key
    else:
        # Create new user
        user = User(
            user_id_hash=user_id_hash,
            public_key=public_key
        )
        db.add(user)
    
    db.commit()

def get_public_key(db: Session, user_id: str) -> bytes:
    """Get user's public key by user_id"""
    user_id_hash = hash_user_id(user_id)
    
    user = db.query(User).filter(User.user_id_hash == user_id_hash).first()
    
    if user is None:
        return None
    
    return user.public_key