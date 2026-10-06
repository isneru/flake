#!/usr/bin/env python3

import concurrent.futures
import getpass
import hashlib
import html
import json
import os
import re
import shutil
import subprocess
import sys
import tempfile
import time
import urllib.error
import urllib.parse
import urllib.request
from pathlib import Path
from typing import NoReturn

SITE = os.environ.get("MOODLE_SITE", "https://moodle.isep.ipp.pt").rstrip("/")
SERVICE = "moodle_mobile_app"
USER_AGENT = "MoodleMobile 4.5.0 (nix-moodle-client)"
STATE_DIR = Path.home() / ".local" / "state" / "moodle"
COURSE_DIR = STATE_DIR / "courses"
TOKEN_FILE = STATE_DIR / "token.json"
INDEX_FILE = STATE_DIR / "index.json"
SEEN_FILE = STATE_DIR / "seen.json"
FILES_FILE = STATE_DIR / "files.json"
SEARCH_FILE = STATE_DIR / "search.json"
PREFS_FILE = STATE_DIR / "prefs.json"
ROOT = Path(os.environ.get("MOODLE_ROOT", str(Path.home() / "notes" / "isep")))
ARCHIVE = ROOT / "archive"
CODE = re.compile(r"(?:^|-)([A-Za-z0-9]+)\(\d+\)$")
CALENDAR_DAYS = 180
CALENDAR_PAGE = 50
CALENDAR_PAGES = 4
REMIND_MARKS = [10080, 1440, 120]
DOWNLOAD_WORKERS = 6
DETAIL_MODS = {"assign", "quiz", "forum"}
MUTED_EVENTS = {"newlogin"}


class WsError(Exception):
    pass


def die(msg) -> NoReturn:
    print(msg, file=sys.stderr)
    sys.exit(1)


def read_json(path, fallback):
    try:
        return json.loads(path.read_text())
    except (OSError, ValueError):
        return fallback


def write_json(path, data):
    path.parent.mkdir(parents=True, exist_ok=True)
    tmp = path.with_suffix(path.suffix + ".tmp")
    tmp.write_text(json.dumps(data))
    tmp.replace(path)


def flatten(params, prefix=""):
    """Encodes nested params the way Moodle's REST server expects them."""
    out = {}
    for key, value in params.items():
        name = f"{prefix}[{key}]" if prefix else str(key)
        if isinstance(value, (list, tuple)):
            for i, item in enumerate(value):
                if isinstance(item, dict):
                    out.update(flatten(item, f"{name}[{i}]"))
                else:
                    out[f"{name}[{i}]"] = item
        elif isinstance(value, dict):
            out.update(flatten(value, name))
        elif value is not None:
            out[name] = value
    return out


def post(url, data, timeout=60):
    body = urllib.parse.urlencode(data).encode()
    req = urllib.request.Request(url, data=body, headers={"User-Agent": USER_AGENT})
    try:
        with urllib.request.urlopen(req, timeout=timeout) as r:
            raw = r.read()
    except urllib.error.HTTPError as e:
        raise WsError(f"{url} returned {e.code}") from e
    except (urllib.error.URLError, TimeoutError) as e:
        raise WsError(f"{url} unreachable: {e}") from e
    try:
        return json.loads(raw) if raw else {}
    except ValueError as e:
        raise WsError(f"{url} returned non-JSON") from e


def token():
    saved = read_json(TOKEN_FILE, {})
    if not saved.get("token"):
        die("not logged in - run: moodle login")
    return saved["token"]


def ws(function, tok=None, **params):
    data = flatten(params)
    data.update(
        {
            "wstoken": tok or token(),
            "wsfunction": function,
            "moodlewsrestformat": "json",
        }
    )
    result = post(f"{SITE}/webservice/rest/server.php", data)
    if isinstance(result, dict) and result.get("exception"):
        raise WsError(f"{function}: {result.get('message', result['exception'])}")
    return result


def maybe(function, default=None, **params):
    try:
        return ws(function, **params)
    except WsError as e:
        print(f"  skipped {e}", file=sys.stderr)
        return default


def label(value):
    return html.unescape(value or "").strip()


def plain(markup):
    if not markup:
        return ""
    text = re.sub(
        r"<br\s*/?>|</p\s*>|</div\s*>|</li\s*>", "\n", markup, flags=re.IGNORECASE
    )
    text = re.sub(r"<[^>]+>", "", text)
    return re.sub(r"\n{3,}", "\n\n", html.unescape(text)).strip()


def safe(name, fallback="untitled"):
    cleaned = re.sub(r"[\x00-\x1f/]+", "_", (name or "").strip()).strip(". ")
    return (cleaned or fallback)[:120]


