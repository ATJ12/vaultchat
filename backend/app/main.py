# app/main.py

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from app.api import users, messages, rooms  # Add rooms
from app.utils.logger import setup_logger

app = FastAPI(
    title="Vault Backend",
    version="1.0.0",
    description="Zero-knowledge secure messaging backend"
)

# CORS
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

setup_logger()

# Register routers
app.include_router(users.router, tags=["Users"])
app.include_router(messages.router, tags=["Messages"])
app.include_router(rooms.router, tags=["Rooms"])  # Add this

@app.get("/health")
def health_check():
    return {"status": "ok"}