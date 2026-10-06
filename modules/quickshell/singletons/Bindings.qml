pragma Singleton
import QtQuick
import Quickshell

Singleton {
    id: root

    readonly property var groups: [
        {
            title: "NOTCH",
            bareTitle: "SHELL",
            items: [
                ["SUPER+B", "Toggle the notch", "Every menu"],
                ["SUPER+SPACE", "Launcher"],
                ["CALC", "Calculator"],
                ["SUPER+V", "Clipboard history"],
                ["SUPER+A", "Appearance", "Wallpaper"],
                ["SUPER+O", "Workspaces", "Windows"],
                ["SUPER+ESC", "Battery & power", "Power menu"],
                ["SUPER+M", "Now playing", "Pin a media player"],
                ["SUPER+SHIFT+V", "Files shelf"],
                ["SUPER+SHIFT+S", "LocalSend", "Send with LocalSend"],
                ["SUPER+SHIFT+T", "Timer"],
                ["SUPER+SHIFT+N", "Alerts", "Notifications"],
                ["SUPER+SHIFT+O", "Open a repository"],
                ["SUPER+N", "New class note"],
                ["SUPER+SHIFT+D", "Course deadlines"],
                ["SUPER+I", "Moodle"],
                ["SUPER+T", "Tray"],
                ["SUPER+?", "This cheatsheet"],
                ["SUPER+CTRL+L", "Lock the session"]
            ]
        },
        {
            title: "BARE MODE",
            items: [
                ["OMEN", "Switch between the notch and the bar"]
            ]
        },
        {
            title: "INSIDE THE NOTCH",
            only: "notch",
            items: [
                ["ESC", "Close it"],
                ["↑ ↓", "Move the selection"],
                ["ENTER", "Activate"],
                ["TAB", "Complete the query"]
            ]
        },
        {
            title: "INSIDE A MENU",
            only: "bare",
            items: [
                ["ESC", "Close it"],
                ["↑ ↓", "Move the selection"],
                ["CTRL+N / CTRL+P", "Move the selection"],
                ["ENTER", "Pick the selection"],
                ["SHIFT+ENTER", "Use what you typed"],
                ["TAB", "Complete to the selection"]
            ]
        },
        {
            title: "APPS",
            items: [
                ["SUPER+RETURN", "Terminal"],
                ["SUPER+E", "Files"],
                ["SUPER+D", "Discord and music pad"]
            ]
        },
        {
            title: "WINDOWS",
            items: [
                ["SUPER+Q", "Close the window"],
                ["SUPER+F", "Float / unfloat"],
                ["SUPER+SHIFT+F", "Fullscreen"],
                ["SUPER+SHIFT+P", "Pin on top, everywhere / unpin"],
                ["SUPER+←↑↓→", "Move focus"],
                ["SUPER+SHIFT+←↑↓→", "Move the column / swap in it"],
                ["SUPER+HJKL", "Same as the arrows, SHIFT too"],
                ["SUPER+. / SUPER+,", "Stack into the next / previous column"],
                ["SUPER++ / SUPER+-", "Widen / narrow the column"],
                ["SUPER+W", "Tab the column / untab it"],
                ["SUPER+wheel", "Workspace up / down"],
                ["SUPER+SHIFT+wheel", "Previous / next column"],
                ["SUPER+left-drag", "Move a window"],
                ["SUPER+right-drag", "Resize a window"],
                ["SUPER+SHIFT+right-drag", "Resize, keeping the aspect ratio"]
            ]
        },
        {
            title: "WORKSPACES",
            items: [
                ["SUPER+1…0", "Go to workspace"],
                ["SUPER+SHIFT+1…0", "Send the window there"]
            ]
        },
        {
            title: "CAPTURE",
            items: [
                ["PRINT", "Screenshot everything"],
                ["SHIFT+PRINT", "Screenshot a region"],
                ["SUPER+PRINT", "A region, then edit it"],
                ["SUPER+SHIFT+R", "Record (asks for audio) / stop"]
            ]
        },
        {
            title: "SYSTEM",
            items: [
                ["Brightness keys", "Screen brightness"],
                ["Volume keys", "Volume up - down - mute", "Volume up, down, mute"],
                ["Mic mute", "Mute - unmute the microphone"],
                ["Media keys", "Play-pause - next - previous", "Play-pause, next, previous"]
            ]
        }
    ]

    function forMode(bare) {
        const mode = bare ? "bare" : "notch";
        const out = [];
        for (const g of groups) {
            if (g.only && g.only !== mode)
                continue;
            const items = [];
            for (const i of g.items) {
                const label = bare && i.length > 2 ? i[2] : i[1];
                const keys = bare ? i[0].replace("←↑↓→", "ARROWS").replace("↑ ↓", "UP / DOWN") : i[0];
                if (label)
                    items.push([keys, label]);
            }
            if (items.length)
                out.push({ title: bare ? (g.bareTitle ?? g.title) : g.title, items: items });
        }
        return out;
    }
}
