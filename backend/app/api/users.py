# app/api/users.py

from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from pydantic import BaseModel
from app.infra.postgres import get_db
from app.core.user import register_user, get_public_key
import base64
import traceback

router = APIRouter(prefix="/users")

class RegisterUserSchema(BaseModel):
    user_id: str
    public_key: str
    signature: str
    timestamp: str

@router.post("/register")
def register_user_endpoint(payload: RegisterUserSchema, db: Session = Depends(get_db)):
    try:
        print(f"📥 Received registration for user: {payload.user_id}")
        
        # 1. Verify Signature
        # The data signed should be user_id + timestamp to prevent reuse
        signed_data = f"{payload.user_id}|{payload.timestamp}"
        from app.core.security import verify_pgp_signature
        
        if not verify_pgp_signature(payload.public_key, payload.signature, signed_data):
            print(f"❌ Signature verification failed for {payload.user_id}")
            raise HTTPException(status_code=401, detail="Invalid identity signature")

        # 2. Decode base64 public key for storage (or store as PEM/Armor)
        # The frontend sends PGP Armor, let's store it as bytes or string
        # To keep it consistent with existing LargeBinary column
        public_key_bytes = payload.public_key.encode('utf-8')
        
        # Register user
        register_user(db, payload.user_id, public_key_bytes)
        print(f"✅ User {payload.user_id} registered successfully")
        
        return {"status": "registered", "user_id": payload.user_id}
    except HTTPException:
        raise
    except Exception as e:
        print(f"❌ Registration failed: {str(e)}")
        traceback.print_exc()
        raise HTTPException(status_code=400, detail=str(e))

@router.get("/{user_id}/public-key")
def get_user_public_key(user_id: str, db: Session = Depends(get_db)):
    public_key = get_public_key(db, user_id)
    if public_key is None:
        raise HTTPException(status_code=404, detail="User not found")
    
    # Encode to base64
    public_key_b64 = base64.b64encode(public_key).decode()
    
    return {"public_key": public_key_b64}