// BarLayoutEditor.qml — Settings › Appearance › Bar: drag the bar's modules
// between Left, Right and Hidden, and along a row to change their order.
//
// It edits the Appearance draft like every other control there (barLeft,
// barRight, plus the old show* switches of the three modules that had one, so
// dragging one into a row also turns it on): the bar follows live, "Aplicar"
// keeps it. The centre of the bar is the notch's and is not offered.
import QtQuick
import QtQuick.Layouts

ColumnLayout {
    id: ed
    spacing: 8

    readonly property var allKeys: ["logo", "workspaces", "app", "date", "game", "devices", "battery"]
    readonly property var v: AppearanceDraft.v

    function flagOf(k) {
        return k === "logo" ? "showArch" : k === "workspaces" ? "showWorkspaces" : k === "app" ? "showAppName" : "";
    }
    function isOn(k) { const f = ed.flagOf(k); return f === "" || ed.v[f] !== false; }
    readonly property var leftKeys: (ed.v.barLeft || []).filter(k => ed.allKeys.indexOf(k) >= 0 && ed.isOn(k))
    readonly property var rightKeys: (ed.v.barRight || []).filter(k => ed.allKeys.indexOf(k) >= 0 && ed.isOn(k))
    readonly property var hiddenKeys: ed.allKeys.filter(k => ed.leftKeys.indexOf(k) < 0 && ed.rightKeys.indexOf(k) < 0)

    function info(k) {
        switch (k) {
        case "logo": return { icon: Icons.arch, label: I18n.tr("Logo") };
        case "workspaces": return { icon: "󰍹", label: I18n.tr("Escritorios") };
        case "app": return { icon: "󰣆", label: I18n.tr("Nombre de la app") };
        case "date": return { icon: "󰃭", label: I18n.tr("Fecha") };
        case "game": return { icon: Icons.gamepad, label: I18n.tr("Modo juego") };
        case "devices": return { icon: "󰂯", label: I18n.tr("Dispositivos") };
        case "battery": return { icon: "󰁹", label: I18n.tr("Batería") };
        }
        return { icon: "", label: k };
    }

    // Puts `k` in `zone` ("left" | "right" | "hidden") at position `idx`.
    function move(k, zone, idx) {
        const L = ed.leftKeys.filter(x => x !== k), R = ed.rightKeys.filter(x => x !== k);
        if (zone === "left") L.splice(Math.max(0, Math.min(idx, L.length)), 0, k);
        else if (zone === "right") R.splice(Math.max(0, Math.min(idx, R.length)), 0, k);
        AppearanceDraft.set("barLeft", L);
        AppearanceDraft.set("barRight", R);
        const f = ed.flagOf(k);
        if (f !== "" && zone !== "hidden" && ed.v[f] === false) AppearanceDraft.set(f, true);
    }

    component Zone: Rectangle {
        id: zoneBox
        property string zone: ""
        property string title: ""
        property var keys: []
        Layout.fillWidth: true
        implicitHeight: Math.max(44, flow.implicitHeight + 16)
        radius: 12
        color: drop.containsDrag ? Qt.rgba(Colors.accent.r, Colors.accent.g, Colors.accent.b, 0.16) : Colors.fill3
        border.width: 1
        border.color: drop.containsDrag ? Colors.accent : Colors.hairline
        Behavior on color { ColorAnimation { duration: Appearance.mQuick } }

        Text {
            id: zt
            x: 12
            anchors.verticalCenter: parent.verticalCenter
            width: 74
            text: zoneBox.title
            color: Colors.label3
            font.family: Appearance.fontUI; font.pixelSize: Appearance.fsXS; font.weight: Font.DemiBold
        }
        Text {
            visible: zoneBox.keys.length === 0
            x: zt.x + zt.width + 4
            anchors.verticalCenter: parent.verticalCenter
            text: I18n.tr("arrastra aquí")
            color: Colors.label4
            font.family: Appearance.fontUI; font.pixelSize: Appearance.fsXS
        }
        Flow {
            id: flow
            x: zt.x + zt.width + 4
            y: 8
            width: zoneBox.width - x - 8
            spacing: 6
            Repeater {
                model: zoneBox.keys
                Item {
                    id: holder
                    required property string modelData
                    width: chip.width
                    height: 28
                    Rectangle {
                        id: chip
                        readonly property string key: holder.modelData
                        width: chipRow.implicitWidth + 20
                        height: 28
                        radius: 14
                        color: dh.active ? Colors.accent : (chipHover.hovered ? Colors.fill1 : Colors.fill2)
                        z: dh.active ? 10 : 0
                        Drag.active: dh.active
                        Drag.source: chip
                        Drag.keys: ["barchip"]
                        Drag.hotSpot.x: width / 2
                        Drag.hotSpot.y: height / 2
                        Row {
                            id: chipRow
                            anchors.centerIn: parent
                            spacing: 6
                            Text {
                                text: ed.info(chip.key).icon
                                color: dh.active ? Colors.accentText : Colors.label
                                font.family: Appearance.font; font.pixelSize: 13
                                anchors.verticalCenter: parent.verticalCenter
                            }
                            Text {
                                text: ed.info(chip.key).label
                                color: dh.active ? Colors.accentText : Colors.label
                                font.family: Appearance.fontUI; font.pixelSize: Appearance.fsXS
                                anchors.verticalCenter: parent.verticalCenter
                            }
                        }
                        HoverHandler { id: chipHover; cursorShape: dh.active ? Qt.ClosedHandCursor : Qt.OpenHandCursor }
                        DragHandler {
                            id: dh
                            onActiveChanged: if (!active) { chip.Drag.drop(); chip.x = 0; chip.y = 0; }
                        }
                        // while dragged it floats over the whole editor
                        states: State {
                            when: dh.active
                            ParentChange { target: chip; parent: ed }
                        }
                    }
                }
            }
        }
        DropArea {
            id: drop
            anchors.fill: parent
            keys: ["barchip"]
            onDropped: function (d) {
                const src = d.source;
                if (!src || !src.key) return;
                // the position among the chips already there, by their centres
                const p = drop.mapToItem(flow, d.x, d.y);
                let idx = 0;
                for (let i = 0; i < flow.children.length; i++) {
                    const c = flow.children[i];
                    if (!c || c.modelData === undefined || c.modelData === src.key) continue;
                    const rowAbove = c.y + c.height < p.y;
                    const sameRow = p.y >= c.y && p.y <= c.y + c.height;
                    if (rowAbove || (sameRow && c.x + c.width / 2 < p.x)) idx++;
                }
                d.accept();
                ed.move(src.key, zoneBox.zone, idx);
            }
        }
    }

    Zone { zone: "left"; title: I18n.tr("Izquierda"); keys: ed.leftKeys }
    Zone { zone: "right"; title: I18n.tr("Derecha"); keys: ed.rightKeys }
    Zone { zone: "hidden"; title: I18n.tr("Ocultos"); keys: ed.hiddenKeys }
}
