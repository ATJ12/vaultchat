# app/infra/init_db.py

from app.infra.postgres import Base, engine
from app.models.user import User
from app.models.message import Message

def init_db():
    """Create all tables in the database"""
    print("Creating database tables...")
    Base.metadata.create_all(bind=engine)
    print("✓ Tables created successfully!")

if __name__ == "__main__":
    init_db()