def slug(shortname):
    found = CODE.search(shortname)
    name = found.group(1) if found else shortname
    return re.sub(r"[^a-z0-9]+", "-", name.lower()).strip("-") or "untitled"


def authed(url):
    if not url:
        return ""
    url = url.replace(
        f"{SITE}/pluginfile.php/", f"{SITE}/webservice/pluginfile.php/", 1
    )
    sep = "&" if "?" in url else "?"
    return f"{url}{sep}token={token()}"


def current(prior, dest, url, size, modified):
    """True when the mirrored copy already matches what Moodle reports."""
    if not prior or prior.get("url") != url or prior.get("modified") != modified:
        return False
    try:
        stat = dest.stat()
    except OSError:
        return False
    return not (size and stat.st_size != size)


def adopt(dest, size, modified):
    if not modified:
        return False
    try:
        stat = dest.stat()
    except OSError:
        return False
    if size and stat.st_size != size:
        return False
    return int(stat.st_mtime) == modified


def download(prior, url, dest, size, modified):
    """Returns (status, record): skipped, new, updated, same or failed."""
    if current(prior, dest, url, size, modified):
        return "skipped", None
    mark = {"url": url, "size": size, "modified": modified, "sha256": ""}
    if prior is None and adopt(dest, size, modified):
        return "skipped", mark
    dest.parent.mkdir(parents=True, exist_ok=True)
    handle, name = tempfile.mkstemp(dir=dest.parent, prefix=".moodle-", suffix=".part")
    tmp = Path(name)
    digest = hashlib.sha256()
    try:
        with (
            urllib.request.urlopen(authed(url), timeout=180) as r,
            os.fdopen(handle, "wb") as f,
        ):
            while chunk := r.read(262144):
                f.write(chunk)
                digest.update(chunk)
        if tmp.stat().st_size and not dest.name.lower().endswith((".html", ".htm")):
            head = tmp.open("rb").read(64).lstrip().lower()
            if head.startswith(b"<html") or head.startswith(b"<!doctype html"):
                tmp.unlink(missing_ok=True)
                print(f"  refused HTML body for {dest.name}", file=sys.stderr)
                return "failed", None
        tmp.replace(dest)
    except Exception as e:
        tmp.unlink(missing_ok=True)
        print(f"  download failed {dest.name}: {e}", file=sys.stderr)
        return "failed", None
    if modified:
        os.utime(dest, (modified, modified))
    mark["sha256"] = digest.hexdigest()
    if prior is None:
        return "new", mark
    if prior.get("sha256") == mark["sha256"]:
        return "same", mark
    return "updated", mark


def unique_path(taken, path, url):
    """Keeps two different files in one course from claiming the same path."""
    if taken.get(path) in (None, url):
        taken[path] = url
        return path
    stem, dot, ext = path.rpartition(".")
    base, tail = (stem, f".{ext}") if dot else (path, "")
    number = 2
    while True:
        candidate = f"{base} ({number}){tail}"
        if taken.get(candidate) in (None, url):
            taken[candidate] = url
            return candidate
        number += 1


def stamp(value):
    return int(value or 0)


def academic_year(when):
    """The September-to-August academic year a timestamp falls in, or 0."""
    if not when:
        return 0
    moment = time.localtime(when)
    return moment.tm_year if moment.tm_mon >= 8 else moment.tm_year - 1


def classify(course, classified):
    now = time.time()
    start, end = stamp(course.get("startdate")), stamp(course.get("enddate"))
    if end and end < now:
        return "past"
    if start and start > now:
        return "future"
    year = academic_year(start) or academic_year(stamp(course.get("lastaccess")))
    if year:
        return "inprogress" if year == academic_year(now) else "past"
    return "inprogress" if course["id"] in classified.get("inprogress", ()) else "past"


def term_of(course):
    when = stamp(course.get("startdate")) or stamp(course.get("lastaccess"))
    if not when:
        return ""
    moment = time.localtime(when)
    year = academic_year(when)
    half = "1S" if moment.tm_mon >= 8 or moment.tm_mon < 2 else "2S"
    return f"{year}/{str(year + 1)[2:]} · {half}"


def collect_courses(tok, userid):
    courses = ws("core_enrol_get_users_courses", tok=tok, userid=userid)
    classified = {}
    for name in ("inprogress", "future", "past"):
        page = maybe(
            "core_course_get_enrolled_courses_by_timeline_classification",
            {},
            classification=name,
            limit=0,
            offset=0,
        )
        classified[name] = {c["id"] for c in (page or {}).get("courses", [])}
    return courses, classified


