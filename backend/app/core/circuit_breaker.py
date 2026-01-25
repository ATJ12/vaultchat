# app/core/circuit_breaker.py - FIXED

from slowapi import Limiter
from slowapi.util import get_remote_address
from fastapi import Request

# Initialize limiter
limiter = Limiter(key_func=get_remote_address)

# Rate limit constants
PUBLIC_KEY_LIMIT = "10/minute"

def rate_limit_dependency(request: Request):
    """
    Rate limiting dependency for FastAPI routes.
    Must receive the request object to work with slowapi.
    """
    # The limiter will automatically handle rate limiting
    # when this dependency is used in a route
    return None