"""模拟器走查辅助：截图 -> 缩放 -> 存 png/jpg。
避免 Windows 上 `adb exec-out` 把 PNG 0x0A 改 0x0D0A 损坏；
落盘再 pull，字节级完整。目标存 build/audit_shots/。
"""
import io
import os
import subprocess
import sys

ADB = "D:/dev/Android/Sdk/platform-tools/adb.exe"
DEVICE = "emulator-5554"
SHOTS = "D:/FlutterProjects/MicroTrip/build/audit_shots"
REMOTE = "/sdcard/_mt_shot.png"
TARGET_W = 540
EXPECT = (1080, 1920)  # 主屏物理分辨率


def capture(name: str) -> str:
    os.makedirs(SHOTS, exist_ok=True)
    from PIL import Image
    subprocess.run([ADB, "-s", DEVICE, "shell", "screencap", "-p", REMOTE],
                   check=True, capture_output=True)
    local = os.path.join(SHOTS, "_raw.png")
    subprocess.run([ADB, "-s", DEVICE, "pull", REMOTE, local],
                   check=True, capture_output=True)
    img = Image.open(local)
    if img.size != EXPECT:
        print(f"WARN: 抓到 {img.size}，期望主屏 {EXPECT}（多 display 抓错屏？）")
    w, h = img.size
    img = img.convert("RGB").resize((TARGET_W, int(h * TARGET_W / w)), Image.LANCZOS)
    out = os.path.join(SHOTS, f"{name}.png")
    img.save(out)
    img.save(os.path.join(SHOTS, f"{name}.jpg"), quality=88)
    print(f"{name}: {w}x{h} -> {img.size}  ({out})")
    return out


if __name__ == "__main__":
    capture(sys.argv[1])
