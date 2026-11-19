// PocketLogin.qml — pocket-dots login screen for SDDM, inside the thyx theme.
//
// Layout: a big clock in the top-left corner with a spaced date under it, the
// user + an underlined password field in a bottom corner (FormPosition: left
// or right), text buttons for power in the other corner, the session picker
// under the password. Colours, font and background come from the thyx
// theme.conf (which login-pywal.sh keeps in sync with the wallpaper), so it
// follows the desktop like the lock screen (LockScreen.qml, same layout).
//
// Installed as src/PocketLogin.qml of the thyx theme and selected with
// `sddm-thyx.sh layout pocket` (metadata.desktop MainScript).
import QtQuick 2.15
import QtQuick.Effects

Rectangle {
    id: root
    width: Screen.width
    height: Screen.height
    color: c("StartupBackgroundColor", "#000000")

    function c(key, fallback) {
        const v = (typeof config !== "undefined" && config) ? config[key] : undefined;
        return (v === undefined || v === "") ? fallback : v;
    }
    readonly property string family: c("Font", "Plus Jakarta Sans")
    readonly property bool onRight: String(c("FormPosition", "left")) === "right"
    readonly property real u: Math.min(width / 1920, height / 1080)   // scale unit
    readonly property color accent: c("LoginButtonBackgroundColor", "#7aa2f7")
    readonly property color ink: c("PasswordFieldTextColor", "#ffffff")
    readonly property color soft: c("SystemButtonsIconsColor", "#c0c0c0")

    // ── users and sessions, read off SDDM's models ──
    property int userIndex: userModel.lastIndex >= 0 ? userModel.lastIndex : 0
    property var users: []
    property int sessionIndex: sessionModel.lastIndex >= 0 ? sessionModel.lastIndex : 0
    property var sessions: []
    Repeater {
        model: userModel
        Item {
            required property int index
            required property string name
            required property string realName
            Component.onCompleted: { const a = root.users.slice(); a[index] = { name: name, real: realName }; root.users = a; }
        }
    }
    Repeater {
        model: sessionModel
        Item {
            required property int index
            required property string name
            Component.onCompleted: { const a = root.sessions.slice(); a[index] = name; root.sessions = a; }
        }
    }
    readonly property var user: users[userIndex] || ({ name: "", real: "" })
    readonly property string sessionName: sessions[sessionIndex] || ""

    property bool busy: false
    property string errorText: ""
    function login() {
        if (pw.text.length === 0 || root.busy || !root.user.name) return;
        root.busy = true;
        root.errorText = "";
        sddm.login(root.user.name, pw.text, root.sessionIndex);
    }
    Connections {
        target: sddm
        function onLoginFailed() {
            root.busy = false;
            pw.text = "";
            root.errorText = "Senha incorreta";
            shake.restart();
            pw.forceActiveFocus();
        }
        function onLoginSucceeded() { root.busy = false; }
    }

    // ── background: the (already blurred) wallpaper copy, a touch more blur,
    //    and a shade towards the corners where the text sits ──
    Image {
        id: bg
        anchors.fill: parent
        source: c("Background", "") !== "" ? Qt.resolvedUrl("../" + c("Background", "")) : ""
        fillMode: Image.PreserveAspectCrop
        visible: false
    }
    MultiEffect {
        anchors.fill: parent
        source: bg
        blurEnabled: true
        blur: Math.max(0, Math.min(1, Number(c("Blur", 0.2))))
        blurMax: 48
        autoPaddingEnabled: false
    }
    Rectangle {
        anchors.fill: parent
        gradient: Gradient {
            orientation: Gradient.Vertical
            GradientStop { position: 0.0; color: Qt.rgba(0, 0, 0, 0.35) }
            GradientStop { position: 0.45; color: Qt.rgba(0, 0, 0, 0.05) }
            GradientStop { position: 1.0; color: Qt.rgba(0, 0, 0, 0.45) }
        }
    }

    // ── clock, top-left ──
    Column {
        x: 104 * root.u
        y: 72 * root.u
        spacing: 10 * root.u
        Text {
            id: clock
            color: c("TimeTextColor", "#ffffff")
            font { family: root.family; pixelSize: 132 * root.u; weight: Font.Black; letterSpacing: 2 * root.u }
        }
        Row {
            spacing: 14 * root.u
            Rectangle { width: 30 * root.u; height: 2; color: c("DateTextColor", "#aaaaaa"); anchors.verticalCenter: parent.verticalCenter; opacity: 0.8 }
            Text {
                id: date
                color: c("DateTextColor", "#aaaaaa")
                font { family: root.family; pixelSize: 19 * root.u; weight: Font.DemiBold; letterSpacing: 4 * root.u; capitalization: Font.AllUppercase }
            }
        }
    }
    Timer {
        interval: 1000; running: true; repeat: true; triggeredOnStart: true
        onTriggered: {
            const now = new Date(), loc = Qt.locale("pt_BR");
            clock.text = loc.toString(now, c("HourFormat", "HH:mm"));
            date.text = loc.toString(now, "dddd") + "  ·  " + loc.toString(now, "d 'de' MMMM");
        }
    }

    // ── login, bottom corner ──
    Column {
        id: form
        width: 400 * root.u
        x: root.onRight ? root.width - width - 58 * root.u : 104 * root.u
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 150 * root.u
        spacing: 20 * root.u

        Text {
            width: parent.width
            horizontalAlignment: root.onRight ? Text.AlignRight : Text.AlignLeft
            text: root.user.real || root.user.name
            color: root.ink
            elide: Text.ElideRight
            font { family: root.family; pixelSize: 30 * root.u; weight: Font.ExtraBold; letterSpacing: 3 * root.u; capitalization: Font.AllUppercase }
            MouseArea {   // more than one user: click cycles through them
                anchors.fill: parent
                enabled: root.users.length > 1
                cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                onClicked: root.userIndex = (root.userIndex + 1) % root.users.length
            }
        }

        Item {
            id: field
            width: parent.width
            height: 44 * root.u
            property real dx: 0
            transform: Translate { x: field.dx }
            SequentialAnimation {
                id: shake
                NumberAnimation { target: field; property: "dx"; to: -12; duration: 50 }
                NumberAnimation { target: field; property: "dx"; to: 10; duration: 70 }
                NumberAnimation { target: field; property: "dx"; to: -6; duration: 60 }
                NumberAnimation { target: field; property: "dx"; to: 0; duration: 60 }
            }
            TextInput {
                id: pw
                anchors.left: parent.left
                anchors.right: arrow.left
                anchors.rightMargin: 12 * root.u
                anchors.verticalCenter: parent.verticalCenter
                echoMode: TextInput.Password
                passwordCharacter: "✦"
                color: root.ink
                font { family: root.family; pixelSize: 20 * root.u; letterSpacing: 6 * root.u }
                focus: true
                enabled: !root.busy
                onAccepted: root.login()
                Keys.onEscapePressed: text = ""
                Component.onCompleted: forceActiveFocus()
            }
            Text {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                visible: pw.text.length === 0
                text: root.busy ? "ENTRANDO…" : "SENHA"
                color: c("PlaceholderTextColor", "#888888")
                font { family: root.family; pixelSize: 15 * root.u; weight: Font.DemiBold; letterSpacing: 4 * root.u }
            }
            Text {
                id: arrow
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                text: "→"
                color: arrowMa.containsMouse ? root.accent : root.soft
                font { family: root.family; pixelSize: 24 * root.u }
                MouseArea { id: arrowMa; anchors.fill: parent; anchors.margins: -8; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.login() }
            }
            Rectangle {
                anchors.left: parent.left; anchors.right: parent.right; anchors.bottom: parent.bottom
                height: 2
                radius: 1
                color: root.errorText !== "" ? "#ff6b6b" : (pw.activeFocus ? root.accent : Qt.rgba(root.ink.r, root.ink.g, root.ink.b, 0.35))
                Behavior on color { ColorAnimation { duration: 160 } }
            }
        }

        Text {
            width: parent.width
            horizontalAlignment: root.onRight ? Text.AlignRight : Text.AlignLeft
            height: 16 * root.u
            text: root.errorText
            color: "#ff8a80"
            font { family: root.family; pixelSize: 14 * root.u; letterSpacing: 2 * root.u; capitalization: Font.AllUppercase }
        }
    }

    // ── session picker: under the form's corner; click or ←/→ ──
    Text {
        id: sessionLabel
        x: root.onRight ? root.width - width - 58 * root.u : 104 * root.u
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 72 * root.u
        text: "●  " + root.sessionName
        color: sessMa.containsMouse ? root.accent : root.soft
        font { family: root.family; pixelSize: 16 * root.u; weight: Font.DemiBold; letterSpacing: 3 * root.u; capitalization: Font.AllUppercase }
        MouseArea {
            id: sessMa
            anchors.fill: parent
            anchors.margins: -8
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: if (root.sessions.length > 0) root.sessionIndex = (root.sessionIndex + 1) % root.sessions.length
        }
    }
    Keys.onPressed: function (e) {
        if (root.sessions.length === 0) return;
        if (e.key === Qt.Key_F10 || (e.key === Qt.Key_Right && (e.modifiers & Qt.AltModifier))) { root.sessionIndex = (root.sessionIndex + 1) % root.sessions.length; e.accepted = true; }
        if (e.key === Qt.Key_Left && (e.modifiers & Qt.AltModifier)) { root.sessionIndex = (root.sessionIndex - 1 + root.sessions.length) % root.sessions.length; e.accepted = true; }
    }

    // ── power, the opposite bottom corner ──
    Row {
        x: root.onRight ? 104 * root.u : root.width - width - 58 * root.u
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 72 * root.u
        spacing: 40 * root.u
        Repeater {
            model: [
                { label: "Suspender", act: function () { sddm.suspend(); }, ok: sddm.canSuspend },
                { label: "Reiniciar", act: function () { sddm.reboot(); }, ok: sddm.canReboot },
                { label: "Desligar",  act: function () { sddm.powerOff(); }, ok: sddm.canPowerOff }
            ]
            Text {
                required property var modelData
                visible: modelData.ok
                text: modelData.label
                color: pma.containsMouse ? root.accent : root.soft
                Behavior on color { ColorAnimation { duration: 160 } }
                font { family: root.family; pixelSize: 16 * root.u; weight: Font.DemiBold; letterSpacing: 3 * root.u; capitalization: Font.AllUppercase }
                MouseArea { id: pma; anchors.fill: parent; anchors.margins: -8; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: modelData.act() }
            }
        }
    }

    // A click anywhere gives the keyboard back to the password.
    TapHandler { onTapped: pw.forceActiveFocus() }
    Component.onCompleted: pw.forceActiveFocus()
}