IMG_SRC = re.compile(r'(<img\b[^>]*?\bsrc=")([^"]+)(")', re.IGNORECASE)


def embed_images(markup, course_dir, section_name):
    """Points <img> sources at local copies, returning the markup and files to fetch."""
    if not markup or "<img" not in markup.lower():
        return markup, []
    wanted = []

    def swap(match):
        url = html.unescape(match.group(2))
        if not url.startswith(SITE):
            return match.group(0)
        parts = urllib.parse.urlparse(url)
        name = safe(urllib.parse.unquote(parts.path.rsplit("/", 1)[-1])) or "image"
        when = urllib.parse.parse_qs(parts.query).get("time", [""])[0]
        digest = hashlib.sha1(url.encode()).hexdigest()[:8]
        dest = course_dir / safe(section_name) / "_media" / digest / name
        wanted.append(
            {
                "name": name,
                "path": str(dest),
                "url": url,
                "size": 0,
                "modified": int(when) // 1000 if when.isdigit() else 0,
                "mime": "",
            }
        )
        return f"{match.group(1)}file://{urllib.parse.quote(str(dest))}{match.group(3)}"

    return IMG_SRC.sub(swap, markup), wanted


def module_files(course_dir, section_name, module):
    files, links = [], []
    for item in module.get("contents") or []:
        if item.get("type") == "url":
            links.append(
                {
                    "name": label(item.get("filename")) or module["name"],
                    "url": label(item.get("fileurl")),
                }
            )
            continue
        if item.get("type") != "file" or not item.get("fileurl"):
            continue
        rel = (item.get("filepath") or "/").strip("/")
        parts = [safe(p) for p in rel.split("/") if p]
        dest = course_dir.joinpath(
            safe(section_name), *parts, safe(item.get("filename"))
        )
        files.append(
            {
                "name": label(item.get("filename")),
                "path": str(dest),
                "url": item.get("fileurl", ""),
                "size": stamp(item.get("filesize")),
                "modified": stamp(item.get("timemodified")),
                "mime": item.get("mimetype", ""),
            }
        )
    return files, links


def build_sections(course, course_dir, media):
    contents = maybe("core_course_get_contents", [], courseid=course["id"])
    sections, taken = [], {}
    for raw in contents or []:
        name = label(re.sub(r"<[^>]+>", "", raw.get("name") or "")) or (
            f"Section {raw.get('section', 0)}"
        )
        modules = []
        for module in raw.get("modules") or []:
            files, links = module_files(course_dir, name, module)
            for item in files:
                item["path"] = unique_path(taken, item["path"], item["url"])
            body, found = embed_images(
                module.get("description") or "", course_dir, name
            )
            media.extend(found)
            modules.append(
                {
                    "cmid": module.get("id"),
                    "modname": module.get("modname", ""),
                    "name": label(module.get("name")),
                    "url": label(module.get("url")),
                    "html": body,
                    "text": plain(module.get("description")),
                    "visible": bool(module.get("uservisible", True)),
                    "files": files,
                    "links": links,
                }
            )
        summary, found = embed_images(raw.get("summary") or "", course_dir, name)
        media.extend(found)
        sections.append(
            {
                "name": name,
                "html": summary,
                "text": plain(raw.get("summary")),
                "modules": modules,
            }
        )
    return sections


def course_grades(course, userid):
    report = maybe(
        "gradereport_user_get_grade_items", {}, courseid=course["id"], userid=userid
    )
    grades = []
    for user in (report or {}).get("usergrades", []):
        for item in user.get("gradeitems", []):
            if item.get("itemtype") == "course":
                label = "Final"
            else:
                label = item.get("itemname") or item.get("itemmodule") or ""
            grades.append(
                {
                    "name": label,
                    "grade": item.get("gradeformatted") or "",
                    "percentage": item.get("percentageformatted") or "",
                    "range": f"{item.get('grademin', '')}-{item.get('grademax', '')}",
                    "feedback": plain(item.get("feedbackformatted")),
                    "weight": item.get("weightformatted") or "",
                }
            )
    return [g for g in grades if g["name"]]


