// ControlPanel.qml — the Control Centre, unfolded FROM the notch.
//
// Replaces swaync's "control center" (which was a GTK window of its own and so
// could not be put in here). Left: vertical player. Centre: sliders and
// switches. Right: the notification history, served by our own
// NotificationServer (see ShellState.qml).
import Quickshell
import Quickshell.Services.Notifications
import Quickshell.Io
import Quickshell.Widgets
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Qt.labs.folderlistmodel

import Quickshell.Services.Pipewire

// This fork: the Control Centre redesigned (inspired by the Ambxst dashboard,
// written from scratch here): an icon rail with pages on the left, a vertical
// rail with brightness / volume / microphone on the right, and on the main
// page the player (wavy progress ring), round quick toggles, a month calendar
// and the profile / power / notifications column.

Item {
    id: root
    property int page: 0                 // 0 painel · 1 wallpapers · 2 sistema · 3 cores · 4 rices · 5 an extra of sistema
    property int extra: 0                // which extra page 5 shows (index in extrasModel)
    readonly property bool opened: ShellState.panel === "control"
    property bool powerDrawer: false
    // Which channel the right rail's vertical slider drives.
    property string rail: Brightness.bright >= 0 ? "bright" : "vol"
    onOpenedChanged: if (opened) {
        root.page = ShellState.controlPage; ShellState.controlPage = 0;
        if (ShellState.controlExtra !== "") { root.openExtra(ShellState.controlExtra); ShellState.controlExtra = ""; }
        root.powerDrawer = false;
        root.rail = Brightness.bright >= 0 ? "bright" : "vol";
    }

    Connections {
        target: NotificationCenter
        function onControlGo(n) { root.page = Math.max(0, Math.min(4, n)); }
    }
    Connections {
        target: ShellState
        function onControlExtraChanged() {
            if (root.opened && ShellState.controlExtra !== "") {
                root.openExtra(ShellState.controlExtra);
                ShellState.controlExtra = "";
            }
        }
    }

    // swallows clicks on the gaps so they do not close the panel
    MouseArea { anchors.fill: parent }

    function openExtra(name) {
        for (let i = 0; i < extrasModel.count; i++) {
            if (extrasModel.get(i, "fileBaseName") === name) { root.extra = i; root.page = 5; return; }
        }
        root.page = 2;
    }

    readonly property var mic: Pipewire.defaultAudioSource
    PwObjectTracker { objects: [root.mic] }

    component RailButton: Rectangle {
        id: rb
        property string icon: ""
        property bool active: false
        signal chosen()
        width: 38; height: 38; radius: 12
        color: rb.active ? Qt.rgba(Colors.accent.r, Colors.accent.g, Colors.accent.b, 0.85)
             : (rbMa.containsMouse ? Colors.fill2 : "transparent")
        Behavior on color { ColorAnimation { duration: Appearance.mQuick } }
        Text {
            anchors.centerIn: parent
            text: rb.icon
            color: rb.active ? Colors.accentInk : Colors.label2
            font.family: Appearance.font; font.pixelSize: 18
        }
        MouseArea { id: rbMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: rb.chosen() }
    }

    component QuickToggle: Rectangle {
        id: qt
        property string icon: ""
        property string tip: ""
        property bool on: false
        signal activated()
        Layout.fillWidth: true
        Layout.preferredHeight: 38
        radius: 13
        color: qt.on ? Qt.rgba(Colors.accent.r, Colors.accent.g, Colors.accent.b, 0.85)
             : (qtMa.containsMouse ? Colors.fill2 : Colors.fill3)
        Behavior on color { ColorAnimation { duration: Appearance.mQuick; easing.type: Easing.OutQuad } }
        Text {
            anchors.centerIn: parent
            text: qt.icon
            color: qt.on ? Colors.accentInk : Colors.label
            font.family: Appearance.font; font.pixelSize: 15
        }
        MouseArea {
            id: qtMa
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: qt.activated()
        }
        // name on hover, under the button
        Text {
            anchors.top: parent.bottom
            anchors.topMargin: 3
            anchors.horizontalCenter: parent.horizontalCenter
            text: qt.tip
            opacity: qtMa.containsMouse ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: Appearance.mQuick } }
            color: Colors.label3
            font.family: Appearance.fontUI; font.pixelSize: Appearance.fsXXS
        }
    }

    RowLayout {
        anchors { fill: parent; leftMargin: 14; rightMargin: 14; topMargin: 14; bottomMargin: 14 }
        spacing: 10

        // ═════════════ left rail: pages ═════════════
        ColumnLayout {
            Layout.fillHeight: true
            Layout.preferredWidth: 38
            spacing: 8
            RailButton { icon: "󰕮"; active: root.page === 0; onChosen: root.page = 0 }      // painel
            RailButton { icon: "󰸉"; active: root.page === 1; onChosen: root.page = 1 }      // wallpapers
            RailButton { icon: "󰓅"; active: root.page === 2 || root.page === 5; onChosen: root.page = 2 }      // sistema (and its extras)
            RailButton { icon: "󰏘"; active: root.page === 3; onChosen: root.page = 3 }      // cores
            RailButton { icon: "󰃣"; active: root.page === 4; onChosen: root.page = 4 }      // rices
            Item { Layout.fillHeight: true }
            RailButton { icon: "󰒓"; onChosen: { ShellState.closePanel(); ShellState.settingsOpen = true; } }
        }

        Rectangle { Layout.fillHeight: true; width: 1; color: Colors.hairline }

        // ═════════════ pages ═════════════
        StackLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            currentIndex: root.page

            // ── 0: painel ──
            RowLayout {
                spacing: 10

                Rectangle {
                    Layout.preferredWidth: 196
                    Layout.fillHeight: true
                    radius: Appearance.radL
                    color: Colors.fill3
                    border.width: 1.5
                    border.color: Qt.rgba(Media.mediaAccent.r, Media.mediaAccent.g, Media.mediaAccent.b, 0.55)
                    MediaPanel { anchors.fill: parent }
                }

                ColumnLayout {
                    Layout.preferredWidth: 262
                    Layout.maximumWidth: 262
                    Layout.fillHeight: true
                    spacing: 10

                    RowLayout {
                        Layout.fillWidth: true
                        Layout.bottomMargin: 8
                        spacing: 8
                        QuickToggle { icon: NetworkState.netIcon; tip: "Rede"; on: NetworkState.online; onActivated: ShellState.togglePanel("network") }
                        QuickToggle { icon: BluetoothState.btIcon; tip: "Bluetooth"; on: BluetoothState.btOn; onActivated: ShellState.togglePanel("bluetooth") }
                        QuickToggle { icon: Icons.moon; tip: "Luz noturna"; on: NightLight.nightLight; onActivated: NightLight.toggleNightLight() }
                        QuickToggle { icon: Icons.coffee; tip: "Cafeína"; on: Caffeine.caffeine; onActivated: Caffeine.caffeine = !Caffeine.caffeine }
                        QuickToggle { icon: Icons.gamepad; tip: "Modo jogo"; on: GameMode.gameMode; onActivated: GameMode.toggleGameMode() }
                    }

                    MiniCalendar {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                    }
                }

                // profile · power · notifications
        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 8

            // ---- who you are (this fork) ----
            // The account picture GNOME/GDM use (AccountsService), your full
            // name from passwd and the distro. Read once; the picture is
            // re-read if you change it in GNOME's settings.
            RowLayout {
                id: profile
                Layout.fillWidth: true
                Layout.bottomMargin: 4
                spacing: 10
                property string fullName: ""
                property string distro: ""
                readonly property string user: Quickshell.env("USER") || ""
                readonly property string avatar: "/var/lib/AccountsService/icons/" + profile.user

                Process {
                    running: true
                    command: ["sh", "-c", "getent passwd \"$USER\" | cut -d: -f5 | cut -d, -f1; . /etc/os-release; echo \"$NAME $VERSION_ID\""]
                    stdout: StdioCollector {
                        onStreamFinished: {
                            const l = this.text.split("\n");
                            profile.fullName = (l[0] || "").trim();
                            profile.distro = (l[1] || "").trim();
                        }
                    }
                }

                ClippingRectangle {
                    Layout.preferredWidth: 40
                    Layout.preferredHeight: 40
                    radius: 20
                    color: Colors.fill3
                    border.width: 1
                    border.color: Qt.rgba(Colors.accent.r, Colors.accent.g, Colors.accent.b, 0.45)
                    Image {
                        id: avatarImg
                        anchors.fill: parent
                        source: "file://" + profile.avatar
                        fillMode: Image.PreserveAspectCrop
                        sourceSize.width: 128
                        sourceSize.height: 128
                        asynchronous: true
                        cache: false
                    }
                    // No picture set: the initial instead.
                    Text {
                        anchors.centerIn: parent
                        visible: avatarImg.status !== Image.Ready
                        text: (profile.fullName || profile.user).charAt(0).toUpperCase()
                        color: Colors.accent
                        font.family: Appearance.fontUI; font.pixelSize: Appearance.fsL; font.weight: Font.DemiBold
                    }
                }
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 1
                    Text {
                        Layout.fillWidth: true
                        elide: Text.ElideRight
                        text: profile.fullName || profile.user
                        color: Colors.label
                        font.family: Appearance.fontUI; font.pixelSize: Appearance.fsM; font.weight: Font.DemiBold
                    }
                    Text {
                        Layout.fillWidth: true
                        elide: Text.ElideRight
                        text: profile.user + (profile.distro ? "  ·  " + profile.distro : "")
                        color: Colors.label3
                        font.family: Appearance.fontUI; font.pixelSize: Appearance.fsXXS
                    }
                }
                // Opens / closes the power drawer below.
                Rectangle {
                    Layout.preferredWidth: 32
                    Layout.preferredHeight: 32
                    radius: 16
                    color: root.powerDrawer ? Qt.rgba(Colors.accent.r, Colors.accent.g, Colors.accent.b, 0.85)
                         : (pwrBtnMa.containsMouse ? Colors.fill2 : Colors.fill3)
                    Behavior on color { ColorAnimation { duration: Appearance.mQuick } }
                    Text {
                        anchors.centerIn: parent
                        text: "󰐥"
                        color: root.powerDrawer ? Colors.accentInk : Colors.label
                        font.family: Appearance.font; font.pixelSize: 15
                    }
                    MouseArea { id: pwrBtnMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                onClicked: { ShellState.closePanel(); Quickshell.execDetached(["qs", "ipc", "call", "exit", "open"]); } }
                }
            }

            // ---- session / power (this fork) ----
            // The same five actions as the power menu (Super+Shift+E), one click
            // away. Lock and suspend act at once; the three that end the session
            // arm on the first click (red, "de novo?") and run on a second click
            // within 4 s, like PowerPanel.qml.
            RowLayout {
                id: powerRow
                Layout.fillWidth: true
                // A drawer: folded away until the ⏻ button next to the name opens it.
                Layout.preferredHeight: root.powerDrawer ? 40 : 0
                Layout.bottomMargin: root.powerDrawer ? 4 : -8
                opacity: root.powerDrawer ? 1 : 0
                visible: opacity > 0.01
                clip: true
                Behavior on Layout.preferredHeight { NumberAnimation { duration: Appearance.mIn; easing.type: Easing.OutCubic } }
                Behavior on opacity { NumberAnimation { duration: Appearance.mIn } }
                spacing: 5
                property int armed: -1
                readonly property var items: [
                    { icon: "󰌾", label: I18n.tr("Bloquear"),  cmd: Compositor.lockCommand,  confirm: false, danger: false },
                    { icon: "󰤄", label: I18n.tr("Suspender"), cmd: "systemctl suspend",     confirm: false, danger: false },
                    { icon: "󰗽", label: I18n.tr("Salir"),     cmd: Compositor.exitCommand,  confirm: true,  danger: false },
                    { icon: "󰜉", label: I18n.tr("Reiniciar"), cmd: "systemctl reboot",      confirm: true,  danger: true  },
                    { icon: "󰐥", label: I18n.tr("Apagar"),    cmd: "systemctl poweroff",    confirm: true,  danger: true  }
                ]
                Timer { id: powerArm; interval: 4000; onTriggered: powerRow.armed = -1 }
                Connections {
                    target: ShellState
                    function onPanelChanged() { powerRow.armed = -1; }
                }
                function run(i) {
                    const it = powerRow.items[i];
                    if (it.confirm && powerRow.armed !== i) { powerRow.armed = i; powerArm.restart(); return; }
                    powerRow.armed = -1; powerArm.stop();
                    ShellState.closePanel();
                    Quickshell.execDetached(["bash", "-lc", it.cmd]);
                }

                Repeater {
                    model: powerRow.items
                    Rectangle {
                        id: pbtn
                        required property var modelData
                        required property int index
                        readonly property bool isArmed: powerRow.armed === index
                        Layout.fillWidth: true
                        Layout.preferredHeight: 40
                        radius: 11
                        color: pbtn.isArmed ? Qt.rgba(Colors.crit.r, Colors.crit.g, Colors.crit.b, 0.28)
                            : (pma.containsMouse ? Qt.rgba(Colors.accent.r, Colors.accent.g, Colors.accent.b, 0.16) : Colors.fill3)
                        border.width: 1
                        border.color: pbtn.isArmed ? Qt.rgba(Colors.crit.r, Colors.crit.g, Colors.crit.b, 0.6) : Colors.hairline
                        Behavior on color { ColorAnimation { duration: Appearance.mQuick; easing.type: Easing.OutQuad } }

                        ColumnLayout {
                            anchors.centerIn: parent
                            spacing: 2
                            Text {
                                Layout.alignment: Qt.AlignHCenter
                                text: pbtn.modelData.icon
                                color: pbtn.isArmed ? Colors.crit
                                    : (pma.containsMouse ? (pbtn.modelData.danger ? Colors.crit : Colors.accentInk) : Colors.label2)
                                font.family: Appearance.font; font.pixelSize: 16
                            }
                            Text {
                                Layout.alignment: Qt.AlignHCenter
                                text: pbtn.isArmed ? I18n.tr("de novo?") : pbtn.modelData.label
                                color: pbtn.isArmed ? Colors.crit : Colors.label3
                                font.family: Appearance.fontUI; font.pixelSize: 9
                            }
                        }
                        MouseArea {
                            id: pma
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: powerRow.run(pbtn.index)
                        }
                    }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 8
                Text {
                    text: I18n.tr("Notificaciones")
                    color: Colors.label
                    font.family: Appearance.fontUI; font.pixelSize: Appearance.fsS; font.weight: Font.DemiBold
                }
                Rectangle {
                    visible: NotificationCenter.notifCount > 0
                    implicitWidth: cnt.implicitWidth + 12
                    implicitHeight: 17
                    radius: 9
                    color: Qt.rgba(Colors.accent.r, Colors.accent.g, Colors.accent.b, 0.28)
                    Text {
                        id: cnt
                        anchors.centerIn: parent
                        text: NotificationCenter.notifCount
                        color: Colors.accentInk
                        font.family: Appearance.fontUI; font.pixelSize: Appearance.fsXXS; font.weight: Font.Medium
                        font.features: ({ "tnum": 1 })
                    }
                }
                Item { Layout.fillWidth: true }
                // Do not disturb, like the reference's bell (Settings moved to the rail).
                Rectangle {
                    width: 28; height: 28; radius: 14
                    color: NotificationCenter.dnd ? Qt.rgba(Colors.accent.r, Colors.accent.g, Colors.accent.b, 0.35)
                         : (bellMa.containsMouse ? Colors.fill2 : Colors.fill3)
                    Text {
                        anchors.centerIn: parent
                        text: NotificationCenter.dnd ? "󰂛" : "󰂚"
                        color: Colors.label
                        font.family: Appearance.font; font.pixelSize: 14
                    }
                    MouseArea { id: bellMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                onClicked: NotificationCenter.dnd = !NotificationCenter.dnd }
                }
                Text {
                    visible: NotificationCenter.notifCount > 0
                    text: I18n.tr("Limpiar")
                    color: clearMa.containsMouse ? Colors.accentInk : Colors.label3
                    font.family: Appearance.fontUI; font.pixelSize: Appearance.fsXS
                    Behavior on color { ColorAnimation { duration: Appearance.mQuick; easing.type: Easing.OutQuad } }
                    MouseArea {
                        id: clearMa
                        anchors.fill: parent; anchors.margins: -5
                        hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                        onClicked: NotificationCenter.clearNotifs()
                    }
                }
            }

            // ─────────── the mouse is read ONCE, and it is read here ───────────
            // Each row had its own MouseArea and the cross another one on top. Three
            // bugs came out of that, and all three show up right when you go to close
            // one:
            //
            //   · the body is in StyledText (whatever markup the app sends), and a
            //     Text with markup ACCEPTS hover events so it can detect links: it
            //     swallowed the row's. Measured: over the title the row lit up and
            //     the cross came out; two lines further down, nothing. Most of the
            //     surface of each row was a dead zone.
            //   · the cross appeared with `visible`, so it went in and out of the
            //     layout: the text column widened by 23 px as soon as you took the
            //     mouse away. It is the least of the three, but it is geometry that
            //     moves by itself right under the pointer.
            //   · and when you dismiss one, the model is a NEW array (see
            //     NotificationCenter.notifications): all the delegates are rebuilt with
            //     hover at zero. Since the hand has not moved no event arrives to
            //     correct it, and the list is left lying: cross lit over a row that
            //     is off, and the second click in the same place closes nothing
            //     because it lands in the gap.
            //
            // With a single MouseArea over the list there is one single owner of
            // "what is under the pointer". And —this is what fixes the third one—
            // that owner can look again when the list changes, without having to
            // wait for the hand to move.
            Item {
                Layout.fillWidth: true
                Layout.fillHeight: true

                ListView {
                    id: notifList
                    anchors.fill: parent
                    clip: true
                    spacing: 7
                    // ScriptModel: with the bare array, dismissing a
                    // notification reset the model and ALL the rows were
                    // rebuilt; now only its own disappears and the rest keep
                    // their delegate. The retrack further down is still
                    // needed: the ones below move up and another row ends up
                    // under a still pointer. Notifications are the same
                    // server objects while they live -> identity.
                    model: ScriptModel {
                        // one row per group of identical notices (NotificationCenter.notifHeads)
                        values: NotificationCenter.notifHeads
                        comparisonMode: ObjectComparison.Identity
                    }
                    boundsBehavior: Flickable.StopAtBounds
                    ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded; width: 4 }

                    property int hoverIdx: -1        // row under the pointer; -1 = none
                    property bool overClose: false   // ...and over its cross

                    // (mx, my) in viewport coordinates, which is how the mouse gives them.
                    function track(mx, my) {
                        const y = my + notifList.contentY;
                        const i = notifList.indexAt(notifList.width / 2, y);
                        notifList.hoverIdx = i;
                        const fila = i >= 0 ? notifList.itemAtIndex(i) : null;
                        const equis = fila ? fila.closeItem : null;
                        if (!equis) {
                            notifList.overClose = false;
                            return;
                        }
                        // The target is not written by hand: the layout is asked where
                        // it left the cross and it is given the 6 px of margin that the
                        // MouseArea that used to live there had. If the row spacing
                        // changes tomorrow, the target moves by itself.
                        const p = equis.mapToItem(fila, 0, 0);
                        notifList.overClose = mx >= p.x - 6 && mx <= p.x + equis.width + 6
                            && (y - fila.y) >= p.y - 6 && (y - fila.y) <= p.y + equis.height + 6;
                    }

                    // Look again without the mouse having moved: when a notification
                    // is closed the ones below move up and what is under the pointer
                    // is now another row. forceLayout because otherwise the old list
                    // is measured and the cross comes out lit on the wrong row.
                    function retrack() {
                        if (!listMa.containsMouse) {
                            notifList.hoverIdx = -1;
                            notifList.overClose = false;
                            return;
                        }
                        notifList.forceLayout();
                        notifList.track(listMa.mouseX, listMa.mouseY);
                    }

                    onCountChanged: Qt.callLater(notifList.retrack)
                    // With the wheel it is the rows that move, not the hand.
                    onContentYChanged: if (listMa.containsMouse) notifList.track(listMa.mouseX, listMa.mouseY)

                    delegate: Rectangle {
                        id: nrow
                        required property var modelData
                        required property int index
                        readonly property bool hovered: notifList.hoverIdx === nrow.index
                        // The only thing the row tells the list: where its cross is,
                        // so it knows who the click is meant for.
                        readonly property Item closeItem: equis

                        width: notifList.width
                        height: ncol.implicitHeight + 20
                        radius: 12
                        color: nrow.hovered ? Colors.fill2 : Colors.fill3
                        Behavior on color { ColorAnimation { duration: Appearance.mQuick; easing.type: Easing.OutQuad } }

                        // what this row shows, worked out once
                        readonly property var n: nrow.modelData
                        readonly property string kind: NotificationCenter.notifKind(nrow.n)
                        readonly property color kindColor: NotificationCenter.notifKindColor(nrow.kind)
                        readonly property string pic: NotificationCenter.notifImage(nrow.n)
                        readonly property int dupes: NotificationCenter.notifDupes(nrow.n).length
                        readonly property bool crit: nrow.n.urgency === NotificationUrgency.Critical
                        // `notch` cards and the shell's own notices say nothing with
                        // their app name; real applications do.
                        readonly property string app: (nrow.kind !== "" || nrow.n.appName === "notch") ? ""
                            : (nrow.n.appName || "")
                        readonly property string meta: [nrow.app, NotificationCenter.notifAgo(nrow.n)]
                            .filter(x => x !== "").join(" · ")

                        RowLayout {
                            anchors { fill: parent; leftMargin: 12; rightMargin: 10; topMargin: 10; bottomMargin: 10 }
                            spacing: 11

                            // icon: the picture (with the kind as a dot on its corner),
                            // or a round mark in the kind's colour
                            Item {
                                Layout.preferredWidth: 30
                                Layout.preferredHeight: 30
                                Layout.alignment: Qt.AlignTop
                                Rectangle {
                                    anchors.fill: parent
                                    visible: nrow.pic === ""
                                    radius: 15
                                    color: Qt.rgba(nrow.kindColor.r, nrow.kindColor.g, nrow.kindColor.b, 0.20)
                                    Text {
                                        anchors.centerIn: parent
                                        text: NotificationCenter.notifMark(nrow.n)
                                        color: nrow.kind !== "" ? nrow.kindColor : Colors.accentInk
                                        font.family: Appearance.font; font.pixelSize: 16
                                    }
                                }
                                Image {
                                    anchors.fill: parent
                                    visible: nrow.pic !== ""
                                    source: nrow.pic
                                    sourceSize.width: 60; sourceSize.height: 60
                                    fillMode: Image.PreserveAspectFit
                                    asynchronous: true
                                }
                                Rectangle {
                                    visible: nrow.pic !== "" && nrow.kind !== ""
                                    width: 11; height: 11; radius: 6
                                    anchors { right: parent.right; bottom: parent.bottom; margins: -2 }
                                    color: nrow.kindColor
                                    border.width: 2
                                    border.color: nrow.color
                                }
                            }

                            ColumnLayout {
                                id: ncol
                                Layout.fillWidth: true
                                spacing: 2
                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: 6
                                    Text {
                                        Layout.fillWidth: true
                                        text: NotificationCenter.tn(nrow.n.summary || nrow.n.appName || "")
                                        color: nrow.crit ? Colors.crit : Colors.label
                                        wrapMode: Text.Wrap
                                        maximumLineCount: 2
                                        elide: Text.ElideRight
                                        font.family: Appearance.fontUI; font.pixelSize: Appearance.fsS; font.weight: Font.DemiBold
                                    }
                                    // ×5: five identical notices folded into this row
                                    Rectangle {
                                        visible: nrow.dupes > 1
                                        Layout.alignment: Qt.AlignTop
                                        implicitWidth: dupT.implicitWidth + 10
                                        implicitHeight: 16
                                        radius: 8
                                        color: Colors.fill2
                                        Text {
                                            id: dupT
                                            anchors.centerIn: parent
                                            text: "×" + nrow.dupes
                                            color: Colors.label2
                                            font.family: Appearance.fontUI; font.pixelSize: Appearance.fsXXS; font.weight: Font.DemiBold
                                            font.features: ({ "tnum": 1 })
                                        }
                                    }
                                }
                                Text {
                                    Layout.fillWidth: true
                                    visible: text.length > 0
                                    text: NotificationCenter.tn(nrow.n.body)
                                    color: Colors.label2
                                    wrapMode: Text.Wrap
                                    maximumLineCount: 2
                                    elide: Text.ElideRight
                                    textFormat: Text.StyledText
                                    font.family: Appearance.fontUI; font.pixelSize: Appearance.fsXS
                                    lineHeight: Appearance.leading(Appearance.fsXS)
                                    lineHeightMode: Text.FixedHeight
                                }
                                Text {
                                    Layout.fillWidth: true
                                    visible: nrow.meta !== ""
                                    text: nrow.meta
                                    color: Colors.label3
                                    elide: Text.ElideRight
                                    font.family: Appearance.fontUI; font.pixelSize: Appearance.fsXXS
                                }
                            }

                            Text {
                                id: equis
                                Layout.alignment: Qt.AlignTop
                                // Opacity, not `visible`: the cross takes up its slot whether
                                // it is lit or not, so the row measures the same with and
                                // without the mouse. Reserving the space costs nothing and
                                // gets rid of the class of bug in which what you are chasing
                                // moves because you are chasing it.
                                opacity: nrow.hovered ? 1 : 0
                                text: "󰅖"
                                color: nrow.hovered && notifList.overClose ? Colors.crit : Colors.label3
                                font.family: Appearance.font; font.pixelSize: Appearance.fsS
                                Behavior on opacity { NumberAnimation { duration: Appearance.mQuick; easing.type: Easing.OutQuad } }
                                Behavior on color { ColorAnimation { duration: Appearance.mQuick; easing.type: Easing.OutQuad } }
                            }
                        }
                    }
                }

                MouseArea {
                    id: listMa
                    anchors.fill: parent
                    z: 1                     // above the rows: the hover is its own
                    hoverEnabled: true
                    acceptedButtons: Qt.LeftButton
                    cursorShape: notifList.overClose ? Qt.PointingHandCursor : Qt.ArrowCursor
                    onPositionChanged: function (mouse) { notifList.track(mouse.x, mouse.y); }
                    onEntered: notifList.track(listMa.mouseX, listMa.mouseY)
                    onExited: { notifList.hoverIdx = -1; notifList.overClose = false; }
                    onClicked: {
                        // ShellState's list and NOT notifList.model: the model
                        // is a ScriptModel, not an array, so `model[i]` would
                        // return undefined and neither the cross nor a click on
                        // the row would do anything. The index came from
                        // indexAt() on this same list and the order is the same,
                        // but the range is checked because one may have expired
                        // between the hover and the click.
                        const ns = NotificationCenter.notifHeads;
                        const n = (notifList.hoverIdx >= 0 && notifList.hoverIdx < ns.length)
                            ? ns[notifList.hoverIdx] : null;
                        if (!n) return;
                        // the cross closes the whole group of identical ones
                        if (notifList.overClose) { NotificationCenter.dismissGroup(n); return; }
                        const acts = n.actions;
                        if (acts && acts.length > 0) { acts[0].invoke(); ShellState.closePanel(); }
                    }
                }
            }

            Text {
                Layout.fillWidth: true
                Layout.fillHeight: true
                visible: NotificationCenter.notifCount === 0
                text: I18n.tr("Sin notificaciones")
                color: Colors.label3
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
                font.family: Appearance.fontUI; font.pixelSize: Appearance.fsS
            }
        }
            }

            // ── 1: wallpapers ──
            ColumnLayout {
                spacing: 12
                WallpaperStrip {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    Layout.preferredHeight: -1
                }
            }

            // ── 2: sistema ──
            ColumnLayout {
                spacing: 16

                // Big gauges: CPU, memory, disk, battery, temperature.
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 12
                    Repeater {
                        model: [
                            { label: "CPU", icon: "󰻠", v: SystemStats.cpu, txt: SystemStats.cpu + "%" },
                            { label: "Memória", icon: "󰍛", v: SystemStats.mem, txt: SystemStats.mem + "%" },
                            { label: "Disco", icon: "󰋊", v: SystemStats.disk, txt: SystemStats.disk + "%" },
                            { label: "Bateria", icon: SystemStats.battIcon, v: Math.max(0, SystemStats.batt), txt: SystemStats.batt >= 0 ? SystemStats.batt + "%" : "—" },
                            { label: "Temperatura", icon: "󰔏", v: SystemStats.cpuTemp > 0 ? Math.min(100, SystemStats.cpuTemp) : 0, txt: SystemStats.cpuTemp > 0 ? Math.round(SystemStats.cpuTemp) + "°C" : "—" }
                        ]
                        Rectangle {
                            id: gauge
                            required property var modelData
                            Layout.fillWidth: true
                            Layout.preferredHeight: 150
                            radius: Appearance.radL
                            color: Colors.fill3
                            border.width: 1
                            border.color: Colors.hairline
                            Knob {
                                id: gk
                                anchors.horizontalCenter: parent.horizontalCenter
                                anchors.top: parent.top
                                anchors.topMargin: 18
                                width: 76; height: 76
                                icon: gauge.modelData.icon
                                value: gauge.modelData.v
                                enabled: false
                            }
                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                anchors.top: gk.bottom
                                anchors.topMargin: 8
                                text: gauge.modelData.txt
                                color: Colors.label
                                font.family: Appearance.fontUI; font.pixelSize: Appearance.fsL; font.weight: Font.DemiBold
                            }
                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                anchors.bottom: parent.bottom
                                anchors.bottomMargin: 12
                                text: gauge.modelData.label
                                color: Colors.label3
                                font.family: Appearance.fontUI; font.pixelSize: Appearance.fsXS
                            }
                        }
                    }
                }
            // ---- weather + system (inherited from the retired Sidebar) ----
            RowLayout {
                Layout.fillWidth: true
                Layout.topMargin: 2
                spacing: 16

                // The sky picks the icon. Here there used to be Icons.brightness —the
                // glyph of the brightness slider— standing in for the weather, with its
                // warning orange included: an orange sun got away with it, but an
                // orange cloud did not, and on top of that it promised a colour that
                // means nothing. Grey, like the labels of the switches that are off.
                Text {
                    text: Weather.weatherIcon
                    color: Colors.label3
                    font.family: Appearance.font; font.pixelSize: 14
                }
                // The temperature is what you look for at a glance and the condition
                // is the context. Both were in the same type and the same grey, so you
                // had to read the whole line to get the number out. Now the number
                // carries weight and the condition comes along.
                Text {
                    text: Weather.weatherTemp
                    color: Colors.label
                    font.family: Appearance.fontUI; font.pixelSize: Appearance.fsS
                    font.features: ({ "tnum": 1 })
                }
                Text {
                    Layout.fillWidth: true
                    text: Weather.weatherCond
                    color: Colors.label3; elide: Text.ElideRight
                    font.family: Appearance.fontUI; font.pixelSize: Appearance.fsXS
                }
            }

            // ---- the two doors: performance and GitHub ----
            // A row of its own and NOT inside the weather one. With both cards up
            // there, that row asked for 506 px and this column is declared at 410:
            // the RowLayout widened it to 474, and it took those 64 px from the
            // notifications column (218 instead of 282), which came out squeezed
            // against the edge, with the slider percentages treading on the
            // separator and the weather compressed until it vanished. They share
            // the width between the two instead of measuring a fixed 222.
            RowLayout {
                Layout.fillWidth: true
                Layout.topMargin: 10
                spacing: 12

                // The three glyphs with percentages were indecipherable unless you
                // knew by heart what each one meant. Now this is a door with a name:
                // it keeps the quick glance and opens the graphs.
                Rectangle {
                    id: performanceLink
                    Layout.fillWidth: true
                    Layout.preferredHeight: 42
                    radius: 13
                    color: performanceMa.containsMouse
                        ? Qt.rgba(Colors.accent.r, Colors.accent.g, Colors.accent.b, 0.14)
                        : Colors.fill3
                    border.width: 1
                    border.color: performanceMa.containsMouse
                        ? Qt.rgba(Colors.accent.r, Colors.accent.g, Colors.accent.b, 0.26)
                        : Colors.hairline
                    Behavior on color { ColorAnimation { duration: Appearance.mQuick; easing.type: Easing.OutQuad } }

                    RowLayout {
                        anchors { fill: parent; leftMargin: 12; rightMargin: 10 }
                        spacing: 8
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 0
                            Text {
                                text: I18n.tr("Tu máquina")
                                color: performanceMa.containsMouse ? Colors.accentInk : Colors.label
                                font.family: Appearance.fontUI; font.pixelSize: Appearance.fsXXS
                                font.weight: Font.DemiBold
                            }
                            Text {
                                text: I18n.tr("CPU {0}%  ·  RAM {1}%  ·  SSD {2}%",
                                              SystemStats.cpu, SystemStats.mem, SystemStats.disk)
                                color: Colors.label3
                                font.family: Appearance.fontUI; font.pixelSize: 8
                                font.features: ({ "tnum": 1 })
                            }
                        }
                        Text {
                            text: "›"
                            color: performanceMa.containsMouse ? Colors.accentInk : Colors.label3
                            font.family: Appearance.fontUI; font.pixelSize: 20
                        }
                    }

                    MouseArea {
                        id: performanceMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: ShellState.togglePanel("system")
                    }
                }

                // Same idea as the one above, and the same shape on purpose: a
                // glance (the last twelve weeks, the total and the streak) and a door
                // to the whole panel. The squares take pywal's accent, not GitHub's
                // green, so it does not look bolted on.
                Rectangle {
                    id: githubLink
                    Layout.fillWidth: true
                    Layout.preferredHeight: 42
                    radius: 13
                    color: githubMa.containsMouse
                        ? Qt.rgba(Colors.accent.r, Colors.accent.g, Colors.accent.b, 0.14)
                        : Colors.fill3
                    border.width: 1
                    border.color: githubMa.containsMouse
                        ? Qt.rgba(Colors.accent.r, Colors.accent.g, Colors.accent.b, 0.26)
                        : Colors.hairline
                    Behavior on color { ColorAnimation { duration: Appearance.mQuick; easing.type: Easing.OutQuad } }

                    // The last twelve columns of the big grid. If the data has not
                    // arrived yet, this is an empty array and nothing is painted:
                    // the card is still a valid door.
                    readonly property var mini: (GitHub.github.weeks || []).slice(-12)

                    RowLayout {
                        anchors { fill: parent; leftMargin: 12; rightMargin: 10 }
                        spacing: 8

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 0
                            Text {
                                text: I18n.tr("GitHub")
                                color: githubMa.containsMouse ? Colors.accentInk : Colors.label
                                font.family: Appearance.fontUI; font.pixelSize: Appearance.fsXXS
                                font.weight: Font.DemiBold
                            }
                            Text {
                                text: GitHub.github.stale
                                    ? I18n.tr("sin conexión")
                                    : I18n.tr("{0}  ·  racha {1}",
                                              GitHub.github.total || 0,
                                              GitHub.github.streak || 0)
                                color: Colors.label3
                                font.family: Appearance.fontUI; font.pixelSize: 8
                                font.features: ({ "tnum": 1 })
                            }
                        }

                        // The grid in miniature: 12 columns of 3 px. It has no mouse
                        // over it and counts nothing; that is what the panel is for.
                        Item {
                            implicitWidth: 12 * 4 - 1
                            implicitHeight: 7 * 4 - 1
                            Repeater {
                                model: githubLink.mini.length
                                Item {
                                    id: miniCol
                                    required property int index
                                    readonly property var niveles: githubLink.mini[index] || []
                                    x: index * 4
                                    width: 3
                                    height: 7 * 4 - 1
                                    Repeater {
                                        model: 7
                                        Rectangle {
                                            required property int index
                                            y: index * 4
                                            width: 3; height: 3; radius: 1
                                            readonly property int lvl:
                                                miniCol.niveles[index] !== undefined
                                                    ? miniCol.niveles[index] : -1
                                            color: lvl < 0 ? "transparent"
                                                 : lvl === 0 ? Colors.fill3
                                                 : Qt.rgba(Colors.accent.r, Colors.accent.g,
                                                           Colors.accent.b,
                                                           [0, 0.30, 0.52, 0.74, 1.0][lvl])
                                        }
                                    }
                                }
                            }
                        }

                        Text {
                            text: "›"
                            color: githubMa.containsMouse ? Colors.accentInk : Colors.label3
                            font.family: Appearance.fontUI; font.pixelSize: 20
                        }
                    }

                    MouseArea {
                        id: githubMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: ShellState.togglePanel("github")
                    }
                }

                // Extras: one more door per QML file in
                // ~/.local/share/glasstty/extras/ (page 5 below). The extra
                // gives the words (`title`, `subtitle`) and whether it wants a
                // look (`attention`); the door has the same shape as the two
                // above so it does not look bolted on.
                Repeater {
                    model: extraLoaders.count
                    Rectangle {
                        id: extraDoor
                        required property int index
                        readonly property var ext: {
                            extraLoaders.count;
                            const l = extraLoaders.itemAt(extraDoor.index);
                            return l && l.status === Loader.Ready ? l.item : null;
                        }
                        visible: extraDoor.ext !== null
                        Layout.fillWidth: true
                        Layout.preferredHeight: 42
                        radius: 13
                        color: extraMa.containsMouse
                            ? Qt.rgba(Colors.accent.r, Colors.accent.g, Colors.accent.b, 0.14)
                            : Colors.fill3
                        border.width: 1
                        border.color: extraMa.containsMouse
                            ? Qt.rgba(Colors.accent.r, Colors.accent.g, Colors.accent.b, 0.26)
                            : Colors.hairline
                        Behavior on color { ColorAnimation { duration: Appearance.mQuick; easing.type: Easing.OutQuad } }

                        RowLayout {
                            anchors { fill: parent; leftMargin: 12; rightMargin: 10 }
                            spacing: 8
                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 0
                                Text {
                                    Layout.fillWidth: true
                                    text: extraDoor.ext ? String(extraDoor.ext.title || "") : ""
                                    color: extraMa.containsMouse ? Colors.accentInk : Colors.label
                                    elide: Text.ElideRight
                                    font.family: Appearance.fontUI; font.pixelSize: Appearance.fsXXS
                                    font.weight: Font.DemiBold
                                }
                                Text {
                                    Layout.fillWidth: true
                                    text: extraDoor.ext ? String(extraDoor.ext.subtitle || "") : ""
                                    color: Colors.label3
                                    elide: Text.ElideRight
                                    font.family: Appearance.fontUI; font.pixelSize: 8
                                    font.features: ({ "tnum": 1 })
                                }
                            }
                            Rectangle {
                                visible: extraDoor.ext ? extraDoor.ext.attention === true : false
                                implicitWidth: 7; implicitHeight: 7; radius: 3.5
                                color: Colors.warn
                            }
                            Text {
                                text: "›"
                                color: extraMa.containsMouse ? Colors.accentInk : Colors.label3
                                font.family: Appearance.fontUI; font.pixelSize: 20
                            }
                        }

                        MouseArea {
                            id: extraMa
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: { root.extra = extraDoor.index; root.page = 5; }
                        }
                    }
                }
            }
                Item { Layout.fillHeight: true }
            }

            // ── 3: cores (same settings as Ajustes > Aparência > Cores) ──
            // Scrolls inside the page instead of stretching the panel: the variants
            // below can wrap onto a second row, and a taller page made the
            // StackLayout (sized by its tallest page) push every page out of the
            // notch.
            Flickable {
                id: coresScroll
                clip: true
                contentHeight: coresPage.implicitHeight
                boundsBehavior: Flickable.StopAtBounds
            ColumnLayout {
                id: coresPage
                width: coresScroll.width
                spacing: 14
                readonly property bool manual: Config.colorMode === "manual"

                component Swatch: Rectangle {
                    id: sw
                    property color swatch: "#000000"
                    property bool selected: false
                    property string caption: ""
                    signal chosen()
                    width: 30; height: 30; radius: 15
                    color: sw.swatch
                    border.width: sw.selected ? 2.5 : 1
                    border.color: sw.selected ? Colors.fg : Colors.hairline
                    scale: swMa.containsMouse ? 1.12 : 1
                    Behavior on scale { NumberAnimation { duration: Appearance.mQuick } }
                    Text { anchors.centerIn: parent; visible: sw.caption !== ""; text: sw.caption; color: Colors.label2; font.pixelSize: 11 }
                    MouseArea { id: swMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: sw.chosen() }
                }
                component Pill: Rectangle {
                    id: pl
                    property string text: ""
                    property bool on: false
                    signal chosen()
                    Layout.preferredHeight: 34
                    Layout.preferredWidth: plT.implicitWidth + 32
                    radius: 17
                    color: pl.on ? Qt.rgba(Colors.accent.r, Colors.accent.g, Colors.accent.b, 0.85) : (plMa.containsMouse ? Colors.fill2 : Colors.fill3)
                    Behavior on color { ColorAnimation { duration: Appearance.mQuick } }
                    // On the accent: black or white by the accent's lightness, so it always reads.
                    readonly property bool lightAccent: (0.2126 * Colors.accent.r + 0.7152 * Colors.accent.g + 0.0722 * Colors.accent.b) > 0.45
                    Text { id: plT; anchors.centerIn: parent; text: pl.text; color: pl.on ? (pl.lightAccent ? "#111111" : "#ffffff") : Colors.label
                           font.family: Appearance.fontUI; font.pixelSize: Appearance.fsS; font.weight: Font.DemiBold }
                    MouseArea { id: plMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: pl.chosen() }
                }

                // origin
                RowLayout {
                    spacing: 8
                    Text { text: "Origem"; color: Colors.label2; Layout.preferredWidth: 90
                           font.family: Appearance.fontUI; font.pixelSize: Appearance.fsS; font.weight: Font.DemiBold }
                    Pill { text: "Do wallpaper"; on: !coresPage.manual; onChosen: { Config.colorMode = "wallpaper"; Config.applyPalette(); } }
                    Pill { text: "Manual"; on: coresPage.manual; onChosen: { Config.colorMode = "manual"; Config.applyPalette(); } }
                    Item { Layout.fillWidth: true }
                }

                // accent (only in Manual: the wallpaper mode picks its colours itself)
                RowLayout {
                    spacing: 8
                    visible: coresPage.manual
                    Text { text: "Destaque"; color: Colors.label2; Layout.preferredWidth: 90
                           font.family: Appearance.fontUI; font.pixelSize: Appearance.fsS; font.weight: Font.DemiBold }
                    Repeater {
                        model: ["#5e81ac", "#3b82f6", "#06b6d4", "#14b8a6", "#22c55e", "#84cc16",
                                "#eab308", "#f97316", "#ef4444", "#ec4899", "#a855f7", "#8b5cf6"]
                        Swatch {
                            required property string modelData
                            swatch: modelData
                            selected: coresPage.manual && Config.manualAccent.toLowerCase() === modelData
                            onChosen: { Config.manualAccent = modelData; Config.colorMode = "manual"; Config.applyPalette(); }
                        }
                    }
                    Rectangle {
                        Layout.preferredWidth: 104; Layout.preferredHeight: 30
                        radius: 15
                        color: Colors.fill3
                        border.width: 1
                        border.color: hexIn2.activeFocus ? Colors.accent : Colors.hairline
                        TextInput {
                            id: hexIn2
                            anchors.fill: parent; anchors.leftMargin: 12; anchors.rightMargin: 10
                            verticalAlignment: TextInput.AlignVCenter
                            text: Config.manualAccent
                            color: Colors.fg
                            font.family: Appearance.font; font.pixelSize: 12
                            maximumLength: 7
                            selectByMouse: true
                            onAccepted: {
                                let v = text.trim(); if (!v.startsWith("#")) v = "#" + v;
                                if (!/^#[0-9a-fA-F]{6}$/.test(v)) { text = Config.manualAccent; return; }
                                Config.manualAccent = v.toLowerCase(); Config.colorMode = "manual"; Config.applyPalette();
                            }
                        }
                    }
                    Item { Layout.fillWidth: true }
                }

                // background (only in Manual: the wallpaper mode picks its colours itself)
                RowLayout {
                    spacing: 8
                    visible: coresPage.manual
                    Text { text: "Fundo"; color: Colors.label2; Layout.preferredWidth: 90
                           font.family: Appearance.fontUI; font.pixelSize: Appearance.fsS; font.weight: Font.DemiBold }
                    Repeater {
                        model: ["", "#0b0b0d", "#16171b", "#1e2128", "#0f1724", "#131a14", "#1d1216", "#241a12", "#eceff4"]
                        Swatch {
                            required property string modelData
                            swatch: modelData === "" ? Colors.bg : modelData
                            caption: modelData === "" ? "W" : ""
                            selected: coresPage.manual && Config.manualBg.toLowerCase() === modelData
                            onChosen: { Config.manualBg = modelData; Config.colorMode = "manual"; Config.applyPalette(); }
                        }
                    }
                    Item { Layout.fillWidth: true }
                }

                // the current palette, as pywal wrote it
                Text {
                    Layout.topMargin: 6
                    text: "Paleta atual"
                    color: Colors.label3
                    font.family: Appearance.fontUI; font.pixelSize: Appearance.fsXS; font.weight: Font.DemiBold
                }
                // Each cell is one of pywal's colours: click it to open a drawer
                // underneath and change that colour for this wallpaper
                // (palette-variants.sh edit; it comes back with the wallpaper).
                property int editIdx: -1
                property var edits: ({})
                readonly property var slots: [
                    { slot: "background", name: "Fundo" },        { slot: "color0", name: "Fundo 2" },
                    { slot: "color1", name: "Cor 1" },             { slot: "color2", name: "Cor 2" },
                    { slot: "color3", name: "Cor 3" },             { slot: "color4", name: "Destaque (cor 4)" },
                    { slot: "color5", name: "Cor 5" },             { slot: "color6", name: "Cor 6" },
                    { slot: "color8", name: "Apagado" },           { slot: "foreground", name: "Texto" }
                ]
                readonly property var slotColors: [Colors.bg, Colors.bgAlt, Colors.c1, Colors.c2, Colors.c3, Colors.c4,
                    Colors.c5, Colors.c6, Colors.dim, Colors.fg]
                function refreshEdits() { if (!editsGet.running) editsGet.running = true; }
                function editColor(slot, hex) {
                    editSet.command = [coresPage.scriptPath, "edit", slot, hex];
                    editSet.running = false;
                    editSet.running = true;
                }
                Process {
                    id: editsGet
                    command: [coresPage.scriptPath, "edits"]
                    stdout: StdioCollector {
                        onStreamFinished: { try { coresPage.edits = JSON.parse(this.text.trim() || "{}"); } catch (e) { coresPage.edits = {}; } }
                    }
                }
                Process { id: editSet; onExited: coresPage.refreshEdits() }
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 40
                    radius: 12
                    clip: true
                    color: "transparent"
                    Row {
                        anchors.fill: parent
                        Repeater {
                            model: coresPage.slots.length
                            Rectangle {
                                id: cell
                                required property int index
                                width: parent.width / coresPage.slots.length; height: parent.height
                                color: coresPage.slotColors[cell.index]
                                // edited by hand: a small dot
                                Rectangle {
                                    visible: coresPage.edits[coresPage.slots[cell.index].slot] !== undefined
                                    width: 6; height: 6; radius: 3
                                    anchors { right: parent.right; top: parent.top; margins: 5 }
                                    color: (0.2126 * cell.color.r + 0.7152 * cell.color.g + 0.0722 * cell.color.b) > 0.5 ? "#111111" : "#ffffff"
                                }
                                Rectangle {
                                    anchors.fill: parent
                                    color: "transparent"
                                    border.width: coresPage.editIdx === cell.index ? 3 : (cellMa.containsMouse ? 2 : 0)
                                    border.color: Colors.fg
                                }
                                MouseArea {
                                    id: cellMa
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: coresPage.editIdx = coresPage.editIdx === cell.index ? -1 : cell.index
                                }
                            }
                        }
                    }
                }

                // ── the drawer: change the chosen colour ──
                Item {
                    id: drawer
                    Layout.fillWidth: true
                    readonly property bool open: coresPage.editIdx >= 0
                    readonly property var cur: drawer.open ? coresPage.slots[coresPage.editIdx] : null
                    Layout.preferredHeight: drawer.open ? drawerBody.implicitHeight + 20 : 0
                    Behavior on Layout.preferredHeight { NumberAnimation { duration: Appearance.mInScale; easing.type: Easing.OutCubic } }
                    clip: true
                    Rectangle {
                        anchors.fill: parent
                        radius: 14
                        color: Colors.fill3
                        opacity: drawer.open ? 1 : 0
                        Behavior on opacity { NumberAnimation { duration: Appearance.mQuick } }
                        ColumnLayout {
                            id: drawerBody
                            anchors { left: parent.left; right: parent.right; top: parent.top; margins: 10 }
                            spacing: 10
                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 10
                                Rectangle {
                                    width: 22; height: 22; radius: 11
                                    color: drawer.open ? coresPage.slotColors[coresPage.editIdx] : "transparent"
                                    border.width: 1; border.color: Colors.hairline
                                }
                                Text {
                                    Layout.fillWidth: true
                                    text: drawer.cur ? "Trocar: " + drawer.cur.name : ""
                                    color: Colors.label
                                    font.family: Appearance.fontUI; font.pixelSize: Appearance.fsS; font.weight: Font.DemiBold
                                }
                                Pill {
                                    visible: drawer.cur !== null && coresPage.edits[drawer.cur.slot] !== undefined
                                    text: "Original"
                                    onChosen: coresPage.editColor(drawer.cur.slot, "")
                                }
                                Pill { text: "Fechar"; onChosen: coresPage.editIdx = -1 }
                            }
                            Flow {
                                Layout.fillWidth: true
                                spacing: 8
                                Repeater {
                                    // vivid hues, then the darks and greys a background or text needs
                                    model: ["#ef4444", "#f97316", "#f59e0b", "#eab308", "#84cc16", "#22c55e", "#14b8a6",
                                            "#06b6d4", "#3b82f6", "#6366f1", "#8b5cf6", "#d946ef", "#ec4899",
                                            "#0b0b0d", "#16171b", "#1e2128", "#2a2d35", "#6b7280", "#9ca3af", "#d1d5db", "#f3f4f6"]
                                    Swatch {
                                        required property string modelData
                                        swatch: modelData
                                        selected: drawer.open && String(coresPage.slotColors[coresPage.editIdx]) === modelData
                                        onChosen: coresPage.editColor(drawer.cur.slot, modelData)
                                    }
                                }
                                Rectangle {
                                    width: 96; height: 30; radius: 15
                                    color: Colors.fill2
                                    border.width: hexEd.activeFocus ? 1 : 0
                                    border.color: Colors.accent
                                    TextInput {
                                        id: hexEd
                                        anchors { fill: parent; leftMargin: 12; rightMargin: 12 }
                                        verticalAlignment: TextInput.AlignVCenter
                                        text: drawer.open ? String(coresPage.slotColors[coresPage.editIdx]) : ""
                                        color: Colors.label
                                        font.family: Appearance.font; font.pixelSize: Appearance.fsS
                                        maximumLength: 7
                                        onAccepted: if (/^#[0-9a-fA-F]{6}$/.test(text) && drawer.cur) coresPage.editColor(drawer.cur.slot, text.toLowerCase())
                                    }
                                }
                            }
                        }
                    }
                }
                // ── variations of this wallpaper's palette (scripts/palette-variants.sh) ──
                // Several palettes from the same picture; the one you pick is saved
                // for this wallpaper and comes back whenever you set it again.
                property var variants: []
                property string choice: "padrao"
                property string pending: ""
                readonly property var variantNames: ({
                    padrao: "Padrão", vibrante: "Vibrante", suave: "Suave", contraste: "Contraste",
                    centro: "Do centro", cima: "De cima", baixo: "De baixo",
                    complementar: "Complementar", claro: "Claro"
                })
                readonly property string scriptPath: Quickshell.env("HOME") + "/.config/glasstty/scripts/palette-variants.sh"
                function refreshVariants() { if (!variantGen.running) variantGen.running = true; }
                onVisibleChanged: if (visible) { if (!coresPage.manual) refreshVariants(); refreshEdits(); } else editIdx = -1
                Connections {
                    target: Colors
                    function onWallpaperChanged() { if (coresPage.visible) { coresPage.refreshVariants(); coresPage.refreshEdits(); } }
                }
                Process {
                    id: variantGen
                    command: [coresPage.scriptPath, "gen"]
                    stdout: StdioCollector {
                        onStreamFinished: {
                            try {
                                const d = JSON.parse(this.text.trim().split("\n").pop());
                                coresPage.variants = d.variants || [];
                                coresPage.choice = d.choice || "padrao";
                            } catch (e) { coresPage.variants = []; }
                            coresPage.pending = "";
                        }
                    }
                }
                Process { id: variantSet; onExited: coresPage.refreshEdits() }

                Text {
                    Layout.topMargin: 6
                    visible: !coresPage.manual
                    text: "Variações deste wallpaper"
                    color: Colors.label3
                    font.family: Appearance.fontUI; font.pixelSize: Appearance.fsXS; font.weight: Font.DemiBold
                }
                Text {
                    visible: !coresPage.manual && coresPage.variants.length === 0
                    text: variantGen.running ? "Gerando paletas…" : "Não foi possível gerar as variações."
                    color: Colors.label3
                    font.family: Appearance.fontUI; font.pixelSize: Appearance.fsXS
                }
                Flow {
                    Layout.fillWidth: true
                    visible: !coresPage.manual && coresPage.variants.length > 0
                    spacing: 8
                    Repeater {
                        model: coresPage.variants
                        Rectangle {
                            id: vt
                            required property var modelData
                            readonly property bool sel: (coresPage.pending || coresPage.choice) === vt.modelData.id
                            width: 112; height: 54
                            radius: 12
                            color: vtMa.containsMouse ? Colors.fill2 : Colors.fill3
                            border.width: vt.sel ? 2 : 0
                            border.color: Colors.accent
                            Behavior on color { ColorAnimation { duration: Appearance.mQuick } }
                            Column {
                                anchors { fill: parent; margins: 7 }
                                spacing: 5
                                Rectangle {
                                    width: parent.width; height: 22; radius: 6; clip: true
                                    color: vt.modelData.colors[0]
                                    Row {
                                        anchors { fill: parent; leftMargin: 6; rightMargin: 6; topMargin: 5; bottomMargin: 5 }
                                        spacing: 3
                                        Repeater {
                                            model: vt.modelData.colors.slice(1, 7)
                                            Rectangle { required property var modelData; width: (parent.width - 15) / 6; height: parent.height; radius: 3; color: modelData }
                                        }
                                    }
                                }
                                Text {
                                    text: coresPage.variantNames[vt.modelData.id] || vt.modelData.id
                                    color: vt.sel ? Colors.label : Colors.label2
                                    font.family: Appearance.fontUI; font.pixelSize: Appearance.fsXS
                                    font.weight: vt.sel ? Font.DemiBold : Font.Normal
                                }
                            }
                            MouseArea {
                                id: vtMa
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    if (vt.sel || variantSet.running) return;
                                    coresPage.pending = vt.modelData.id;
                                    coresPage.choice = vt.modelData.id;
                                    variantSet.command = [coresPage.scriptPath, "set", vt.modelData.id];
                                    variantSet.running = true;
                                }
                            }
                        }
                    }
                }

                Text {
                    Layout.fillWidth: true
                    wrapMode: Text.WordWrap
                    text: coresPage.manual
                        ? "Manual: o destaque e o fundo escolhidos valem para tudo (barra, janelas, login, terminal, apps) em qualquer wallpaper."
                        : "Do wallpaper: as cores mudam com cada wallpaper. Escolha uma variação acima, ou Manual para fixar as suas."
                    color: Colors.label3
                    font.family: Appearance.fontUI; font.pixelSize: Appearance.fsXS
                }
            }
            }

            // ── 4: rices (save / switch looks; see RicesPage.qml) ──
            RicesPage {}

            // ── 5: an extra of sistema ──
            // Each QML file in ~/.local/share/glasstty/extras/ is a page of its
            // own, reached from its door in Sistema (or `notch extra NAME`).
            // Outside the repository on purpose: they are the user's own
            // add-ons. The file's root Item may declare `title`, `subtitle`
            // (the door's words), `attention` (a dot on the door) and
            // `property var host`, which it gets with the theme tokens, whether
            // it is `shown`, `back()` to Sistema and `close()`. Loaded once and
            // kept, so an extra can keep sampling while it is not on screen.
            StackLayout {
                currentIndex: root.extra
                Repeater {
                    id: extraLoaders
                    model: FolderListModel {
                        id: extrasModel
                        folder: "file://" + Quickshell.env("HOME") + "/.local/share/glasstty/extras"
                        nameFilters: ["*.qml"]
                        showDirs: false
                        sortField: FolderListModel.Name
                    }
                    Loader {
                        id: extraLoader
                        required property int index
                        required property url fileUrl
                        readonly property QtObject host: QtObject {
                            readonly property bool shown: root.opened && root.page === 5 && root.extra === extraLoader.index
                            readonly property color bg: Colors.bg
                            readonly property color accent: Colors.accent
                            readonly property color accentInk: Colors.accentInk
                            readonly property color label: Colors.label
                            readonly property color label2: Colors.label2
                            readonly property color label3: Colors.label3
                            readonly property color fill1: Colors.fill1
                            readonly property color fill2: Colors.fill2
                            readonly property color fill3: Colors.fill3
                            readonly property color hairline: Colors.hairline
                            readonly property color surface1: Colors.surface1
                            readonly property color ok: Colors.ok
                            readonly property color warn: Colors.warn
                            readonly property color crit: Colors.crit
                            readonly property string fontUI: Appearance.fontUI
                            readonly property string fontIcon: Appearance.font
                            function back() { root.page = 2; }
                            function close() { ShellState.closePanel(); }
                        }
                        Component.onCompleted: extraLoader.setSource(extraLoader.fileUrl, { host: extraLoader.host })
                    }
                }
            }
        }

        Rectangle { Layout.fillHeight: true; width: 1; color: Colors.hairline }

        // ═════════════ right rail: brightness · volume · mic ═════════════
        ColumnLayout {
            Layout.fillHeight: true
            Layout.preferredWidth: 44
            spacing: 10
            // ONE vertical slider for the active channel: brightness, volume or
            // microphone. A click on a knob makes it the active one (a second
            // click mutes it); a click on the slider's icon goes back to brightness.
            VSlider {
                Layout.fillHeight: true
                Layout.alignment: Qt.AlignHCenter
                readonly property bool micOk: root.mic !== null && root.mic.audio !== null
                icon: root.rail === "vol" ? (Audio.muted ? Icons.volMute : Icons.volHigh)
                    : root.rail === "mic" ? ((micOk && root.mic.audio.muted) ? "󰍭" : "󰍬")
                    : Icons.brightness
                value: root.rail === "vol" ? Audio.vol
                     : root.rail === "mic" ? (micOk ? Math.round(root.mic.audio.volume * 100) : 0)
                     : Math.max(0, Brightness.bright)
                onMoved: function (v) {
                    if (root.rail === "vol") Audio.setVolume(v);
                    else if (root.rail === "mic") { if (micOk) root.mic.audio.volume = v / 100; }
                    else Brightness.setBrightness(v);
                }
                onIconClicked: if (Brightness.bright >= 0) root.rail = "bright"
            }
            Knob {
                Layout.alignment: Qt.AlignHCenter
                implicitWidth: 44; implicitHeight: 44
                icon: Audio.muted ? Icons.volMute : Icons.volHigh
                value: Audio.vol
                muted: Audio.muted
                active: root.rail === "vol"
                onMoved: function (v) { Audio.setVolume(v); }
                onClicked: if (root.rail === "vol") Audio.toggleMute(); else root.rail = "vol"
            }
            Knob {
                Layout.alignment: Qt.AlignHCenter
                implicitWidth: 44; implicitHeight: 44
                readonly property bool ok: root.mic !== null && root.mic.audio !== null
                icon: (ok && root.mic.audio.muted) ? "󰍭" : "󰍬"
                value: ok ? Math.round(root.mic.audio.volume * 100) : 0
                muted: ok ? root.mic.audio.muted : true
                active: root.rail === "mic"
                onMoved: function (v) { if (ok) root.mic.audio.volume = v / 100; }
                onClicked: if (root.rail !== "mic") root.rail = "mic"; else if (ok) root.mic.audio.muted = !root.mic.audio.muted
            }
        }
    }
}
