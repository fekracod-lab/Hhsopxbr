import subprocess
import os
import sys
import json

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

def install_apk(serial=None, apk_path=None):
    if not apk_path:
        apk_path = os.path.join(ROOT, "build", "app", "outputs", "flutter-apk", "app-release.apk")
    
    if not os.path.exists(apk_path):
        return {
            "status": "FAILED",
            "reason": f"APK not found at {apk_path}. Run 'flutter build apk --release' first."
        }
    
    device_flag = f"-s {serial}" if serial else ""
    cmd = f"adb {device_flag} install -r -d \"{apk_path}\""
    print(f"Executing: {cmd}")
    
    res = subprocess.run(cmd, shell=True, capture_output=True, text=True)
    if "Success" in res.stdout:
        return {
            "status": "SUCCESS",
            "apk_path": apk_path,
            "stdout": res.stdout.strip()
        }
    else:
        return {
            "status": "FAILED",
            "stdout": res.stdout.strip(),
            "stderr": res.stderr.strip()
        }

if __name__ == "__main__":
    serial = sys.argv[1] if len(sys.argv) > 1 else None
    res = install_apk(serial)
    print(json.dumps(res, indent=2))
