pragma Singleton
import QtQuick
import Quickshell

Singleton {
    id: root

    property var targets: []

    function add(target: Item): void {
        root.targets = root.targets.concat([target]);
    }

    function remove(target: Item): void {
        root.targets = root.targets.filter(t => t !== target);
    }
}
