# Backend package# init_db.py (in backend folder)

from app.infra.postgres import Base, engine
from app.models.user import User
from app.models.message import Message

def init_db():
    """Drop and recreate all tables"""
    print("⚠️  Dropping all tables...")
    Base.metadata.drop_all(bind=engine)
    print("✓ Tables dropped")
    
    print("📦 Creating tables...")
    Base.metadata.create_all(bind=engine)
    print("✅ Database initialized successfully!")
    
    # Print created tables
    from sqlalchemy import inspect
    inspector = inspect(engine)
    tables = inspector.get_table_names()
    print(f"\nCreated tables: {tables}")
    
    for table in tables:
        columns = inspector.get_columns(table)
        print(f"\n{table}:")
        for col in columns:
            print(f"  - {col['name']}: {col['type']}")

if __name__ == "__main__":
    init_db()