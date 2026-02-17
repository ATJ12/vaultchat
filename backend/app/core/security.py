# app/core/security.py

import pgpy
from typing import Tuple

def verify_pgp_signature(public_key_text: str, signature_text: str, data: str) -> bool:
    """
    Verify a PGP signature for a given data string using the provided public key.
    """
    try:
        # Load the public key
        key, _ = pgpy.PGPKey.from_blob(public_key_text)
        
        # Load the signature
        sig = pgpy.PGPSignature.from_blob(signature_text)
        
        # Verify the signature against the data
        # Note: In PGP, cleartext signatures are common, but here we expect a detached signature
        # for simplicity in our API.
        verify = key.verify(data, sig)
        return bool(verify)
    except Exception as e:
        print(f"Signature verification failed: {e}")
        return False