def course_announcements(course, course_dir, media):
    forums = maybe("mod_forum_get_forums_by_courses", [], courseids=[course["id"]])
    posts = []
    for forum in forums or []:
        page = maybe(
            "mod_forum_get_forum_discussions",
            None,
            forumid=forum.get("id"),
            perpage=20,
        )
        if page is None:
            page = maybe(
                "mod_forum_get_forum_discussions_paginated",
                {},
                forumid=forum.get("id"),
                perpage=20,
            )
        for item in (page or {}).get("discussions", []):
            body, found = embed_images(
                item.get("message") or "", course_dir, label(forum.get("name"))
            )
            media.extend(found)
            posts.append(
                {
                    "id": f"{forum.get('id')}:{item.get('discussion') or item.get('id')}",
                    "forum": label(forum.get("name")),
                    "subject": label(item.get("name") or item.get("subject")),
                    "author": label(item.get("userfullname")),
                    "time": stamp(item.get("timemodified") or item.get("created")),
                    "html": body,
                    "text": plain(item.get("message")),
                    "url": f"{SITE}/mod/forum/discuss.php?d={item.get('discussion') or item.get('id')}",
                }
            )
    posts.sort(key=lambda p: p["time"], reverse=True)
    return posts[:40]


def course_assessments(course, course_dir, media):
    out = []
    assigns = maybe("mod_assign_get_assignments", {}, courseids=[course["id"]])
    for entry in (assigns or {}).get("courses", []):
        for assign in entry.get("assignments", []):
            status = maybe(
                "mod_assign_get_submission_status", {}, assignid=assign.get("id")
            )
            submission = ((status or {}).get("lastattempt") or {}).get(
                "submission"
            ) or {}
            body, found = embed_images(
                assign.get("intro") or "", course_dir, "_assessment"
            )
            media.extend(found)
            out.append(
                {
                    "kind": "assign",
                    "id": assign.get("id"),
                    "cmid": assign.get("cmid"),
                    "name": label(assign.get("name")),
                    "due": stamp(assign.get("duedate")),
                    "cutoff": stamp(assign.get("cutoffdate")),
                    "opens": stamp(assign.get("allowsubmissionsfromdate")),
                    "html": body,
                    "text": plain(assign.get("intro")),
                    "state": submission.get("status", ""),
                    "url": f"{SITE}/mod/assign/view.php?id={assign.get('cmid')}",
                }
            )
    quizzes = maybe("mod_quiz_get_quizzes_by_courses", {}, courseids=[course["id"]])
    for quiz in (quizzes or {}).get("quizzes", []):
        intro, found = embed_images(quiz.get("intro") or "", course_dir, "_assessment")
        media.extend(found)
        out.append(
            {
                "kind": "quiz",
                "id": quiz.get("id"),
                "cmid": quiz.get("coursemodule"),
                "name": label(quiz.get("name")),
                "due": stamp(quiz.get("timeclose")),
                "cutoff": 0,
                "opens": stamp(quiz.get("timeopen")),
                "html": intro,
                "text": plain(quiz.get("intro")),
                "state": "",
                "url": f"{SITE}/mod/quiz/view.php?id={quiz.get('coursemodule')}",
            }
        )
    out.sort(key=lambda a: a["due"] or 1 << 62)
    return out


def upcoming(courses_by_id):
    now = int(time.time())
    events, after = [], None
    for _ in range(CALENDAR_PAGES):
        page = maybe(
            "core_calendar_get_action_events_by_timesort",
            {},
            timesortfrom=now - 86400,
            timesortto=now + CALENDAR_DAYS * 86400,
            limitnum=CALENDAR_PAGE,
            aftereventid=after,
        )
        batch = (page or {}).get("events", [])
        for event in batch:
            course = (event.get("course") or {}).get("id")
            events.append(
                {
                    "id": str(event.get("id")),
                    "name": label(event.get("name")),
                    "when": stamp(event.get("timesort")),
                    "modname": event.get("modulename") or event.get("eventtype", ""),
                    "courseId": course,
                    "course": courses_by_id.get(course, {}).get("shortname", ""),
                    "url": label(
                        (event.get("action") or {}).get("url") or event.get("url")
                    ),
                    "overdue": bool(event.get("overdue")),
                }
            )
        if len(batch) < CALENDAR_PAGE:
            break
        after = batch[-1].get("id")
    events.sort(key=lambda e: e["when"])
    return events


def notifications(userid):
    page = maybe("message_popup_get_popup_notifications", {}, useridto=userid, limit=40)
    out = []
    for note in (page or {}).get("notifications", []):
        if note.get("eventtype") in MUTED_EVENTS:
            continue
        out.append(
            {
                "id": str(note.get("id")),
                "subject": label(note.get("subject")),
                "text": plain(note.get("fullmessagehtml") or note.get("fullmessage")),
                "time": stamp(note.get("timecreated")),
                "read": bool(note.get("read")),
                "url": label(note.get("contexturl")),
            }
        )
    return out


def snippet(text, limit=240):
    flat = re.sub(r"\s+", " ", text or "").strip()
    return flat[:limit]


