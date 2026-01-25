import os
from sqlalchemy.orm import sessionmaker, declarative_base
from contextlib import contextmanager
from sqlalchemy import create_engine, text  # <-- add text here

from app.models.base import Base

# =========================
# CONFIGURATION
# =========================

# For testing, using the user we created: vaultchat_user / taha123
# In production, you should use environment variables
DB_USER = os.getenv("DB_USER", "vaultchat_user")
DB_PASS = os.getenv("DB_PASS", "taha123")
DB_HOST = os.getenv("DB_HOST", "localhost")
DB_PORT = os.getenv("DB_PORT", "5432")
DB_NAME = os.getenv("DB_NAME", "vaultchat")

# Build PostgreSQL connection URL
DATABASE_URL = f"postgresql://{DB_USER}:{DB_PASS}@{DB_HOST}:{DB_PORT}/{DB_NAME}"

# =========================
# ENGINE CONFIGURATION
# =========================

engine = create_engine(
    DATABASE_URL,
    pool_pre_ping=True,  # Check connections before using them
    pool_size=5,         # Maintain 5 connections in the pool
    max_overflow=10,     # Allow 10 extra connections if needed
    pool_recycle=3600,   # Recycle connections every hour
    echo=False           # Set True to see SQL statements (debugging)
)

# =========================
# SESSION CONFIGURATION
# =========================

SessionLocal = sessionmaker(
    autocommit=False,
    autoflush=False,
    bind=engine
)

# =========================
# DATABASE FUNCTIONS
# =========================

def get_db():
    """
    FastAPI dependency to provide a DB session to routes.
    Usage:
        def my_route(db: Session = Depends(get_db)):
            ...
    """
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()


@contextmanager
def db_session():
    """
    Context manager for standalone DB operations.
    Usage:
        with db_session() as db:
            user = db.query(User).first()
    """
    session = SessionLocal()
    try:
        yield session
        session.commit()
    except Exception as e:
        session.rollback()
        raise e
    finally:
        session.close()


def init_db():
    """
    Create all tables based on registered models.
    Call this after adding your models (User, Message, etc.).
    """
    # Import models here to register them with Base
    # from app.models.user_model import User
    # from app.models.message_model import Message
    Base.metadata.create_all(bind=engine)
    print("✅ Database tables created successfully")


def test_connection():
    """
    Test DB connection.
    """
    try:
        with engine.connect() as conn:
            conn.execute(text("SELECT 1"))  # <-- wrap in text()
            print("✅ Database connection successful")
            return True
    except Exception as e:
        print(f"❌ Database connection failed: {e}")
        return False


# =========================
# EXAMPLE USAGE
# =========================

if __name__ == "__main__":
    # Test connection
    test_connection()

    # Example 1: Using context manager
    print("\n--- Example 1: Context Manager ---")
    try:
        with db_session() as db:
            # Example: db.query(User).all()
            print("Database session opened and closed automatically")
    except Exception as e:
        print(f"Error: {e}")

    # Example 2: Manual session management
    print("\n--- Example 2: Manual Session ---")
    db = SessionLocal()
    try:
        # Example: users = db.query(User).all()
        db.commit()
        print("Manual session - don't forget to close!")
    except Exception as e:
        db.rollback()
        print(f"Error: {e}")
    finally:
        db.close()
