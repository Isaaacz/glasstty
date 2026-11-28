// NotchContent.qml — what you see INSIDE the notch, depending on the mode.
// It receives the notch's full rectangle (bar strip + bulge); each mode is a
// layer that appears/disappears with opacity, so the morph is done by
// TopShell's shape and the content only cross-fades.
import Quickshell
import QtQuick
import QtQuick.Layouts

Item {
    id: root
    property int barH: 32

    // Overridable ON PURPOSE: TopShell passes it the idle face on the screens
    // that do not have focus. By default, whatever ShellState says.
    property string mode: ShellState.mode

    // ─────────────── idle / media ───────────────
    // Fixed two-pole structure, so nothing jumps when the state changes:
    //   LEFT (always): the clock.
    //   RIGHT (contextual): battery at rest, cover art + peaks with music.
    // The battery is HERE and only here: it left the bar to avoid repeating it.
    NotchLayer {
        anchors.fill: parent
        active: root.mode === "media" || root.mode === "idle"

        // ---- time (+ date if enabled) ----
        // Centred: at rest there is only one piece of data, so anchoring it to
        // a side would leave the notch lopsided. With music it moves left to
        // make room for the cover art and the peaks.
        Row {
            anchors {
                horizontalCenter: parent.horizontalCenter
                horizontalCenterOffset: ShellState.mediaLive ? -52 : 0
                verticalCenter: parent.verticalCenter
            }
            Behavior on anchors.horizontalCenterOffset {
                NumberAnimation { duration: Appearance.mInScale; easing.type: Easing.OutBack; easing.overshoot: Appearance.mInOvershoot }
            }
            spacing: 11

            Row {
                anchors.verticalCenter: parent.verticalCenter
                spacing: 0

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.verticalCenterOffset: Appearance.clockNudge(Config.clockSize)
                    text: Qt.formatDateTime(ShellState.now, "HH:mm")
                    color: Colors.label
                    font.family: Appearance.fontClock
                    font.pixelSize: Appearance.clockPixelSize(Config.clockSize)
                    font.weight: Font.DemiBold
                    font.features: ({ "tnum": 1 })   // fixed-width digits: no jitter when the minute changes

                }
            }

            Column {
                anchors.verticalCenter: parent.verticalCenter
                // fade instead of popping in/out abruptly when music starts
                opacity: (Config.showDate && !ShellState.mediaLive) ? 1 : 0
                visible: opacity > 0.01
                Behavior on opacity { NumberAnimation { duration: Appearance.mIn; easing.type: Easing.OutCubic } }
                spacing: 0
                Text {
                    height: 12
                    verticalAlignment: Text.AlignVCenter
                    text: Media.capitalize(ShellState.now.toLocaleDateString(ShellState.loc, "dddd"))
                    color: Colors.label
                    font.family: Appearance.fontUI
                    font.pixelSize: Appearance.fsXXS
                    font.weight: Font.Medium
                }
                Text {
                    height: 12
                    verticalAlignment: Text.AlignVCenter
                    text: ShellState.now.toLocaleDateString(ShellState.loc, I18n.tr("d 'de' MMMM"))
                    color: Colors.label2
                    font.family: Appearance.fontUI
                    font.pixelSize: Appearance.fsXXS
                }
            }
        }

        // ---- right pole at rest: battery ----
        Row {
            anchors { right: parent.right; rightMargin: 15; verticalCenter: parent.verticalCenter }
            spacing: 6
            opacity: (Config.showBattery && !ShellState.mediaLive && SystemStats.batt >= 0) ? 1 : 0
            visible: opacity > 0.01
            Behavior on opacity { NumberAnimation { duration: Appearance.mIn; easing.type: Easing.OutCubic } }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: SystemStats.battIcon
                color: SystemStats.ac ? Colors.ok
                    : SystemStats.batt < 15 ? Colors.crit
                    : SystemStats.batt < 30 ? Colors.warn : Colors.label
                font.family: Appearance.font; font.pixelSize: Appearance.fsM
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: SystemStats.batt + "%"
                color: SystemStats.ac ? Colors.ok
                    : SystemStats.batt < 15 ? Colors.crit
                    : SystemStats.batt < 30 ? Colors.warn : Colors.label
                font.family: Appearance.fontUI
                font.pixelSize: Appearance.fsXS
                font.weight: Font.Medium
                font.features: ({ "tnum": 1 })   // the % must not change width as the charge drops
            }
        }

        // ---- right pole with music: cover art + peaks ----
        Row {
            anchors { right: parent.right; rightMargin: 12; verticalCenter: parent.verticalCenter }
            spacing: 9
            opacity: ShellState.mediaLive ? 1 : 0
            visible: opacity > 0.01
            Behavior on opacity { NumberAnimation { duration: Appearance.mIn; easing.type: Easing.OutCubic } }

            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: 22; height: 22; radius: 7
                color: Colors.fill3
                clip: true
                Image {
                    anchors.fill: parent
                    source: (Media.player && Media.player.trackArtUrl) ? Media.player.trackArtUrl : ""
                    fillMode: Image.PreserveAspectCrop
                    // Without sourceSize the cover art is decoded at its native
                    // resolution (600-1000 px) to paint 22-34 px; 64 is plenty.
                    sourceSize.width: 64
                    visible: status === Image.Ready
                }
                Text {
                    anchors.centerIn: parent
                    visible: !(Media.player && Media.player.trackArtUrl)
                    text: Icons.play; color: Media.mediaAccent
                    font.family: Appearance.font; font.pixelSize: Appearance.fsXS
                    Behavior on color { ColorAnimation { duration: Appearance.mIn; easing.type: Easing.OutCubic } }
                }
            }

            // THE BARS' BOX IS FIXED, not a Row that sizes itself.
            //
            // With a Row, the Row's height is that of its tallest child, and
            // each bar was centred on that Row. In other words: every time the
            // tallest bar changed, the box changed, and with it the vertical
            // position of ALL EIGHT at once. A kick drum hit moved the whole
            // strip, not just its bar — the collective tremor you could see on
            // top of each bar's own movement.
            //
            // Here the box is 18 px no matter what, and each bar lives in its
            // slot: 4 wide + 4 gap = 8 px pitch. One bar cannot move its
            // neighbours.
            Item {
                anchors.verticalCenter: parent.verticalCenter
                width: AudioSpectrum.bands * 8 - 4
                height: 18

                Repeater {
                    // One bar per cava band: bass on the left, treble on the
                    // right. No Behavior, and it has been tested that this is
                    // right: the motion is already carried by ShellState's
                    // per-frame follower; an animation here restarts with
                    // every sample, never finishes, and only adds judder.
                    model: AudioSpectrum.bands
                    Rectangle {
                        required property int index
                        x: index * 8
                        width: 4; radius: 2
                        color: Media.mediaAccent
                        Behavior on color { ColorAnimation { duration: Appearance.mIn; easing.type: Easing.OutCubic } }

                        // CONTINUOUS HEIGHT, WITH DECIMALS. There was once a
                        // rounding to whole pixels here with 0.7 px hysteresis,
                        // and it was exactly what kept this from being smooth:
                        // over a travel of only 14 px (4→18) that leaves fifteen
                        // possible heights, so the bar stayed STILL and then
                        // JUMPED 7% of its travel all at once. On top of that,
                        // being centred, each jump flipped the parity of the
                        // height and with it the subpixel split of the rounded
                        // caps: the bar alternated between sharp and blurry on
                        // every step. That is literally the flicker.
                        //
                        // (It is measured and noted in scripts/cava.conf:
                        // quantising left the visualiser MORE static, 2.6 px/s
                        // against 4.4. The rounding crept in after that test.)
                        //
                        // A Rectangle with radius is drawn antialiased, so it
                        // can paint half a pixel: the edge is split across two
                        // rows. That is NOT flicker, it is exactly the
                        // mechanism by which a screen shows motion finer than
                        // its own grid. What flickered was the step, not the
                        // decimal.
                        antialiasing: true
                        // The floor is the width: at rest each bar is a round
                        // dot, not a squashed pill.
                        height: Math.max(4, 18 * (AudioSpectrum.levels[index] || 0))
                        // It grows both ways from the centre of the box, which
                        // is a constant: the reference never moves.
                        y: (18 - height) / 2
                    }
                }
            }
        }
    }

    // ─────────────── peek (hover): the idle clock, in more detail ───────────────
    // Same centred row as in idle, but the date is written out in full and the
    // battery is added: on hover, the clock "unfolds".
    NotchLayer {
        anchors.fill: parent
        active: root.mode === "peek"

        // Centred just as at rest: on hover the group grows and re-centres,
        // instead of jumping from one anchor to another.
        Row {
            anchors {
                horizontalCenter: parent.horizontalCenter
                horizontalCenterOffset: -26
                verticalCenter: parent.verticalCenter
            }
            spacing: 13

            // THE PEEK CLOCK FOLLOWS THE SETTING, NOT THE OTHER WAY ROUND.
            //
            // It was pinned at 21 while the idle one uses Config.clockSize,
            // which is 17 by default. So the peek was 4 px bigger, and that is
            // fine -- what was wrong is that it was a fixed number: if you
            // raise the clock size in Settings above 21, on hover it SHRINKS,
            // which is exactly the opposite of what a peek does.
            // Now the +4 step holds whatever the size is.
            readonly property int pxPeek: Config.clockSize + 4

            Text {
                anchors.verticalCenter: parent.verticalCenter
                anchors.verticalCenterOffset: Appearance.clockNudge(parent.pxPeek)
                text: Qt.formatDateTime(ShellState.now, "HH:mm")
                color: Colors.label
                font.family: Appearance.fontClock
                font.pixelSize: Appearance.clockPixelSize(parent.pxPeek)
                font.weight: Font.DemiBold
                font.features: ({ "tnum": 1 })
            }

            Column {
                anchors.verticalCenter: parent.verticalCenter
                spacing: 0
                Text {
                    height: 14
                    verticalAlignment: Text.AlignVCenter
                    text: Media.capitalize(ShellState.now.toLocaleDateString(ShellState.loc, "dddd"))
                    color: Colors.label
                    font.family: Appearance.fontUI
                    font.pixelSize: Appearance.fsXS
                    font.weight: Font.Medium
                }
                Text {
                    height: 14
                    verticalAlignment: Text.AlignVCenter
                    text: ShellState.now.toLocaleDateString(ShellState.loc, I18n.tr("d 'de' MMMM 'de' yyyy"))
                    color: Colors.label2
                    font.family: Appearance.fontUI
                    font.pixelSize: Appearance.fsXS
                }
            }
        }

        Row {
            anchors { right: parent.right; rightMargin: 15; verticalCenter: parent.verticalCenter }
            spacing: 6
            visible: SystemStats.batt >= 0
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: SystemStats.battIcon
                color: SystemStats.ac ? Colors.ok
                    : SystemStats.batt < 15 ? Colors.crit
                    : SystemStats.batt < 30 ? Colors.warn : Colors.label
                font.family: Appearance.font; font.pixelSize: Appearance.fsL
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: SystemStats.batt + "%"
                color: SystemStats.ac ? Colors.ok
                    : SystemStats.batt < 15 ? Colors.crit
                    : SystemStats.batt < 30 ? Colors.warn : Colors.label
                font.family: Appearance.fontUI
                font.pixelSize: Appearance.fsS
                font.weight: Font.Medium
                font.features: ({ "tnum": 1 })
            }
        }
    }

    // ─────────────── activity: volume / brightness OSD ───────────────
    NotchLayer {
        id: osd
        anchors.fill: parent
        active: root.mode === "activity"

        readonly property bool isVol: ShellState.activity === "volume"
        // THE LEVEL IS NOT FAKED: THE ICON ALREADY SAYS IT IS MUTED.
        //
        // This was `muted ? 0 : vol`, and raising the volume does NOT unmute
        // (hyprland.lua:627 and :629 are different keys). So with the sound
        // muted you pressed up, the OSD showed 0%, you pressed again, 0%, and
        // on unmuting you got slapped at 140%. The mute icon was already right
        // here below, so this notice never lied about the mute: it lied about
        // the LEVEL, which is the only thing there is to show. It is what
        // impasto's OsdService.qml:51-58 documents.
        //
        // In the sliders (SettingsAudio.qml:123, ControlPanel.qml:50) the
        // `muted ? 0 : vol` stays, and rightly so: moving them calls
        // setVolume(), which unmutes. Here there is nothing to move.
        readonly property int value: isVol ? Audio.vol : Math.max(0, Brightness.bright)
        readonly property bool callado: isVol && Audio.muted
        // same reason: the notch widens on entering OSD mode, so the track
        // grows; animating the width would make the bar lag behind
        property real shown: osd.value
        Behavior on shown { NumberAnimation { duration: Appearance.mQuick; easing.type: Easing.OutCubic } }

        RowLayout {
            anchors { fill: parent; leftMargin: 20; rightMargin: 20 }
            spacing: 12

            Text {
                text: osd.isVol
                    ? (Audio.muted ? Icons.volMute
                        : Audio.vol > 55 ? Icons.volHigh
                        : Audio.vol > 20 ? Icons.volMed : Icons.volLow)
                    : Icons.brightness
                color: Colors.label
                font.family: Appearance.font; font.pixelSize: Appearance.fsL
            }
            Rectangle {
                id: osdTrack
                Layout.fillWidth: true
                Layout.preferredHeight: 5
                radius: 3
                color: Colors.fill3
                Rectangle {
                    width: osdTrack.width * Math.max(0, Math.min(1, osd.shown / 100))
                    height: parent.height; radius: parent.radius
                    color: osd.isVol ? Colors.accent : Colors.warn
                    // Now that the bar tells the real level, you need to tell
                    // "playing at 40" apart from "at 40 but muted". The icon
                    // says it; this repeats it without hiding the value.
                    opacity: osd.callado ? 0.35 : 1
                    Behavior on opacity { NumberAnimation { duration: Appearance.mQuick } }
                }
            }
            Text {
                text: Math.round(osd.shown) + "%"
                // label4 is the level reserved for what is unavailable, and with
                // the sound muted the level is exactly that: there, but silent.
                color: osd.callado ? Colors.label4 : Colors.label
                Behavior on color { ColorAnimation { duration: Appearance.mQuick } }
                Layout.preferredWidth: 34
                horizontalAlignment: Text.AlignRight
                font.family: Appearance.font; font.pixelSize: Appearance.fsXS
            }
        }
    }

    // ─────────────── ws: the workspace you just jumped to ───────────────
    // It only shows with the horizontal-wheel GESTURE over the notch, never with
    // Super+1..0. Not an omission: with the shortcut you know where you are going
    // because you just typed the number, and the bar indicator is right beside
    // it. With the wheel there is no number to type and you are looking at the
    // notch, so it is the only case where the gesture needs an acknowledgement.
    NotchLayer {
        anchors.fill: parent
        active: root.mode === "ws"

        Row {
            anchors.centerIn: parent
            spacing: 11

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: I18n.tr("Escritorio")
                color: Colors.label3
                font.family: Appearance.fontUI
                font.pixelSize: Appearance.fsS
                font.weight: Font.Medium
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: String(ShellState.activeWs)
                color: Colors.accentInk
                font.family: Appearance.fontUI
                font.pixelSize: 20
                font.weight: Font.DemiBold
                font.features: ({ "tnum": 1 })   // from 9 to 10 the group must not shift
            }
        }
    }

    // ─────────────── charge: you have plugged in or unplugged ───────────────
    // The only notch notice you do NOT trigger. The rest (OSD, peek, panels)
    // appear because you just did something; this one because something just
    // happened, so it lingers a little longer than an OSD: you were not looking.
    NotchLayer {
        id: chargeLayer
        anchors.fill: parent
        active: root.mode === "charge"

        readonly property color tone: SystemStats.ac ? Colors.ok
            : SystemStats.batt < 15 ? Colors.crit
            : SystemStats.batt < 30 ? Colors.warn : Colors.label

        Row {
            anchors.centerIn: parent
            spacing: 12

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: SystemStats.battIcon
                color: chargeLayer.tone
                font.family: Appearance.font
                font.pixelSize: 21
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                // "Con batería" (On battery) and not "Desenchufado" (Unplugged):
                // what matters is not that a cable came out, but what you run on.
                text: SystemStats.ac ? I18n.tr("Cargando") : I18n.tr("Con batería")
                color: Colors.label
                font.family: Appearance.fontUI
                font.pixelSize: Appearance.fsM
                font.weight: Font.Medium
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                visible: SystemStats.batt >= 0
                text: I18n.tr("{0} %", SystemStats.batt)
                color: chargeLayer.tone
                font.family: Appearance.fontUI
                font.pixelSize: 15
                font.weight: Font.DemiBold
                font.features: ({ "tnum": 1 })
            }
        }
    }

    // ─────────────── device: something plugged in or out ───────────────
    // USB or Bluetooth (Devices.qml). Like the charge face it is something
    // that happened, not something you did, so it lingers a little.
    NotchLayer {
        id: deviceLayer
        anchors.fill: parent
        active: root.mode === "device"

        readonly property var d: Devices.last
        readonly property bool on: deviceLayer.d ? deviceLayer.d.plugged : false
        readonly property var dev: deviceLayer.d ? deviceLayer.d.dev : null
        readonly property int pct: deviceLayer.dev && deviceLayer.dev.batteryAvailable
            ? Math.round(deviceLayer.dev.battery * 100) : -1

        RowLayout {
            anchors { fill: parent; leftMargin: 18; rightMargin: 18 }
            spacing: 11

            Rectangle {
                Layout.preferredWidth: 28
                Layout.preferredHeight: 28
                radius: 14
                color: deviceLayer.on ? Qt.rgba(Colors.ok.r, Colors.ok.g, Colors.ok.b, 0.20) : Colors.fill2
                Text {
                    anchors.centerIn: parent
                    text: deviceLayer.d ? deviceLayer.d.icon : ""
                    color: deviceLayer.on ? Colors.ok : Colors.label3
                    font.family: Appearance.font
                    font.pixelSize: 16
                }
            }
            Text {
                Layout.fillWidth: true
                elide: Text.ElideRight
                text: deviceLayer.d ? deviceLayer.d.name : ""
                color: Colors.label
                font.family: Appearance.fontUI
                font.pixelSize: Appearance.fsM
                font.weight: Font.Medium
            }
            Text {
                text: deviceLayer.pct >= 0 && deviceLayer.on ? I18n.tr("{0} %", deviceLayer.pct)
                    : deviceLayer.on ? I18n.tr("Conectado") : I18n.tr("Desconectado")
                color: deviceLayer.on ? (deviceLayer.pct >= 0 && deviceLayer.pct <= 15 ? Colors.crit : Colors.ok) : Colors.label3
                font.family: Appearance.fontUI
                font.pixelSize: Appearance.fsS
                font.weight: Font.DemiBold
                font.features: ({ "tnum": 1 })
            }
        }
    }

    // ─────────────── btpair: pairing a device ───────────────
    // The only face that comes out in front of an open panel, because on the
    // other end there is a device with a timer running. Two forms:
    //   · "display"  -> BlueZ gives us the code and YOU type it on the keyboard.
    //                   There is nothing to answer, only something to read.
    //   · the rest   -> you have to say yes or no, and there are two buttons.
    NotchLayer {
        id: btLayer
        anchors.fill: parent
        active: root.mode === "btpair"

        readonly property bool ask: BluetoothPairing.btKind !== "display"

        ColumnLayout {
            anchors { fill: parent; leftMargin: 16; rightMargin: 16; topMargin: 8; bottomMargin: 10 }
            spacing: 6

            RowLayout {
                Layout.fillWidth: true
                spacing: 12

                Text {
                    text: BluetoothPairing.btKind === "display" ? Icons.keyboard : Icons.btPair
                    color: Colors.accentInk
                    font.family: Appearance.font
                    font.pixelSize: Appearance.fsXL
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 0
                    Text {
                        Layout.fillWidth: true
                        text: BluetoothPairing.btName.length > 0 ? BluetoothPairing.btName : I18n.tr("Aparato desconocido")
                        color: Colors.label
                        elide: Text.ElideRight
                        font.family: Appearance.fontUI
                        font.pixelSize: 14
                        font.weight: Font.DemiBold
                    }
                    Text {
                        Layout.fillWidth: true
                        text: BluetoothPairing.btKind === "display"
                                ? I18n.tr("Teclea este código y pulsa Enter")
                                : BluetoothPairing.btKind === "authorize"
                                    ? I18n.tr("Quiere emparejarse con este equipo")
                                    : I18n.tr("¿Sale este mismo código en el aparato?")
                        color: Colors.label2
                        elide: Text.ElideRight
                        font.family: Appearance.fontUI
                        font.pixelSize: Appearance.fsXS
                    }
                }

                // The code, in large digits: it is what you compare at a glance
                // with what the device shows. tnum so it does not jitter as you
                // type.
                Text {
                    visible: BluetoothPairing.btCode.length > 0
                    text: BluetoothPairing.btCode
                    color: Colors.label
                    font.family: Appearance.fontUI
                    font.pixelSize: Appearance.fsXL
                    font.weight: Font.DemiBold
                    font.letterSpacing: 2
                    font.features: ({ "tnum": 1 })
                }
            }

            // Typing progress: BlueZ keeps reporting how many digits you have
            // typed. It is the only sign the keyboard is talking to the machine.
            Rectangle {
                visible: BluetoothPairing.btKind === "display" && BluetoothPairing.btEntered >= 0
                Layout.fillWidth: true
                Layout.preferredHeight: 3
                radius: 2
                color: Colors.fill3
                Rectangle {
                    // The fraction, not the width: the rail stretches with the
                    // notch as it opens, and animating the width makes the code
                    // progress seem to advance by itself. See MediaPanel.
                    property real p: Math.min(1, BluetoothPairing.btEntered
                            / Math.max(1, BluetoothPairing.btCode.length))
                    Behavior on p { NumberAnimation { duration: Appearance.mQuick; easing.type: Easing.OutQuad } }

                    height: parent.height
                    radius: parent.radius
                    color: Colors.accent
                    width: parent.width * p
                }
            }

            RowLayout {
                visible: btLayer.ask
                Layout.fillWidth: true
                Layout.topMargin: 2
                spacing: 8

                Item { Layout.fillWidth: true }

                Repeater {
                    model: [
                        { txt: I18n.tr("No"), ico: Icons.no, ok: false },
                        { txt: I18n.tr("Sí"), ico: Icons.yes, ok: true }
                    ]
                    delegate: Rectangle {
                        required property var modelData
                        implicitWidth: btBtnRow.implicitWidth + 26
                        implicitHeight: 30
                        radius: 15
                        color: modelData.ok
                            ? (btBtnMa.containsMouse ? Qt.rgba(Colors.accent.r, Colors.accent.g, Colors.accent.b, 0.34)
                                                     : Qt.rgba(Colors.accent.r, Colors.accent.g, Colors.accent.b, 0.20))
                            : (btBtnMa.containsMouse ? Colors.fill2 : Colors.fill3)
                        Behavior on color { ColorAnimation { duration: Appearance.mQuick; easing.type: Easing.OutQuad } }

                        RowLayout {
                            id: btBtnRow
                            anchors.centerIn: parent
                            spacing: 7
                            Text {
                                text: modelData.ico
                                color: modelData.ok ? Colors.accentInk : Colors.label2
                                font.family: Appearance.font
                                font.pixelSize: Appearance.fsM
                            }
                            Text {
                                text: modelData.txt
                                color: modelData.ok ? Colors.label : Colors.label2
                                font.family: Appearance.fontUI
                                font.pixelSize: Appearance.fsS
                                font.weight: Font.Medium
                            }
                        }

                        MouseArea {
                            id: btBtnMa
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: BluetoothPairing.btReply(modelData.ok)
                        }
                    }
                }
            }
        }
    }

    // ─────────────── track: "now playing" ───────────────
    NotchLayer {
        anchors.fill: parent
        active: root.mode === "track"

        RowLayout {
            anchors { fill: parent; leftMargin: 12; rightMargin: 14 }
            spacing: 10

            Rectangle {
                Layout.preferredWidth: 34; Layout.preferredHeight: 34
                Layout.alignment: Qt.AlignVCenter
                radius: 9
                color: Colors.fill3
                clip: true
                Image {
                    anchors.fill: parent
                    source: (Media.player && Media.player.trackArtUrl) ? Media.player.trackArtUrl : ""
                    fillMode: Image.PreserveAspectCrop
                    // Without sourceSize the cover art is decoded at its native
                    // resolution (600-1000 px) to paint 22-34 px; 64 is plenty.
                    sourceSize.width: 64
                    visible: status === Image.Ready
                }
                Text {
                    anchors.centerIn: parent
                    visible: !(Media.player && Media.player.trackArtUrl)
                    text: "󰎈"; color: Media.mediaAccent
                    font.family: Appearance.font; font.pixelSize: Appearance.fsL
                    Behavior on color { ColorAnimation { duration: Appearance.mIn; easing.type: Easing.OutCubic } }
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignVCenter
                spacing: 1
                Text {
                    Layout.fillWidth: true
                    text: Media.player ? (Media.player.trackTitle || "") : ""
                    color: Colors.label; elide: Text.ElideRight
                    font.family: Appearance.font; font.pixelSize: Appearance.fsXS; font.bold: true
                }
                Text {
                    Layout.fillWidth: true
                    text: Media.player ? (Media.player.trackArtist || "") : ""
                    color: Colors.label2; elide: Text.ElideRight
                    font.family: Appearance.font; font.pixelSize: Appearance.fsXXS
                }
            }

            // Same fixed box and same continuous height as in the right pole
            // (see the why there), here over 22 px of height. It uses implicit*
            // because the parent is a RowLayout: the layout is what hands out
            // space, and what we tell it is how much we ask for, not our size.
            Item {
                Layout.alignment: Qt.AlignVCenter
                implicitWidth: AudioSpectrum.bands * 8 - 4
                implicitHeight: 22

                Repeater {
                    model: AudioSpectrum.bands
                    Rectangle {
                        required property int index
                        x: index * 8
                        width: 4; radius: 2
                        color: Media.mediaAccent
                        Behavior on color { ColorAnimation { duration: Appearance.mIn; easing.type: Easing.OutCubic } }
                        antialiasing: true
                        height: Math.max(4, 22 * (AudioSpectrum.levels[index] || 0))
                        y: (22 - height) / 2
                    }
                }
            }
        }
    }

    // ─────────────── notif: pop-up notice ───────────────
    // When a notification arrives the notch stretches and shows it for a few
    // seconds, like a live activity. Then it stays in the Control Centre.
    NotchLayer {
        id: notifLayer
        anchors.fill: parent
        active: root.mode === "notif"

        readonly property var n: NotificationCenter.lastNotif
        // drip-style cards from ~/.local/bin/notch: a coloured mark per kind
        // and the actions as buttons (see NotificationCenter.notifKind).
        readonly property string kind: NotificationCenter.notifKind(n)
        readonly property var buttons: kind !== "" ? NotificationCenter.notifButtons(n) : []
        readonly property color kindColor: kind === "ok" ? "#4ade80" : kind === "warn" ? "#fbbf24"
            : kind === "fail" ? "#f87171" : Colors.accent

        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            // If the notice carries actions, clicking it DOES THAT instead of
            // opening the Control Centre: it is what anyone expects from a
            // notice with something to do behind it. The screenshot sends an
            // "Editar" (Edit) action that opens the picture in satty
            // (~/.config/glasstty/scripts/notify-shot.sh); the other notices, which
            // carry none, still open the Control Centre as before.
            onClicked: {
                const n = notifLayer.n;
                const acts = n ? n.actions : null;
                // A card's click is its "default" action; its other actions
                // are the buttons, so a click on the card never answers them.
                if (notifLayer.kind !== "") {
                    const d = acts ? acts.find(a => a.identifier === "default") : null;
                    if (d) { ShellState.activity = ""; d.invoke(); }
                    else if (notifLayer.buttons.length === 0) { ShellState.activity = ""; ShellState.togglePanel("control"); }
                    return;
                }
                ShellState.activity = "";
                if (acts && acts.length > 0) acts[0].invoke();
                else ShellState.togglePanel("control");
            }
        }

        RowLayout {
            anchors { fill: parent; leftMargin: 13; rightMargin: 15 }
            spacing: 11

            Rectangle {
                visible: notifLayer.kind !== ""
                Layout.preferredWidth: 34; Layout.preferredHeight: 34
                Layout.alignment: Qt.AlignVCenter
                radius: 17
                color: Qt.rgba(notifLayer.kindColor.r, notifLayer.kindColor.g, notifLayer.kindColor.b, 0.18)
                border.width: 1
                border.color: Qt.rgba(notifLayer.kindColor.r, notifLayer.kindColor.g, notifLayer.kindColor.b, 0.45)
                Text {
                    anchors.centerIn: parent
                    text: notifLayer.kind === "ok" ? "󰄬" : notifLayer.kind === "warn" ? "󰀦"
                        : notifLayer.kind === "fail" ? "󰅖" : "󰋽"
                    color: notifLayer.kindColor
                    font.family: Appearance.font; font.pixelSize: 18
                }
            }
            Image {
                visible: notifLayer.kind === ""
                Layout.preferredWidth: 34; Layout.preferredHeight: 34
                Layout.alignment: Qt.AlignVCenter
                source: {
                    const n = notifLayer.n;
                    if (!n) return "";
                    return (n.image && n.image.length > 0) ? n.image
                        : Quickshell.iconPath(n.appIcon, "dialog-information");
                }
                sourceSize.width: 34; sourceSize.height: 34
                fillMode: Image.PreserveAspectFit
            }

            ColumnLayout {
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignVCenter
                spacing: 1
                Text {
                    Layout.fillWidth: true
                    text: notifLayer.n ? NotificationCenter.tn(notifLayer.n.summary) : ""
                    color: Colors.label; elide: Text.ElideRight
                    font.family: Appearance.fontUI; font.pixelSize: Appearance.fsS; font.weight: Font.DemiBold
                }
                Text {
                    Layout.fillWidth: true
                    visible: text.length > 0
                    text: notifLayer.n ? NotificationCenter.tn(notifLayer.n.body) : ""
                    color: Colors.label2; elide: Text.ElideRight
                    textFormat: Text.StyledText
                    font.family: Appearance.fontUI; font.pixelSize: Appearance.fsXXS
                }
            }

            Text {
                visible: notifLayer.kind === ""
                Layout.alignment: Qt.AlignVCenter
                text: notifLayer.n ? (notifLayer.n.appName || "") : ""
                color: Colors.accentInk
                font.family: Appearance.fontUI; font.pixelSize: Appearance.fsXXS; font.weight: Font.Medium
            }
            // The card's buttons; the first is the main one (filled).
            Row {
                visible: notifLayer.buttons.length > 0
                Layout.alignment: Qt.AlignVCenter
                spacing: 6
                Repeater {
                    model: notifLayer.buttons.slice(0, 3)
                    Rectangle {
                        id: btn
                        required property var modelData
                        required property int index
                        readonly property bool main: index === 0
                        width: btnText.implicitWidth + 22; height: 26; radius: 13
                        color: main ? notifLayer.kindColor
                            : (btnMa.containsMouse ? Colors.fill2 : Colors.fill3)
                        border.width: main ? 0 : 1
                        border.color: Colors.hairline
                        Text {
                            id: btnText
                            anchors.centerIn: parent
                            text: btn.modelData.text
                            color: btn.main ? "#101010" : Colors.label
                            font.family: Appearance.fontUI; font.pixelSize: Appearance.fsXXS; font.weight: Font.DemiBold
                        }
                        MouseArea {
                            id: btnMa
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: { ShellState.activity = ""; btn.modelData.invoke(); }
                        }
                    }
                }
            }
        }
    }

    // ─────────────── toast: brief notice (copied to clipboard) ───────────────
    NotchLayer {
        anchors.fill: parent
        active: root.mode === "toast"

        Row {
            anchors.centerIn: parent
            spacing: 11
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: Launcher.toastIcon
                color: Colors.accentInk
                font.family: Appearance.font; font.pixelSize: 17
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: Launcher.toastText
                color: Colors.label
                font.family: Appearance.fontUI; font.pixelSize: Appearance.fsM; font.weight: Font.Medium
            }
        }
    }

    // ─────────────── launcher: application launcher ───────────────
    NotchLayer {
        anchors.fill: parent
        active: root.mode === "launcher"
        origin: -1   // the Arch button is on the left
        // The same condition as the layer: if this screen is not showing the
        // launcher, its copy ignores everything. See the LauncherPanel block.
        LauncherPanel { anchors.fill: parent; enPantalla: root.mode === "launcher" }
    }

    // ─────────────── overview: workspace map ───────────────
    // It is born in the CENTRE (origin 0) and not from a side: no bar button
    // opens it, Super+Tab does. What you did not ask for from a particular
    // place has no reason to come from a particular place.
    NotchLayer {
        anchors.fill: parent
        active: root.mode === "overview"
        OverviewPanel { anchors.fill: parent }
    }

    // ─────────────── control: Control Centre ───────────────
    NotchLayer {
        anchors.fill: parent
        active: root.mode === "control"
        origin: 1   // the notification bell is on the right
        ControlPanel { anchors.fill: parent }
    }

    // ─────────────── system: a calm look at the machine ───────────────
    NotchLayer {
        anchors.fill: parent
        active: root.mode === "system"
        origin: 1   // born from the Control Centre's "Tu máquina" (Your machine) button
        PerformancePanel { anchors.fill: parent }
    }

    // ─────────────── network: network picker ───────────────
    NotchLayer {
        anchors.fill: parent
        active: root.mode === "network"
        origin: 1   // opens from the control panel, on the right
        NetworkPanel { anchors.fill: parent }
    }

    // ─────────────── bluetooth: devices ───────────────
    NotchLayer {
        anchors.fill: parent
        active: root.mode === "bluetooth"
        origin: 1   // opens from the control panel, on the right
        BluetoothPanel { anchors.fill: parent }
    }

    // ─────────────── power: power menu ───────────────
    NotchLayer {
        anchors.fill: parent
        active: root.mode === "power"
        origin: 1   // its icon is on the right
        PowerPanel { anchors.fill: parent }
    }

    // ─────────────── gamesum: the game you just closed ───────────────
    // How long you played and how it ran (GameMode.lastSession), and how many
    // notices waited quietly meanwhile.
    NotchLayer {
        id: sumLayer
        anchors.fill: parent
        active: root.mode === "gamesum"
        readonly property var s: GameMode.lastSession

        RowLayout {
            anchors { fill: parent; leftMargin: 18; rightMargin: 18; topMargin: 6 }
            spacing: 13
            Rectangle {
                Layout.preferredWidth: 38
                Layout.preferredHeight: 38
                radius: 12
                color: Qt.rgba(Colors.accent.r, Colors.accent.g, Colors.accent.b, 0.20)
                Text {
                    anchors.centerIn: parent
                    text: Icons.gamepad
                    color: Colors.accentInk
                    font.family: Appearance.font
                    font.pixelSize: 19
                }
            }
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 2
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8
                    Text {
                        Layout.fillWidth: true
                        elide: Text.ElideRight
                        text: sumLayer.s ? sumLayer.s.name : ""
                        color: Colors.label
                        font.family: Appearance.fontUI
                        font.pixelSize: Appearance.fsM
                        font.weight: Font.DemiBold
                    }
                    Text {
                        text: sumLayer.s ? GameMode.duration(sumLayer.s.mins) : ""
                        color: Colors.accentInk
                        font.family: Appearance.fontUI
                        font.pixelSize: Appearance.fsS
                        font.weight: Font.DemiBold
                        font.features: ({ "tnum": 1 })
                    }
                }
                Text {
                    Layout.fillWidth: true
                    elide: Text.ElideRight
                    text: {
                        const s = sumLayer.s;
                        if (!s) return "";
                        const bits = [];
                        if (s.avg > 0) bits.push(I18n.tr("media {0} fps", s.avg), I18n.tr("mín. {0}", s.min));
                        if (s.cpu > 0) bits.push("CPU " + s.cpu + "°");
                        if (s.gpu > 0) bits.push("GPU " + s.gpu + "°");
                        if (s.missed > 0) bits.push(I18n.tr("{0} avisos", s.missed));
                        return bits.length ? bits.join("  ·  ") : I18n.tr("Partida terminada");
                    }
                    color: Colors.label3
                    font.family: Appearance.fontUI
                    font.pixelSize: Appearance.fsXS
                    font.features: ({ "tnum": 1 })
                }
            }
        }
    }

    // ─────────────── display: laptop screen / TV ───────────────
    NotchLayer {
        anchors.fill: parent
        active: root.mode === "display"
        DisplayPanel { anchors.fill: parent }
    }

    // ─────────────── calendar: the month's calendar ───────────────
    NotchLayer {
        anchors.fill: parent
        active: root.mode === "calendar"
        origin: 1   // opens from the Control Centre, on the right
        CalendarPanel { anchors.fill: parent }
    }

    // ─────────────── github: contributions and latest commits ───────────────
    NotchLayer {
        anchors.fill: parent
        active: root.mode === "github"
        origin: 1   // also comes out of a Control Centre card
        GithubPanel { anchors.fill: parent }
    }
}