def search_rows(record, detail):
    """Flat rows for the app's cross-course search."""
    course, cid = record.get("shortname") or record.get("fullname", ""), record["id"]
    rows = [
        {
            "kind": "course",
            "course": course,
            "courseId": cid,
            "modname": "school",
            "name": record.get("fullname", ""),
            "text": record.get("term", ""),
            "url": record.get("url", ""),
            "path": "",
            "mime": "",
        }
    ]
    for section in detail.get("sections", []):
        for module in section["modules"]:
            rows.append(
                {
                    "kind": "module",
                    "course": course,
                    "courseId": cid,
                    "modname": module["modname"],
                    "name": module["name"] or section["name"],
                    "text": snippet(module["text"]) or section["name"],
                    "url": module["url"],
                    "path": "",
                    "mime": "",
                }
            )
            for item in module["files"]:
                rows.append(
                    {
                        "kind": "file",
                        "course": course,
                        "courseId": cid,
                        "modname": module["modname"],
                        "name": item["name"],
                        "text": f"{section['name']} \u00b7 {module['name']}",
                        "url": module["url"],
                        "path": item["path"],
                        "mime": item["mime"],
                    }
                )
    for post in detail.get("announcements", []):
        rows.append(
            {
                "kind": "post",
                "course": course,
                "courseId": cid,
                "modname": "forum",
                "name": post["subject"],
                "text": snippet(post["text"]),
                "url": post["url"],
                "path": "",
                "mime": "",
            }
        )
    for work in detail.get("assessments", []):
        rows.append(
            {
                "kind": "assess",
                "course": course,
                "courseId": cid,
                "modname": work["kind"],
                "name": work["name"],
                "text": snippet(work["text"]),
                "url": work["url"],
                "path": "",
                "mime": "",
            }
        )
    return rows


def notify(title, body, urgency="normal"):
    try:
        subprocess.run(
            [
                "notify-send",
                "-a",
                "moodle",
                "-u",
                urgency,
                "-i",
                "applications-education",
                title,
                body,
            ],
            check=False,
        )
    except FileNotFoundError:
        pass


def announce(seen, first_run, index, details, changes):
    fresh_posts, fresh_grades = [], []
    posts_seen = set(seen.get("posts", []))
    grades_seen = seen.get("grades", {})

    for course in index["courses"]:
        detail = details.get(course["id"], {})
        for post in detail.get("announcements", []):
            if post["id"] not in posts_seen:
                posts_seen.add(post["id"])
                fresh_posts.append((course["shortname"], post["subject"]))
        for grade in detail.get("grades", []):
            key = f"{course['id']}:{grade['name']}"
            if grade["grade"] and grades_seen.get(key) != grade["grade"]:
                if key in grades_seen or not first_run:
                    fresh_grades.append(
                        (course["shortname"], grade["name"], grade["grade"])
                    )
                grades_seen[key] = grade["grade"]

    added = [(c, n) for c, n, status in changes if status == "new"]
    revised = [(c, n) for c, n, status in changes if status == "updated"]
    reminded = seen.get("reminded", {})
    now = time.time()
    if not first_run:
        for event in index["deadlines"]:
            minutes = (event["when"] - now) / 60
            if minutes < 0:
                continue
            fired = set(reminded.get(event["id"], []))
            for mark in REMIND_MARKS:
                if minutes <= mark and mark not in fired:
                    fired.add(mark)
                    notify(
                        f"{event['course']} · {event['name']}",
                        f"due {due_label(event['when'])}",
                        "critical" if mark <= 120 else "normal",
                    )
            reminded[event["id"]] = sorted(fired)

    if not first_run:
        for shortname, name in fresh_posts[:6]:
            notify(f"{shortname} · announcement", name)
        for shortname, name, value in fresh_grades[:6]:
            notify(f"{shortname} · grade", f"{name}: {value}")
        for word, group in (("new", added), ("updated", revised)):
            if group:
                head = ", ".join(f"{c} {n}" for c, n in group[:3])
                extra = f" +{len(group) - 3} more" if len(group) > 3 else ""
                notify(f"{len(group)} {word} file(s)", head + extra)

    write_json(
        SEEN_FILE,
        {
            "posts": sorted(posts_seen),
            "grades": grades_seen,
            "reminded": reminded,
        },
    )
    return len(added), len(revised), len(fresh_posts), len(fresh_grades)


def due_label(when):
    delta = when - time.time()
    if delta < 0:
        return "overdue"
    if delta < 3600:
        return f"in {int(delta // 60)} min"
    if delta < 86400:
        return f"in {int(delta // 3600)} h"
    return f"in {int(delta // 86400)} d"


