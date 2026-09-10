"""模拟器走查辅助：截图 → 缩放 → 存 png/jpg（与 build/audit_shots 既有约定一致）。

用法：
    python scripts/shots.py <编号_名称>

为什么缩放：原始截图 1080x2400，直接查看不便；既有 audit_shots 目录里的图也
都是缩过的（宽约 540），保持一致。
"""
import io
import os
import subprocess
import sys
import tempfile

SHOTS = os.path.normpath(
    os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "build", "audit_shots"))
TARGET_W = 540
REMOTE = "/sdcard/_mt_shot.png"


def grab_raw() -> bytes:
    """取一帧原始 PNG 字节。

    刻意不用 `adb exec-out screencap -p`：Windows 上该命令的输出流会经过换行转换，
    把 PNG 中的 0x0A 字节改写成 0x0D0A，导致文件损坏
    （PIL 报 cannot identify image file）。改为设备端落盘再 pull，字节级完整。
    """
    local = os.path.join(tempfile.gettempdir(), "_mt_shot.png")
    if os.path.exists(local):
        os.remove(local)
    subprocess.run(["adb", "shell", "screencap", "-p", REMOTE],
                   check=True, capture_output=True)
    subprocess.run(["adb", "pull", REMOTE, local], check=True, capture_output=True)
    with open(local, "rb") as f:
        return f.read()


def capture(name: str) -> str:
    os.makedirs(SHOTS, exist_ok=True)
    raw = grab_raw()

    from PIL import Image
    img = Image.open(io.BytesIO(raw))
    w, h = img.size
    # 该模拟器存在第二个（未激活的）display，screencap 未指定 display id 时
    # 会给出 "Multiple displays were found" 警告且不保证每次抓到同一屏。
    # 主屏固定为 1080x2400，尺寸不符即说明抓错屏，宁可报错也不要存下误导性的图。
    if (w, h) != (1080, 2400):
        raise RuntimeError(f"抓到的分辨率 {w}x{h} 不是主屏 1080x2400，请重跑")
    nh = int(h * TARGET_W / w)
    img = img.convert("RGB").resize((TARGET_W, nh), Image.LANCZOS)

    out_png = os.path.join(SHOTS, f"{name}.png")
    img.save(out_png)
    img.save(os.path.join(SHOTS, f"{name}.jpg"), quality=88)
    print(f"{name}: {w}x{h} -> {TARGET_W}x{nh}")
    return out_png


if __name__ == "__main__":
    if len(sys.argv) < 2:
        raise SystemExit("用法: python scripts/shots.py <编号_名称>")
    capture(sys.argv[1])
