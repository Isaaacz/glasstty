// NotifDrops.qml — notifications as drops that fall out of the notch
// (in the spirit of jrnxf/drip).
//
// Each notification is its own pill-shaped card. It is born as a small blob
// under the notch, falls into place and opens up; the cards stack downwards,
// at most three, and the rest wait in a "drop" under the stack that counts
// them. A ring on the right shows the time left; hovering a card stops it.
// When a card goes, it shrinks back up into the notch and the ones below it
// move up.
//
// Clicking a card does what the notification offers (its "default" action,
// or its first action for ordinary notifications) and otherwise opens the
// Control Centre; a right click only puts the card away. Either way the
// notification stays in the Control Centre's history, as always.
//
// This is the "drops" style (Config.notifStyle). The "notch" style keeps the
// old notice inside the notch (NotchContent.qml, notifLayer).
import QtQuick
import QtQuick.Layouts
import QtQuick.Shapes
import Quickshell
import Quickshell.Wayland
import Quickshell.Services.Notifications

Scope {
    id: root

    readonly property int maxShown: 3
    readonly property int gap: 8
    // Cards live on the focused screen, right under the notch at rest.
    readonly property int topY: ShellState.bandH + ShellState.notchTopGap + 8

    // Live card items, top to bottom, and the notifications waiting their turn.
    property var cards: []
    property var queue: []
    // Bumped whenever `cards` changes order or size, so the layout re-runs.
    property int layoutTick: 0

    Connections {
        target: ShellState
        function onNotifPopped(n) { root.pop(n); }
    }

    function pop(n) {
        if (!n) return;
        // Already on screen (a card updated in place): show it again.
        for (let i = 0; i < root.cards.length; i++)
            if (root.cards[i].n === n && !root.cards[i].leaving) { root.cards[i].refresh(); return; }
        if (root.queue.indexOf(n) >= 0) return;
        if (root.liveCount() < root.maxShown) root.spawn(n);
        else root.queue = root.queue.concat([n]);
    }

    function liveCount() {
        let c = 0;
        for (let i = 0; i < root.cards.length; i++) if (!root.cards[i].leaving) c++;
        return c;
    }

    function spawn(n) {
        const c = cardComp.createObject(stack, { n: n });
        if (!c) return;
        root.cards = root.cards.concat([c]);
        root.layoutTick++;
    }

    // A card finished leaving: drop it and let the next one in line fall.
    function gone(c) {
        const i = root.cards.indexOf(c);
        if (i >= 0) {
            const next = root.cards.slice();
            next.splice(i, 1);
            root.cards = next;
        }
        c.destroy();
        root.layoutTick++;
        root.fill();
    }

    // A card started leaving: the ones below move up at once.
    function leaving() { root.layoutTick++; root.fill(); }

    function fill() {
        while (root.queue.length > 0 && root.liveCount() < root.maxShown) {
            const q = root.queue.slice();
            const n = q.shift();
            root.queue = q;
            // A queued notification can close before its turn comes.
            if (n && root.alive(n)) root.spawn(n);
        }
    }

    function alive(n) {
        const vs = ShellState.notifications;
        return vs.indexOf(n) >= 0;
    }

    // Where each card goes: stacked downwards, leaving ones keep their place
    // (they are shrinking away) and do not push the rest.
    function slotY(c) {
        let y = 0;
        for (let i = 0; i < root.cards.length; i++) {
            const k = root.cards[i];
            if (k === c) return y;
            if (!k.leaving) y += k.fullH + root.gap;
        }
        return y;
    }
    readonly property real stackH: {
        root.layoutTick;
        let y = 0;
        for (let i = 0; i < root.cards.length; i++)
            if (!root.cards[i].leaving) y += root.cards[i].fullH + root.gap;
        return y;
    }

    PanelWindow {
        id: win
        screen: {
            const ss = Quickshell.screens;
            for (let i = 0; i < ss.length; i++)
                if (ss[i].name === ShellState.focusedMon) return ss[i];
            return ss.length > 0 ? ss[0] : null;
        }
        visible: root.cards.length > 0 || root.queue.length > 0
        anchors { top: true }
        implicitWidth: 560
        implicitHeight: root.topY + 3 * 76 + 60
        exclusiveZone: 0
        exclusionMode: ExclusionMode.Ignore
        color: "transparent"
        // Under the bar on niri (the bar is on Overlay there), so a card comes
        // out from behind the notch instead of being drawn over it.
        WlrLayershell.layer: WlrLayer.Top
        WlrLayershell.namespace: "quickshell:drops"
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

        // Only the cards take the mouse; the rest of the window lets it through.
        mask: Region {
            item: hit
        }
        Item {
            id: hit
            x: (win.width - width) / 2
            y: root.topY
            width: {
                root.layoutTick;
                let w = 0;
                for (let i = 0; i < root.cards.length; i++) w = Math.max(w, root.cards[i].width);
                return w;
            }
            height: root.stackH + (root.queue.length > 0 ? 30 : 0)
        }

        // Cards are born and leave as a blob tucked under the notch: the
        // window sits below the bar, so the notch itself hides that part.
        Item {
            id: stack
            anchors.fill: parent
        }

        // The waiting ones: a small drop under the stack with their count.
        Rectangle {
            id: waiting
            readonly property bool on: root.queue.length > 0
            x: (win.width - width) / 2
            y: root.topY + root.stackH + (on ? 0 : -14)
            width: Math.max(24, waitText.implicitWidth + 14)
            height: 24
            radius: 12
            color: root.cardColor
            opacity: on ? 1 : 0
            scale: on ? 1 : 0.4
            Behavior on y { SpringAnimation { spring: 4; damping: 0.32; epsilon: 0.3 } }
            Behavior on opacity { NumberAnimation { duration: Appearance.mIn; easing.type: Easing.OutCubic } }
            Behavior on scale { SpringAnimation { spring: 5; damping: 0.3; epsilon: 0.01 } }
            Text {
                id: waitText
                anchors.centerIn: parent
                text: Math.max(1, root.queue.length)   // keeps its number while it fades out
                color: Colors.label
                font.family: Appearance.fontUI; font.pixelSize: Appearance.fsXXS; font.weight: Font.DemiBold
            }
        }
    }

    // The card's colour follows the notch's, so a drop looks like a piece of it.
    readonly property color cardColor: Colors.notchTint(Config.notchColor)

    Component {
        id: cardComp

        Item {
            id: card
            property var n: null
            property bool leaving: false
            property bool landed: false

            // Text copies: the server destroys `n` when the notification closes,
            // and the card still needs its words while it shrinks away.
            property string title: ""
            property string body: ""
            property string appName: ""
            property string image: ""
            property string kind: ""
            property var buttons: []
            property bool critical: false

            function readN() {
                if (!card.n) return;
                card.title = ShellState.tn(card.n.summary || card.n.appName || "");
                card.body = ShellState.tn(card.n.body || "");
                card.appName = card.n.appName || "";
                card.image = (card.n.image && card.n.image.length > 0) ? card.n.image
                    : (card.n.appIcon ? Quickshell.iconPath(card.n.appIcon, "dialog-information") : "");
                card.kind = ShellState.notifKind(card.n);
                card.buttons = ShellState.notifButtons(card.n).slice(0, 3);
                card.critical = card.n.urgency === NotificationUrgency.Critical;
            }
            function refresh() {
                card.readN();
                countdown.restart();
                bump.restart();
            }
            // Where it was when it started to go: it shrinks away right there
            // (travelling back up would cross the cards above it).
            property real leaveY: 0
            function leave() {
                if (card.leaving) return;
                card.leaveY = card.y;
                card.leaving = true;
                countdown.stop();
                root.leaving();
                goneTimer.start();
            }

            readonly property color kindColor: kind === "ok" ? "#4ade80" : kind === "warn" ? "#fbbf24"
                : kind === "fail" ? "#f87171" : Colors.accent

            readonly property int fullH: body.length > 0 ? 58 : 46
            readonly property int fullW: Math.max(230, Math.min(460, row.implicitWidth + 28))

            // ── the drop: born small under the notch, falls, opens up ──
            readonly property real targetY: { root.layoutTick; return root.topY + root.slotY(card); }
            x: (parent.width - width) / 2
            y: leaving ? leaveY + (fullH - height) / 2
                : landed ? targetY : root.topY - 30
            width: leaving ? fullW * 0.55 : landed ? fullW : 64
            height: leaving ? fullH * 0.55 : landed ? fullH : 26
            opacity: leaving ? 0 : 1
            Behavior on y {
                enabled: !card.leaving
                SpringAnimation { spring: 3.4; damping: 0.26; epsilon: 0.3 }
            }
            Behavior on width { SpringAnimation { spring: 4.2; damping: 0.3; epsilon: 0.3 } }
            Behavior on height { SpringAnimation { spring: 4.2; damping: 0.3; epsilon: 0.3 } }
            Behavior on opacity {
                SequentialAnimation {
                    PauseAnimation { duration: 90 }
                    NumberAnimation { duration: 180; easing.type: Easing.InQuad }
                }
            }

            Component.onCompleted: {
                card.readN();
                // One frame at the blob size first, so the fall is animated.
                Qt.callLater(function () { card.landed = true; countdown.start(); });
            }

            Timer { id: goneTimer; interval: 420; onTriggered: root.gone(card) }

            // An updated card gives a small nudge so the change is noticed.
            SequentialAnimation {
                id: bump
                NumberAnimation { target: shape; property: "scale"; to: 1.05; duration: 110; easing.type: Easing.OutQuad }
                SpringAnimation { target: shape; property: "scale"; to: 1; spring: 5; damping: 0.25 }
            }

            Connections {
                target: card.n
                ignoreUnknownSignals: true
                function onClosed(reason) { card.n = null; card.leave(); }
            }

            // ── time left; hovering the card stops the clock ──
            // Only a pointer that MOVES over the card counts: a card that falls
            // under a resting pointer (top centre, right after using the notch)
            // would otherwise never go away.
            property real remain: 1
            NumberAnimation {
                id: countdown
                target: card; property: "remain"
                from: 1; to: 0
                duration: card.n ? ShellState.notifFlashMs(card.n) : 4200
                paused: running && ma.containsMouse && ma.moved
                onFinished: if (!card.leaving && card.remain <= 0.001) card.leave()
            }

            Rectangle {
                id: shape
                anchors.fill: parent
                radius: height / 2
                color: root.cardColor
                border.width: 1
                border.color: Qt.rgba(1, 1, 1, ma.containsMouse && ma.moved ? 0.12 : 0.05)

                MouseArea {
                    id: ma
                    anchors.fill: parent
                    hoverEnabled: true
                    acceptedButtons: Qt.LeftButton | Qt.RightButton
                    cursorShape: Qt.PointingHandCursor
                    property bool moved: false
                    property point first: Qt.point(-1, -1)
                    // In window coordinates: cards sliding under a still
                    // pointer also send hover moves, but those do not change.
                    onPositionChanged: function (ev) {
                        const p = mapToItem(null, ev.x, ev.y);
                        if (first.x < 0) { first = p; return; }
                        if (Math.abs(p.x - first.x) + Math.abs(p.y - first.y) > 3) moved = true;
                    }
                    onExited: { moved = false; first = Qt.point(-1, -1); }
                    onClicked: function (ev) {
                        if (ev.button === Qt.RightButton) { card.leave(); return; }
                        const n = card.n;
                        const acts = n ? n.actions : null;
                        if (card.kind !== "") {
                            const d = acts ? acts.find(a => a.identifier === "default") : null;
                            if (d) d.invoke();
                            else if (card.buttons.length > 0) return;   // answer with a button
                            else ShellState.togglePanel("control");
                        } else if (acts && acts.length > 0) acts[0].invoke();
                        else ShellState.togglePanel("control");
                        card.leave();
                    }
                }

                RowLayout {
                    id: row
                    anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter
                              leftMargin: 12; rightMargin: 14 }
                    spacing: 10
                    // Content comes in once the drop has opened, and goes first.
                    opacity: card.landed && !card.leaving && card.width > card.fullW * 0.8 ? 1 : 0
                    Behavior on opacity { NumberAnimation { duration: card.leaving ? 90 : 200; easing.type: Easing.OutCubic } }

                    // kind mark, or the application's icon for an ordinary notification
                    Rectangle {
                        visible: card.kind !== "" || card.image === ""
                        Layout.preferredWidth: 24; Layout.preferredHeight: 24
                        Layout.alignment: Qt.AlignVCenter
                        radius: 12
                        color: card.kind !== "" ? card.kindColor : Colors.accent
                        Text {
                            anchors.centerIn: parent
                            text: card.kind === "ok" ? "󰄬" : card.kind === "warn" ? "󰀦"
                                : card.kind === "fail" ? "󰅖" : card.kind === "info" ? "󰋽" : "󰂚"
                            color: "#101010"
                            font.family: Appearance.font; font.pixelSize: 14
                        }
                    }
                    Image {
                        visible: card.kind === "" && card.image !== ""
                        Layout.preferredWidth: 26; Layout.preferredHeight: 26
                        Layout.alignment: Qt.AlignVCenter
                        source: card.image
                        sourceSize.width: 52; sourceSize.height: 52
                        fillMode: Image.PreserveAspectFit
                        asynchronous: true
                    }

                    ColumnLayout {
                        Layout.alignment: Qt.AlignVCenter
                        Layout.fillWidth: true
                        Layout.maximumWidth: 300
                        spacing: 1
                        Text {
                            Layout.fillWidth: true
                            Layout.maximumWidth: 300
                            text: card.title
                            color: "#f5f5f5"; elide: Text.ElideRight
                            font.family: Appearance.fontUI; font.pixelSize: Appearance.fsS; font.weight: Font.DemiBold
                        }
                        Text {
                            Layout.fillWidth: true
                            Layout.maximumWidth: 300
                            visible: card.body.length > 0
                            text: card.body
                            color: Qt.rgba(1, 1, 1, 0.6); elide: Text.ElideRight
                            textFormat: Text.StyledText
                            maximumLineCount: 1
                            font.family: Appearance.fontUI; font.pixelSize: Appearance.fsXXS
                        }
                    }

                    // buttons; the first is the main one (filled)
                    Row {
                        visible: card.buttons.length > 0
                        Layout.alignment: Qt.AlignVCenter
                        spacing: 6
                        Repeater {
                            model: card.buttons
                            Rectangle {
                                id: btn
                                required property var modelData
                                required property int index
                                readonly property bool main: index === 0
                                width: btnText.implicitWidth + 22; height: 26; radius: 13
                                color: main ? Qt.darker(card.kindColor, btnMa.containsMouse ? 1.0 : 1.15)
                                    : (btnMa.containsMouse ? Qt.rgba(1, 1, 1, 0.16) : Qt.rgba(1, 1, 1, 0.09))
                                Text {
                                    id: btnText
                                    anchors.centerIn: parent
                                    text: btn.modelData.text
                                    color: btn.main ? "#101010" : "#f5f5f5"
                                    font.family: Appearance.fontUI; font.pixelSize: Appearance.fsXXS; font.weight: Font.DemiBold
                                }
                                MouseArea {
                                    id: btnMa
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: { btn.modelData.invoke(); card.leave(); }
                                }
                            }
                        }
                    }

                    // the ring with the time left (also next to buttons: a question waits too)
                    Item {
                        Layout.preferredWidth: 18; Layout.preferredHeight: 18
                        Layout.alignment: Qt.AlignVCenter
                        Shape {
                            anchors.fill: parent
                            preferredRendererType: Shape.CurveRenderer
                            ShapePath {
                                strokeColor: Qt.rgba(1, 1, 1, 0.12)
                                strokeWidth: 2.2
                                fillColor: "transparent"
                                PathAngleArc { centerX: 9; centerY: 9; radiusX: 7; radiusY: 7; startAngle: 0; sweepAngle: 360 }
                            }
                            ShapePath {
                                strokeColor: card.kind !== "" ? card.kindColor : Colors.accent
                                strokeWidth: 2.2
                                fillColor: "transparent"
                                capStyle: ShapePath.RoundCap
                                PathAngleArc { centerX: 9; centerY: 9; radiusX: 7; radiusY: 7
                                               startAngle: -90; sweepAngle: 360 * card.remain }
                            }
                        }
                    }
                }
            }
        }
    }
}