def cmd_login():
    print(f"Moodle at {SITE}")
    user = input("username: ").strip()
    password = getpass.getpass("password: ")
    answer = post(
        f"{SITE}/login/token.php",
        {"username": user, "password": password, "service": SERVICE},
    )
    if "token" not in answer:
        die(answer.get("error", "login refused"))
    tok = answer["token"]
    info = ws("core_webservice_get_site_info", tok=tok)
    STATE_DIR.mkdir(parents=True, exist_ok=True)
    write_json(
        TOKEN_FILE,
        {
            "token": tok,
            "privatetoken": answer.get("privatetoken") or "",
            "userid": info.get("userid"),
            "username": info.get("username", user),
            "fullname": info.get("fullname", ""),
            "site": SITE,
        },
    )
    TOKEN_FILE.chmod(0o600)
    print(f"logged in as {info.get('fullname', user)}")
    if not answer.get("privatetoken"):
        print(
            "note: the site returned no private token - 'open in browser' will not "
            "carry your session",
            file=sys.stderr,
        )


def course_record(course, classified, hidden, pinned):
    return {
        "id": course["id"],
        "shortname": label(course.get("shortname")),
        "fullname": label(course.get("fullname")),
        "term": term_of(course),
        "classification": classify(course, classified),
        "start": stamp(course.get("startdate")),
        "end": stamp(course.get("enddate")),
        "progress": course.get("progress"),
        "lastaccess": stamp(course.get("lastaccess")),
        "hidden": course["id"] in hidden,
        "pinned": course["id"] in pinned,
        "files": 0,
        "url": f"{SITE}/course/view.php?id={course['id']}",
    }


def place(records):
    """Current courses mirror into <name>/materials; past and older ones into archive/."""
    taken = set()
    ranked = sorted(
        (r for r in records if not r["hidden"]),
        key=lambda r: (
            r["classification"] != "inprogress",
            -(academic_year(r["start"]) or academic_year(r["lastaccess"])),
            -r["id"],
        ),
    )
    for record in ranked:
        name = slug(record["shortname"] or record["fullname"])
        year = academic_year(record["start"]) or academic_year(record["lastaccess"])
        record["home"] = str(ROOT / name)
        dest = ROOT / name / "materials"
        if record["classification"] != "inprogress" or dest in taken:
            dest = ARCHIVE / name
        if dest in taken:
            dest = ARCHIVE / f"{name}-{year}-{(year + 1) % 100:02d}"
        if dest in taken:
            dest = ARCHIVE / f"{name}-{record['id']}"
        taken.add(dest)
        record["dir"] = str(dest)


def relocate(old, new, mirror):
    """Moves a course's mirror when its folder changes, keeping files.json in step."""
    if not old or old == new:
        return
    source, dest = Path(old), Path(new)
    if not source.is_dir() or dest.exists():
        return
    dest.parent.mkdir(parents=True, exist_ok=True)
    source.rename(dest)
    print(f"moved {source} -> {dest}", flush=True)
    for path in [p for p in mirror if p.startswith(old + "/")]:
        mirror[new + path[len(old) :]] = mirror.pop(path)


def owned(target):
    root = ROOT.resolve()
    return (target.name == "materials" and target.parent.parent == root) or (
        target.parent == ARCHIVE.resolve()
    )


def purge_course(record):
    """Deletes a hidden course's mirrored files and cached detail."""
    removed = freed = 0
    target = Path(record.get("dir") or "/").resolve()
    if owned(target) and target.is_dir():
        for item in target.rglob("*"):
            if item.is_file():
                removed += 1
                freed += item.stat().st_size
        shutil.rmtree(target, ignore_errors=True)
        mirror = read_json(FILES_FILE, {})
        alive = {p: mark for p, mark in mirror.items() if Path(p).exists()}
        if len(alive) != len(mirror):
            write_json(FILES_FILE, alive)
    (COURSE_DIR / f"{record['id']}.json").unlink(missing_ok=True)
    record["files"] = 0
    record.pop("dir", None)
    return removed, freed


def drop_rows(course_id):
    rows = [
        row
        for row in read_json(SEARCH_FILE, {}).get("rows", [])
        if row.get("courseId") != course_id
    ]
    write_json(SEARCH_FILE, {"rows": rows})


def course_order(course):
    return (
        not course["pinned"],
        course["classification"] != "inprogress",
        -course["lastaccess"],
    )


