// DisplayPanel.qml — the display menu unfolded FROM the notch (Mod+P): how
// the laptop screen and the TV / monitor share the picture. Four cards like
// the power menu's: ←/→ or Tab to move, Enter or a click picks, Esc closes.
// The mode you are in is marked; scripts/displaymode.sh does the switching.
import Quickshell
import Quickshell.Io
import QtQuick
import QtQuick.Layouts

Item {
    id: root

    readonly property bool active: ShellState.panel === "display"
    property int current: 0
    property string mode: ""             // what displaymode.sh status said

    readonly property string script: ShellState.home + "/.config/quickshell/scripts/displaymode.sh"
    readonly property var items: [
        { id: "internal", icon: "󰌢", label: I18n.tr("Solo portátil") },
        { id: "extend",   icon: "󰍺", label: I18n.tr("Extender") },
        { id: "mirror",   icon: "󱇽", label: I18n.tr("Espejar") },
        { id: "external", icon: "󰍹", label: I18n.tr("Solo pantalla externa") }
    ]
    readonly property bool noExternal: root.mode === "none"

    Process {
        id: statusProc
        command: [root.script, "status"]
        stdout: StdioCollector {
            onStreamFinished: {
                root.mode = this.text.trim();
                const i = root.items.findIndex(x => x.id === root.mode);
                if (i >= 0) root.current = i;
            }
        }
    }

    function run(i) {
        if (i < 0 || i >= root.items.length || root.noExternal) return;
        ShellState.closePanel();
        if (root.items[i].id === root.mode) return;
        Quickshell.execDetached([root.script, root.items[i].id]);
    }
    function move(d) {
        root.current = (root.current + d + root.items.length) % root.items.length;
    }

    onActiveChanged: if (root.active) {
        root.mode = "";
        statusProc.running = true;
        keys.forceActiveFocus();
    }

    MouseArea { anchors.fill: parent }

    Item {
        id: keys
        anchors.fill: parent
        focus: true
        Keys.onEscapePressed: ShellState.closePanel()
        Keys.onLeftPressed: root.move(-1)
        Keys.onRightPressed: root.move(1)
        Keys.onTabPressed: root.move(1)
        Keys.onBacktabPressed: root.move(-1)
        Keys.onReturnPressed: root.run(root.current)
        Keys.onEnterPressed: root.run(root.current)
        // Mod+P again while it is open: next card, like Windows' menu
        Keys.onPressed: function (e) { if (e.key === Qt.Key_P) { root.move(1); e.accepted = true; } }

        RowLayout {
            anchors { fill: parent; leftMargin: 22; rightMargin: 22; topMargin: 30; bottomMargin: 20 }
            spacing: 12
            visible: !root.noExternal

            Repeater {
                model: root.items

                Rectangle {
                    id: card
                    required property var modelData
                    required property int index
                    readonly property bool sel: index === root.current
                    readonly property bool isNow: modelData.id === root.mode

                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    radius: 16
                    color: card.sel ? Qt.rgba(Colors.accent.r, Colors.accent.g, Colors.accent.b, 0.26)
                        : cMa.containsMouse ? Colors.fill2 : Colors.fill3
                    border.width: card.isNow ? 1.5 : 0
                    border.color: Qt.rgba(Colors.accent.r, Colors.accent.g, Colors.accent.b, 0.7)
                    Behavior on color { ColorAnimation { duration: Appearance.mQuick; easing.type: Easing.OutQuad } }
                    scale: cMa.pressed ? 0.95 : 1
                    Behavior on scale { NumberAnimation { duration: Appearance.mQuick; easing.type: Easing.OutCubic } }

                    ColumnLayout {
                        anchors.centerIn: parent
                        width: parent.width - 12
                        spacing: 6
                        Text {
                            Layout.alignment: Qt.AlignHCenter
                            text: card.modelData.icon
                            color: card.sel || card.isNow ? Colors.accentInk : Colors.label
                            font.family: Appearance.font; font.pixelSize: 26
                        }
                        Text {
                            Layout.fillWidth: true
                            horizontalAlignment: Text.AlignHCenter
                            elide: Text.ElideRight
                            text: card.modelData.label
                            color: card.sel ? Colors.label : Colors.label3
                            font.family: Appearance.fontUI; font.pixelSize: Appearance.fsXS
                            font.weight: card.sel ? Font.Medium : Font.Normal
                        }
                    }
                    // the mode you are in now
                    Rectangle {
                        visible: card.isNow
                        width: 6; height: 6; radius: 3
                        anchors { top: parent.top; right: parent.right; margins: 9 }
                        color: Colors.accent
                    }

                    MouseArea {
                        id: cMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onEntered: root.current = card.index
                        onClicked: root.run(card.index)
                    }
                }
            }
        }

        Text {
            anchors.centerIn: parent
            anchors.verticalCenterOffset: 6
            visible: root.noExternal
            text: I18n.tr("No hay ninguna pantalla externa conectada")
            color: Colors.label3
            font.family: Appearance.fontUI; font.pixelSize: Appearance.fsS
        }
    }
}
