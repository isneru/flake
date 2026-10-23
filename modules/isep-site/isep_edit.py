#!/usr/bin/env python3
import difflib
import hashlib
import json
import os
import re
import subprocess
import sys
import tempfile
import threading
import time
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from urllib.parse import parse_qs, urlparse

import jwt

ROOT = Path(os.environ.get("ISEP_EDIT_ROOT", "/srv/isep"))
STATE = Path(os.environ.get("STATE_DIRECTORY", "/var/lib/isep-edit"))
TEAM = os.environ.get("ISEP_EDIT_TEAM", "")
AUD = os.environ.get("ISEP_EDIT_AUD", "")
OWNER = os.environ.get("ISEP_EDIT_OWNER", "").lower()
ORIGIN = os.environ.get("ISEP_EDIT_ORIGIN", "")
PORT = int(os.environ.get("ISEP_EDIT_PORT", "8487"))
LIMIT = 2 << 20

LOCK = threading.Lock()
KEYS = jwt.PyJWKClient(f"{TEAM}/cdn-cgi/access/certs") if TEAM else None
PENDING = STATE / "pending"
PREV = STATE / "prev"


def log(*a):
    print(*a, file=sys.stderr, flush=True)


class Refused(Exception):
    def __init__(self, status, message):
        super().__init__(message)
        self.status = status


def identity(token):
    if not (TEAM and AUD and OWNER and ORIGIN):
        raise Refused(503, "Editing is not configured yet.")
    if not token:
        raise Refused(401, "Not signed in.")
    try:
        key = KEYS.get_signing_key_from_jwt(token)
        claims = jwt.decode(
            token, key.key, algorithms=["RS256"], audience=AUD, issuer=TEAM
        )
    except jwt.PyJWTError as e:
        log("rejected token:", e)
        raise Refused(401, "Your sign-in is not valid. Reload the page.") from None
    email = str(claims.get("email", "")).lower()
    if not email:
        raise Refused(403, "Your sign-in carries no email address.")
    return email


def note(raw):
    parts = raw.strip("/").split("/")
    if (
        not raw.startswith("/")
        or not raw.endswith(".md")
        or len(parts) < 2
        or any(p in ("", "..", "node_modules") or p.startswith(".") for p in parts)
        or parts[1] == "materials"
        or (parts[0] != "lab" and not (ROOT / parts[0] / "materials").is_dir())
    ):
        raise Refused(403, "This file cannot be edited.")
    path = ROOT.joinpath(*parts)
    if (
        path.is_symlink()
        or not path.is_file()
        or not path.resolve().is_relative_to(ROOT.resolve())
    ):
        raise Refused(404, "No such note.")
    return path


def tag(text):
    return hashlib.sha256(text.encode()).hexdigest()


def read(path):
    try:
        return path.read_bytes().decode()
    except UnicodeDecodeError:
        raise Refused(415, "This note is not UTF-8.") from None


def conform(text, current):
    text = text.replace("\r\n", "\n")
    return text.replace("\n", "\r\n") if "\r\n" in current else text


def write(path, text, previous):
    keep = PREV / path.relative_to(ROOT)
    keep.parent.mkdir(parents=True, exist_ok=True)
    keep.write_bytes(previous.encode())
    mode = path.stat().st_mode & 0o777
    fd, tmp = tempfile.mkstemp(dir=path.parent, prefix=".isep-edit-")
    try:
        with os.fdopen(fd, "wb") as f:
            f.write(text.encode())
            os.fchmod(f.fileno(), mode)
        os.replace(tmp, path)
    except BaseException:
        Path(tmp).unlink(missing_ok=True)
        raise


def merge(current, base, text):
    if current == base:
        return text
    with tempfile.TemporaryDirectory() as d:
        files = []
        for name, body in (("current", current), ("base", base), ("proposed", text)):
            f = Path(d) / name
            f.write_bytes(body.encode())
            files.append(str(f))
        run = subprocess.run(
            ["git", "merge-file", "-p", *files], capture_output=True, check=False
        )
    return None if run.returncode else run.stdout.decode()


def proposal_id(author, raw):
    return hashlib.sha256(f"{author}\0{raw}".encode()).hexdigest()[:16]


def load(pid):
    if not re.fullmatch(r"[0-9a-f]{16}", pid):
        raise Refused(404, "No such proposal.")
    f = PENDING / f"{pid}.json"
    if not f.exists():
        raise Refused(404, "No such proposal.")
    return json.loads(f.read_text())


def summary(pid, p):
    try:
        current = read(note(p["path"]))
    except Refused:
        current = None
    diff = difflib.unified_diff(
        p["base"].splitlines(keepends=True),
        p["text"].splitlines(keepends=True),
        fromfile=p["path"],
        tofile=p["path"],
    )
    return {
        "id": pid,
        "path": p["path"],
        "author": p["author"],
        "time": p["time"],
        "diff": "".join(diff),
        "stale": current != p["base"],
        "clean": current is not None
        and merge(current, p["base"], p["text"]) is not None,
    }