def cmd_sync(full):
    saved = read_json(TOKEN_FILE, {})
    tok, userid = token(), saved.get("userid")
    if not userid:
        info = ws("core_webservice_get_site_info", tok=tok)
        userid = info.get("userid")
        saved["userid"] = userid
        write_json(TOKEN_FILE, saved)

    prefs = read_json(PREFS_FILE, {})
    hidden, pinned = set(prefs.get("hidden", [])), set(prefs.get("pinned", []))
    raw_courses, classified = collect_courses(tok, userid)

    records = [course_record(c, classified, hidden, pinned) for c in raw_courses]
    records.sort(key=course_order)
    prior = {
        c["id"]: c.get("dir") for c in read_json(INDEX_FILE, {}).get("courses", [])
    }
    place(records)
    mirror = read_json(FILES_FILE, {})
    for record in records:
        if record["hidden"]:
            record["dir"] = prior.get(record["id"])
        else:
            relocate(prior.get(record["id"]), record["dir"], mirror)
    write_json(FILES_FILE, mirror)

    purged = purged_bytes = 0
    for record in records:
        if record["hidden"]:
            gone, freed = purge_course(record)
            purged += gone
            purged_bytes += freed

    by_id = {c["id"]: c for c in records}
    index = {
        "updated": int(time.time()),
        "site": SITE,
        "user": saved.get("fullname", ""),
        "courses": records,
        "deadlines": [
            event
            for event in upcoming(by_id)
            if not by_id.get(event["courseId"], {}).get("hidden")
        ],
        "notifications": notifications(userid),
    }
    write_json(INDEX_FILE, index)
    print(f"{len(records)} courses indexed", flush=True)
    if purged:
        print(f"purged {purged} files from hidden courses", flush=True)

    queue = [
        r
        for r in records
        if not r["hidden"]
        and (full or r["classification"] == "inprogress" or r["pinned"])
    ]
    raw_by_id = {c["id"]: c for c in raw_courses}
    known = {r["id"] for r in records if not r["hidden"]}
    refreshing = {r["id"] for r in queue}
    rows = [
        row
        for row in read_json(SEARCH_FILE, {}).get("rows", [])
        if row.get("courseId") in known and row.get("courseId") not in refreshing
    ]
    details, fetched, changes = {}, 0, []

    try:
        for position, record in enumerate(queue, 1):
            course = raw_by_id[record["id"]]
            course_dir = Path(record["dir"])
            print(f"[{position}/{len(queue)}] {record['shortname']}", flush=True)

            media = []
            sections = build_sections(course, course_dir, media)
            detail = {
                "id": record["id"],
                "sections": sections,
                "grades": course_grades(course, userid),
                "announcements": course_announcements(course, course_dir, media),
                "assessments": course_assessments(course, course_dir, media),
            }
            details[record["id"]] = detail
            write_json(COURSE_DIR / f"{record['id']}.json", detail)

            items = [
                item
                for section in sections
                for module in section["modules"]
                if module["visible"]
                for item in module["files"]
            ]
            record["files"] = len(items)
            items += media

            rows.extend(search_rows(record, detail))
            write_json(SEARCH_FILE, {"rows": rows})
            index["updated"] = int(time.time())
            write_json(INDEX_FILE, index)

            got, changed = fetch_downloads(items, mirror)
            fetched += got
            changes.extend(
                (record["shortname"], name, status) for name, status in changed
            )
            write_json(FILES_FILE, mirror)
    except KeyboardInterrupt:
        print(f"\ninterrupted - {len(details)} of {len(queue)} courses kept")

    first_run = not SEEN_FILE.exists()
    seen = read_json(SEEN_FILE, {})
    new, updated, posts, grades = announce(seen, first_run, index, details, changes)
    print(
        f"{len(records)} courses, {fetched} files downloaded, "
        f"{new} new, {updated} updated, {posts} announcements, "
        f"{grades} grade changes"
    )


def fetch_downloads(items, mirror):
    seen, wanted = set(), []
    for item in items:
        if item["path"] not in seen:
            seen.add(item["path"])
            wanted.append(item)
    got, changed = 0, []
    if not wanted:
        return got, changed
    with concurrent.futures.ThreadPoolExecutor(DOWNLOAD_WORKERS) as pool:
        outcomes = pool.map(
            lambda i: (
                i,
                download(
                    mirror.get(i["path"]),
                    i["url"],
                    Path(i["path"]),
                    i["size"],
                    i["modified"],
                ),
            ),
            wanted,
        )
        for item, (status, mark) in outcomes:
            if mark is not None:
                mirror[item["path"]] = mark
            if status in ("new", "updated", "same"):
                got += 1
            if status in ("new", "updated"):
                changed.append((item["name"], status))
    return got, changed


