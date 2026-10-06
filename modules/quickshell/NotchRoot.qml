import QtQuick
import Quickshell
import "root:/notch"

Scope {
    Variants {
        model: Quickshell.screens
        delegate: SpecialCorner {}
    }
    Variants {
        model: Quickshell.screens
        delegate: Scrim {}
    }
    Variants {
        model: Quickshell.screens
        delegate: Corners {}
    }
    Variants {
        model: Quickshell.screens
        delegate: Notch {}
    }
    Variants {
        model: Quickshell.screens
        delegate: TrayPop {}
    }
    Variants {
        model: Quickshell.screens
        delegate: SliderDock {}
    }
}
