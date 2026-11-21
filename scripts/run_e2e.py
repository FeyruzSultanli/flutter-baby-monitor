#!/usr/bin/env python3
"""Two-device end-to-end test runner (Android emulators + Firebase emulators).

1. Starts the Firebase Emulator Suite (scripts/firebase_emulators.sh) if it is
   not running and wipes its Firestore/Auth data.
2. Boots the AVDs "baby" and "parent" (headless) if they are not running.
3. Installs a debug APK built with USE_FIREBASE_EMULATOR=true with all runtime
   permissions granted (adb install -g + adb shell pm grant).
4. Runs integration_test/baby_test.dart on the baby emulator, waits until it
   created a room (E2E_BABY_READY), then runs parent_test.dart on the parent.
5. Watches logcat of both devices for markers printed by the tests:
     E2E_SCREENSHOT:<name> -> adb exec-out screencap -p
     E2E_HOST:<action>     -> airplane_on / airplane_off on that device
     E2E_RESULT:<k>=<v>    -> summary
6. Writes everything to test-results/<timestamp>/ (git-ignored).

Usage: python3 scripts/run_e2e.py [--no-build] [--keep-data]
"""

from __future__ import annotations

import argparse
import datetime as dt
import json
import os
import re
import socket
import subprocess
import sys
import threading
import time
import urllib.request
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SDK = Path(os.environ.get("ANDROID_HOME", Path.home() / "Library/Android/sdk"))
ADB = str(SDK / "platform-tools/adb")
EMULATOR = str(SDK / "emulator/emulator")
PROJECT = "bebekmonitor-282fd"
PACKAGE = "com.example.bebek_monitor_clean"
DEFINE = "--dart-define=USE_FIREBASE_EMULATOR=true"
PERMISSIONS = [
    "android.permission.CAMERA",
    "android.permission.RECORD_AUDIO",
    "android.permission.POST_NOTIFICATIONS",
    "android.permission.ACCESS_FINE_LOCATION",
    "android.permission.ACCESS_COARSE_LOCATION",
    "android.permission.NEARBY_WIFI_DEVICES",
    "android.permission.BLUETOOTH_SCAN",
    "android.permission.BLUETOOTH_CONNECT",
    "android.permission.BLUETOOTH_ADVERTISE",
]
MARKER = re.compile(r"E2E_(SCREENSHOT|HOST|RESULT|LOG|BABY_READY|DONE)(?::(.*))?")


def log(msg: str) -> None:
    print(f"[{dt.datetime.now():%H:%M:%S}] {msg}", flush=True)


def run(cmd: list[str], **kw) -> subprocess.CompletedProcess:
    return subprocess.run(cmd, text=True, capture_output=True, **kw)


def port_open(port: int) -> bool:
    with socket.socket() as s:
        s.settimeout(0.5)
        return s.connect_ex(("127.0.0.1", port)) == 0


def http_delete(url: str) -> None:
    """DELETE with retries (the emulators answer 499 while reloading functions)."""
    for attempt in range(6):
        try:
            req = urllib.request.Request(url, method="DELETE", headers={"Authorization": "Bearer owner"})
            urllib.request.urlopen(req, timeout=10).read()
            return
        except Exception as e:  # noqa: BLE001
            log(f"DELETE {url} failed ({e}), retry {attempt + 1}")
            time.sleep(3)
    raise SystemExit(f"Could not wipe emulator data: {url}")


def ensure_firebase_emulators(out: Path) -> subprocess.Popen | None:
    if port_open(8080) and port_open(9099):
        log("Firebase emulators already running")
        return None
    log("Starting Firebase emulators")
    logf = open(out / "firebase_emulators.log", "w")
    proc = subprocess.Popen([str(ROOT / "scripts/firebase_emulators.sh")], stdout=logf, stderr=subprocess.STDOUT)
    for _ in range(120):
        if port_open(8080) and port_open(9099) and port_open(5001):
            time.sleep(3)
            return proc
        time.sleep(1)
    raise SystemExit("Firebase emulators did not start (see firebase_emulators.log)")


