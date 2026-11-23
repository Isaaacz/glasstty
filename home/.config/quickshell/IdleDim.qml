// IdleDim.qml — the screen fades to dark before the idle lock.
//
// swayidle (config.kdl) calls `qs ipc call dim start` 20 s before it locks and
// `qs ipc call dim stop` on any input. The layer takes no input (empty mask),
// so the mouse or keyboard reach the apps underneath and swayidle's resume
// lifts it at once.
import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import QtQuick

Scope {
    id: root
    property bool dimming: false
    property real level: 0          // 0 = clear, 0.9 = almost black
    readonly property int fadeMs: 20000

    NumberAnimation {
        id: fadeIn
        target: root; property: "level"
        to: 0.9; duration: root.fadeMs; easing.type: Easing.InQuad
    }
    NumberAnimation {
        id: fadeOut
        target: root; property: "level"
        to: 0; duration: 250; easing.type: Easing.OutQuad
        onFinished: root.dimming = false
    }

    function start() { fadeOut.stop(); root.dimming = true; fadeIn.restart(); }
    function stop() { if (!root.dimming) return; fadeIn.stop(); fadeOut.restart(); }

    IpcHandler {
        target: "dim"
        function start(): void { root.start(); }
        function stop(): void { root.stop(); }
    }

    Variants {
        model: Quickshell.screens
        PanelWindow {
            required property var modelData
            screen: modelData
            visible: root.dimming
            color: "transparent"
            anchors { top: true; bottom: true; left: true; right: true }
            exclusionMode: ExclusionMode.Ignore
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
            WlrLayershell.namespace: "quickshell:dim"
            mask: Region {}

            Rectangle {
                anchors.fill: parent
                color: "#000000"
                opacity: root.level
            }
        }
    }
}
