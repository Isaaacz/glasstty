// BarSlot.qml — one place in a bar group (TopShell.qml). A module is moved in
// here by changing its parent; the slot takes the module's width (plus a
// little air) while it is visible, and none when it is hidden or empty.
import QtQuick
import QtQuick.Layouts

Item {
    id: slot
    property int barH: 32
    readonly property Item kid: {
        for (let i = 0; i < slot.children.length; i++) return slot.children[i];
        return null;
    }
    Layout.alignment: Qt.AlignVCenter
    implicitHeight: slot.barH
    implicitWidth: slot.kid && slot.kid.visible ? slot.kid.implicitWidth + 4 : 0
    onKidChanged: if (slot.kid) slot.kid.x = 2
}
