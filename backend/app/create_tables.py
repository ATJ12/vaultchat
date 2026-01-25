# app/create_tables.py
from app.infra.postgres import Base, engine
from app.models.user import User

def init_db():
    Base.metadata.create_all(bind=engine)
    print("Tables created!")

if __name__ == "__main__":
    init_db()
