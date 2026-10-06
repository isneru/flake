import QtQuick
import Quickshell
import "root:/bare"

Scope {
    Variants {
        model: Quickshell.screens
        delegate: Bar {}
    }

    Osd {}
    Auth {}
    Share {}
    Send {}
    Cheatsheet {}
}
