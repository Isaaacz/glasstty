// GameOverlay.qml — performance over the game, Afterburner style.
//
// A small card in the top-left corner of the focused screen with the game's
// fps (big, plus a minute of history), frame time, CPU and GPU load and
// temperature, and memory. Super+Shift+G (`qs ipc call gamemode overlay`)
// shows / hides it. It sits on the Overlay layer, so it is drawn above a
// fullscreen game, and it takes no input at all: clicks and keys go to the
// game. The numbers are MangoHud's (GameMode.qml); with no game logging, it
// falls back to the system's own CPU and memory.
//
// It also carries GameMode's heat warning, which shows even with the card
// hidden: in fullscreen the notch steps aside, so this is the only place a
// warning can be seen while you play.
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland

Scope {
    id: root

    readonly property bool live: GameMode.gameRunning
    readonly property bool showCard: GameMode.overlayOn
    readonly property bool showHeat: GameMode.heatAlert !== ""

    function tempColor(t) { return t >= 90 ? Colors.crit : t >= 80 ? Colors.warn : Colors.label; }
    function fpsColor(f) { return f > 0 && f < 30 ? Colors.crit : f < 50 ? Colors.warn : Colors.ok; }

    PanelWindow {
        id: win
        screen: {
            const ss = Quickshell.screens;
            for (let i = 0; i < ss.length; i++)
                if (ss[i].name === ShellState.focusedMon) return ss[i];
            return ss.length > 0 ? ss[0] : null;
        }
        visible: root.showCard || root.showHeat
        anchors { top: true; left: true }
        // just under the bar's band, so it never covers the bar, game or not
        margins { top: Config.bandH + 10; left: 14 }
        implicitWidth: 236
        implicitHeight: col.implicitHeight
        exclusionMode: ExclusionMode.Ignore
        color: "transparent"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "quickshell:gameoverlay"
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
        // an empty input region: the mouse passes straight through to the game
        mask: Region {}

        Column {
            id: col
            width: parent.width
            spacing: 8

            // ───── the card ─────
            Rectangle {
                id: card
                visible: root.showCard
                width: parent.width
                height: cardCol.implicitHeight + 22
                radius: 14
                color: Qt.rgba(0, 0, 0, 0.78)
                border.width: 1
                border.color: Qt.rgba(1, 1, 1, 0.08)

                ColumnLayout {
                    id: cardCol
                    anchors { left: parent.left; right: parent.right; top: parent.top; margins: 12 }
                    spacing: 6

                    // game · time played
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 6
                        Text {
                            text: Icons.gamepad
                            color: Colors.accentInk
                            font.family: Appearance.font; font.pixelSize: 12
                        }
                        Text {
                            Layout.fillWidth: true
                            elide: Text.ElideRight
                            text: GameMode.gameName || (root.live ? I18n.tr("Juego") : I18n.tr("Sistema"))
                            color: Colors.label2
                            font.family: Appearance.fontUI; font.pixelSize: Appearance.fsXXS; font.weight: Font.Medium
                        }
                        Text {
                            visible: GameMode.sessionLive
                            text: GameMode.duration(Math.floor((clock.now - GameMode.sessionStart) / 60000))
                            color: Colors.label3
                            font.family: Appearance.fontUI; font.pixelSize: Appearance.fsXXS
                            font.features: ({ "tnum": 1 })
                        }
                    }

                    // fps, big, with the last minute drawn behind it
                    Item {
                        visible: root.live
                        Layout.fillWidth: true
                        Layout.preferredHeight: 46
                        Canvas {
                            id: spark
                            anchors.fill: parent
                            opacity: 0.55
                            readonly property var data: GameMode.fpsHistory
                            onDataChanged: requestPaint()
                            onPaint: {
                                const ctx = getContext("2d");
                                ctx.reset();
                                const d = spark.data;
                                if (d.length < 2) return;
                                const top = Math.max(60, Math.max.apply(null, d));
                                ctx.beginPath();
                                for (let i = 0; i < d.length; i++) {
                                    const x = width * i / 59 + (60 - d.length) * width / 59;
                                    const y = height - 3 - (height - 6) * d[i] / top;
                                    if (i === 0) ctx.moveTo(x, y); else ctx.lineTo(x, y);
                                }
                                ctx.strokeStyle = Colors.accent;
                                ctx.lineWidth = 1.5;
                                ctx.stroke();
                            }
                        }
                        Row {
                            anchors { left: parent.left; verticalCenter: parent.verticalCenter }
                            spacing: 6
                            Text {
                                text: GameMode.gameFps
                                color: root.fpsColor(GameMode.gameFps)
                                font.family: Appearance.fontUI; font.pixelSize: 32; font.weight: Font.Bold
                                font.features: ({ "tnum": 1 })
                            }
                            Column {
                                anchors.verticalCenter: parent.verticalCenter
                                Text {
                                    text: "fps"
                                    color: Colors.label2
                                    font.family: Appearance.fontUI; font.pixelSize: Appearance.fsXS; font.weight: Font.DemiBold
                                }
                                Text {
                                    text: GameMode.gameFrametime.toFixed(1) + " ms"
                                    color: Colors.label3
                                    font.family: Appearance.fontUI; font.pixelSize: Appearance.fsXXS
                                    font.features: ({ "tnum": 1 })
                                }
                            }
                        }
                    }

                    // CPU / GPU / RAM rows
                    component Stat: RowLayout {
                        property string name: ""
                        property string load: ""
                        property int temp: 0
                        Layout.fillWidth: true
                        spacing: 8
                        Text {
                            Layout.preferredWidth: 34
                            text: parent.name
                            color: Colors.label3
                            font.family: Appearance.fontUI; font.pixelSize: Appearance.fsXS; font.weight: Font.DemiBold
                        }
                        Text {
                            Layout.fillWidth: true
                            text: parent.load
                            color: Colors.label
                            font.family: Appearance.fontUI; font.pixelSize: Appearance.fsS
                            font.features: ({ "tnum": 1 })
                        }
                        Text {
                            visible: parent.temp > 0
                            text: parent.temp + "°"
                            color: root.tempColor(parent.temp)
                            font.family: Appearance.fontUI; font.pixelSize: Appearance.fsS; font.weight: Font.DemiBold
                            font.features: ({ "tnum": 1 })
                        }
                    }
                    Stat {
                        name: "CPU"
                        load: (root.live ? GameMode.gameCpu : SystemStats.cpu) + "%"
                        temp: root.live ? GameMode.gameCpuTemp : 0
                    }
                    Stat {
                        visible: root.live
                        name: "GPU"
                        load: GameMode.gameGpu + "%" + (GameMode.gameVram > 0 ? "  ·  " + GameMode.gameVram.toFixed(1) + " GB" : "")
                        temp: GameMode.gameGpuTemp
                    }
                    Stat {
                        name: "RAM"
                        load: {
                            const used = root.live && GameMode.gameRam > 0 ? GameMode.gameRam : SystemStats.memUsedKib / 1048576;
                            const total = SystemStats.memTotalKib / 1048576;
                            return used.toFixed(1) + (total > 0 ? " / " + total.toFixed(1) : "") + " GB";
                        }
                    }
                }
            }

            // ───── running hot ─────
            Rectangle {
                visible: root.showHeat
                width: heatRow.implicitWidth + 24
                height: 34
                radius: 17
                color: Qt.rgba(Colors.crit.r, Colors.crit.g, Colors.crit.b, 0.85)
                Row {
                    id: heatRow
                    anchors.centerIn: parent
                    spacing: 8
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "󰈸"
                        color: "white"
                        font.family: Appearance.font; font.pixelSize: 15
                    }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: GameMode.heatAlert
                        color: "white"
                        font.family: Appearance.fontUI; font.pixelSize: Appearance.fsS; font.weight: Font.DemiBold
                    }
                }
            }
        }
    }

    // the minutes played tick by themselves
    QtObject {
        id: clock
        property real now: Date.now()
    }
    Timer {
        interval: 15000
        repeat: true
        running: root.showCard && GameMode.sessionLive
        triggeredOnStart: true
        onTriggered: clock.now = Date.now()
    }
}
