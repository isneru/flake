pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    readonly property string stateDir: `${Quickshell.env("HOME")}/.local/state/moodle`

    property var index: ({})
    property bool ready: false
    readonly property var courses: root.index.courses ?? []
    readonly property var deadlines: root.index.deadlines ?? []
    readonly property var notices: root.index.notifications ?? []
    readonly property int updated: root.index.updated ?? 0
    readonly property string user: root.index.user ?? ""

    property int courseId: 0
    property var detail: ({})
    property bool detailReady: false
    property var rows: []

    property var notes: []

    property string filter: "current"
    property string query: ""
    property string tab: "content"

    readonly property bool syncing: syncer.running
    readonly property bool refreshing: refresher.running

    readonly property var course: root.courses.find(c => c.id === root.courseId) ?? null

    readonly property var shown: {
        const all = root.courses.filter(c => root.filter === "all" || !c.hidden);
        if (root.filter === "past")
            return all.filter(c => c.classification === "past" && !c.pinned);
        if (root.filter === "all")
            return all;
        return all.filter(c => c.pinned || c.classification === "inprogress");
    }

    readonly property var soon: root.deadlines.filter(d => !d.overdue || d.when > Date.now() / 1000 - 604800)

    property bool week: false
    property var agenda: []
    property double now: Date.now()

    Timer {
        interval: 30000
        running: true
        repeat: true
        onTriggered: root.now = Date.now()
    }

    FileView {
        path: `${Quickshell.env("HOME")}/.local/state/quickshell/agenda.json`
        watchChanges: true
        onFileChanged: reload()
        onLoaded: {
            try {
                root.agenda = JSON.parse(text()).events ?? [];
            } catch (e) {
                root.agenda = [];
            }
        }
        onLoadFailed: root.agenda = []
    }

    function courseFor(code: string): int {
        const pattern = new RegExp(`(^|-)${code}(\\(|\\s|$)`);
        const hits = root.courses.filter(c => c.classification === "inprogress" && !c.hidden && pattern.test(c.shortname ?? ""));
        hits.sort((a, b) => (b.lastaccess ?? 0) - (a.lastaccess ?? 0));
        return hits.length ? hits[0].id : 0;
    }

    readonly property var lecture: /^(PL|TP|T) - (\S+) - (.+)$/

    readonly property var classes: {
        const ids = {};
        return root.agenda.filter(e => !e.allDay && root.lecture.test(e.title)).map(e => {
            const parts = String(e.title).match(root.lecture);
            const code = parts[2];
            if (!(code in ids))
                ids[code] = root.courseFor(code);
            return {
                code: code,
                kind: parts[1],
                title: e.title,
                room: e.location || parts[3],
                teacher: String(e.description ?? "").split("\n")[0],
                start: new Date(e.start).getTime(),
                end: new Date(e.end).getTime(),
                courseId: ids[code],
                link: e.link ?? ""
            };
        });
    }

    readonly property var nextClass: root.classes.find(c => c.end > root.now) ?? null

    function classesOf(id: int): var {
        return root.classes.filter(c => c.courseId === id && c.end > root.now);
    }

    readonly property var task: /^(\S+) - (.+)$/

    readonly property var tasks: {
        const ids = {};
        return root.agenda.filter(e => e.calendar === "Deadlines" && root.task.test(e.title)).map(e => {
            const parts = String(e.title).match(root.task);
            const code = parts[1];
            if (!(code in ids))
                ids[code] = root.courseFor(code);
            return {
                kind: "deadline",
                name: parts[2],
                due: new Date(e.start).getTime() / 1000,
                state: "",
                url: e.link ?? "",
                file: e.file ?? "",
                courseId: ids[code]
            };
        });
    }

    function tasksOf(id: int): var {
        return root.tasks.filter(t => t.courseId === id);
    }

    function span(c): string {
        return `${Qt.formatDateTime(new Date(c.start), "HH:mm")} - ${Qt.formatDateTime(new Date(c.end), "HH:mm")}`;
    }

    function until(c): string {
        if (c.start <= root.now)
            return "now";
        const mins = Math.ceil((c.start - root.now) / 60000);
        if (mins < 60)
            return `in ${mins} min`;
        const day = new Date(c.start);
        const today = new Date(root.now);
        if (day.toDateString() === today.toDateString())
            return `in ${Math.round(mins / 60)} h`;
        today.setDate(today.getDate() + 1);
        return day.toDateString() === today.toDateString() ? "tomorrow" : Qt.formatDateTime(day, "ddd d MMM");
    }

    FileView {
        path: `${root.stateDir}/index.json`
        watchChanges: true
        onFileChanged: reload()
        onLoaded: {
            try {
                root.index = JSON.parse(text());
                root.ready = true;
            } catch (e) {
                root.index = ({});
            }
        }
        onLoadFailed: {
            root.index = ({});
            root.ready = false;
        }
    }

    FileView {
        path: root.courseId ? `${root.stateDir}/courses/${root.courseId}.json` : ""
        watchChanges: true
        onFileChanged: reload()
        onLoaded: {
            try {
                root.detail = JSON.parse(text());
                root.detailReady = true;
            } catch (e) {
                root.detail = ({});
                root.detailReady = false;
            }
        }
        onLoadFailed: {
            root.detail = ({});
            root.detailReady = false;
        }
    }

    FileView {
        path: `${root.stateDir}/search.json`
        watchChanges: true
        onFileChanged: reload()
        onLoaded: {
            try {
                root.rows = JSON.parse(text()).rows ?? [];
            } catch (e) {
                root.rows = [];
            }
        }
        onLoadFailed: root.rows = []
    }

    Process {
        id: syncer
        command: ["moodle", "sync"]
    }

    Process {
        id: refresher
    }

    Process {
        id: prefs
    }

    Process {
        id: notesLister
        stdout: StdioCollector {
            onStreamFinished: root.notes = text.split("\n").filter(l => l).map(l => {
                const tab = l.indexOf("\t");
                const path = l.slice(tab + 1);
                const parts = path.split("/");
                return {
                    path: path,
                    name: parts[parts.length - 1].replace(/\.md$/, ""),
                    day: parts[parts.length - 2],
                    when: Number(l.slice(0, tab))
                };
            }).sort((a, b) => b.when - a.when)
        }
    }

    onTabChanged: if (root.tab === "notes")
        root.listNotes()

    function sync(): void {
        if (!syncer.running)
            syncer.running = true;
    }

    function select(id: int): void {
        if (root.courseId === id)
            return;
        root.courseId = id;
        root.tab = "content";
        root.refresh(id);
        root.listNotes();
    }

    function listNotes(): void {
        const home = root.course?.home ?? "";
        root.notes = [];
        if (!home || notesLister.running)
            return;
        notesLister.command = ["find", `${home}/notes`, "-name", "*.md", "-printf", "%T@\t%p\n"];
        notesLister.running = true;
    }

    function openNote(path: string): void {
        if (root.course?.home)
            Quickshell.execDetached(["kitty", "--directory", root.course.home, "-e", "nvim", path]);
    }

    function newNote(): void {
        if (root.course?.home)
            Quickshell.execDetached(["note", root.course.home.replace(/.*\//, "")]);
    }

    function refresh(id: int): void {
        if (refresher.running || !id)
            return;
        refresher.command = ["moodle", "course", String(id)];
        refresher.running = true;
        root.listNotes();
    }

    function toggle(key: string, id: int, on: bool): void {
        if (prefs.running || !id)
            return;
        prefs.command = ["moodle", (on ? "" : "un") + key, String(id)];
        prefs.running = true;
    }

    function browse(url: string): void {
        Quickshell.execDetached(["moodle", "browser", url || ""]);
    }

    function open(path: string): void {
        if (path)
            Quickshell.execDetached(["xdg-open", path]);
    }

    function reveal(path: string): void {
        const dir = String(path).replace(/\/[^/]*$/, "");
        if (dir)
            Quickshell.execDetached(["xdg-open", dir]);
    }

    readonly property var hits: {
        const q = root.query.trim().toLowerCase();
        if (q.length < 2)
            return [];
        const terms = q.split(/\s+/);
        return root.rows.filter(r => {
            const hay = `${r.course} ${r.name} ${r.text}`.toLowerCase();
            return terms.every(t => hay.indexOf(t) >= 0);
        }).slice(0, 200);
    }

    function due(when: int): string {
        const delta = when - Date.now() / 1000;
        if (delta < 0)
            return "overdue";
        if (delta < 3600)
            return `in ${Math.round(delta / 60)} min`;
        if (delta < 86400)
            return `in ${Math.round(delta / 3600)} h`;
        if (delta < 604800)
            return `in ${Math.round(delta / 86400)} d`;
        return Qt.formatDateTime(new Date(when * 1000), "d MMM");
    }

    function stamp(when: int): string {
        if (!when)
            return "";
        const d = new Date(when * 1000);
        const sameYear = d.getFullYear() === new Date().getFullYear();
        return Qt.formatDateTime(d, sameYear ? "d MMM, HH:mm" : "d MMM yyyy");
    }

    function size(bytes: int): string {
        if (!bytes)
            return "";
        if (bytes < 1024)
            return `${bytes} B`;
        if (bytes < 1048576)
            return `${Math.round(bytes / 1024)} kB`;
        return `${(bytes / 1048576).toFixed(1)} MB`;
    }

    function modIcon(modname: string): string {
        switch (modname) {
        case "assign":
            return "assignment";
        case "deadline":
            return "flag";
        case "quiz":
            return "quiz";
        case "forum":
            return "forum";
        case "resource":
            return "description";
        case "folder":
            return "folder";
        case "url":
            return "link";
        case "page":
            return "article";
        case "book":
            return "menu_book";
        case "label":
            return "notes";
        case "lesson":
            return "school";
        case "glossary":
            return "spellcheck";
        case "wiki":
            return "hub";
        case "feedback":
        case "questionnaire":
        case "survey":
            return "rate_review";
        case "choice":
            return "how_to_vote";
        case "workshop":
            return "groups";
        case "attendance":
            return "fact_check";
        case "chat":
            return "chat";
        case "lti":
            return "extension";
        case "scorm":
            return "interactive_space";
        default:
            return "widgets";
        }
    }

    function fileIcon(mime: string, name: string): string {
        const n = String(name ?? "").toLowerCase();
        const m = String(mime ?? "");
        if (m.indexOf("pdf") >= 0 || n.endsWith(".pdf"))
            return "picture_as_pdf";
        if (m.indexOf("image") === 0)
            return "image";
        if (m.indexOf("video") === 0)
            return "movie";
        if (m.indexOf("audio") === 0)
            return "audio_file";
        if (/\.(zip|rar|7z|tar|gz|tgz)$/.test(n))
            return "folder_zip";
        if (/\.(docx?|odt|rtf)$/.test(n))
            return "description";
        if (/\.(pptx?|odp)$/.test(n))
            return "slideshow";
        if (/\.(xlsx?|ods|csv)$/.test(n))
            return "table_chart";
        if (/\.(java|py|c|cpp|h|hpp|js|ts|sql|sh|nix|html|css|json|xml)$/.test(n))
            return "code";
        return "draft";
    }
}