def wipe_emulator_data() -> None:
    http_delete(f"http://127.0.0.1:8080/emulator/v1/projects/{PROJECT}/databases/(default)/documents")
    http_delete(f"http://127.0.0.1:9099/emulator/v1/projects/{PROJECT}/accounts")
    log("Emulator data wiped")


def running_avds() -> dict[str, str]:
    serials = [l.split()[0] for l in run([ADB, "devices"]).stdout.splitlines()[1:] if l.strip().endswith("device")]
    found = {}
    for s in serials:
        if not s.startswith("emulator-"):
            continue
        name = run([ADB, "-s", s, "emu", "avd", "name"]).stdout.splitlines()
        if name:
            found[name[0].strip()] = s
    return found


def boot_avd(name: str, out: Path) -> str:
    avds = running_avds()
    if name in avds:
        return avds[name]
    log(f"Booting AVD {name}")
    logf = open(out / f"emulator_{name}.log", "w")
    subprocess.Popen(
        [EMULATOR, "-avd", name, "-no-window", "-no-audio", "-no-boot-anim", "-no-snapshot",
         "-gpu", "swiftshader_indirect", "-camera-back", "emulated", "-camera-front", "emulated"],
        stdout=logf, stderr=subprocess.STDOUT)
    for _ in range(300):
        avds = running_avds()
        if name in avds:
            serial = avds[name]
            if run([ADB, "-s", serial, "shell", "getprop", "sys.boot_completed"]).stdout.strip() == "1":
                time.sleep(5)
                return serial
        time.sleep(2)
    raise SystemExit(f"AVD {name} did not boot")


def prepare_device(serial: str, apk: Path) -> None:
    run([ADB, "-s", serial, "shell", "cmd", "connectivity", "airplane-mode", "disable"])
    r = run([ADB, "-s", serial, "install", "-r", "-g", str(apk)])
    log(f"{serial}: install {r.stdout.strip().splitlines()[-1] if r.stdout.strip() else r.stderr.strip()}")
    grant(serial)
    run([ADB, "-s", serial, "shell", "pm", "clear", PACKAGE])  # fresh app data (alert history etc.)
    grant(serial)
    run([ADB, "-s", serial, "shell", "dumpsys", "deviceidle", "whitelist", f"+{PACKAGE}"])


def grant(serial: str) -> None:
    for p in PERMISSIONS:
        run([ADB, "-s", serial, "shell", "pm", "grant", PACKAGE, p])


class Device:
    def __init__(self, role: str, serial: str, out: Path, platform: str = "android"):
        self.role, self.serial, self.out, self.platform = role, serial, out, platform
        self.results: dict[str, str] = {}
        self.ready = threading.Event()
        self.done = threading.Event()
        self.shots = 0

    def screenshot(self, name: str) -> None:
        path = self.out / "screenshots" / f"{name}.png"
        path.parent.mkdir(exist_ok=True)
        if self.platform == "ios":
            run(["xcrun", "simctl", "io", self.serial, "screenshot", str(path)])
        else:
            with open(path, "wb") as f:
                subprocess.run([ADB, "-s", self.serial, "exec-out", "screencap", "-p"], stdout=f)
        self.shots += 1

    def host_action(self, action: str) -> None:
        log(f"{self.role}: host action {action}")
        if self.platform == "ios":
            log(f"{self.role}: host actions are not supported on the iOS simulator")
        elif action == "airplane_on":
            run([ADB, "-s", self.serial, "shell", "cmd", "connectivity", "airplane-mode", "enable"])
        elif action == "airplane_off":
            run([ADB, "-s", self.serial, "shell", "cmd", "connectivity", "airplane-mode", "disable"])

    def handle_line(self, line: str) -> None:
        m = MARKER.search(line)
        if not m:
            return
        kind, arg = m.group(1), (m.group(2) or "").strip()
        if kind == "SCREENSHOT":
            threading.Thread(target=self.screenshot, args=(arg,), daemon=True).start()
        elif kind == "HOST":
            threading.Thread(target=self.host_action, args=(arg,), daemon=True).start()
        elif kind == "RESULT" and "=" in arg:
            k, v = arg.split("=", 1)
            self.results[k] = v
            log(f"{self.role}: {k} = {v}")
        elif kind == "LOG":
            log(f"{self.role}: {arg}")
        elif kind == "BABY_READY":
            self.ready.set()
        elif kind == "DONE":
            self.done.set()

    def watch_logcat(self) -> None:
        """Records logcat. Markers are NOT read here: in integration tests the
        Dart print() output goes to the flutter test output, not logcat."""
        run([ADB, "-s", self.serial, "logcat", "-c"])
        logf = open(self.out / f"logcat_{self.role}.txt", "w")
        proc = subprocess.Popen([ADB, "-s", self.serial, "logcat", "-v", "time"],
                                stdout=subprocess.PIPE, text=True, errors="replace")
        assert proc.stdout
        for line in proc.stdout:
            logf.write(line)


