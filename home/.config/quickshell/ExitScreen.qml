// ExitScreen.qml — a minimalist full-screen exit screen (in the spirit of
// raexera/yoru's): the desktop blurred and dimmed behind, your picture, a
// goodbye, and five round buttons.
//
// Keys: ← → (or Tab) and Enter · B lock · S suspend · E log out · R restart ·
// D shut down · Esc closes. Log out, restart and shut down ask twice: the
// first press arms the button (red, "Confirmar?"), the second runs it. Lock
// and suspend lose nothing, so they run at once.
//
//   qs ipc call exit toggle      (Super+Shift+E, the power key, the Control
//                                 Centre's power button)
import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import Quickshell.Widgets
import QtQuick
import QtQuick.Layouts
import QtQuick.Effects

Scope {
    id: root
    property bool open: false
    property int sel: 0
    property int armed: -1

    readonly property string user: Quickshell.env("USER") || ""
    property string firstName: ""
    Process {
        running: true
        command: ["sh", "-c", "getent passwd \"$USER\" | cut -d: -f5 | cut -d, -f1"]
        stdout: StdioCollector { onStreamFinished: root.firstName = (this.text.trim().split(" ")[0] || root.user) }
    }

    readonly property var items: [
        { icon: "󰌾", label: I18n.tr("Bloquear"),  key: "B", cmd: Compositor.lockCommand,    confirm: false, danger: false },
        { icon: "󰤄", label: I18n.tr("Suspender"), key: "S", cmd: "systemctl suspend",      confirm: false, danger: false },
        { icon: "󰗽", label: I18n.tr("Salir"),     key: "E", cmd: Compositor.exitCommand,   confirm: true,  danger: false },
        { icon: "󰜉", label: I18n.tr("Reiniciar"), key: "R", cmd: "systemctl reboot",       confirm: true,  danger: true },
        { icon: "󰐥", label: I18n.tr("Apagar"),    key: "D", cmd: "systemctl poweroff",     confirm: true,  danger: true }
    ]

    function show() { root.sel = 0; root.armed = -1; ShellState.closePanel(); root.open = true; }
    function pick(i) {
        const it = root.items[i];
        if (!it) return;
        root.sel = i;
        if (it.confirm && root.armed !== i) { root.armed = i; disarm.restart(); return; }
        root.open = false;
        root.armed = -1;
        // after the fade, so a lock or a suspend does not catch the overlay
        run.cmd = it.cmd;
        run.restart();
    }
    Timer { id: run; property string cmd: ""; interval: 180; onTriggered: Quickshell.execDetached(["bash", "-lc", cmd]) }
    Timer { id: disarm; interval: 4000; onTriggered: root.armed = -1 }

    IpcHandler {
        target: "exit"
        function toggle(): void { if (root.open) root.open = false; else root.show(); }
        function open(): void { root.show(); }
    }

    // "Ligado há 3 h 12 min"
    function uptimeText() {
        const s = SystemStats.uptimeSeconds;
        if (!(s > 0)) return "";
        const d = Math.floor(s / 86400), h = Math.floor(s % 86400 / 3600), m = Math.floor(s % 3600 / 60);
        const parts = d > 0 ? [d + " d", h + " h"] : h > 0 ? [h + " h", m + " min"] : [m + " min"];
        return I18n.tr("Encendido hace {0}", parts.join(" "));
    }

    PanelWindow {
        id: win
        screen: ShellState.focusedScreen
        visible: root.open || stage.fade > 0
        color: "transparent"
        anchors { top: true; bottom: true; left: true; right: true }
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: root.open ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
        WlrLayershell.namespace: "quickshell:exit"
        // niri blurs the desktop behind the whole screen (ext-background-effect)
        BackgroundEffect.blurRegion: root.open ? fullRegion : null
        Region { id: fullRegion; width: win.width; height: win.height }

        Item {
            id: stage
            anchors.fill: parent
            focus: root.open
            property real fade: root.open ? 1 : 0
            Behavior on fade { NumberAnimation { duration: root.open ? 260 : 160; easing.type: Easing.OutCubic } }

            Keys.onPressed: (e) => {
                const n = root.items.length;
                if (e.key === Qt.Key_Escape) root.open = false;
                else if (e.key === Qt.Key_Right || e.key === Qt.Key_Tab) { root.sel = (root.sel + 1) % n; root.armed = -1; }
                else if (e.key === Qt.Key_Left || e.key === Qt.Key_Backtab) { root.sel = (root.sel + n - 1) % n; root.armed = -1; }
                else if (e.key === Qt.Key_Return || e.key === Qt.Key_Enter || e.key === Qt.Key_Space) root.pick(root.sel);
                else {
                    const k = String(e.text || "").toUpperCase();
                    const i = root.items.findIndex(it => it.key === k);
                    if (i < 0) return;
                    root.pick(i);
                }
                e.accepted = true;
            }

            // the dim, in the palette's background
            Rectangle {
                anchors.fill: parent
                color: Qt.rgba(Colors.bg.r, Colors.bg.g, Colors.bg.b, 0.62)
                opacity: stage.fade
            }
            // a click on the empty screen closes
            MouseArea { anchors.fill: parent; onClicked: root.open = false }

            ColumnLayout {
                anchors.centerIn: parent
                spacing: 0
                opacity: stage.fade
                scale: 0.96 + 0.04 * stage.fade

                // your picture (AccountsService), or the initial
                ClippingRectangle {
                    Layout.alignment: Qt.AlignHCenter
                    Layout.preferredWidth: 104; Layout.preferredHeight: 104
                    radius: 52
                    color: Colors.fill2
                    border.width: 2; border.color: Colors.hairline
                    Image {
                        id: face
                        anchors.fill: parent
                        source: "file:///var/lib/AccountsService/icons/" + root.user
                        fillMode: Image.PreserveAspectCrop
                        sourceSize: Qt.size(208, 208)
                        asynchronous: true
                    }
                    Text {
                        anchors.centerIn: parent
                        visible: face.status !== Image.Ready
                        text: (root.firstName || root.user || "?").charAt(0).toUpperCase()
                        color: Colors.label
                        font { family: Appearance.fontUI; pixelSize: 44; weight: Font.DemiBold }
                    }
                }
                Text {
                    Layout.alignment: Qt.AlignHCenter
                    Layout.topMargin: 22
                    text: I18n.tr("Hasta luego, {0}", root.firstName || root.user)
                    color: Colors.label
                    font { family: Appearance.fontUI; pixelSize: 34; weight: Font.DemiBold }
                }
                Text {
                    Layout.alignment: Qt.AlignHCenter
                    Layout.topMargin: 6
                    text: root.uptimeText()
                    color: Colors.label3
                    font { family: Appearance.fontUI; pixelSize: 15 }
                }

                Row {
                    Layout.alignment: Qt.AlignHCenter
                    Layout.topMargin: 44
                    spacing: 26
                    Repeater {
                        model: root.items
                        Column {
                            id: btn
                            required property var modelData
                            required property int index
                            readonly property bool on: root.sel === btn.index
                            readonly property bool isArmed: root.armed === btn.index
                            spacing: 12
                            Rectangle {
                                anchors.horizontalCenter: parent.horizontalCenter
                                width: 88; height: 88; radius: 44
                                color: btn.isArmed ? Colors.crit
                                     : btn.on ? (btn.modelData.danger ? Qt.rgba(Colors.crit.r, Colors.crit.g, Colors.crit.b, 0.85) : Colors.accent)
                                     : Qt.rgba(Colors.fg.r, Colors.fg.g, Colors.fg.b, 0.08)
                                border.width: btn.on ? 0 : 1
                                border.color: Colors.hairline
                                scale: btnMa.pressed ? 0.94 : btn.on ? 1.06 : 1
                                Behavior on color { ColorAnimation { duration: 140 } }
                                Behavior on scale { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }
                                Text {
                                    anchors.centerIn: parent
                                    text: btn.modelData.icon
                                    color: btn.on || btn.isArmed ? (btn.modelData.danger || btn.isArmed ? "#ffffff" : Colors.accentText) : Colors.label
                                    font { family: Appearance.font; pixelSize: 32 }
                                }
                                MouseArea {
                                    id: btnMa
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onEntered: if (root.sel !== btn.index) { root.sel = btn.index; if (root.armed !== btn.index) root.armed = -1; }
                                    onClicked: root.pick(btn.index)
                                }
                            }
                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: btn.isArmed ? I18n.tr("¿Seguro?") : btn.modelData.label
                                color: btn.isArmed ? Colors.crit : btn.on ? Colors.label : Colors.label2
                                font { family: Appearance.fontUI; pixelSize: 14; weight: btn.on ? Font.DemiBold : Font.Normal }
                            }
                        }
                    }
                }
            }
        }
    }
}
