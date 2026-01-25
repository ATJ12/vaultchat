# app/api/rooms.py

from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from pydantic import BaseModel
from app.infra.postgres import get_db
import hashlib

router = APIRouter(prefix="/rooms")

# In-memory storage for simplicity (use database in production)
_rooms = {}
# Track active room per user
_user_active_rooms = {}

class CreateRoomSchema(BaseModel):
    user1_id: str
    user2_id: str
    room_code: str

class JoinRoomSchema(BaseModel):
    user1_id: str
    user2_id: str
    room_code: str

class DeleteRoomSchema(BaseModel):
    room_code: str
    user_id: str

@router.post("/create")
def create_room(payload: CreateRoomSchema):
    """Create a new chat room"""
    
    # DELETE PREVIOUS ROOM if user has one
    if payload.user1_id in _user_active_rooms:
        old_room_code = _user_active_rooms[payload.user1_id]
        print(f"🗑️ Deleting previous room for user {payload.user1_id}: {old_room_code}")
        
        # Remove old room
        if old_room_code in _rooms:
            del _rooms[old_room_code]
        
        # Note: The PROTOCOL_USER_LEFT_ROOM signal will be sent via messages API
    
    # Create new room
    room_key = f"{payload.room_code}"
    
    _rooms[room_key] = {
        'code': payload.room_code,
        'user1_id': payload.user1_id,
        'user2_id': payload.user2_id,
    }
    
    # Track active room for this user
    _user_active_rooms[payload.user1_id] = room_key
    
    print(f"✅ Room created: {room_key}, Users: {payload.user1_id} <-> {payload.user2_id}")
    
    return {"status": "created", "room_code": payload.room_code}

@router.post("/join")
def join_room(payload: JoinRoomSchema):
    """Join an existing room with code"""
    room_key = f"{payload.room_code.upper()}"
    
    # Check if room exists
    if room_key not in _rooms:
        print(f"❌ Room not found: {room_key}")
        raise HTTPException(status_code=404, detail="Room not found or has been deleted")
    
    room = _rooms[room_key]
    
    # Check if users match
    users_in_room = {room['user1_id'], room['user2_id']}
    provided_users = {payload.user1_id, payload.user2_id}
    
    if users_in_room != provided_users:
        print(f"❌ User mismatch. Room has: {users_in_room}, Provided: {provided_users}")
        raise HTTPException(status_code=403, detail="Invalid users for this room")
    
    # DELETE PREVIOUS ROOM for user2 if they have one
    if payload.user2_id in _user_active_rooms:
        old_room_code = _user_active_rooms[payload.user2_id]
        if old_room_code != room_key:  # Don't delete if it's the same room
            print(f"🗑️ Deleting previous room for user {payload.user2_id}: {old_room_code}")
            if old_room_code in _rooms:
                del _rooms[old_room_code]
    
    # Track active room for this user
    _user_active_rooms[payload.user2_id] = room_key
    
    print(f"✅ User joined room: {room_key}")
    
    return {
        "status": "joined",
        "room": room
    }

@router.delete("/{room_code}")
def delete_room(room_code: str, user_id: str):
    """Delete a room (called when user creates new room)"""
    room_key = room_code.upper()
    
    if room_key not in _rooms:
        print(f"⚠️ Room already deleted: {room_key}")
        return {"status": "already_deleted"}
    
    # Remove room
    del _rooms[room_key]
    
    # Remove from user's active rooms
    if user_id in _user_active_rooms and _user_active_rooms[user_id] == room_key:
        del _user_active_rooms[user_id]
    
    print(f"🗑️ Room deleted: {room_key}")
    
    return {"status": "deleted", "room_code": room_code}

@router.post("/{room_code}/leave")
def notify_user_left(room_code: str, payload: dict):
    """Notify that a user left the room"""
    user_id = payload.get('userId')
    
    print(f"👋 User {user_id} left room {room_code}")
    
    # The actual notification is sent via PROTOCOL_USER_LEFT_ROOM message
    # This endpoint is just for logging/tracking
    
    return {"status": "notified"}

@router.get("/debug")
def debug_rooms():
    """Debug endpoint to see all active rooms"""
    return {
        "active_rooms": _rooms,
        "user_active_rooms": _user_active_rooms
    }