def keep_granting(serial: str, seconds: int) -> None:
    """flutter test reinstalls the app; re-grant (idempotent) until it runs."""
    end = time.time() + seconds
    while time.time() < end:
        grant(serial)
        time.sleep(2)


def run_flutter_test(dev: Device, target: str) -> subprocess.Popen:
    log(f"{dev.role}: flutter test {target}")
    cmd = ["flutter", "test", target, "-d", dev.serial, DEFINE, "-r", "expanded"]
    if dev.platform == "android":
        threading.Thread(target=keep_granting, args=(dev.serial, 300), daemon=True).start()
    else:
        cmd.append("--dart-define=E2E_SKIP_NETWORK_DROP=true")

    # Markers come from the flutter test output (the test's print()).
    proc = subprocess.Popen(cmd, cwd=ROOT, stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                            text=True, errors="replace")

    def pump() -> None:
        with open(dev.out / f"flutter_{dev.role}.txt", "w") as logf:
            assert proc.stdout
            for line in proc.stdout:
                logf.write(line)
                logf.flush()
                dev.handle_line(line)

    threading.Thread(target=pump, daemon=True).start()
    return proc


IOS_BUNDLE = "com.feyruz.bebekmonitorclean"
IOS_DEVICE_TYPE = "iPhone 17"


def ios_simulator(name: str) -> str:
    """Returns the UDID of simulator `name`, creating and booting it if needed."""
    data = json.loads(run(["xcrun", "simctl", "list", "devices", "available", "-j"]).stdout)
    udid = None
    for runtime, devices in data["devices"].items():
        for d in devices:
            if d["name"] == name:
                udid = d["udid"]
    if udid is None:
        runtimes = json.loads(run(["xcrun", "simctl", "list", "runtimes", "available", "-j"]).stdout)["runtimes"]
        ios = sorted([r for r in runtimes if r["platform"] == "iOS"],
                     key=lambda r: [int(x) for x in r["version"].split(".")])
        # Newest runtime: on the iOS 26.5 simulator the sound_stream plugin
        # aborts at launch (CoreAudio AURemoteIO RPC timeout); iOS 27 is fine.
        runtime_id = ios[-1]["identifier"]
        udid = run(["xcrun", "simctl", "create", name, IOS_DEVICE_TYPE, runtime_id]).stdout.strip()
        log(f"Created simulator {name} ({udid}) on {runtime_id}")
    run(["xcrun", "simctl", "boot", udid])
    run(["xcrun", "simctl", "bootstatus", udid, "-b"])
    return udid


IOS_APP = ROOT / "build/ios/iphonesimulator/Runner.app"


def build_ios_app(out: Path) -> None:
    log("Building iOS simulator app (emulator mode)")
    r = run(["flutter", "build", "ios", "--simulator", "--debug", DEFINE], cwd=ROOT)
    (out / "build_ios.txt").write_text(r.stdout + r.stderr)
    if r.returncode != 0 and not IOS_APP.exists():
        raise SystemExit("iOS build failed (see build_ios.txt)")


