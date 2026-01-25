from cryptography.hazmat.primitives.asymmetric import x25519
from cryptography.hazmat.primitives.kdf.hkdf import HKDF
from cryptography.hazmat.primitives import hashes
from cryptography.hazmat.primitives.ciphers.aead import AESGCM
import os

# ---------- KEY DERIVATION ----------

def derive_shared_key(
    private_key_bytes: bytes,
    peer_public_key_bytes: bytes,
    salt: bytes | None = None
) -> bytes:
    """
    X25519 + HKDF → 32-byte AES-256 key
    """
    private_key = x25519.X25519PrivateKey.from_private_bytes(private_key_bytes)
    peer_public_key = x25519.X25519PublicKey.from_public_bytes(peer_public_key_bytes)

    shared_secret = private_key.exchange(peer_public_key)

    return HKDF(
        algorithm=hashes.SHA256(),
        length=32,
        salt=salt,
        info=b"vault-chat-v1"
    ).derive(shared_secret)


# ---------- ENCRYPTION ----------

def encrypt_vault_message(key: bytes, plaintext: bytes) -> bytes:
    """
    AES-GCM → nonce (12) + ciphertext + tag (16)
    """
    aesgcm = AESGCM(key)
    nonce = os.urandom(12)
    ciphertext = aesgcm.encrypt(nonce, plaintext, None)
    return nonce + ciphertext


def decrypt_vault_message(key: bytes, encrypted_payload: bytes) -> bytes:
    """
    Decrypt AES-GCM payload
    """
    nonce = encrypted_payload[:12]
    ciphertext = encrypted_payload[12:]
    aesgcm = AESGCM(key)
    return aesgcm.decrypt(nonce, ciphertext, None)
