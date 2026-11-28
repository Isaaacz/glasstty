// BluetoothPairing.qml — what BlueZ asks halfway through pairing ("does this
// code match?", "type these digits"), as scripts/bt-agent.py passes it on
// over IPC, and the answer sent back. The notch shows it. Split out of
// ShellState.qml.
pragma Singleton

import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Networking
import Quickshell.Bluetooth
import Quickshell.Services.Mpris
import Quickshell.Services.Notifications
import Quickshell.Services.Pipewire
import Quickshell.Services.UPower
import QtQuick

Singleton {
    id: root

    // ══════════════════════════ bluetooth pairing ═══════════════════════════
    // Quickshell knows how to pair (Bluetooth.pair()) but NOT how to answer what
    // BlueZ asks halfway through pairing: "does this code match?", "type these
    // six digits". Those questions arrive at a D-Bus object that has to be
    // EXPORTED, and QML cannot export D-Bus objects. That is why there is a
    // separate process (scripts/bt-agent.py) that does, and that talks to the
    // notch over IPC. Only what has to be shown and the answer live here.
    //
    // Without this headphones pair just the same (they ask nothing) but a
    // keyboard or a controller fails SILENTLY, which is the worst of all: there
    // is no error, it simply never pairs.
    property string btKind: ""     // "" | "confirm" | "display" | "authorize"
    property string btName: ""     // name of the device
    property string btCode: ""     // the six digits, "" if there are none
    property int btEntered: -1     // digits already typed (only in "display")
    readonly property bool btAsking: root.btKind !== ""

    function btAsk(kind, name, code, entered) {
        root.btKind = kind;
        root.btName = name;
        root.btCode = code;
        root.btEntered = entered;
    }

    function btClear() {
        root.btKind = ""; root.btName = ""; root.btCode = ""; root.btEntered = -1;
    }

    function btReply(accept) {
        // ALWAYS cleared, whatever the agent answers: if the process had died,
        // the face would stay stuck in the notch covering everything else
        // (btpair goes ahead even of the panels).
        btReplyProc.command = ["busctl", "--user", "call",
            "org.quickshell.BtAgent", "/org/quickshell/btagent",
            "org.quickshell.BtAgent1", "Reply", "b", accept ? "true" : "false"];
        btReplyProc.running = true;
        root.btClear();
    }

    Process { id: btReplyProc }
}
