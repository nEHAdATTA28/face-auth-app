import subprocess
import os
import time
from cryptography.fernet import Fernet

# --- CONFIGURATION ---
ADB_PATH = r"C:\Users\nehad\AppData\Local\Android\Sdk\platform-tools\adb.exe"
REMOTE_FILE = "/sdcard/test.txt"          # The file that gets encrypted
LOCAL_TEMP = "temp_file.txt"
KEY_FILE = "secret.key"
CAMERA_FOLDER = "/sdcard/DCIM/Camera/"    # Folder where the face app saves photos
# --------------------

def send_ui_alert(title, message):
    """Show a VERY CLEAR notification on the emulator screen."""
    try:
        # This creates a high-priority system notification that pops up instantly
        subprocess.run(
            [ADB_PATH, "shell", "cmd", "notification", "post", 
             "-t", title, 
             "-m", message],
            check=True, capture_output=True
        )
        print(f"[UI] ✅ Notification sent: {title}")
    except Exception as e:
        print(f"[UI] ⚠️ Could not send notification (fallback: console log): {e}")
        # Fallback: just print clearly in terminal
        print("\n" + "="*50)
        print(f"🔴 {title.upper()}")
        print(f"📄 {message}")
        print("="*50 + "\n")

def encrypt_test_file():
    """Pull, encrypt, and push back test.txt."""
    print("[*] 🔐 Encrypting /sdcard/test.txt...")
    try:
        # 1. Pull
        subprocess.run([ADB_PATH, "pull", REMOTE_FILE, LOCAL_TEMP], check=True)
        # 2. Generate key & encrypt
        key = Fernet.generate_key()
        cipher = Fernet(key)
        with open(LOCAL_TEMP, "rb") as f:
            data = f.read()
        encrypted_data = cipher.encrypt(data)
        with open(LOCAL_TEMP, "wb") as f:
            f.write(encrypted_data)
        # 3. Push back
        subprocess.run([ADB_PATH, "push", LOCAL_TEMP, REMOTE_FILE], check=True)
        # 4. Save key
        with open(KEY_FILE, "wb") as f:
            f.write(key)
        os.remove(LOCAL_TEMP)
        print("[+] ✅ test.txt encrypted successfully!")
        return True
    except Exception as e:
        print(f"[-] ❌ Encryption failed: {e}")
        return False

def get_camera_photos():
    """List existing photos in the emulator's camera folder."""
    result = subprocess.run([ADB_PATH, "shell", "ls", CAMERA_FOLDER], 
                            capture_output=True, text=True)
    if result.returncode != 0:
        return set()
    files = result.stdout.splitlines()
    # Filter only image files
    return {f for f in files if f.lower().endswith(('.jpg', '.jpeg', '.png'))}

def main():
    print("\n" + "="*50)
    print("📱 FACE AUTH → CLASS B TRIGGER SYSTEM")
    print("="*50)
    print("[*] Waiting for the face app to capture a photo...")
    print("[*] ANY new photo will be treated as 'Class B'")
    print("[*] This will encrypt /sdcard/test.txt and show a UI alert!")
    print("[*] Press Ctrl+C to stop.\n")

    # Initial snapshot of existing photos
    seen_photos = get_camera_photos()

    try:
        while True:
            current_photos = get_camera_photos()
            new_photos = current_photos - seen_photos

            if new_photos:
                # A new photo was captured → treat as Class B
                print(f"\n[!] 📸 Class B Person Detected! (New photo captured)")
                
                # 1. Encrypt the test.txt file
                success = encrypt_test_file()
                
                # 2. Show VERY CLEAR UI alert
                if success:
                    send_ui_alert(
                        "⚠️ CLASS B DETECTED",
                        "test.txt has been ENCRYPTED!"
                    )
                else:
                    send_ui_alert(
                        "⚠️ ENCRYPTION FAILED",
                        "Check terminal for errors!"
                    )
                
                # 3. Update the seen list so we don't re-trigger on the same photo
                seen_photos = current_photos

            time.sleep(2)  # Check every 2 seconds

    except KeyboardInterrupt:
        print("\n[*] 🛑 Monitoring stopped.")
        print("[*] To decrypt, run: python decrypt_file.py")

if __name__ == "__main__":
    main()