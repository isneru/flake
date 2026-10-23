//@ pragma AppId excalidraw
import QtQuick
import QtWebEngine
import Quickshell
import "root:/singletons"

ShellRoot {
    FloatingWindow {
        title: "Excalidraw"
        implicitWidth: 1280
        implicitHeight: 840
        color: Theme.bg

        WebEngineProfilePrototype {
            id: storage
            storageName: "excalidraw"
            persistentStoragePath: `${Quickshell.env("XDG_DATA_HOME") || Quickshell.env("HOME") + "/.local/share"}/excalidraw`
        }

        WebEngineView {
            id: view
            anchors.fill: parent
            focus: true
            Component.onCompleted: {
                profile = storage.instance();
                url = `file://${Quickshell.env("EXCALIDRAW_WEB")}/index.html`;
            }

            function pushTheme(): void {
                view.runJavaScript(`window.applyTheme(${JSON.stringify(Theme.colors)})`);
            }

            onLoadingChanged: request => {
                forceActiveFocus();
                if (request.status === WebEngineView.LoadSucceededStatus)
                    pushTheme();
            }

            Connections {
                target: Theme
                function onColorsChanged(): void {
                    view.pushTheme();
                }
            }

            Connections {
                target: view.profile
                function onDownloadRequested(download): void {
                    download.accept();
                }
            }
        }
    }

    Connections {
        target: Quickshell
        function onLastWindowClosed(): void {
            Qt.quit();
        }
    }
}
