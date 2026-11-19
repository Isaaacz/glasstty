// MiniCalendar.qml — month grid for the Control Centre (pt_BR).
// Header with the month and arrows, weekday initials, 6×7 days; today is an
// accent circle, days of the neighbouring months are dimmed.
import QtQuick
import QtQuick.Layouts

Rectangle {
    id: cal
    radius: Appearance.radM
    color: Colors.fill3
    border.width: 1
    border.color: Colors.hairline

    property date shown: new Date()
    readonly property var today: ShellState.now
    readonly property var loc: Qt.locale("pt_BR")

    function shift(n) { cal.shown = new Date(cal.shown.getFullYear(), cal.shown.getMonth() + n, 1); }
    readonly property var cells: {
        const y = cal.shown.getFullYear(), m = cal.shown.getMonth();
        const first = new Date(y, m, 1);
        const lead = (first.getDay() + 6) % 7;        // weeks start on Monday
        const out = [];
        for (let i = 0; i < 42; i++) {
            const d = new Date(y, m, 1 - lead + i);
            out.push({ day: d.getDate(), inMonth: d.getMonth() === m,
                       isToday: d.toDateString() === cal.today.toDateString() });
        }
        return out;
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 12
        spacing: 6

        RowLayout {
            Layout.fillWidth: true
            spacing: 6
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 28
                radius: 14
                color: Colors.fill2
                Text {
                    anchors.centerIn: parent
                    text: { const t = cal.loc.toString(cal.shown, "MMMM yyyy"); return t.charAt(0).toUpperCase() + t.slice(1); }
                    color: Colors.label
                    font.family: Appearance.fontUI; font.pixelSize: Appearance.fsS; font.weight: Font.DemiBold
                }
                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: cal.shown = new Date() }
            }
            Repeater {
                model: [{ t: "‹", n: -1 }, { t: "›", n: 1 }]
                Rectangle {
                    required property var modelData
                    width: 28; height: 28; radius: 14
                    color: navMa.containsMouse ? Colors.fill1 : Colors.fill2
                    Text { anchors.centerIn: parent; text: modelData.t; color: Colors.label; font.pixelSize: 18; font.family: Appearance.fontUI }
                    MouseArea { id: navMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: cal.shift(modelData.n) }
                }
            }
        }

        GridLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            columns: 7
            rowSpacing: 0
            columnSpacing: 0
            Repeater {
                model: ["Seg", "Ter", "Qua", "Qui", "Sex", "Sáb", "Dom"]
                Text {
                    required property string modelData
                    Layout.fillWidth: true
                    horizontalAlignment: Text.AlignHCenter
                    text: modelData
                    color: Colors.label3
                    font.family: Appearance.fontUI; font.pixelSize: Appearance.fsXXS; font.weight: Font.DemiBold
                }
            }
            Repeater {
                model: cal.cells
                Item {
                    required property var modelData
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    Rectangle {
                        anchors.centerIn: parent
                        width: 26; height: 26; radius: 13
                        visible: modelData.isToday
                        color: Colors.accent
                    }
                    Text {
                        anchors.centerIn: parent
                        text: modelData.day
                        color: modelData.isToday ? Colors.accentInk : (modelData.inMonth ? Colors.label : Colors.label3)
                        opacity: modelData.inMonth ? 1 : 0.45
                        font.family: Appearance.fontUI; font.pixelSize: Appearance.fsXS
                        font.weight: modelData.isToday ? Font.Bold : Font.Normal
                    }
                }
            }
        }
    }
}
