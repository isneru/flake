#!/usr/bin/env python3
import argparse
import fcntl
import hashlib
import http.client
import json
import mimetypes
import os
import secrets
import signal
import socket
import ssl
import stat as statmod
import struct
import subprocess
import sys
import threading
import time
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from urllib.parse import parse_qs, urlparse

GROUP = "224.0.0.167"
PORT = 53317
VERSION = "2.0"
PEER_TTL = 300
LINGER = 60
TERMINAL = ("done", "failed", "cancelled", "declined", "expired")

VERBOSE = False


def log(*a):
    if VERBOSE:
        print(time.strftime("%H:%M:%S"), *a, file=sys.stderr, flush=True)


def warn(*a):
    print(time.strftime("%H:%M:%S"), *a, file=sys.stderr, flush=True)


class Identity:
    def __init__(self, home: Path):
        home.mkdir(parents=True, exist_ok=True)
        self.cert = home / "cert.pem"
        self.key = home / "key.pem"
        if not (self.cert.exists() and self.key.exists()):
            self._generate()
        der = ssl.PEM_cert_to_DER_cert(self.cert.read_text())
        self.fingerprint = hashlib.sha256(der).hexdigest().upper()

    def _generate(self):
        log("generating identity in", self.cert.parent)
        subprocess.run(
            [
                "openssl",
                "req",
                "-x509",
                "-newkey",
                "rsa:2048",
                "-nodes",
                "-keyout",
                str(self.key),
                "-out",
                str(self.cert),
                "-days",
                "36500",
                "-subj",
                "/CN=LocalSend User",
            ],
            check=True,
            capture_output=True,
        )
        os.chmod(self.key, 0o600)
        os.chmod(self.cert, 0o644)


def info_payload(announce=None):
    d = {
        "alias": CFG.alias,
        "version": VERSION,
        "deviceModel": "NixOS",
        "deviceType": "desktop",
        "fingerprint": IDENT.fingerprint,
        "port": CFG.port,
        "protocol": "https" if CFG.https else "http",
        "download": False,
    }
    if announce is not None:
        d["announce"] = announce
    return d


def safe_name(raw):
    """Basename only. A fileName is attacker-controlled and lands on disk."""
    name = os.path.basename(str(raw or "").replace("\\", "/"))
    name = name.replace("\x00", "").strip()
    if name in ("", ".", ".."):
        return None
    return name[:200]


def reserve(dirpath: Path, name: str):
    base, ext = os.path.splitext(name)
    i = 0
    while True:
        cand = dirpath / (name if i == 0 else f"{base} ({i}){ext}")
        part = Path(str(cand) + ".part")
        try:
            fd = os.open(part, os.O_CREAT | os.O_EXCL | os.O_WRONLY, 0o644)
        except FileExistsError:
            i += 1
            continue
        if cand.exists():
            os.close(fd)
            part.unlink(missing_ok=True)
            i += 1
            continue
        return cand, part, fd


class Cancelled(Exception):
    pass


class Session:
    def __init__(self, peer, files):
        self.id = secrets.token_hex(8)
        self.direction = "in"
        self.peer = peer
        self.files = files
        self.tokens = {f["id"]: secrets.token_hex(8) for f in files}
        self.total = sum(f["size"] for f in files)
        self.answered = threading.Event()
        self.accepted = False
        self.cancelled = False
        self.state = "asking"
        self.error = ""
        self.done = set()
        self.received = 0
        self.name = files[0]["name"] if files else ""
        self.index = 1
        self.finished = 0

    def request(self):
        return {
            "id": self.id,
            "alias": self.peer["alias"],
            "deviceType": self.peer["deviceType"],
            "ip": self.peer["ip"],
            "total": self.total,
            "count": len(self.files),
            "files": [
                {
                    "id": f["id"],
                    "name": f["name"],
                    "size": f["size"],
                    "type": f["type"],
                    "modified": f["modified"],
                    "preview": f["preview"],
                }
                for f in self.files
            ],
        }

    def transfer(self):
        return {
            "id": self.id,
            "dir": self.direction,
            "peer": self.peer["alias"],
            "name": self.name,
            "index": self.index,
            "count": len(self.files),
            "sent": self.received,
            "total": self.total,
            "state": self.state,
            "error": self.error,
        }


