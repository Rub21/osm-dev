#!/usr/bin/env python3
"""Test GPS trace upload with different visibility values against the dev API."""

import json
import os
import sys
from pathlib import Path

import requests

BASE_URL = os.environ.get("OSM_URL", "http://localhost:3000")
SCRIPT_DIR = Path(__file__).parent
TOKENS_FILE = SCRIPT_DIR / ".tokens.json"
GPX_FILE = SCRIPT_DIR / "sample.gpx"

# Which user to test with (override with OSM_USER env var)
TEST_USER = os.environ.get("OSM_USER", "mapper1")

CASES = [
    # (params, expected_status, description)
    ({"visibility": "public"},        200, "new visibility public"),
    ({"visibility": "identifiable"},  200, "new visibility identifiable"),
    ({"visibility": "private"},       400, "blocked: private"),
    ({"visibility": "trackable"},     400, "blocked: trackable"),
    ({"public": "1"},                 200, "legacy public=1"),
    ({"public": "0"},                 400, "legacy public=0 rejected"),
    ({},                              400, "no visibility param"),
]


def load_token(user):
    if not TOKENS_FILE.exists():
        sys.exit(f"ERROR: tokens file not found at {TOKENS_FILE}. Start the dev container first.")
    tokens = json.loads(TOKENS_FILE.read_text())
    if user not in tokens:
        sys.exit(f"ERROR: no token for user '{user}'. Available: {list(tokens.keys())}")
    return tokens[user]


def upload(token, params):
    with open(GPX_FILE, "rb") as f:
        files = {"file": ("sample.gpx", f, "application/gpx+xml")}
        data = {"description": "visibility test", "tags": "test", **params}
        return requests.post(
            f"{BASE_URL}/api/0.6/gpx",
            headers={"Authorization": f"Bearer {token}"},
            files=files,
            data=data,
            timeout=30,
        )


def main():
    token = load_token(TEST_USER)
    print(f"Testing as user: {TEST_USER}\n")
    passed = 0
    failed = 0
    for params, expected, desc in CASES:
        r = upload(token, params)
        ok = r.status_code == expected
        mark = "PASS" if ok else "FAIL"
        body = r.text.strip()[:100]
        print(f"[{mark}] {desc:35s} expected={expected} got={r.status_code}  {body}")
        if ok:
            passed += 1
        else:
            failed += 1
    print(f"\n{passed} passed, {failed} failed")
    sys.exit(0 if failed == 0 else 1)


if __name__ == "__main__":
    main()
