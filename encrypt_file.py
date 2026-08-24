import subprocess
import os
from cryptography.fernet import Fernet

# --- HARDCODED ADB PATH ---
ADB_PATH = r"C:\Users\nehad\AppData\Local\Android\Sdk\platform-tools\adb.exe"
# ---------------------------

REMOTE_FILE = "/sdcard/test.txt"
LOCAL_TEMP = "temp_file.txt"
KEY_FILE = "secret.key"

def encrypt_file():
    print("[*] Pulling file from emulator...")
    subprocess.run([ADB_PATH, "pull", REMOTE_FILE, LOCAL_TEMP], check=True)

    key = Fernet.generate_key()
    cipher = Fernet(key)

    with open(LOCAL_TEMP, "rb") as f:
        file_data = f.read()
    
    encrypted_data = cipher.encrypt(file_data)

    with open(LOCAL_TEMP, "wb") as f:
        f.write(encrypted_data)

    print("[*] Pushing encrypted file back to emulator...")
    subprocess.run([ADB_PATH, "push", LOCAL_TEMP, REMOTE_FILE], check=True)

    with open(KEY_FILE, "wb") as f:
        f.write(key)
    
    print(f"[+] File '{REMOTE_FILE}' successfully encrypted!")
    print(f"[+] Decryption key saved to '{KEY_FILE}'")
    
    os.remove(LOCAL_TEMP)

if __name__ == "__main__":
    encrypt_file()