def expand(paths):
    """Directories become their files. The protocol has no folder concept, so
    a folder is sent as its contents, flattened — which is what the app does."""
    out = []
    for path in paths:
        if os.path.isdir(path):
            for root, _, names in os.walk(path):
                for n in sorted(names):
                    out.append(os.path.join(root, n))
        else:
            out.append(path)
    return out


class Outgoing:
    """A transfer this machine started. The peer's user has to accept it, so
    prepare-upload can sit unanswered for as long as their prompt is up."""

    def __init__(self, peer, paths, preview=None):
        self.id = secrets.token_hex(8)
        self.direction = "out"
        self.target = peer
        self.peer = peer
        self.files = []
        for path in expand(paths):
            try:
                st = os.stat(path)
            except OSError:
                continue
            if not statmod.S_ISREG(st.st_mode):
                continue
            self.files.append(
                {
                    "id": "f%d" % len(self.files),
                    "name": os.path.basename(path),
                    "path": path,
                    "size": st.st_size,
                    "type": mimetypes.guess_type(path)[0] or "application/octet-stream",
                    "preview": preview,
                }
            )
        self.total = sum(f["size"] for f in self.files)
        self.sent = 0
        self.session = ""
        self.state = "asking"
        self.error = ""
        self.cancelled = False
        self.name = os.path.basename(paths[0]) if paths else ""
        if self.files:
            self.name = self.files[0]["name"]
        self.index = 1
        self.finished = 0

    def transfer(self):
        return {
            "id": self.id,
            "dir": "out",
            "peer": self.peer["alias"],
            "name": self.name,
            "index": self.index,
            "count": len(self.files),
            "sent": self.sent,
            "total": self.total,
            "state": self.state,
            "error": self.error,
        }


class Store:
    """Everything the shell can see, and the thread that publishes it."""

    def __init__(self, path: Path):
        self.path = path
        self.lock = threading.RLock()
        self.dirty = threading.Event()
        self.peers = {}
        self.session = None
        self.out = None
        self.recent = []

    def touch(self):
        self.dirty.set()

    def see_peer(self, msg, ip):
        fp = str(msg.get("fingerprint"))
        with self.lock:
            self.peers[fp] = {
                "fingerprint": fp,
                "alias": str(msg.get("alias") or "Unknown"),
                "deviceType": str(msg.get("deviceType") or "desktop"),
                "deviceModel": str(msg.get("deviceModel") or ""),
                "ip": ip,
                "port": int(msg.get("port") or PORT),
                "protocol": "http" if msg.get("protocol") == "http" else "https",
                "seen": time.time(),
            }
        self.touch()

    def peer_by(self, key):
        with self.lock:
            p = self.peers.get(key)
            if p:
                return p
            for p in self.peers.values():
                if p["alias"] == key or p["ip"] == key:
                    return p
        return None

    def start(self, session):
        """Claim the one active session slot, or refuse."""
        with self.lock:
            if self.session is not None:
                return False
            self.session = session
        self.touch()
        return True

    def end(self, session, state, error=""):
        with self.lock:
            if session.state not in TERMINAL:
                session.state = state
                session.error = error
                session.finished = time.time()
                entry = session.transfer()
                entry["at"] = session.finished
                self.recent = ([entry] + self.recent)[:10]
            if self.session is session:
                self.session = None
        session.answered.set()
        self.touch()

    def start_out(self, o):
        with self.lock:
            if self.out is not None:
                return False
            self.out = o
        self.touch()
        return True

    def end_out(self, o, state, error=""):
        with self.lock:
            if o.state not in TERMINAL:
                o.state = state
                o.error = error
                o.finished = time.time()
                entry = o.transfer()
                entry["at"] = o.finished
                self.recent = ([entry] + self.recent)[:10]
            if self.out is o:
                self.out = None
        self.touch()

    def snapshot(self):
        now = time.time()
        with self.lock:
            self.peers = {
                k: v for k, v in self.peers.items() if now - v["seen"] < PEER_TTL
            }
            s = self.session
            o = self.out
            incoming = [s.request()] if s and s.state == "asking" else []
            live = [s.transfer()] if s and s.state == "running" else []
            if o and o.state in ("asking", "running"):
                live.append(o.transfer())
            self.recent = [t for t in self.recent if now - t["at"] < LINGER]
            return {
                "self": {
                    "alias": CFG.alias,
                    "fingerprint": IDENT.fingerprint,
                    "port": CFG.port,
                    "dest": str(CFG.dest),
                },
                "peers": sorted(self.peers.values(), key=lambda p: p["alias"].lower()),
                "incoming": incoming,
                "transfers": live + self.recent,
                "at": now,
            }

    def publish_loop(self):
        while True:
            self.dirty.wait()
            self.dirty.clear()
            self.write()
            time.sleep(0.2)

    def write(self):
        tmp = self.path.with_name(self.path.name + ".tmp")
        try:
            tmp.write_text(json.dumps(self.snapshot()))
            os.replace(tmp, self.path)
        except OSError as e:
            warn("state write failed:", e)


