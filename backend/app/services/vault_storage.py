from app.infra.s3 import upload_encrypted_blob

def backup_encrypted_chat(user_id: str, encrypted_blob: bytes):
    upload_encrypted_blob(
        bucket="vault-backups",
        key=f"{user_id}/backup.bin",
        data=encrypted_blob
    )
