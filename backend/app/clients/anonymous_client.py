# app/clients/anonymous_client.py

import requests
import os
import time
import random
from cryptography.hazmat.primitives.asymmetric import x25519
from cryptography.hazmat.primitives import hashes
from cryptography.hazmat.primitives.kdf.hkdf import HKDF
from cryptography.hazmat.primitives.ciphers.aead import AESGCM

# =========================
# CONFIGURATION
# =========================

TOR_PROXY = {
    'http': 'socks5h://127.0.0.1:9050',
    'https': 'socks5h://127.0.0.1:9050'
}

SERVER_URL = "http://127.0.0.1:8000"  # change to .onion for Tor backend
PADDED_MESSAGE_SIZE = 64 * 1024       # 64 KB fixed message size for metadata obfuscation
MIN_DELAY_MS = 100                     # minimum random delay
MAX_DELAY_MS = 2000                    # maximum random delay

# =========================
# TOR SESSION
# =========================

def create_tor_session():
    """Create a requests session that routes through Tor"""
    session = requests.Session()
    session.proxies = TOR_PROXY
    return session

# =========================
# METADATA OBFUSCATION
# =========================

def pad_message(message_bytes: bytes) -> bytes:
    """Pad message to fixed size to prevent length-based analysis"""
    actual_length = len(message_bytes)
    if actual_length > PADDED_MESSAGE_SIZE - 4:
        raise ValueError("Message too large")
    length_prefix = actual_length.to_bytes(4, 'big')
    padding = os.urandom(PADDED_MESSAGE_SIZE - 4 - actual_length)
    return length_prefix + message_bytes + padding

def unpad_message(padded_bytes: bytes) -> bytes:
    """Extract original message from padded data"""
    length = int.from_bytes(padded_bytes[:4], 'big')
    return padded_bytes[4:4+length]

def random_delay(min_ms=MIN_DELAY_MS, max_ms=MAX_DELAY_MS):
    """Random delay to prevent timing analysis"""
    time.sleep(random.uniform(min_ms / 1000, max_ms / 1000))

# =========================
# CRYPTO FUNCTIONS
# =========================

def derive_session_key(private_key: x25519.X25519PrivateKey, 
                       peer_public_key_bytes: bytes) -> bytes:
    """Derive a 32-byte AES key from X25519 exchange using HKDF"""
    peer_public_key = x25519.X25519PublicKey.from_public_bytes(peer_public_key_bytes)
    shared_secret = private_key.exchange(peer_public_key)
    return HKDF(
        algorithm=hashes.SHA256(),
        length=32,
        salt=None,
        info=b"vault-chat",
    ).derive(shared_secret)

# =========================
# ANONYMOUS VAULT CLIENT
# =========================

class AnonymousVaultClient:
    def __init__(self, user_id: str, use_tor=True, enable_padding=True, enable_delays=True):
        self.user_id = user_id
        self.use_tor = use_tor
        self.enable_padding = enable_padding
        self.enable_delays = enable_delays

        # Generate ephemeral key pair
        self.private_key = x25519.X25519PrivateKey.generate()
        self.public_key = self.private_key.public_key()

        # Session for HTTP requests
        self.session = create_tor_session() if use_tor else requests.Session()
        self.session_keys = {}  # cache session keys

        # Register public key on server
        self.register_public_key()

    def register_public_key(self):
        """Send public key to the server"""
        from cryptography.hazmat.primitives import serialization
        pub_bytes = self.public_key.public_bytes(
            encoding=serialization.Encoding.Raw,
            format=serialization.PublicFormat.Raw
        )
        resp = self.session.post(f"{SERVER_URL}/users/{self.user_id}",
                                 json={"public_key": pub_bytes.hex()})
        if resp.status_code == 200:
            print(f"✅ Public key registered for {self.user_id}")
        else:
            print(f"❌ Registration failed: {resp.text}")

    def get_session_key(self, recipient_id: str, recipient_pub_bytes: bytes) -> bytes:
        """Get or derive AES key for a recipient"""
        if recipient_id not in self.session_keys:
            key = derive_session_key(self.private_key, recipient_pub_bytes)
            self.session_keys[recipient_id] = key
        return self.session_keys[recipient_id]

    def send_message(self, recipient_id: str, recipient_pub_bytes: bytes, message: str):
        """Encrypt and send message to recipient anonymously"""
        key = self.get_session_key(recipient_id, recipient_pub_bytes)

        # Encrypt using AES-GCM
        aesgcm = AESGCM(key)
        nonce = os.urandom(12)
        ciphertext = aesgcm.encrypt(nonce, message.encode(), None)
        payload = nonce + ciphertext

        # Padding
        if self.enable_padding:
            payload = pad_message(payload)

        # Random delay
        if self.enable_delays:
            random_delay()

        # POST encrypted payload (no sender info!)
        resp = self.session.post(f"{SERVER_URL}/messages/send",
                                 json={"recipient": recipient_id,
                                       "ciphertext": payload.hex()})
        if resp.status_code == 200:
            print(f"✅ Message sent to {recipient_id}")
        else:
            print(f"❌ Failed to send message: {resp.text}")
        return resp.json()

    def fetch_messages(self, sender_pub_bytes_dict: dict):
        """Fetch and decrypt messages for this client"""
        resp = self.session.get(f"{SERVER_URL}/messages/{self.user_id}")
        if resp.status_code != 200:
            return []

        messages = resp.json()
        decrypted = []

        for msg in messages:
            recipient_key = self.get_session_key(msg['sender'], sender_pub_bytes_dict[msg['sender']])
            payload = bytes.fromhex(msg['ciphertext'])

            if self.enable_padding and len(payload) == PADDED_MESSAGE_SIZE:
                payload = unpad_message(payload)

            aesgcm = AESGCM(recipient_key)
            nonce = payload[:12]
            ciphertext = payload[12:]
            plaintext = aesgcm.decrypt(nonce, ciphertext, None)
            decrypted.append({"sender": msg['sender'], "message": plaintext.decode()})

        return decrypted

# =========================
# DEMO USAGE
# =========================

if __name__ == "__main__":
    print("="*60)
    print("VaultChat - Anonymous Encrypted Messaging Demo")
    print("="*60)

    # Example usage
    alice = AnonymousVaultClient("alice")
    # Fetch Bob's public key from server (simulated)
    bob_pub_bytes = bytes.fromhex("...")  # replace with actual hex
    alice.send_message("bob", bob_pub_bytes, "Hello Bob! This message is anonymous and encrypted! 🔒")