def default_iface_ip():
    try:
        for line in Path("/proc/net/route").read_text().splitlines()[1:]:
            f = line.split()
            if len(f) > 2 and f[1] == "00000000":
                return iface_ip(f[0])
    except OSError:
        pass
    return None


def iface_ip(name):
    s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    try:
        packed = fcntl.ioctl(
            s.fileno(), 0x8915, struct.pack("256s", name.encode()[:15])
        )
        return socket.inet_ntoa(packed[20:24])
    except OSError:
        return None
    finally:
        s.close()


def make_udp():
    s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    s.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
    try:
        s.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEPORT, 1)
    except OSError:
        pass
    s.bind(("", CFG.port))
    for local in (default_iface_ip(), "0.0.0.0"):
        if not local:
            continue
        try:
            s.setsockopt(
                socket.IPPROTO_IP,
                socket.IP_ADD_MEMBERSHIP,
                struct.pack("4s4s", socket.inet_aton(GROUP), socket.inet_aton(local)),
            )
        except OSError as e:
            log("membership", local, "failed:", e)
    ip = default_iface_ip()
    if ip:
        s.setsockopt(socket.IPPROTO_IP, socket.IP_MULTICAST_IF, socket.inet_aton(ip))
    s.setsockopt(socket.IPPROTO_IP, socket.IP_MULTICAST_TTL, 4)
    s.setsockopt(socket.IPPROTO_IP, socket.IP_MULTICAST_LOOP, 1)
    return s


def client(ip, port, https, timeout):
    if https:
        ctx = ssl.SSLContext(ssl.PROTOCOL_TLS_CLIENT)
        ctx.check_hostname = False
        ctx.verify_mode = ssl.CERT_NONE
        ctx.load_cert_chain(IDENT.cert, IDENT.key)
        return http.client.HTTPSConnection(ip, port, timeout=timeout, context=ctx)
    return http.client.HTTPConnection(ip, port, timeout=timeout)


def announce(sock, flag=True):
    try:
        sock.sendto(json.dumps(info_payload(announce=flag)).encode(), (GROUP, CFG.port))
    except OSError as e:
        log("announce failed:", e)


UDP = None


def announce_loop(sock):
    for _ in range(3):
        announce(sock)
        time.sleep(5)
    while True:
        announce(sock)
        time.sleep(60)


def listen_loop(sock):
    while True:
        try:
            data, addr = sock.recvfrom(65536)
        except OSError:
            return
        try:
            msg = json.loads(data)
        except ValueError:
            continue
        if not isinstance(msg, dict):
            continue
        fp = msg.get("fingerprint")
        if not fp or fp == IDENT.fingerprint:
            continue
        STORE.see_peer(msg, addr[0])
        log("discovered", msg.get("alias"), addr[0])
        if msg.get("announce"):
            threading.Thread(
                target=reply_register, args=(msg, addr[0], sock), daemon=True
            ).start()


def reply_register(msg, ip, sock):
    """Answer an announcement. Multicast is the fallback the spec allows."""
    body = json.dumps(info_payload()).encode()
    try:
        c = client(ip, int(msg.get("port") or PORT), msg.get("protocol") != "http", 5)
        c.request(
            "POST",
            "/api/localsend/v2/register",
            body,
            {"Content-Type": "application/json"},
        )
        c.getresponse().read()
        c.close()
        return
    except Exception as e:
        log("register reply to", ip, "failed:", e)
    announce(sock, flag=False)


def send_files(peer, paths):
    o = Outgoing(peer, paths)
    if not STORE.start_out(o):
        log("already sending, ignoring")
        return
    if not o.files:
        return STORE.end_out(o, "failed", "no regular files")
    try:
        do_send(o)
    except Exception as e:
        warn("send failed:", e)
        STORE.end_out(o, "failed", str(e))


