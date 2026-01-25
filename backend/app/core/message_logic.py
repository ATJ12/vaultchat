from datetime import datetime, timedelta

DEFAULT_TTL_SECONDS = 30

def is_expired(created_at: datetime) -> bool:
    return datetime.utcnow() > created_at + timedelta(seconds=DEFAULT_TTL_SECONDS)
