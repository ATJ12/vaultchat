# app/models/user.py

from sqlalchemy import Column, Integer, LargeBinary
from app.infra.postgres import Base

class User(Base):
    __tablename__ = "users"

    id = Column(Integer, primary_key=True, index=True)
    user_id_hash = Column(LargeBinary, unique=True, nullable=False, index=True)
    public_key = Column(LargeBinary, nullable=False)