def send_text(peer, text):
    d = RUN / "outbox"
    d.mkdir(parents=True, exist_ok=True)
    path = d / "message.txt"
    path.write_text(text)
    o = Outgoing(peer, [str(path)], preview=text[:4096])
    if not STORE.start_out(o):
        return
    if not o.files:
        return STORE.end_out(o, "failed", "could not stage the message")
    o.files[0]["type"] = "text/plain"
    try:
        do_send(o)
    except Exception as e:
        warn("send failed:", e)
        STORE.end_out(o, "failed", str(e))


PREPARE_RESULTS = {
    204: ("done", ""),
    403: ("declined", ""),
    401: ("failed", "PIN required"),
    409: ("failed", "device busy"),
}


def do_send(o):
    p = o.target
    https = p["protocol"] != "http"
    body = json.dumps(
        {
            "info": info_payload(),
            "files": {
                f["id"]: dict(
                    {
                        "id": f["id"],
                        "fileName": f["name"],
                        "size": f["size"],
                        "fileType": f["type"],
                    },
                    **({"preview": f["preview"]} if f.get("preview") else {}),
                )
                for f in o.files
            },
        }
    ).encode()

    log("offering", len(o.files), "file(s) to", p["alias"])
    c = client(p["ip"], p["port"], https, 200)
    try:
        c.request(
            "POST",
            "/api/localsend/v2/prepare-upload",
            body,
            {"Content-Type": "application/json"},
        )
        r = c.getresponse()
        raw = r.read()
    finally:
        c.close()

    if r.status != 200:
        return STORE.end_out(
            o, *PREPARE_RESULTS.get(r.status, ("failed", "HTTP %d" % r.status))
        )

    try:
        ans = json.loads(raw)
        tokens = ans["files"]
        o.session = str(ans["sessionId"])
    except (ValueError, KeyError, TypeError):
        return STORE.end_out(o, "failed", "bad response")

    o.state = "running"
    STORE.touch()

    n = 0
    for f in o.files:
        tok = tokens.get(f["id"])
        if not tok:
            o.total -= f["size"]
            continue
        n += 1
        o.index = n
        o.name = f["name"]
        STORE.touch()
        upload_one(o, f, str(tok), https)
        if o.cancelled:
            cancel_remote(o, https)
            return STORE.end_out(o, "cancelled")

    log("sent", n, "file(s) to", p["alias"])
    STORE.end_out(o, "done")


def upload_one(o, f, token, https):
    p = o.target
    path = "/api/localsend/v2/upload?sessionId=%s&fileId=%s&token=%s" % (
        o.session,
        f["id"],
        token,
    )
    c = client(p["ip"], p["port"], https, 300)
    try:
        c.putrequest("POST", path, skip_accept_encoding=True)
        c.putheader("Content-Type", "application/octet-stream")
        c.putheader("Content-Length", str(f["size"]))
        c.endheaders()
        with open(f["path"], "rb") as fh:
            left = f["size"]
            while left > 0:
                if o.cancelled:
                    return
                chunk = fh.read(min(65536, left))
                if not chunk:
                    break
                c.send(chunk)
                left -= len(chunk)
                o.sent += len(chunk)
                STORE.touch()
        r = c.getresponse()
        r.read()
    finally:
        c.close()
    if r.status != 200:
        raise RuntimeError("%s rejected with HTTP %d" % (f["name"], r.status))


def cancel_remote(o, https):
    if not o.session:
        return
    p = o.target
    try:
        c = client(p["ip"], p["port"], https, 5)
        c.request("POST", "/api/localsend/v2/cancel?sessionId=" + o.session)
        c.getresponse().read()
        c.close()
    except Exception as e:
        log("remote cancel failed:", e)


def first(q, key):
    v = q.get(key)
    return v[0] if v else None


def _opt_str(v, limit=None):
    """A sender-supplied string, or "" — senders write null for anything unset."""
    if not isinstance(v, str) or not v:
        return ""
    return v[:limit] if limit else v


def _offer_file(fid, f):
    """One entry of a prepare-upload `files` map, or None if it is malformed."""
    if not isinstance(f, dict):
        return None
    name = safe_name(f.get("fileName"))
    if not name:
        return None
    meta = f.get("metadata") if isinstance(f.get("metadata"), dict) else {}
    return {
        "id": str(fid),
        "name": name,
        "size": max(0, int(f.get("size") or 0)),
        "type": str(f.get("fileType") or ""),
        "sha256": _opt_str(f.get("sha256")).lower() or None,
        "modified": str(meta.get("modified") or ""),
        "preview": _opt_str(f.get("preview"), 4096),
    }


