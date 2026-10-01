import re
import subprocess
import sys
import time

sys.stdout.reconfigure(encoding="utf-8")

ADB = r"C:\Users\anime\AppData\Local\Android\Sdk\platform-tools\adb.exe"
PKG = "in.shadidriver.app"
_n = [0]


def sh(*args, timeout=30):
    try:
        return subprocess.run(
            [ADB, *args], capture_output=True, timeout=timeout
        ).stdout.decode("utf-8", "replace")
    except subprocess.TimeoutExpired:
        return ""


def texts(raw):
    out = []
    for t in re.findall(r'(?:content-desc|text)="([^"]*)"', raw):
        t = t.replace("&#10;", " / ").replace("&#39;", "'").replace("&amp;", "&")
        if t.strip():
            out.append(t)
    return out


def dump(tries=8):
    for _ in range(tries):
        _n[0] += 1
        remote = f"/data/local/tmp/v{_n[0]}.xml"
        if "dumped to" not in sh("shell", "uiautomator", "dump", remote):
            time.sleep(1)
            continue
        raw = sh("exec-out", "cat", remote)
        sh("shell", "rm", "-f", remote)
        if len(raw) > 400 and "<node" in raw and texts(raw):
            return raw
        time.sleep(1)
    return ""


def find(label, raw):
    """Match on the node's own label; prefer content-desc, fall back to text."""
    for node in re.findall(r"<node[^>]*?>", raw):
        cd = re.search(r'content-desc="([^"]*)"', node)
        tx = re.search(r'text="([^"]*)"', node)
        own = (cd.group(1) if cd and cd.group(1).strip() else None) or (
            tx.group(1) if tx and tx.group(1).strip() else None
        )
        if own and own.startswith(label):
            b = re.search(r'bounds="\[(\d+),(\d+)\]\[(\d+),(\d+)\]"', node)
            if b:
                return tuple(int(b.group(i)) for i in range(1, 5))
    return None


def overflow():
    return [
        l.strip()
        for l in sh("shell", "logcat", "-d", timeout=40).splitlines()
        if "overflow" in l.lower() or "renderflex" in l.lower()
    ]


def tap_cta(max_steps=16, swipe="1050", y1="1900", y2="1750"):
    for i in range(max_steps):
        raw = dump()
        b = find("Find a Chauffeur", raw)
        print(f"step {i}: CTA={'yes ' + str(b) if b else 'no'}")
        if b:
            return b
        sh("shell", "input", "swipe", swipe, y1, swipe, y2, "300")
        time.sleep(0.9)
    return None


def main():
    b = tap_cta()
    if not b:
        print("!! CTA never surfaced")
        sys.exit(1)
    x = (b[0] + b[2]) // 2
    y = (b[1] + b[3]) // 2
    sh("shell", "logcat", "-c")
    sh("shell", "input", "tap", str(x), str(y))
    time.sleep(8)
    after = dump()
    print(f"--- after tapping CTA at ({x},{y}) ---")
    for t in texts(after)[:30]:
        print("  -", t)
    ov = overflow()
    print("overflow lines after tap:", len(ov))
    for line in ov[:15]:
        print("  !", line)


main()
