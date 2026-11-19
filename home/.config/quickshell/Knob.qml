// Knob.qml — a round dial for a 0..100 value (volume, microphone).
//
// A 270° arc shows the level around an icon. Wheel or vertical drag changes
// it; a click (without dragging) fires `clicked` (mute). Muted = dimmed arc.
import QtQuick

Item {
    id: knob
    property real value: 0             // 0..100
    property bool muted: false
    property string icon: ""
    property color accent: Colors.accent
    property bool active: false        // drives the rail's vertical slider
    signal moved(real v)
    signal clicked()

    implicitWidth: 52
    implicitHeight: 52

    Rectangle {
        anchors.fill: parent
        radius: width / 2
        color: knob.active ? Qt.rgba(knob.accent.r, knob.accent.g, knob.accent.b, 0.22)
             : (ma.containsMouse ? Colors.fill2 : Colors.fill3)
        border.width: knob.active ? 1.5 : 1
        border.color: knob.active ? knob.accent : Colors.hairline
        Behavior on color { ColorAnimation { duration: Appearance.mQuick } }
    }

    Canvas {
        id: arc
        anchors.fill: parent
        anchors.margins: 5
        property real v: knob.muted ? 0 : knob.value
        Behavior on v { NumberAnimation { duration: Appearance.mQuick; easing.type: Easing.OutCubic } }
        onVChanged: requestPaint()
        Connections { target: knob; function onAccentChanged() { arc.requestPaint(); } function onMutedChanged() { arc.requestPaint(); } }
        onPaint: {
            const ctx = getContext("2d");
            ctx.reset();
            const cx = width / 2, cy = height / 2, r = Math.min(width, height) / 2 - 3;
            const a0 = Math.PI * 0.75, sweep = Math.PI * 1.5;
            ctx.lineCap = "round";
            ctx.lineWidth = 3.5;
            ctx.strokeStyle = Qt.rgba(knob.accent.r, knob.accent.g, knob.accent.b, 0.20);
            ctx.beginPath(); ctx.arc(cx, cy, r, a0, a0 + sweep); ctx.stroke();
            const f = Math.max(0, Math.min(1, arc.v / 100));
            if (f > 0.005) {
                ctx.strokeStyle = knob.accent;
                ctx.beginPath(); ctx.arc(cx, cy, r, a0, a0 + sweep * f); ctx.stroke();
            }
        }
    }

    Text {
        anchors.centerIn: parent
        text: knob.icon
        color: knob.muted ? Colors.label3 : Colors.label
        font.family: Appearance.font
        font.pixelSize: 17
    }

    MouseArea {
        id: ma
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        property real y0: 0
        property real v0: 0
        property bool dragged: false
        onPressed: function (m) { y0 = m.y; v0 = knob.value; dragged = false; }
        onPositionChanged: function (m) {
            if (!pressed) return;
            const dy = y0 - m.y;
            if (Math.abs(dy) > 3) dragged = true;
            if (dragged) knob.moved(Math.max(0, Math.min(100, v0 + dy * 0.8)));
        }
        onReleased: if (!dragged) knob.clicked()
        onWheel: function (w) {
            const step = (w.angleDelta.y > 0 ? 5 : -5);
            knob.moved(Math.max(0, Math.min(100, knob.value + step)));
        }
    }
}