def _offer_peer(info, ip):
    """Who is offering, preferring what they say over what we remember."""
    known = STORE.peer_by(str(info.get("fingerprint") or "")) or {}
    return {
        "alias": str(info.get("alias") or known.get("alias") or ip),
        "deviceType": str(
            info.get("deviceType") or known.get("deviceType") or "desktop"
        ),
        "fingerprint": str(info.get("fingerprint") or ""),
        "ip": ip,
    }


class Handler(BaseHTTPRequestHandler):
    protocol_version = "HTTP/1.1"
    server_version = "LocalSend/2.0"
    timeout = 120

    def log_message(self, fmt, *args):
        log("http", self.address_string(), fmt % args)

    def reply(self, code, payload=None):
        body = b"" if payload is None else json.dumps(payload).encode()
        self.send_response(code)
        if code >= 400:
            self.close_connection = True
            self.send_header("Connection", "close")
        if payload is not None:
            self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        if body:
            self.wfile.write(body)

    def route(self):
        u = urlparse(self.path)
        p = u.path.strip("/").split("/")
        if (
            len(p) == 4
            and p[0] == "api"
            and p[1] == "localsend"
            and p[2] in ("v1", "v2")
        ):
            name = p[3]
            if p[2] == "v1":
                name = {"send-request": "prepare-upload", "send": "upload"}.get(
                    name, name
                )
            return name, parse_qs(u.query)
        return None, {}

    def json_body(self, limit=4 << 20):
        n = int(self.headers.get("Content-Length") or 0)
        if n <= 0 or n > limit:
            return None
        try:
            return json.loads(self.rfile.read(n))
        except ValueError:
            return None

    def _read_chunked(self):
        """RFC 7230 chunked bodies: a hex length per chunk, terminated by 0."""
        while True:
            head = self.rfile.readline(65536).split(b";")[0].strip()
            try:
                n = int(head, 16)
            except ValueError:
                return
            if n == 0:
                while self.rfile.readline(65536) not in (b"\r\n", b"\n", b""):
                    pass
                return
            while n > 0:
                chunk = self.rfile.read(min(65536, n))
                if not chunk:
                    return
                n -= len(chunk)
                yield chunk
            self.rfile.readline(65536)

    def _read_sized(self, expect):
        got = 0
        while got < expect:
            chunk = self.rfile.read(min(65536, expect - got))
            if not chunk:
                return
            got += len(chunk)
            yield chunk

    def stream_body(self, expect):
        """Yield the request body, whether it is length-delimited or chunked."""
        encoding = (self.headers.get("Transfer-Encoding") or "").lower()
        source = (
            self._read_chunked() if "chunked" in encoding else self._read_sized(expect)
        )
        yield from source

    def do_GET(self):
        name, _ = self.route()
        if name == "info":
            return self.reply(200, info_payload())
        self.reply(404)

    def do_POST(self):
        name, q = self.route()
        if name == "info":
            return self.reply(200, info_payload())
        if name == "register":
            return self.do_register()
        if name == "prepare-upload":
            return self.do_prepare_upload()
        if name == "upload":
            return self.do_upload(q)
        if name == "cancel":
            return self.do_cancel(q)
        if name == "show":
            return self.reply(200)
        self.reply(404)

    def do_register(self):
        msg = self.json_body(1 << 16)
        if isinstance(msg, dict) and msg.get("fingerprint") != IDENT.fingerprint:
            STORE.see_peer(msg, self.client_address[0])
        self.reply(200, info_payload())

    def do_prepare_upload(self):
        data = self.json_body()
        if not isinstance(data, dict):
            return self.reply(400)
        raw = data.get("files")
        if not isinstance(raw, dict) or not raw:
            return self.reply(400)
        files = [_offer_file(fid, f) for fid, f in raw.items()]
        if not all(files):
            return self.reply(400)

        info = data.get("info") if isinstance(data.get("info"), dict) else {}
        session = Session(_offer_peer(info, self.client_address[0]), files)
        if not STORE.start(session):
            return self.reply(409)
        if not self._ask(session):
            return self.reply(403)

        session.state = "running"
        STORE.touch()
        self.reply(200, {"sessionId": session.id, "files": session.tokens})

    def _ask(self, session):
        """Put the offer on the notch and block until it is answered."""
        log("asking for", len(session.files), "file(s) from", session.peer["alias"])
        answered = session.answered.wait(CFG.ask_timeout)
        if answered and session.accepted:
            return True
        STORE.end(
            session,
            "declined" if answered else "expired",
            "" if answered else "no answer",
        )
        return False

    def _upload_session(self, sid):
        """The session this upload belongs to, or (None, status to reject with)."""
        s = STORE.session
        if s is None or s.id != sid:
            return None, 409
        if s.state != "running" or s.cancelled:
            return None, 403
        if s.peer["ip"] != self.client_address[0]:
            return None, 403
        return s, 0

    def _upload_entry(self, s, fid, tok):
        """The offered file this upload claims to be, if the token matches and
        it has not already arrived."""
        if s.tokens.get(fid) != tok or fid in s.done:
            return None
        return next((f for f in s.files if f["id"] == fid), None)

    def _expected_length(self, entry):
        declared = int(self.headers.get("Content-Length") or -1)
        chunked = "chunked" in (self.headers.get("Transfer-Encoding") or "").lower()
        return entry["size"] if chunked or declared < 0 else declared

    def _receive(self, s, entry, expect, fd):
        """Stream the body into the open .part file. Returns (bytes, digest)."""
        digest = hashlib.sha256() if entry["sha256"] else None
        got = 0
        with os.fdopen(fd, "wb") as fh:
            for chunk in self.stream_body(expect):
                if s.cancelled:
                    raise Cancelled()
                fh.write(chunk)
                if digest:
                    digest.update(chunk)
                got += len(chunk)
                s.received += len(chunk)
                STORE.touch()
        return got, digest

    def _verify(self, s, entry, got, expect, digest):
        """Status to reject with, or 0 if what arrived is sound."""
        if got < expect:
            STORE.end(s, "failed", "connection closed early")
            return 400
        if digest and digest.hexdigest() != entry["sha256"]:
            STORE.end(s, "failed", "checksum mismatch")
            return 422
        return 0

    def do_upload(self, q):
        sid, fid, tok = first(q, "sessionId"), first(q, "fileId"), first(q, "token")
        if not (sid and fid and tok):
            return self.reply(400)
        s, code = self._upload_session(sid)
        if s is None:
            return self.reply(code)
        entry = self._upload_entry(s, fid, tok)
        if entry is None:
            return self.reply(403)

        s.name = entry["name"]
        s.index = len(s.done) + 1
        STORE.touch()

        expect = self._expected_length(entry)
        final, part, fd = reserve(CFG.dest, entry["name"])
        try:
            got, digest = self._receive(s, entry, expect, fd)
        except Cancelled:
            part.unlink(missing_ok=True)
            return self.reply(403)
        except OSError as e:
            part.unlink(missing_ok=True)
            STORE.end(s, "failed", str(e))
            return self.reply(500)

        bad = self._verify(s, entry, got, expect, digest)
        if bad:
            part.unlink(missing_ok=True)
            return self.reply(bad)

        os.replace(part, final)
        s.done.add(fid)
        log("received", final)
        if len(s.done) == len(s.files):
            STORE.end(s, "done")
        else:
            STORE.touch()
        self.reply(200)

    def do_cancel(self, q):
        sid = first(q, "sessionId")
        s = STORE.session
        if s is not None and s.id == sid:
            s.cancelled = True
            STORE.end(s, "cancelled")
        self.reply(200)