class Handler(BaseHTTPRequestHandler):
    def log_message(self, *a):
        pass

    def send(self, status, body):
        data = json.dumps(body).encode()
        self.send_response(status)
        self.send_header("Content-Type", "application/json")
        self.send_header("Cache-Control", "no-store")
        self.send_header("Content-Length", str(len(data)))
        self.end_headers()
        self.wfile.write(data)

    def body(self):
        size = int(self.headers.get("Content-Length") or 0)
        if size > LIMIT:
            raise Refused(413, "That note is too large.")
        try:
            return json.loads(self.rfile.read(size) or b"{}")
        except ValueError:
            raise Refused(400, "Malformed request.") from None

    def do_GET(self):
        self.dispatch("GET")

    def do_PUT(self):
        self.dispatch("PUT")

    def do_POST(self):
        self.dispatch("POST")

    def dispatch(self, method):
        url = urlparse(self.path)
        query = parse_qs(url.query)
        try:
            if method != "GET" and self.headers.get("Origin") != ORIGIN:
                raise Refused(403, "Cross-origin request refused.")
            email = identity(self.headers.get("Cf-Access-Jwt-Assertion"))
            owner = email == OWNER
            route = url.path.removeprefix("/.edit/api/")
            if method == "GET" and route == "me":
                self.send(200, self.me(email, owner))
            elif route == "note" and method in ("GET", "PUT"):
                raw = query.get("path", [""])[0]
                if method == "GET":
                    self.send(200, self.open(email, owner, raw))
                else:
                    self.send(200, self.save(email, owner, raw, self.body()))
            elif not owner:
                raise Refused(403, "Only the owner can review changes.")
            elif method == "GET" and route == "pending":
                with LOCK:
                    found = sorted(PENDING.glob("*.json"))
                    self.send(
                        200,
                        [summary(f.stem, json.loads(f.read_text())) for f in found],
                    )
            elif method == "POST" and (
                m := re.fullmatch(r"pending/(\w+)/(approve|reject)", route)
            ):
                self.send(200, self.decide(*m.groups()))
            else:
                raise Refused(404, "Not found.")
        except Refused as e:
            self.send(e.status, {"error": str(e)})

    def me(self, email, owner):
        found = len(list(PENDING.glob("*.json"))) if owner else 0
        return {"email": email, "owner": owner, "pending": found}

    def open(self, email, owner, raw):
        current = read(note(raw))
        f = PENDING / f"{proposal_id(email, raw)}.json"
        if not owner and f.exists():
            p = json.loads(f.read_text())
            return {"text": p["text"], "etag": tag(p["base"]), "pending": True}
        return {"text": current, "etag": tag(current), "pending": False}

    def save(self, email, owner, raw, body):
        path = note(raw)
        if not isinstance(body.get("text"), str):
            raise Refused(400, "Malformed request.")
        stale = Refused(409, "This note changed since you opened it. Reload it.")
        with LOCK:
            current = read(path)
            text = conform(body["text"], current)
            if owner:
                if body.get("etag") != tag(current):
                    raise stale
                if text != current:
                    write(path, text, current)
                    log(f"saved {raw} by {email}")
                return {"status": "saved"}
            f = PENDING / f"{proposal_id(email, raw)}.json"
            old = json.loads(f.read_text()) if f.exists() else None
            if old and body.get("etag") == tag(old["base"]):
                base = old["base"]
            elif body.get("etag") == tag(current):
                base = current
            else:
                raise stale
            if text == base:
                f.unlink(missing_ok=True)
                return {"status": "unchanged"}
            p = {
                "path": raw,
                "author": email,
                "time": int(time.time()),
                "base": base,
                "text": text,
            }
            f.write_text(json.dumps(p))
            log(f"proposed {raw} by {email}")
            return {"status": "pending"}

    def decide(self, pid, action):
        with LOCK:
            p = load(pid)
            if action == "approve":
                path = note(p["path"])
                current = read(path)
                result = merge(current, p["base"], p["text"])
                if result is None:
                    raise Refused(409, "This change conflicts with the current note.")
                if result != current:
                    write(path, result, current)
            (PENDING / f"{pid}.json").unlink()
            done = {"approve": "approved", "reject": "rejected"}[action]
            log(f"{done} {p['path']} by {p['author']}")
            return {"status": done}


def main():
    PENDING.mkdir(parents=True, exist_ok=True)
    PREV.mkdir(parents=True, exist_ok=True)
    ThreadingHTTPServer(("127.0.0.1", PORT), Handler).serve_forever()


if __name__ == "__main__":
    main()
