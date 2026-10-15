pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Services.Notifications
import "root:/singletons"

Singleton {
    id: root

    NotificationServer {
        bodySupported: true
        bodyMarkupSupported: true

        onNotification: n => {
            const urgent = n.urgency === NotificationUrgency.Critical;
            if (BareState.dnd && !urgent)
                return;
            BareState.showOsd("notif", {
                app: n.appName || n.desktopEntry || "Unknown",
                title: n.summary || "",
                body: root.strip(n.body || ""),
                urgent: urgent,
                dwell: root.dwellFor(n)
            });
        }
    }

    function dwellFor(n) {
        const base = n.urgency === NotificationUrgency.Critical ? 6000 : 4200;
        const ms = Number(n.expireTimeout);
        return isFinite(ms) && ms > 0 ? Math.min(30000, Math.max(base, Math.round(ms))) : base;
    }

    function strip(s) {
        return s.replace(/<[^>]*>/g, "").replace(/&amp;/g, "&").replace(/&lt;/g, "<")
                .replace(/&gt;/g, ">").replace(/&quot;/g, '"').replace(/\s+/g, " ").trim();
    }
}