def prepare_ios(udid: str) -> None:
    """Fresh install + permissions granted ONCE. `simctl privacy grant` kills
    a running app, so it must not run while the test is running; TCC grants
    survive the reinstall that flutter test does over this install."""
    run(["xcrun", "simctl", "uninstall", udid, IOS_BUNDLE])  # fresh app data
    r = run(["xcrun", "simctl", "install", udid, str(IOS_APP)])
    log(f"{udid}: install {'ok' if r.returncode == 0 else r.stderr.strip()}")
    for service in ("camera", "microphone", "photos", "photos-add"):
        run(["xcrun", "simctl", "privacy", udid, "grant", service, IOS_BUNDLE])


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--platform", choices=["android", "ios"], default="android")
    ap.add_argument("--no-build", action="store_true")
    ap.add_argument("--keep-data", action="store_true")
    args = ap.parse_args()

    out = ROOT / "test-results" / (dt.datetime.now().strftime("%Y%m%d-%H%M%S") + f"-{args.platform}")
    out.mkdir(parents=True)
    log(f"Results: {out}")

    fb = ensure_firebase_emulators(out)
    if not args.keep_data:
        wipe_emulator_data()

    if args.platform == "ios":
        baby = Device("baby", ios_simulator("baby-ios27"), out, "ios")
        parent = Device("parent", ios_simulator("parent-ios27"), out, "ios")
        if not args.no_build or not IOS_APP.exists():
            build_ios_app(out)
        for d in (baby, parent):
            prepare_ios(d.serial)
    else:
        baby = Device("baby", boot_avd("baby", out), out)
        parent = Device("parent", boot_avd("parent", out), out)

        apk = ROOT / "build/app/outputs/flutter-apk/app-debug.apk"
        if not args.no_build:
            log("Building debug APK (emulator mode)")
            r = run(["flutter", "build", "apk", "--debug", DEFINE], cwd=ROOT)
            (out / "build.txt").write_text(r.stdout + r.stderr)
            if r.returncode != 0:
                raise SystemExit("APK build failed (see build.txt)")
        for d in (baby, parent):
            prepare_device(d.serial, apk)
            threading.Thread(target=d.watch_logcat, daemon=True).start()
    time.sleep(2)

    started = time.time()
    baby_proc = run_flutter_test(baby, "integration_test/baby_test.dart")
    if not baby.ready.wait(timeout=15 * 60):
        log("baby never became ready")
    parent_proc = run_flutter_test(parent, "integration_test/parent_test.dart")

    codes = {}
    for name, proc in (("parent", parent_proc), ("baby", baby_proc)):
        try:
            codes[name] = proc.wait(timeout=60 * 60)
        except subprocess.TimeoutExpired:
            proc.kill()
            codes[name] = "timeout"
    time.sleep(3)

    # Functions emulator log: did onCryAlertCreated run?
    fn_log = ""
    for p in [out / "firebase_emulators.log", ROOT.parent / "firebase-debug.log"]:
        if p.exists():
            fn_log += p.read_text(errors="replace")
    fn_runs = fn_log.count('Beginning execution of "us-central1-onCryAlertCreated"')

    summary = {
        "duration_min": round((time.time() - started) / 60, 1),
        "exit_codes": codes,
        "baby": baby.results,
        "parent": parent.results,
        "function_executions_in_log": fn_runs,
        "screenshots": baby.shots + parent.shots,
    }
    (out / "summary.json").write_text(json.dumps(summary, indent=2, ensure_ascii=False))
    lines = [f"# E2E run {out.name}", "", f"- exit codes: {codes}", f"- duration: {summary['duration_min']} min",
             f"- function executions seen in emulator log: {fn_runs}", ""]
    for role, res in (("baby", baby.results), ("parent", parent.results)):
        lines += [f"## {role}", "", "| check | result |", "|---|---|"]
        lines += [f"| {k} | {v} |" for k, v in res.items()]
        lines.append("")
    (out / "summary.md").write_text("\n".join(lines))
    log(f"Done: {codes}. Summary: {out / 'summary.md'}")
    if fb:
        log("Firebase emulators left running (stop with: pkill -f 'firebase.*emulators:start')")


if __name__ == "__main__":
    sys.exit(main())
