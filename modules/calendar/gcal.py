#!/usr/bin/env python3

import base64
import fcntl
import hashlib
import html
import json
import os
import re
import subprocess
import sys
import time
import urllib.error
import urllib.parse
import urllib.request
from datetime import datetime, timedelta
from pathlib import Path
from typing import NoReturn

SECRETS_DIR = Path(os.environ.get("GCAL_SECRETS_DIR", "/run/secrets"))
STATE_FILE = Path.home() / ".local" / "state" / "quickshell" / "agenda.json"
LOCK_FILE = STATE_FILE.with_name("deadlines.lock")
NOTES = Path.home() / "notes" / "isep"
DEADLINES = "Deadlines"
FRONT = re.compile(r"\A---\n(.*?)\n---\n?(.*)\Z", re.DOTALL)
DUE = re.compile(r"\d{2}/\d{2}/\d{4} \d{2}:\d{2}")
TOKEN_URL = "https://oauth2.googleapis.com/token"
API = "https://www.googleapis.com/calendar/v3"
SCOPE = "https://www.googleapis.com/auth/calendar"
PAST_DAYS = 7
FUTURE_DAYS = 120
PAGE_SIZE = 250


def die(msg) -> NoReturn:
    print(msg, file=sys.stderr)
    sys.exit(1)


def secret(name):
    path = SECRETS_DIR / name
    try:
        return path.read_text().strip()
    except OSError:
        die(
            f"missing secret {path} - add it to secrets/secrets.yaml and run just switch"
        )


def post_form(url, data):
    body = urllib.parse.urlencode(data).encode()
    req = urllib.request.Request(url, data=body)
    try:
        with urllib.request.urlopen(req, timeout=20) as r:
            return json.load(r)
    except urllib.error.HTTPError as e:
        die(f"{url} returned {e.code}: {e.read().decode(errors='replace')}")


def api(method, path, token, params=None, body=None):
    url = f"{API}{path}"
    if params:
        url = f"{url}?{urllib.parse.urlencode(params)}"
    headers = {"Authorization": f"Bearer {token}"}
    data = None
    if body is not None:
        data = json.dumps(body).encode()
        headers["Content-Type"] = "application/json"
    req = urllib.request.Request(url, data=data, method=method, headers=headers)
    try:
        with urllib.request.urlopen(req, timeout=20) as r:
            body = r.read()
            return json.loads(body) if body else {}
    except urllib.error.HTTPError as e:
        die(f"{method} {path} returned {e.code}: {e.read().decode(errors='replace')}")


def b64(data):
    return base64.urlsafe_b64encode(data).rstrip(b"=")


def sign(data, pem):
    read, write = os.pipe()
    os.write(write, pem.encode())
    os.close(write)
    try:
        out = subprocess.run(
            ["openssl", "dgst", "-sha256", "-sign", f"/dev/fd/{read}"],
            input=data,
            capture_output=True,
            check=False,
            pass_fds=(read,),
        )
    finally:
        os.close(read)
    if out.returncode:
        die(f"openssl could not sign: {out.stderr.decode(errors='replace')}")
    return out.stdout


def access_token():
    account = json.loads(secret("gcal-service-account"))
    now = int(time.time())
    claims = {
        "iss": account["client_email"],
        "scope": SCOPE,
        "aud": TOKEN_URL,
        "iat": now,
        "exp": now + 3600,
    }
    head = b64(b'{"alg":"RS256","typ":"JWT"}') + b"." + b64(json.dumps(claims).encode())
    tok = post_form(
        TOKEN_URL,
        {
            "grant_type": "urn:ietf:params:oauth:grant-type:jwt-bearer",
            "assertion": (
                head + b"." + b64(sign(head, account["private_key"]))
            ).decode(),
        },
    )
    if "access_token" not in tok:
        die(f"no access token in response: {tok}")
    return tok["access_token"]


def when(slot):
    stamp = slot.get("dateTime")
    if stamp:
        return stamp, False
    day = slot.get("date")
    return (f"{day}T00:00:00", True) if day else (None, False)


def calendars(token):
    for cal in api("GET", "/users/me/calendarList", token).get("items", []):
        if cal.get("selected", True) and not cal.get("primary"):
            yield cal


def mine(cal):
    return cal.get("accessRole") in ("owner", "writer") and not cal["id"].endswith(
        "calendar.google.com"
    )


