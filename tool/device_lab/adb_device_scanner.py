import subprocess
import json
import os
import re

def run_cmd(cmd):
    try:
        res = subprocess.run(cmd, capture_output=True, text=True, shell=True)
        return res.stdout.strip(), res.stderr.strip(), res.returncode
    except Exception as e:
        return "", str(e), 1

def scan_devices():
    stdout, stderr, code = run_cmd("adb devices -l")
    devices = []
    
    if code != 0 or not stdout:
        return {
            "status": "ERROR",
            "error": stderr or "ADB not found or failed",
            "connected_count": 0,
            "devices": []
        }

    lines = stdout.splitlines()
    for line in lines[1:]:
        line = line.strip()
        if not line:
            continue
        parts = re.split(r'\s+', line)
        if len(parts) >= 2:
            serial = parts[0]
            state = parts[1]
            if state != "device":
                continue
            
            # Fetch detailed device characteristics
            model, _, _ = run_cmd(f"adb -s {serial} shell getprop ro.product.model")
            manufacturer, _, _ = run_cmd(f"adb -s {serial} shell getprop ro.product.manufacturer")
            android_ver, _, _ = run_cmd(f"adb -s {serial} shell getprop ro.build.version.release")
            sdk_ver, _, _ = run_cmd(f"adb -s {serial} shell getprop ro.build.version.sdk")
            abi, _, _ = run_cmd(f"adb -s {serial} shell getprop ro.product.cpu.abi")
            
            # Battery info
            battery_raw, _, _ = run_cmd(f"adb -s {serial} shell dumpsys battery")
            level_match = re.search(r'level:\s*(\d+)', battery_raw)
            battery_level = int(level_match.group(1)) if level_match else None
            
            # Screen resolution
            wm_size, _, _ = run_cmd(f"adb -s {serial} shell wm size")
            res_match = re.search(r'Physical size:\s*(\d+x\d+)', wm_size)
            resolution = res_match.group(1) if res_match else wm_size
            
            devices.append({
                "serial": serial,
                "state": state,
                "model": model or "Unknown",
                "manufacturer": manufacturer or "Unknown",
                "android_version": android_ver or "Unknown",
                "sdk_version": sdk_ver or "Unknown",
                "abi": abi or "Unknown",
                "battery_level_percent": battery_level,
                "screen_resolution": resolution,
                "is_emulator": "emulator" in serial.lower() or "generic" in model.lower()
            })

    status = "SUCCESS" if devices else "NO_DEVICES"
    return {
        "status": status,
        "connected_count": len(devices),
        "devices": devices,
        "rule_zero_notice": "NOT EXECUTED — NO PHYSICAL DEVICE AVAILABLE" if len(devices) == 0 else "DEVICES_ONLINE"
    }

if __name__ == "__main__":
    result = scan_devices()
    print(json.dumps(result, indent=2, ensure_ascii=False))