class Server(ThreadingHTTPServer):
    daemon_threads = True
    allow_reuse_address = True


def control_loop(fifo: Path):
    fd = os.open(fifo, os.O_RDWR)
    with os.fdopen(fd, "r", buffering=1) as f:
        while True:
            line = f.readline()
            if not line:
                time.sleep(0.1)
                continue
            try:
                cmd = json.loads(line)
            except ValueError:
                continue
            if isinstance(cmd, dict):
                try:
                    dispatch(cmd)
                except Exception as e:
                    warn("command failed:", e)


def _answer(cmd, accepted):
    s = STORE.session
    if s is None or s.id != cmd.get("id"):
        return
    s.accepted = accepted
    s.answered.set()


def _cmd_cancel(cmd):
    cid = cmd.get("id")
    s, o = STORE.session, STORE.out
    if s is not None and s.id == cid:
        s.cancelled = True
        STORE.end(s, "cancelled")
    elif o is not None and o.id == cid:
        o.cancelled = True


def _cmd_send(cmd):
    peer = STORE.peer_by(str(cmd.get("peer") or ""))
    if not peer:
        return warn("send: no such peer")
    text, paths = cmd.get("text"), cmd.get("paths")
    if isinstance(text, str) and text:
        target, args = send_text, (peer, text)
    elif isinstance(paths, list) and paths:
        target, args = send_files, (peer, paths)
    else:
        return warn("send: nothing to send")
    threading.Thread(target=target, args=args, daemon=True).start()