def cmd_course(course_id):
    if not course_id:
        die("usage: moodle course <courseId>")
    wanted = int(course_id)
    userid = read_json(TOKEN_FILE, {}).get("userid")
    index = read_json(INDEX_FILE, {})
    record = next((c for c in index.get("courses", []) if c["id"] == wanted), None)
    if not record:
        die(f"course {wanted} is not in the index - run: moodle sync")
    if record.get("hidden"):
        die(f"course {wanted} is hidden - run: moodle unhide {wanted}")
    if not record.get("dir"):
        die(f"course {wanted} has no folder yet - run: moodle sync")
    course_dir = Path(record["dir"])
    media = []
    sections = build_sections({"id": wanted}, course_dir, media)
    detail = {
        "id": wanted,
        "sections": sections,
        "grades": course_grades({"id": wanted}, userid),
        "announcements": course_announcements({"id": wanted}, course_dir, media),
        "assessments": course_assessments({"id": wanted}, course_dir, media),
    }
    write_json(COURSE_DIR / f"{wanted}.json", detail)
    kept = [
        row
        for row in read_json(SEARCH_FILE, {}).get("rows", [])
        if row.get("courseId") != wanted
    ]
    write_json(SEARCH_FILE, {"rows": kept + search_rows(record, detail)})
    items = [
        item
        for section in sections
        for module in section["modules"]
        if module["visible"]
        for item in module["files"]
    ]
    mirror = read_json(FILES_FILE, {})
    got, _ = fetch_downloads(items + media, mirror)
    write_json(FILES_FILE, mirror)
    print(f"{record['shortname']}: {got} files updated")


def cmd_browser(target):
    url = target or f"{SITE}/my/"
    saved = read_json(TOKEN_FILE, {})
    private = saved.get("privatetoken")
    if not private:
        print(
            "no private token stored - run: moodle login (opening without a session)",
            file=sys.stderr,
        )
    else:
        key = maybe("tool_mobile_get_autologin_key", {}, privatetoken=private)
        if key and key.get("key"):
            url = f"{key.get('autologinurl')}?" + urllib.parse.urlencode(
                {
                    "userid": saved.get("userid"),
                    "key": key["key"],
                    "urltogo": url,
                }
            )
    subprocess.Popen(
        ["qutebrowser", url],
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
        start_new_session=True,
    )


def cmd_prefs(action, course_id):
    if not course_id:
        die(f"usage: moodle {action} <courseId>")
    wanted = int(course_id)
    prefs = read_json(PREFS_FILE, {"hidden": [], "pinned": []})
    key = "hidden" if action in ("hide", "unhide") else "pinned"
    values = set(prefs.get(key, []))
    if action in ("unhide", "unpin"):
        values.discard(wanted)
    else:
        values.add(wanted)
    prefs[key] = sorted(values)
    write_json(PREFS_FILE, prefs)

    index = read_json(INDEX_FILE, {})
    courses = index.get("courses") or []
    record = next((c for c in courses if c["id"] == wanted), None)
    if record:
        record[key] = wanted in values
    if action == "hide" and record:
        removed, freed = purge_course(record)
        drop_rows(wanted)
        index["deadlines"] = [
            event for event in index.get("deadlines", []) if event["courseId"] != wanted
        ]
        if removed:
            print(f"removed {removed} files ({freed / 1048576:.1f} MB) from disk")
        print("it will be skipped by every sync until you unhide it")
    if action == "unhide":
        print("run: moodle sync --full   to mirror it again")
    if courses:
        courses.sort(key=course_order)
        write_json(INDEX_FILE, index)
    print(f"{key}: {prefs[key]}")


def cmd_status():
    saved = read_json(TOKEN_FILE, {})
    if not saved.get("token"):
        die("not logged in")
    index = read_json(INDEX_FILE, {})
    updated = index.get("updated")
    when = time.strftime("%d/%m %H:%M", time.localtime(updated)) if updated else "never"
    print(f"{saved.get('fullname', saved.get('username'))} @ {saved.get('site', SITE)}")
    print(f"synced {when}, {len(index.get('courses', []))} courses")


def main():
    command = sys.argv[1] if len(sys.argv) > 1 else "sync"
    args = sys.argv[2:]
    if command == "login":
        cmd_login()
    elif command == "sync":
        cmd_sync("--full" in args)
    elif command == "course":
        cmd_course(args[0] if args else "")
    elif command == "browser":
        cmd_browser(args[0] if args else "")
    elif command in ("hide", "unhide", "pin", "unpin"):
        cmd_prefs(command, args[0] if args else "")
    elif command == "status":
        cmd_status()
    else:
        die(
            "usage: moodle [login|sync [--full]|course <id>|browser [url]"
            "|hide|unhide|pin|unpin <id>|status]"
        )


if __name__ == "__main__":
    main()
