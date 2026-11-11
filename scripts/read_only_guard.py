#!/usr/bin/env python3
"""Fails CI if app code could change the calendar or reach the network.

Promptly reads the calendar and keeps everything on the iPhone. This guard keeps it that way:
no EventKit writes, no URLSession or other network clients, no analytics SDKs.
Usage: read_only_guard.py check | selftest
"""
import re
import sys
from pathlib import Path

FORBIDDEN = [
    (r"\.save\s*\(\s*\w*[Ee]vent", "EventKit save"),
    (r"\.remove\s*\(\s*\w*[Ee]vent", "EventKit remove"),
    (r"\bstore\.(save|remove|commit|reset)\b", "EventKit store write"),
    (r"\bEKEvent\s*\(\s*eventStore", "creating an event"),
    (r"\bEKReminder\b", "reminders"),
    (r"\bURLSession\b", "network (URLSession)"),
    (r"\bNWConnection\b", "network (Network.framework)"),
    (r"\bURLRequest\b", "network request"),
    (r"import\s+(Firebase\w*|Mixpanel|Amplitude|Segment|Sentry)", "analytics or crash SDK"),
]


def scan(text: str):
    hits = []
    for pattern, why in FORBIDDEN:
        for m in re.finditer(pattern, text):
            line = text.count("\n", 0, m.start()) + 1
            hits.append((line, why))
    return hits


def check(root: Path) -> int:
    failures = 0
    for path in sorted((root / "App" / "Promptly").rglob("*.swift")):
        for line, why in scan(path.read_text(encoding="utf-8")):
            print(f"::error file={path},line={line}::{why} is not allowed in Promptly")
            failures += 1
    if failures == 0:
        print("Read-only guard: no calendar writes or network use found.")
    return 1 if failures else 0


def selftest() -> int:
    assert scan("try store.save(event, span: .thisEvent)")
    assert scan("let s = URLSession.shared")
    assert scan("store.remove(ev, span: .thisEvent)")
    assert scan("import FirebaseAnalytics")
    assert not scan("let events = store.events(matching: predicate)")
    assert not scan("prefs.clearedMeetingIDs = cleared")
    print("Read-only guard self-test passed.")
    return 0


if __name__ == "__main__":
    cmd = sys.argv[1] if len(sys.argv) > 1 else "check"
    sys.exit(selftest() if cmd == "selftest" else check(Path(__file__).resolve().parent.parent))