def plain(markup):
    if not markup:
        return ""
    text = re.sub(r"<br\s*/?>|</p\s*>|</div\s*>", "\n", markup, flags=re.IGNORECASE)
    text = re.sub(r"<[^>]+>", "", text)
    return re.sub(r"\n{3,}", "\n\n", html.unescape(text)).strip()


def meeting_link(e):
    if e.get("hangoutLink"):
        return e["hangoutLink"]
    for point in (e.get("conferenceData") or {}).get("entryPoints", []):
        if point.get("entryPointType") == "video" and point.get("uri"):
            return point["uri"]
    return ""


def events_in(token, cal, lo, hi):
    params = {
        "singleEvents": "true",
        "orderBy": "startTime",
        "timeMin": lo.isoformat(),
        "timeMax": hi.isoformat(),
        "maxResults": str(PAGE_SIZE),
    }
    path = f"/calendars/{urllib.parse.quote(cal['id'])}/events"
    while True:
        page = api("GET", path, token, params)
        for e in page.get("items", []):
            if e.get("status") == "cancelled":
                continue
            start, all_day = when(e.get("start", {}))
            end, _ = when(e.get("end", {}))
            if not start:
                continue
            key = (e.get("extendedProperties") or {}).get("private", {}).get("deadline")
            yield {
                "uid": e.get("iCalUID", e.get("id", "")),
                "id": e.get("id", ""),
                "calendarId": cal.get("id", ""),
                "title": e.get("summary", "(no title)"),
                "location": e.get("location", ""),
                "description": plain(e.get("description", "")),
                "meetLink": meeting_link(e),
                "link": e.get("htmlLink", ""),
                "writable": cal.get("accessRole", "") in ("owner", "writer"),
                "start": start,
                "end": end or start,
                "allDay": all_day,
                "calendar": "My calendar" if mine(cal) else cal.get("summary", ""),
                "color": cal.get("backgroundColor", "#7fa8f5"),
                "file": str(NOTES / key) if key else "",
            }
        token_next = page.get("nextPageToken")
        if not token_next:
            return
        params["pageToken"] = token_next


def cmd_sync():
    token = access_token()
    now = datetime.now().astimezone()
    lo = (now - timedelta(days=PAST_DAYS)).replace(
        hour=0, minute=0, second=0, microsecond=0
    )
    hi = now + timedelta(days=FUTURE_DAYS)

    events = []
    seen = set()
    for cal in calendars(token):
        for e in events_in(token, cal, lo, hi):
            key = (e["uid"], e["start"])
            if key in seen:
                continue
            seen.add(key)
            events.append(e)
    events.sort(key=lambda e: e["start"])

    STATE_FILE.parent.mkdir(parents=True, exist_ok=True)
    tmp = STATE_FILE.with_suffix(".json.tmp")
    tmp.write_text(json.dumps({"updated": now.isoformat(), "events": events}))
    tmp.replace(STATE_FILE)
    print(f"{len(events)} events -> {STATE_FILE}")


def cmd_add(text):
    if not text:
        die('usage: gcal add "gym tomorrow 7pm"')
    token = access_token()
    cal = next((c for c in calendars(token) if mine(c)), None)
    if not cal:
        die("no calendar of yours is shared - run gcal subscribe <your gmail address>")
    path = f"/calendars/{urllib.parse.quote(cal['id'])}/events/quickAdd"
    created = api("POST", path, token, {"text": text})
    print(f"added: {created.get('summary', text)}")
    cmd_sync()


def cmd_rm(calendar_id, event_id):
    if not calendar_id or not event_id:
        die("usage: gcal rm <calendarId> <eventId>")
    token = access_token()
    api(
        "DELETE",
        f"/calendars/{urllib.parse.quote(calendar_id)}/events/{urllib.parse.quote(event_id)}",
        token,
    )
    print("deleted")
    cmd_sync()


