def detect_class_b():
    # For now, always returns True (Class B detected every time)
    return True

def main():
    if detect_class_b():
        print("[ALERT] Class B detected! Executing synthetic response...")
        from encrypt_file import encrypt_file
        encrypt_file()
    else:
        print("No threat detected.")

if __name__ == "__main__":
    main()