pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Services.Polkit
import "root:/singletons"

Singleton {
    id: root

    readonly property var flow: agent.flow
    readonly property bool pending: flow !== null && !flow.isCompleted
    readonly property bool registered: agent.isRegistered

    PolkitAgent {
        id: agent

        onAuthenticationRequestStarted: {
            NotchState.open("auth");
        }
    }

    function submit(value) {
        if (pending)
            flow.submit(value);
    }

    function cancel() {
        if (pending)
            flow.cancelAuthenticationRequest();
    }

    function pick(identity) {
        if (pending)
            flow.selectedIdentity = identity;
    }
}
