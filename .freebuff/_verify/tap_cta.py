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
    for node in re.findall(r"<node[^>]*?>", raw):
        d = re.search(r'(?:content-desc|text)="([^"]*)"', node)
        if d and d.group(1).startswith(label):
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


raw = dump()
print("home text at start:", texts(raw)[:4])

bounds = None
for step in range(9):
    bounds = find("Find a Chauffeur", raw)
    if bounds:
        print(f"CTA surfaced after {step} swipe(s)")
        break
    sh("shell", "input", "swipe", "1050", "1800", "1050", "700", "400")
    time.sleep(1.5)
    raw = dump()

print("CTA bounds:", bounds)
if not bounds:
    print("!! CTA not found; screen text:")
    for t in texts(raw):
        print("  -", t)
    sys.exit(0)

x = (bounds[0] + bounds[2]) // 2
y = (bounds[1] + bounds[3]) // 2
sh("shell", "logcat", "-c")
sh("shell", "input", "tap", str(x), str(y))
time.sleep(7)
after = dump()
print(f"--- after tapping CTA at ({x},{y}) ---")
for t in texts(after)[:30]:
    print("  -", t)
ov = overflow()
print("overflow lines after tap:", len(ov))
for line in ov[:15]:
    print("  !", line)