def deadline(path):
    match = FRONT.match(path.read_text())
    if not match:
        return None
    meta = {}
    for line in match[1].splitlines():
        name, _, value = line.partition(":")
        meta[name.strip()] = value.strip().strip("\"'")
    if not DUE.fullmatch(meta.get("due", "")):
        return None
    try:
        due = datetime.strptime(meta["due"], "%d/%m/%Y %H:%M").astimezone()
    except ValueError:
        return None
    body = match[2].strip()
    heading = re.match(r"#[ \t]+(.+)\n*", body)
    title = heading[1].strip() if heading else path.stem
    key = str(path.relative_to(NOTES))
    event = {
        "summary": f"{path.parts[-3].upper()} - {title}",
        "description": body[heading.end() :].strip() if heading else body,
        "start": {"dateTime": due.isoformat()},
        "end": {"dateTime": due.isoformat()},
    }
    digest = hashlib.sha256(json.dumps(event, sort_keys=True).encode()).hexdigest()
    event["extendedProperties"] = {"private": {"deadline": key, "hash": digest[:16]}}
    return key, event


def push(token):
    found = api("GET", "/users/me/calendarList", token).get("items", [])
    cal = next((c for c in found if c.get("summary") == DEADLINES), None)
    if not cal:
        die(f'no "{DEADLINES}" calendar - create it in Google Calendar first')
    path = f"/calendars/{urllib.parse.quote(cal['id'])}/events"

    wanted, skipped = {}, set()
    for file in sorted(NOTES.glob("*/deadlines/*.md")):
        parsed = deadline(file)
        if parsed:
            wanted[parsed[0]] = parsed[1]
        else:
            skipped.add(str(file.relative_to(NOTES)))
            print(
                f"skipped {file}: needs ---/due: DD/MM/YYYY HH:MM/---", file=sys.stderr
            )

    existing = {}
    params = {"maxResults": str(PAGE_SIZE)}
    while True:
        page = api("GET", path, token, params)
        for e in page.get("items", []):
            private = (e.get("extendedProperties") or {}).get("private", {})
            if private.get("deadline"):
                existing[private["deadline"]] = e
        if not page.get("nextPageToken"):
            break
        params["pageToken"] = page["nextPageToken"]

    for key, event in wanted.items():
        have = existing.pop(key, None)
        if have is None:
            api("POST", path, token, body=event)
            print(f"added {key}")
        elif (
            have["extendedProperties"]["private"].get("hash")
            != event["extendedProperties"]["private"]["hash"]
        ):
            api("PATCH", f"{path}/{urllib.parse.quote(have['id'])}", token, body=event)
            print(f"updated {key}")
    for key, have in existing.items():
        if key not in skipped:
            api("DELETE", f"{path}/{urllib.parse.quote(have['id'])}", token)
            print(f"removed {key}")


def cmd_push():
    LOCK_FILE.parent.mkdir(parents=True, exist_ok=True)
    with LOCK_FILE.open("w") as lock:
        fcntl.flock(lock, fcntl.LOCK_EX)
        push(access_token())


def cmd_done(name):
    if not name:
        die("usage: gcal done <file>")
    src = Path(name).resolve()
    if src.suffix != ".md" or src.parent.name != "deadlines" or not src.is_file():
        die(f"{name} is not a file in a deadlines/ folder")
    dest = src.parent / "done" / src.name
    if dest.exists():
        die(f"{dest} already exists")
    dest.parent.mkdir(exist_ok=True)
    src.rename(dest)
    print(f"done: {dest}")
    cmd_push()
    cmd_sync()


def cmd_subscribe(calendar_id):
    if not calendar_id:
        die("usage: gcal subscribe <calendarId>")
    token = access_token()
    cal = api(
        "POST",
        "/users/me/calendarList",
        token,
        body={"id": calendar_id, "selected": True},
    )
    print(f"subscribed: {cal.get('summary', calendar_id)}")
    cmd_sync()


def main():
    cmd = sys.argv[1] if len(sys.argv) > 1 else "sync"
    args = sys.argv[2:]
    if cmd == "sync":
        cmd_sync()
    elif cmd == "subscribe":
        cmd_subscribe(args[0] if args else "")
    elif cmd == "add":
        cmd_add(" ".join(args).strip())
    elif cmd == "rm":
        cmd_rm(args[0] if args else "", args[1] if len(args) > 1 else "")
    elif cmd == "push":
        cmd_push()
    elif cmd == "done":
        cmd_done(args[0] if args else "")
    else:
        die(
            'usage: gcal [sync|subscribe <calendarId>|add "<text>"'
            "|rm <calendarId> <eventId>|push|done <file>]"
        )


if __name__ == "__main__":
    main()
