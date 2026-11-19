// LockScreen.qml — the lock screen, dressed as the login screen.
//
// The login screen is SDDM with the thyx theme (github.com/rccyx/thyx, MIT;
// see sddm-thyx.sh). SDDM cannot lock a running session, so this draws the
// same thing here: it reads thyx's own theme.conf (colours, font, background
// image or video, blur), so changing the thyx preset changes both screens.
//
// Security: ext-session-lock (WlSessionLock). If this process dies while
// locked, niri keeps the session locked; scripts/lock.sh falls back to
// swaylock if the shell does not confirm a secure lock within 2 s.
// The password goes through PAM, service "swaylock" (/etc/pam.d/swaylock).
pragma ComponentBehavior: Bound

import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Services.Pam
import Quickshell.Widgets
import QtQuick
import QtQuick.Effects
import QtQuick.Layouts
import QtMultimedia

Scope {
    id: root

    readonly property string home: Quickshell.env("HOME")
    readonly property string user: Quickshell.env("USER") || ""
    // Full name from passwd ("Isaac Inacio Alves"), as the login shows it.
    property string fullName: ""
    Process {
        running: true
        command: ["sh", "-c", "getent passwd \"$USER\" | cut -d: -f5 | cut -d, -f1"]
        stdout: StdioCollector { onStreamFinished: root.fullName = this.text.trim() }
    }

    // ─── the thyx theme (installed one first, repo clone as fallback) ───
    property string themeDir: "/usr/share/sddm/themes/thyx"
    property var cfg: ({})
    function c(key, fallback) { const v = root.cfg[key]; return (v === undefined || v === "") ? fallback : v; }
    function parseIni(text) {
        const out = {};
        for (const raw of String(text).split("\n")) {
            const line = raw.trim();
            if (line === "" || line[0] === "#" || line[0] === ";" || line[0] === "[") continue;
            const i = line.indexOf("=");
            if (i < 0) continue;
            let v = line.slice(i + 1).trim();
            if (v.length >= 2 && v[0] === '"' && v[v.length - 1] === '"') v = v.slice(1, -1);
            out[line.slice(0, i).trim()] = v;
        }
        return out;
    }
    FileView {
        id: themeFile
        path: root.themeDir + "/theme.conf"
        watchChanges: true
        onFileChanged: reload()
        onLoaded: root.cfg = root.parseIni(text())
        // SDDM theme not installed yet: use the thyx clone. A new `path` is not
        // read by itself after a failed load, hence the explicit reload.
        onLoadFailed: if (root.themeDir.indexOf("/usr/share") === 0) {
            root.themeDir = root.home + "/Projetos/thyx";
            Qt.callLater(themeFile.reload);
        }
    }
    readonly property string bgPath: root.c("Background", "") === "" ? "" : root.themeDir + "/" + root.c("Background", "")
    readonly property bool bgIsVideo: /\.(mp4|webm|mkv|mov|m4v|avi)$/i.test(root.bgPath)

    // ─── state shared by every screen ───
    property string password: ""
    property bool busy: false
    property string errorText: ""
    property int failures: 0
    readonly property bool locked: lock.locked
    readonly property bool secure: lock.secure

    // NO RELOADS WHILE LOCKED. A shell reload (a QML file changing) destroys
    // the lock object: niri keeps the session locked (safe), but the reloaded
    // shell cannot lock it again and dies, leaving a locked screen with no
    // password field. So file watching is switched off for as long as the
    // screen is locked and back on after unlocking.
    function lockNow() {
        if (lock.locked) return;
        root.password = ""; root.errorText = ""; root.busy = false;
        ShellState.closePanel();
        Quickshell.watchFiles = false;
        lock.locked = true;
    }
    function unlockNow() {
        lock.locked = false;
        Quickshell.watchFiles = true;
    }
    function submit() {
        if (root.busy || root.password.length === 0) return;
        root.busy = true;
        root.errorText = "";
        if (!pam.start()) { root.busy = false; root.errorText = "Não foi possível iniciar a autenticação"; }
    }

    PamContext {
        id: pam
        // The same PAM service swaylock uses (auth include login): known to
        // work on this system, and swaylock is the fallback locker anyway.
        configDirectory: "/etc/pam.d"
        config: "swaylock"
        user: root.user
        onPamMessage: {
            if (pam.responseRequired) pam.respond(root.password);
            else if (pam.messageIsError) root.errorText = pam.message;
        }
        onCompleted: function (result) {
            root.busy = false;
            if (result === PamResult.Success) {
                root.password = "";
                root.failures = 0;
                root.unlockNow();
            } else {
                root.password = "";
                root.failures++;
                root.errorText = result === PamResult.MaxTries ? "Muitas tentativas. Aguarde um pouco." : "Senha incorreta";
            }
        }
        onError: function (err) {
            root.busy = false;
            root.password = "";
            root.errorText = "Erro de autenticação";
        }
    }

    IpcHandler {
        target: "lock"
        function lock(): void { root.lockNow(); }
        // "unlocked" | "locking" | "secure": scripts/lock.sh waits for "secure".
        function status(): string { return !lock.locked ? "unlocked" : (lock.secure ? "secure" : "locking"); }
        // Which thyx theme.conf is in use and how many keys were read.
        function theme(): string { return root.themeDir + " keys=" + Object.keys(root.cfg).length + " bg=" + root.bgPath; }
    }

    WlSessionLock {
        id: lock
        locked: false

        WlSessionLockSurface {
            id: surf
            color: root.c("StartupBackgroundColor", "#000000")

            Item {
                id: page
                anchors.fill: parent
                readonly property real pt: Math.max(9, Number(root.c("FontSize", 12)))
                readonly property string family: root.c("Font", "Plus Jakarta Sans")
                readonly property int anim: Number(root.c("AnimationDuration", 300))

                // ── background: the thyx image or video, blurred like thyx ──
                Item {
                    id: bgSource
                    anchors.fill: parent
                    visible: false
                    Image {
                        anchors.fill: parent
                        visible: !root.bgIsVideo
                        source: (!root.bgIsVideo && root.bgPath !== "") ? "file://" + root.bgPath : ""
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                    }
                    VideoOutput {
                        id: vout
                        anchors.fill: parent
                        visible: root.bgIsVideo
                        fillMode: VideoOutput.PreserveAspectCrop
                    }
                    MediaPlayer {
                        videoOutput: vout
                        source: root.bgIsVideo ? "file://" + root.bgPath : ""
                        loops: MediaPlayer.Infinite
                        autoPlay: root.bgIsVideo
                    }
                }
                MultiEffect {
                    anchors.fill: parent
                    source: bgSource
                    blurEnabled: true
                    blur: Math.max(0, Math.min(1, Number(root.c("Blur", 0.4))))
                    blurMax: 64
                    autoPaddingEnabled: false
                }
                // Same shade as the login screen (sddm/PocketLogin.qml).
                Rectangle {
                    anchors.fill: parent
                    gradient: Gradient {
                        orientation: Gradient.Vertical
                        GradientStop { position: 0.0; color: Qt.rgba(0, 0, 0, 0.35) }
                        GradientStop { position: 0.45; color: Qt.rgba(0, 0, 0, 0.05) }
                        GradientStop { position: 1.0; color: Qt.rgba(0, 0, 0, 0.45) }
                    }
                }

                // ── the login screen's layout: clock top-left, user + underlined
                //    password in a bottom corner (FormPosition), power opposite ──
                readonly property real u: Math.min(width / 1920, height / 1080)
                readonly property bool onRight: String(root.c("FormPosition", "left")) === "right"
                readonly property color accent: root.c("LoginButtonBackgroundColor", "#7aa2f7")
                readonly property color ink: root.c("PasswordFieldTextColor", "#ffffff")
                readonly property color soft: root.c("SystemButtonsIconsColor", "#c0c0c0")

                Column {
                    x: 104 * page.u
                    y: 72 * page.u
                    spacing: 10 * page.u
                    Text {
                        id: timeLabel
                        color: root.c("TimeTextColor", "#ffffff")
                        font { family: page.family; pixelSize: 132 * page.u; weight: Font.Black; letterSpacing: 2 * page.u }
                    }
                    Row {
                        spacing: 14 * page.u
                        Rectangle { width: 30 * page.u; height: 2; opacity: 0.8; color: root.c("DateTextColor", "#aaaaaa"); anchors.verticalCenter: parent.verticalCenter }
                        Text {
                            id: dateLabel
                            color: root.c("DateTextColor", "#aaaaaa")
                            font { family: page.family; pixelSize: 19 * page.u; weight: Font.DemiBold; letterSpacing: 4 * page.u; capitalization: Font.AllUppercase }
                        }
                    }
                }
                Timer {
                    interval: 1000; running: true; repeat: true; triggeredOnStart: true
                    onTriggered: {
                        const now = new Date(), loc = Qt.locale("pt_BR");
                        timeLabel.text = loc.toString(now, root.c("HourFormat", "HH:mm"));
                        dateLabel.text = loc.toString(now, "dddd") + "  ·  " + loc.toString(now, "d 'de' MMMM");
                    }
                }

                Column {
                    width: 400 * page.u
                    x: page.onRight ? page.width - width - 58 * page.u : 104 * page.u
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: 150 * page.u
                    spacing: 20 * page.u

                    Text {
                        width: parent.width
                        horizontalAlignment: page.onRight ? Text.AlignRight : Text.AlignLeft
                        text: root.fullName || root.user
                        color: page.ink
                        elide: Text.ElideRight
                        font { family: page.family; pixelSize: 30 * page.u; weight: Font.ExtraBold; letterSpacing: 3 * page.u; capitalization: Font.AllUppercase }
                    }

                    Item {
                        id: field
                        width: parent.width
                        height: 44 * page.u
                        property real shake: 0
                        transform: Translate { x: field.shake }
                        SequentialAnimation {
                            id: shakeAnim
                            NumberAnimation { target: field; property: "shake"; to: -12; duration: 50 }
                            NumberAnimation { target: field; property: "shake"; to: 10; duration: 70 }
                            NumberAnimation { target: field; property: "shake"; to: -6; duration: 60 }
                            NumberAnimation { target: field; property: "shake"; to: 0; duration: 60 }
                        }
                        Connections {
                            target: root
                            function onFailuresChanged() { if (root.failures > 0) shakeAnim.restart(); }
                            function onPasswordChanged() { if (input.text !== root.password) input.text = root.password; }
                        }
                        TextInput {
                            id: input
                            anchors.left: parent.left
                            anchors.right: arrow.left
                            anchors.rightMargin: 12 * page.u
                            anchors.verticalCenter: parent.verticalCenter
                            echoMode: TextInput.Password
                            passwordCharacter: "✦"
                            color: page.ink
                            font { family: page.family; pixelSize: 20 * page.u; letterSpacing: 6 * page.u }
                            focus: true
                            enabled: !root.busy
                            onTextChanged: if (text !== root.password) root.password = text
                            onAccepted: root.submit()
                            Keys.onEscapePressed: root.password = ""
                            Component.onCompleted: forceActiveFocus()
                        }
                        Text {
                            anchors.left: parent.left
                            anchors.verticalCenter: parent.verticalCenter
                            visible: input.text === ""
                            text: root.busy ? "VERIFICANDO…" : "SENHA"
                            color: root.c("PlaceholderTextColor", "#888888")
                            font { family: page.family; pixelSize: 15 * page.u; weight: Font.DemiBold; letterSpacing: 4 * page.u }
                        }
                        Text {
                            id: arrow
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            text: "→"
                            color: arrowMa.containsMouse ? page.accent : page.soft
                            font { family: page.family; pixelSize: 24 * page.u }
                            MouseArea { id: arrowMa; anchors.fill: parent; anchors.margins: -8; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: { root.submit(); input.forceActiveFocus(); } }
                        }
                        Rectangle {
                            anchors.left: parent.left; anchors.right: parent.right; anchors.bottom: parent.bottom
                            height: 2
                            radius: 1
                            color: root.errorText !== "" ? "#ff6b6b" : (input.activeFocus ? page.accent : Qt.rgba(page.ink.r, page.ink.g, page.ink.b, 0.35))
                            Behavior on color { ColorAnimation { duration: 160 } }
                        }
                    }

                    Text {
                        width: parent.width
                        height: 16 * page.u
                        horizontalAlignment: page.onRight ? Text.AlignRight : Text.AlignLeft
                        text: root.errorText
                        color: "#ff8a80"
                        font { family: page.family; pixelSize: 14 * page.u; letterSpacing: 2 * page.u; capitalization: Font.AllUppercase }
                    }
                }

                // Where the login shows the session: here, that it is locked.
                Text {
                    x: page.onRight ? page.width - width - 58 * page.u : 104 * page.u
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: 72 * page.u
                    text: "●  BLOQUEADO"
                    color: page.soft
                    font { family: page.family; pixelSize: 16 * page.u; weight: Font.DemiBold; letterSpacing: 3 * page.u }
                }

                Row {
                    x: page.onRight ? 104 * page.u : page.width - width - 58 * page.u
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: 72 * page.u
                    spacing: 40 * page.u
                    Repeater {
                        model: [
                            { label: "Suspender", cmd: "systemctl suspend" },
                            { label: "Reiniciar", cmd: "systemctl reboot" },
                            { label: "Desligar",  cmd: "systemctl poweroff" }
                        ]
                        Text {
                            id: pwr
                            required property var modelData
                            text: pwr.modelData.label
                            color: pwrMa.containsMouse ? page.accent : page.soft
                            Behavior on color { ColorAnimation { duration: 160 } }
                            font { family: page.family; pixelSize: 16 * page.u; weight: Font.DemiBold; letterSpacing: 3 * page.u; capitalization: Font.AllUppercase }
                            MouseArea { id: pwrMa; anchors.fill: parent; anchors.margins: -8; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: Quickshell.execDetached(["sh", "-c", pwr.modelData.cmd]) }
                        }
                    }
                }

                // A click anywhere gives the keyboard back to the field.
                TapHandler { onTapped: input.forceActiveFocus() }
            }
        }
    }
}
