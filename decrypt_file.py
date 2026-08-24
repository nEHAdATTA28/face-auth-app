import subprocess
import os
from cryptography.fernet import Fernet

# --- HARDCODED ADB PATH ---
ADB_PATH = r"C:\Users\nehad\AppData\Local\Android\Sdk\platform-tools\adb.exe"
# ---------------------------

REMOTE_FILE = "/sdcard/test.txt"
LOCAL_TEMP = "temp_file.txt"
KEY_FILE = "secret.key"

def decrypt_file():
    print("[*] Pulling encrypted file from emulator...")
    subprocess.run([ADB_PATH, "pull", REMOTE_FILE, LOCAL_TEMP], check=True)

    with open(KEY_FILE, "rb") as f:
        key = f.read()
    cipher = Fernet(key)

    with open(LOCAL_TEMP, "rb") as f:
        encrypted_data = f.read()
    
    decrypted_data = cipher.decrypt(encrypted_data)

    with open(LOCAL_TEMP, "wb") as f:
        f.write(decrypted_data)

    print("[*] Pushing decrypted file back to emulator...")
    subprocess.run([ADB_PATH, "push", LOCAL_TEMP, REMOTE_FILE], check=True)

    print(f"[+] File '{REMOTE_FILE}' successfully decrypted and restored!")
    os.remove(LOCAL_TEMP)

if __name__ == "__main__":
    decrypt_file()