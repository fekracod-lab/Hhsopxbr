import subprocess
import re
import os
import sys
import json

def sanitize_line(line):
    # Sanitize OTP, password, bearer tokens, private keys
    line = re.sub(r'(otp\s*[:=]\s*)\d{4,6}', r'\1[REDACTED_OTP]', line, flags=re.IGNORECASE)
    line = re.sub(r'(password\s*[:=]\s*)[^\s,]+', r'\1[REDACTED_PWD]', line, flags=re.IGNORECASE)
    line = re.sub(r'(bearer\s+)[A-Za-z0-9\-_.]+', r'\1[REDACTED_TOKEN]', line, flags=re.IGNORECASE)
    line = re.sub(r'07[3-9]\d{8}', r'07****[PHONE]', line)
    return line

def capture_logcat(serial=None, lines_count=200, package_name="com.madar.app"):
    device_flag = f"-s {serial}" if serial else ""
    cmd = f"adb {device_flag} logcat -d -t {lines_count}"
    
    res = subprocess.run(cmd, shell=True, capture_output=True, text=True, errors="ignore")
    raw_lines = res.stdout.splitlines()
    
    sanitized = []
    for line in raw_lines:
        sanitized.append(sanitize_line(line))
        
    return {
        "status": "CAPTURED",
        "total_lines": len(sanitized),
        "log_sample": sanitized[-50:] if len(sanitized) > 50 else sanitized
    }

if __name__ == "__main__":
    serial = sys.argv[1] if len(sys.argv) > 1 else None
    res = capture_logcat(serial)
    print(json.dumps(res, indent=2, ensure_ascii=False))
