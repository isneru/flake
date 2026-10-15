//@ pragma AppId whatsapp
import QtQuick
import Quickshell
import Quickshell.Io
import "root:/singletons"
import "root:/store"
import "root:/ui"

ShellRoot {
    FloatingWindow {
        title: "WhatsApp"
        implicitWidth: 1180
        implicitHeight: 820
        minimumSize: Qt.size(760, 520)
        color: "transparent"

        App {
            anchors.fill: parent
            focus: true
        }
    }

    Connections {
        target: Quickshell
        function onLastWindowClosed(): void {
            Qt.quit();
        }
    }

    IpcHandler {
        target: "whatsapp"
        function select(jid: string): void {
            Chats.select(jid);
        }
        function attach(path: string): void {
            Chats.attach(path);
        }
        function pick(): void {
            Chats.pick();
        }
        function status(): string {
            return `${Chats.state || "no state"}, ${Chats.chats.length} chats`;
        }
    }
}
