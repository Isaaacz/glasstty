// VSlider.qml — vertical pill slider (brightness) with an icon on top.
import QtQuick

Item {
    id: sl
    property real value: 0             // 0..100
    property string icon: ""
    property color accent: Colors.accent
    signal moved(real v)
    signal iconClicked()

    implicitWidth: 44

    Rectangle {
        id: iconBox
        width: 38; height: 38; radius: 12
        anchors.horizontalCenter: parent.horizontalCenter
        color: Qt.rgba(sl.accent.r, sl.accent.g, sl.accent.b, 0.22)
        Text {
            anchors.centerIn: parent
            text: sl.icon
            color: Colors.label
            font.family: Appearance.font
            font.pixelSize: 16
        }
        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: sl.iconClicked() }
    }

    Rectangle {
        id: track
        anchors.top: iconBox.bottom
        anchors.topMargin: 12
        anchors.bottom: parent.bottom
        anchors.horizontalCenter: parent.horizontalCenter
        width: 8
        radius: 4
        color: Qt.rgba(sl.accent.r, sl.accent.g, sl.accent.b, 0.20)
        Rectangle {
            anchors.left: parent.left; anchors.right: parent.right; anchors.bottom: parent.bottom
            radius: 4
            height: Math.max(width, parent.height * Math.max(0, Math.min(1, sl.value / 100)))
            color: sl.accent
            Behavior on height { NumberAnimation { duration: Appearance.mQuick; easing.type: Easing.OutCubic } }
        }
        // The handle, like the reference: a short bar across the fill's top.
        Rectangle {
            width: 20; height: 4; radius: 2
            anchors.horizontalCenter: parent.horizontalCenter
            y: parent.height * (1 - Math.max(0, Math.min(1, sl.value / 100))) - height / 2
            color: Colors.label
            Behavior on y { NumberAnimation { duration: Appearance.mQuick; easing.type: Easing.OutCubic } }
        }
        MouseArea {
            anchors.fill: parent
            anchors.margins: -12
            cursorShape: Qt.PointingHandCursor
            function setAt(y) { sl.moved(Math.max(0, Math.min(100, 100 * (1 - (y - 12) / track.height)))); }
            onPressed: function (m) { setAt(m.y); }
            onPositionChanged: function (m) { if (pressed) setAt(m.y); }
            onWheel: function (w) { sl.moved(Math.max(0, Math.min(100, sl.value + (w.angleDelta.y > 0 ? 5 : -5)))); }
        }
    }
}