def _cmd_scan(_cmd):
    with STORE.lock:
        STORE.peers = {}
    STORE.touch()
    if UDP is not None:
        announce(UDP)


CONTROL_COMMANDS = {
    "accept": lambda c: _answer(c, True),
    "deny": lambda c: _answer(c, False),
    "cancel": _cmd_cancel,
    "send": _cmd_send,
    "scan": _cmd_scan,
    "ping": lambda _c: STORE.touch(),
}


def dispatch(cmd):
    kind = cmd.get("cmd")
    log("cmd", kind)
    handler = CONTROL_COMMANDS.get(kind)
    if handler is not None:
        handler(cmd)


def parse_args():
    p = argparse.ArgumentParser(prog="notch-localsend")
    p.add_argument(
        "--alias", default=os.environ.get("LOCALSEND_ALIAS") or socket.gethostname()
    )
    p.add_argument(
        "--port", type=int, default=int(os.environ.get("LOCALSEND_PORT") or PORT)
    )
    p.add_argument(
        "--dest",
        type=Path,
        default=Path(
            os.environ.get("LOCALSEND_DESTINATION")
            or Path.home() / "downloads" / "localsend"
        ),
    )
    p.add_argument("--ask-timeout", type=int, default=60)
    p.add_argument(
        "--http",
        dest="https",
        action="store_false",
        help="serve plain HTTP instead of self-signed TLS",
    )
    p.add_argument("--verbose", action="store_true")
    return p.parse_args()


def runtime_dir():
    global RUN
    base = os.environ.get("XDG_RUNTIME_DIR") or f"/run/user/{os.getuid()}"
    d = Path(base) / "quickshell" / "localsend"
    d.mkdir(parents=True, exist_ok=True)
    os.chmod(d, 0o700)
    RUN = d
    return d


def main():
    global CFG, IDENT, STORE, VERBOSE
    CFG = parse_args()
    VERBOSE = CFG.verbose
    CFG.dest.mkdir(parents=True, exist_ok=True)

    home = Path(os.environ.get("XDG_STATE_HOME") or Path.home() / ".local" / "state")
    IDENT = Identity(home / "notch-localsend")

    run = runtime_dir()
    state, fifo = run / "state.json", run / "control"
    STORE = Store(state)

    if not fifo.exists():
        os.mkfifo(fifo, 0o600)

    ctx = None
    if CFG.https:
        ctx = ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER)
        ctx.load_cert_chain(IDENT.cert, IDENT.key)

    try:
        server = Server(("0.0.0.0", CFG.port), Handler)
    except OSError as e:
        warn(f"cannot bind {CFG.port}: {e}")
        return 1
    if ctx:
        server.socket = ctx.wrap_socket(server.socket, server_side=True)

    def bye(*_):
        state.unlink(missing_ok=True)
        fifo.unlink(missing_ok=True)
        os._exit(0)

    signal.signal(signal.SIGTERM, bye)
    signal.signal(signal.SIGINT, bye)

    STORE.write()
    threading.Thread(target=STORE.publish_loop, daemon=True).start()
    threading.Thread(target=control_loop, args=(fifo,), daemon=True).start()

    global UDP
    udp = make_udp()
    UDP = udp
    threading.Thread(target=listen_loop, args=(udp,), daemon=True).start()
    threading.Thread(target=announce_loop, args=(udp,), daemon=True).start()

    warn(
        f"notch-localsend: {CFG.alias} on {CFG.port} "
        f"({'https' if CFG.https else 'http'}), saving to {CFG.dest}"
    )
    try:
        server.serve_forever()
    finally:
        bye()
    return 0


if __name__ == "__main__":
    sys.exit(main())
