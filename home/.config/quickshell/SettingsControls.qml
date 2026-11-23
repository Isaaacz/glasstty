// SettingsControls.qml — the controls of the Settings app.
// The sections use them as types: `SettingsControls.Card_ { ... }`.
//
// TWO DECISIONS THAT EXPLAIN EVERYTHING ELSE:
//
// 1) A setting's description does NOT go under its label. It used to, and each
//    row was three lines tall: a 520 px tall window fitted seven settings and
//    Appearance was an endless scroll. Now the row is 42 px and the
//    description travels to `ShellState.settingsHint`, which the window shows
//    in a fixed strip at the bottom. Zero reflow on hover, nothing covering
//    anything, and not a single word lost.
//
// 2) Settings go in rounded CARDS (law 1 of the rice's motion rules:
//    roundness belongs to the shell). It used to be a flat list with 1 px
//    separators, which grouped nothing and did not speak the language of the
//    rest of the rice.
//
// Motion: there is only hover and press here, i.e. RESPONSE (130 ms), and
// symmetric because hover is a state, not an event (law 3).
import QtQuick
import QtQuick.Layouts

QtObject {
    id: root

    // ─────────── group card ───────────
    // It hides itself if the search leaves no row inside it. The count can NOT
    // look at the children's `visible`: in QML `visible` is the effective
    // value, so once the card hid, its rows would say false and it would never
    // appear again. That is why each row publishes `matches` separately.
    component Card_: ColumnLayout {
        id: card
        property string title: ""
        readonly property bool isSettingsCard: true
        property int visibleRows: 0
        default property alias rows: inner.data

        function recount() {
            let n = 0;
            const cs = inner.children;
            for (let i = 0; i < cs.length; i++)
                if (cs[i] && cs[i].isSettingsRow && cs[i].matches) n++;
            card.visibleRows = n;
        }

        Layout.fillWidth: true
        Layout.topMargin: 8
        spacing: 9
        visible: card.visibleRows > 0

        // The menus' look (Control Centre, capture toolbar): a quiet caps
        // caption over a frosted, borderless card.
        Text {
            Layout.leftMargin: 8
            visible: card.title.length > 0
            text: card.title
            color: Colors.label3
            font.family: Appearance.fontUI
            font.pixelSize: Appearance.fsXS
            font.weight: Font.DemiBold
            font.letterSpacing: 1.1
            font.capitalization: Font.AllUppercase
        }

        Rectangle {
            Layout.fillWidth: true
            implicitHeight: inner.implicitHeight + 12
            radius: Appearance.radL
            color: Colors.fill3

            ColumnLayout {
                id: inner
                anchors { fill: parent; topMargin: 6; bottomMargin: 6; leftMargin: 6; rightMargin: 6 }
                spacing: 2
            }
        }
    }

    // ─────────── row: label + control ───────────
    component Row_: Rectangle {
        id: r
        property string label: ""
        property string hint: ""
        property bool active: true                  // false = dimmed (e.g. bluetooth blocked)
        property bool shown: true                   // false = does not apply right now (e.g. island settings in notch mode)
        readonly property bool isSettingsRow: true
        // CAREFUL: whoever uses the row must NOT touch `visible` (it would break
        // the search); to make a row conditional there is `shown`.
        readonly property bool matches: r.shown && ShellState.settingsMatch(r.label, r.hint)
        default property alias content: inner.data

        function _recount() {
            let p = r.parent;
            while (p) { if (p.isSettingsCard) { p.recount(); return; } p = p.parent; }
        }
        onMatchesChanged: r._recount()
        Component.onCompleted: r._recount()

        Layout.fillWidth: true
        // 42 px is the FLOOR, not the height. It was hard-coded, and the font
        // picker —seven options in a 270 px Flow— wraps onto three lines: those
        // lines spilled out of the row and were painted ON TOP of the setting
        // below and the card's border (the "Tamaño de la hora" (clock size)
        // slider ended up struck through by the pills). A control that grows
        // has to push the row, not spill out of it.
        Layout.preferredHeight: Math.max(46, inner.implicitHeight + 16)
        visible: r.matches
        radius: Appearance.radM
        color: hh.hovered ? Colors.fill2 : "transparent"
        opacity: r.active ? 1 : 0.42
        Behavior on color { ColorAnimation { duration: Appearance.mQuick; easing.type: Easing.OutQuad } }
        Behavior on opacity { NumberAnimation { duration: Appearance.mQuick } }

        // HoverHandler and not MouseArea: it does not block, so the row knows
        // the mouse is over it even when the pointer is right over the slider,
        // and the slider still gets its clicks.
        HoverHandler {
            id: hh
            onHoveredChanged: {
                if (hovered) ShellState.settingsHint = r.hint;
                else if (ShellState.settingsHint === r.hint) ShellState.settingsHint = "";
            }
        }

        RowLayout {
            id: inner
            anchors { fill: parent; leftMargin: 14; rightMargin: 14 }
            spacing: 16

            Text {
                Layout.fillWidth: true
                Layout.minimumWidth: 120
                text: r.label
                color: Colors.label
                elide: Text.ElideRight
                font.family: Appearance.fontUI
                font.pixelSize: Appearance.fsM
            }
        }
    }

    // ─────────── whole clickable row (leads somewhere else) ───────────
    component Action_: Rectangle {
        id: a
        property string label: ""
        property string hint: ""
        property string value: ""
        property string icon: ""
        property bool shown: true
        signal triggered

        readonly property bool isSettingsRow: true
        readonly property bool matches: a.shown && ShellState.settingsMatch(a.label, a.hint)
        function _recount() {
            let p = a.parent;
            while (p) { if (p.isSettingsCard) { p.recount(); return; } p = p.parent; }
        }
        onMatchesChanged: a._recount()
        Component.onCompleted: a._recount()

        Layout.fillWidth: true
        Layout.preferredHeight: 46
        visible: a.matches
        radius: Appearance.radM
        color: aMa.containsMouse ? Colors.fill2 : "transparent"
        Behavior on color { ColorAnimation { duration: Appearance.mQuick; easing.type: Easing.OutQuad } }

        RowLayout {
            anchors { fill: parent; leftMargin: 10; rightMargin: 14 }
            spacing: 12
            Rectangle {
                visible: a.icon.length > 0
                Layout.preferredWidth: 28; Layout.preferredHeight: 28
                radius: 9
                color: Qt.rgba(Colors.accent.r, Colors.accent.g, Colors.accent.b, 0.16)
                Text {
                    anchors.centerIn: parent
                    text: a.icon
                    color: Colors.accentInk
                    font.family: Appearance.font
                    font.pixelSize: 14
                }
            }
            Text {
                Layout.fillWidth: true
                Layout.leftMargin: a.icon.length > 0 ? 0 : 4
                text: a.label
                color: Colors.label
                elide: Text.ElideRight
                font.family: Appearance.fontUI
                font.pixelSize: Appearance.fsM
            }
            Text {
                text: a.value
                color: Colors.label2
                elide: Text.ElideRight
                font.family: Appearance.fontUI
                font.pixelSize: Appearance.fsXS
                // Counters that refresh by themselves land here (the
                // notification queue, the number of applications): with fontUI,
                // which is proportional, the width jitters on every refresh
                // without tabular figures.
                font.features: ({ "tnum": 1 })
            }
            Text {
                text: "›"
                color: aMa.containsMouse ? Colors.label : Colors.label3
                font.family: Appearance.fontUI
                font.pixelSize: 15
            }
        }

        MouseArea {
            id: aMa
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onEntered: ShellState.settingsHint = a.hint
            onExited: if (ShellState.settingsHint === a.hint) ShellState.settingsHint = ""
            onClicked: a.triggered()
        }
    }

    // ─────────── switch ───────────
    component Switch_: Rectangle {
        id: sw
        property bool checked: false
        property bool live: true                    // false = does not respond (and looks off)
        signal toggled(bool value)

        implicitWidth: 42; implicitHeight: 24
        radius: 12
        color: sw.checked ? Colors.accent : Colors.fill1
        opacity: sw.live ? 1 : 0.45
        Behavior on color { ColorAnimation { duration: Appearance.mQuick; easing.type: Easing.OutQuad } }

        Rectangle {
            width: 18; height: 18; radius: 9
            color: sw.checked ? Colors.accentText : Colors.label2
            y: 3
            x: sw.checked ? parent.width - width - 3 : 3
            Behavior on x { NumberAnimation { duration: Appearance.mQuick; easing.type: Easing.OutCubic } }
            Behavior on color { ColorAnimation { duration: Appearance.mQuick } }
        }
        MouseArea {
            anchors.fill: parent
            anchors.margins: -6
            enabled: sw.live
            cursorShape: Qt.PointingHandCursor
            onClicked: sw.toggled(!sw.checked)
        }
    }

    // ─────────── slider with value ───────────
    component Slider_: RowLayout {
        id: sl
        property real value: 0
        property real from: 0
        property real to: 100
        property int decimals: 0
        property string suffix: ""
        // Step per Ctrl+wheel notch. 0 = derive it from the range (see onWheel).
        property real stepSize: 0
        signal moved(real v)

        // same as in NotchSlider: the value is animated, never the derived width
        property real shown: sl.value
        Behavior on shown {
            enabled: !drag.pressed
            NumberAnimation { duration: Appearance.mQuick; easing.type: Easing.OutCubic }
        }

        spacing: 10
        Layout.preferredWidth: 270
        Layout.fillWidth: false

        Rectangle {
            id: track
            Layout.fillWidth: true
            Layout.preferredHeight: 6
            radius: 3
            color: Colors.fill1

            Rectangle {
                id: fill
                width: track.width * Math.max(0, Math.min(1, (sl.shown - sl.from) / (sl.to - sl.from)))
                height: parent.height; radius: parent.radius
                color: Colors.accent
            }
            Rectangle {
                width: 16; height: 16; radius: 8
                color: Colors.accentText
                border.width: 3
                border.color: Colors.accent
                x: Math.max(0, Math.min(track.width - width, fill.width - width / 2))
                anchors.verticalCenter: parent.verticalCenter
                scale: drag.pressed ? 1.25 : drag.containsMouse ? 1.12 : 1
                Behavior on scale { NumberAnimation { duration: Appearance.mQuick; easing.type: Easing.OutCubic } }
            }
            MouseArea {
                id: drag
                // A tall grab area (the whole row height) and no stealing: the
                // page is a Flickable, and a drag that drifted a few pixels up
                // or down used to be taken over by it and scroll the page
                // instead of moving the slider.
                anchors.fill: parent
                anchors.leftMargin: -9
                anchors.rightMargin: -9
                anchors.topMargin: -16
                anchors.bottomMargin: -16
                hoverEnabled: true
                preventStealing: true
                cursorShape: pressed ? Qt.ClosedHandCursor : Qt.PointingHandCursor
                function emit(x) {
                    // x is in the grab area, which starts 9 px left of the track.
                    const raw = sl.from + Math.max(0, Math.min(1, (x - 9) / track.width)) * (sl.to - sl.from);
                    // Snap to the slider's step, so it lands on the numbers it shows.
                    const st = sl.stepSize > 0 ? sl.stepSize : Math.pow(10, -sl.decimals);
                    sl.moved(Math.max(sl.from, Math.min(sl.to, Math.round((raw - sl.from) / st) * st + sl.from)));
                }
                onPressed: function (m) { emit(m.x); }
                onPositionChanged: function (m) { if (pressed) emit(m.x); }
                // The wheel SCROLLS the page, it does not move the slider. The
                // sliders take up the right half of each row, so scrolling down
                // Appearance the pointer passes over one by accident and you
                // ended up changing the band height thinking you were scrolling.
                // With Ctrl it does adjust: handy for fine-tuning one at a time
                // without dragging.
                //
                // accepted = false is what lets the event bubble up to the
                // page's Flickable; without that line the MouseArea keeps it
                // (onWheel accepts by default) and the page does not move.
                onWheel: function (w) {
                    if (!(w.modifiers & Qt.ControlModifier)) {
                        w.accepted = false;
                        return;
                    }
                    // THE STEP CANNOT COME FROM THE RANGE ALONE.
                    //
                    // This used to be plain `(to - from) / 40`, and on two of
                    // the twelve sliders it gave less than their onMoved can
                    // store: "Separación del borde" (edge gap, 0-14) came out at
                    // 0.35 and "Tamaño de la hora" (clock size, 12-24) at 0.30,
                    // and both round to an integer. Math.round(v + 0.35)
                    // returns the SAME integer, so Config did not change, the
                    // binding gave back the previous value and the next turn
                    // repeated the sum from the same starting value. Stuck by
                    // construction -not by accumulation- and at the ends too,
                    // while the comment above promised one-at-a-time tuning.
                    //
                    // The floor is the resolution the slider itself displays:
                    // if it labels integers, one notch is worth 1. That way the
                    // ten that already worked keep their big step and the two
                    // broken ones start moving.
                    const step = sl.stepSize > 0
                        ? sl.stepSize
                        : Math.max((sl.to - sl.from) / 40, Math.pow(10, -sl.decimals));
                    sl.moved(Math.max(sl.from, Math.min(sl.to, sl.value + (w.angleDelta.y > 0 ? step : -step))));
                }
            }
        }

        // The value: click it to type an exact number (Enter applies, Esc or
        // clicking away cancels). Out-of-range numbers are clamped.
        Rectangle {
            id: valBox
            property bool editing: false
            Layout.preferredWidth: 56
            Layout.preferredHeight: 26
            radius: 13
            color: valBox.editing ? Colors.fill1 : valMa.containsMouse ? Colors.fill2 : "transparent"
            border.width: valBox.editing ? 1 : 0
            border.color: Colors.accent
            Behavior on color { ColorAnimation { duration: Appearance.mQuick } }
            Text {
                anchors { right: parent.right; rightMargin: 8; verticalCenter: parent.verticalCenter }
                visible: !valBox.editing
                text: sl.shown.toFixed(sl.decimals) + sl.suffix
                color: valMa.containsMouse ? Colors.label : Colors.label2
                font.family: Appearance.fontUI
                font.pixelSize: Appearance.fsXS
                font.features: ({ "tnum": 1 })
            }
            TextInput {
                id: valIn
                anchors { left: parent.left; right: parent.right; leftMargin: 8; rightMargin: 8; verticalCenter: parent.verticalCenter }
                visible: valBox.editing
                horizontalAlignment: TextInput.AlignRight
                color: Colors.label
                selectionColor: Qt.rgba(Colors.accent.r, Colors.accent.g, Colors.accent.b, 0.45)
                selectByMouse: true
                font.family: Appearance.fontUI
                font.pixelSize: Appearance.fsXS
                font.features: ({ "tnum": 1 })
                validator: RegularExpressionValidator { regularExpression: /-?[0-9]*[.,]?[0-9]*/ }
                function commit() {
                    const v = parseFloat(String(valIn.text).replace(",", "."));
                    if (!isNaN(v)) sl.moved(Math.max(sl.from, Math.min(sl.to, v)));
                    valBox.editing = false;
                }
                onAccepted: valIn.commit()
                Keys.onEscapePressed: valBox.editing = false
                onActiveFocusChanged: if (!activeFocus && valBox.editing) valBox.editing = false
            }
            MouseArea {
                id: valMa
                anchors.fill: parent
                visible: !valBox.editing
                hoverEnabled: true
                cursorShape: Qt.IBeamCursor
                onClicked: {
                    valIn.text = sl.value.toFixed(sl.decimals);
                    valBox.editing = true;
                    valIn.forceActiveFocus();
                    valIn.selectAll();
                }
            }
        }
    }

    // ─────────── option picker ───────────
    component Choice_: Flow {
        id: ch
        property var options: []
        property string current: ""
        signal picked(string value)

        Layout.preferredWidth: 270
        Layout.fillWidth: false
        spacing: 6

        Repeater {
            model: ch.options
            Rectangle {
                required property var modelData
                readonly property bool sel: String(modelData) === ch.current
                implicitWidth: t.implicitWidth + 22
                implicitHeight: 28
                radius: 14
                color: sel ? Colors.accent
                     : cMa.containsMouse ? Colors.fill2 : Colors.fill3
                Behavior on color { ColorAnimation { duration: Appearance.mQuick; easing.type: Easing.OutQuad } }
                Text {
                    id: t
                    anchors.centerIn: parent
                    text: modelData
                    color: parent.sel ? Colors.accentText : Colors.label2
                    font.family: Appearance.fontUI
                    font.pixelSize: Appearance.fsXS
                    font.weight: parent.sel ? Font.DemiBold : Font.Normal
                }
                MouseArea {
                    id: cMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: ch.picked(String(modelData))
                }
            }
        }
    }

    // ─────────── one line of text (Enter or leaving the field saves) ───────────
    component Text_: Rectangle {
        id: tf
        property string text: ""
        property string placeholder: ""
        property int maxLength: 80
        signal edited(string value)

        Layout.preferredWidth: 270
        implicitHeight: 32
        radius: 16
        color: tIn.activeFocus ? Colors.fill1 : Colors.fill3
        border.width: tIn.activeFocus ? 1 : 0
        border.color: Qt.rgba(Colors.accent.r, Colors.accent.g, Colors.accent.b, 0.5)
        Behavior on color { ColorAnimation { duration: Appearance.mQuick } }

        TextInput {
            id: tIn
            anchors { left: parent.left; right: parent.right; leftMargin: 14; rightMargin: 14; verticalCenter: parent.verticalCenter }
            text: tf.text
            maximumLength: tf.maxLength
            color: Colors.label
            selectionColor: Qt.rgba(Colors.accent.r, Colors.accent.g, Colors.accent.b, 0.45)
            selectByMouse: true
            clip: true
            font.family: Appearance.fontUI
            font.pixelSize: Appearance.fsS
            onAccepted: { tf.edited(tIn.text); tIn.focus = false; }
            onActiveFocusChanged: if (!activeFocus && tIn.text !== tf.text) tf.edited(tIn.text)
            Keys.onEscapePressed: { tIn.text = tf.text; tIn.focus = false; }
        }
        Text {
            anchors { left: parent.left; leftMargin: 14; verticalCenter: parent.verticalCenter }
            visible: tIn.text.length === 0 && !tIn.activeFocus
            text: tf.placeholder
            color: Colors.label3
            font.family: Appearance.fontUI
            font.pixelSize: Appearance.fsS
        }
    }

    // ─────────── small button ───────────
    component Btn_: Rectangle {
        id: b
        property string text: ""
        property bool danger: false
        property bool primary: false                // the accent button (Aplicar)
        signal clicked

        implicitWidth: bt.implicitWidth + 28
        implicitHeight: 30
        radius: 15
        color: b.primary ? (bMa.containsMouse ? Qt.lighter(Colors.accent, 1.12) : Colors.accent)
             : bMa.containsMouse
             ? (b.danger ? Qt.rgba(Colors.crit.r, Colors.crit.g, Colors.crit.b, 0.30) : Colors.fill2)
             : Colors.fill3
        Behavior on color { ColorAnimation { duration: Appearance.mQuick; easing.type: Easing.OutQuad } }

        Text {
            id: bt
            anchors.centerIn: parent
            text: b.text
            color: b.primary ? Colors.accentText : bMa.containsMouse ? Colors.label : Colors.label2
            font.family: Appearance.fontUI
            font.pixelSize: Appearance.fsXS
            font.weight: b.primary ? Font.DemiBold : Font.Normal
        }
        MouseArea {
            id: bMa
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: b.clicked()
        }
    }

    // ─────────── read-only value (About) ───────────
    component Val_: Text {
        Layout.maximumWidth: 310
        color: Colors.label2
        elide: Text.ElideRight
        horizontalAlignment: Text.AlignRight
        font.family: Appearance.fontUI
        font.pixelSize: Appearance.fsS
        // Tabular figures: this shows the battery percentage, the watts, the
        // cycles and the remaining time, which refresh by themselves. With
        // fontUI, which is proportional, a "1" is not as wide as an "8" and the
        // value —right-aligned— moved on every update.
        font.features: ({ "tnum": 1 })
    }

    // ─────────── loose text (empty states, notes) ───────────
    component Note_: Text {
        Layout.fillWidth: true
        wrapMode: Text.Wrap
        color: Colors.label3
        font.family: Appearance.fontUI
        font.pixelSize: Appearance.fsXS
        lineHeight: Appearance.leading(Appearance.fsXS)
        lineHeightMode: Text.FixedHeight
    }

    // ─────────── an empty state with intent, not a gap that looks broken ───────────
    component Empty_: Rectangle {
        id: empty
        property string icon: ""
        property string title: ""
        property string body: ""

        Layout.fillWidth: true
        Layout.preferredHeight: 126
        radius: Appearance.radL
        color: Colors.fill3

        ColumnLayout {
            anchors.centerIn: parent
            width: Math.min(parent.width - 40, 380)
            spacing: 5
            Text {
                Layout.alignment: Qt.AlignHCenter
                text: empty.icon
                color: Colors.label3
                font.family: Appearance.font
                font.pixelSize: Appearance.fsXL
            }
            Text {
                Layout.fillWidth: true
                text: empty.title
                color: Colors.label
                horizontalAlignment: Text.AlignHCenter
                font.family: Appearance.fontUI
                font.pixelSize: Appearance.fsS
                font.weight: Font.Medium
            }
            Text {
                Layout.fillWidth: true
                text: empty.body
                color: Colors.label2
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.Wrap
                font.family: Appearance.fontUI
                font.pixelSize: Appearance.fsXS
                lineHeight: Appearance.leading(Appearance.fsXS)
                lineHeightMode: Text.FixedHeight
            }
        }
    }
}
