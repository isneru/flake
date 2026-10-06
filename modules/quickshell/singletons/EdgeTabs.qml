pragma Singleton
import QtQuick
import Quickshell

Singleton {
    id: root

    property var tabs: []

    function register(tab) {
        if (tabs.indexOf(tab) < 0)
            tabs = tabs.concat([tab]);
    }
    function unregister(tab) {
        tabs = tabs.filter(t => t !== tab);
    }
}
