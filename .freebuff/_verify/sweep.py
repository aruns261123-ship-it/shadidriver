import re
import subprocess
import sys
import time

sys.stdout.reconfigure(encoding="utf-8")

ADB = r"C:\Users\anime\AppData\Local\Android\Sdk\platform-tools\adb.exe"
PKG = "in.shadidriver.app"


def sh(*args, binary=False):
    out = subprocess.run([ADB, *args], capture_output=True)
    if binary:
        return out.stdout
    return out.stdout.decode("utf-8", "replace")


def swipe(x1, y1, x2, y2, ms=300):
    sh("shell", "input", "swipe", str(x1), str(y1), str(x2), str(y2), str(ms))


def dump_texts():
    sh("shell", "uiautomator", "dump", "/sdcard/wd.xml")
    raw = sh("exec-out", "cat", "/sdcard/wd.xml")
    texts = []
    for t in re.findall(r'content-desc="([^"]*)"', raw):
        t = t.replace("&#10;", " / ").replace("&#39;", "'")
        if t.strip():
            texts.append(t)
    for t in re.findall(r'text="([^"]*)"', raw):
        if t.strip():
            texts.append(t)
    return texts


def overflow_lines():
    out = sh("shell", "logcat", "-d")
    keep = []
    for line in out.splitlines():
        low = line.lower()
        if "overflow" in low or "renderflex" in low:
            keep.append(line.strip())
    return keep


def main():
    label = sys.argv[1] if len(sys.argv) > 1 else "run"
    sh("shell", "logcat", "-c")
    sh("shell", "am", "force-stop", PKG)
    sh("shell", "am", "start", "-n", f"{PKG}/.MainActivity")
    time.sleep(10)
    seen = []
    # walk the feed downward, sampling text at each stop
    for step in range(14):
        for t in dump_texts():
            if t not in seen:
                seen.append(t)
        swipe(1050, 1900, 1050, 800, 400)
        time.sleep(0.7)
    # and back up
    for _ in range(20):
        swipe(1050, 800, 1050, 1900, 400)
        time.sleep(0.4)
    time.sleep(1)
    print(f"=== [{label}] unique visible text ({len(seen)}) ===")
    for t in seen:
        print("  -", t)
    ov = overflow_lines()
    print(f"=== [{label}] overflow logcat lines: {len(ov)} ===")
    for line in ov[:25]:
        print("  !", line)


main()
