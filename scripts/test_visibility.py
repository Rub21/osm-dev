#!/usr/bin/env python3
"""Bulk-upload GPX files from a folder, rotating user x visibility for variety.

Picks one (user, visibility) combo per file in round-robin order, so the dev
DB ends up with a mix of traces across all users and all visibility values.

Usage:

  INSTANCE_SLUG=gps-db \\
    OSM_URL=https://gps-db.<your-ip>.nip.io \\
    GPX_DIR=/apps/gps-fetcher/gpx_files \\
    python3 test_visibility.py

Env vars:
  INSTANCE_SLUG   instance slug (matches deploy.sh). default: "default"
  OSM_URL         API base URL. default: http://localhost:3000
  GPX_DIR         folder with *.gpx files to upload. default: ./gpx
  LIMIT           max files to upload (0 = all). default: 0
  USERS           comma-separated user list. default: admin,mapper1,mapper2,mapper3
  VISIBILITIES    comma-separated visibility list.
                  default: public,identifiable,trackable,private

Tokens read from ./.tokens-<slug>.json (written by generate_token.rb).
"""

import json
import os
import sys
from pathlib import Path

import requests

BASE_URL = os.environ.get("OSM_URL", "http://localhost:3000").rstrip("/")
SCRIPT_DIR = Path(__file__).parent
SLUG = os.environ.get("INSTANCE_SLUG", "default")
TOKENS_FILE = SCRIPT_DIR / f".tokens-{SLUG}.json"
GPX_DIR = Path(os.environ.get("GPX_DIR", SCRIPT_DIR / "gpx"))
LIMIT = int(os.environ.get("LIMIT", "0"))

USERS = [u.strip() for u in os.environ.get(
    "USERS", "admin,mapper1,mapper2,mapper3").split(",") if u.strip()]
VISIBILITIES = [v.strip() for v in os.environ.get(
    "VISIBILITIES", "public,identifiable,trackable,private").split(",") if v.strip()]


def load_tokens():
    if not TOKENS_FILE.exists():
        sys.exit(f"ERROR: tokens file not found at {TOKENS_FILE}. Start the dev container first.")
    return json.loads(TOKENS_FILE.read_text())


def list_gpx(folder):
    if not folder.is_dir():
        sys.exit(f"ERROR: GPX_DIR not found or not a directory: {folder}")
    files = sorted(folder.glob("*.gpx"))
    if not files:
        sys.exit(f"ERROR: no .gpx files in {folder}")
    return files


def upload(token, gpx_path, visibility):
    with open(gpx_path, "rb") as f:
        files = {"file": (gpx_path.name, f, "application/gpx+xml")}
        data = {
            "description": f"bulk test {gpx_path.stem}",
            "tags": f"test,{visibility}",
            "visibility": visibility,
        }
        return requests.post(
            f"{BASE_URL}/api/0.6/gpx",
            headers={"Authorization": f"Bearer {token}"},
            files=files,
            data=data,
            timeout=60,
        )


def main():
    tokens = load_tokens()
    missing = [u for u in USERS if u not in tokens]
    if missing:
        sys.exit(f"ERROR: tokens missing for users {missing}. Available: {list(tokens.keys())}")

    gpx_files = list_gpx(GPX_DIR)
    if LIMIT > 0:
        gpx_files = gpx_files[:LIMIT]

    combos = [(u, v) for u in USERS for v in VISIBILITIES]
    print(f"URL:    {BASE_URL}")
    print(f"slug:   {SLUG}")
    print(f"folder: {GPX_DIR}  ({len(gpx_files)} files)")
    print(f"combos: {len(combos)}  ({len(USERS)} users x {len(VISIBILITIES)} vis)\n")

    ok = 0
    fail = 0
    for i, gpx in enumerate(gpx_files):
        user, vis = combos[i % len(combos)]
        try:
            r = upload(tokens[user], gpx, vis)
        except requests.RequestException as e:
            print(f"[ERR ] {gpx.name:30s} user={user:8s} vis={vis:13s} {e}")
            fail += 1
            continue
        status = r.status_code
        good = status == 200
        mark = "OK  " if good else "FAIL"
        body = "" if good else r.text.strip()[:80]
        print(f"[{mark}] {gpx.name:30s} user={user:8s} vis={vis:13s} status={status} {body}")
        if good:
            ok += 1
        else:
            fail += 1

    print(f"\n{ok} uploaded, {fail} failed")
    sys.exit(0 if fail == 0 else 1)


if __name__ == "__main__":
    main()
