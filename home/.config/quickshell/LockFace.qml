// LockFace.qml — how the lock screen looks: the login screen's layout (thyx),
// plus what Settings > Appearance > Lock changes. Used twice: full screen by
// LockScreen.qml (with `lock` set, so the password works) and small, live, as
// the preview in that Settings tab (`lock` null, nothing interactive).
// Everything is sized from `u` (width / 1920), so it scales down as is.
import Quickshell
import QtQuick
import QtQuick.Effects
import QtQuick.Layouts
import QtMultimedia
import Quickshell.Widgets

Item {
    id: page
    // The LockScreen that owns the password and PAM. null = a preview (Settings):
    // nothing can be typed or clicked, and nothing grabs the keyboard.
    property var lock: null
    // Where the settings come from: Config for the real lock, the Settings
    // draft (AppearanceDraft.v) for the preview.
    property var cfg: Config
    readonly property bool preview: page.lock === null
    readonly property bool busy: page.lock ? page.lock.busy : false
    readonly property string errorText: page.lock ? page.lock.errorText : ""
    clip: true
    readonly property real pt: Math.max(9, Number(LockTheme.c("FontSize", 12)))
    readonly property string family: LockTheme.c("Font", "Plus Jakarta Sans")
    readonly property int anim: Number(LockTheme.c("AnimationDuration", 300))

    // ── background: the picture, or a blurred copy of it made by LockTheme ──
    readonly property string bgPath: LockTheme.bgFor(page.cfg.lockBg)
    readonly property bool bgIsVideo: /\.(mp4|webm|mkv|mov|m4v|avi)$/i.test(page.bgPath)
    readonly property int blurPct: page.cfg.lockBlur >= 0 ? page.cfg.lockBlur : LockTheme.defaultBlur
    readonly property real blurAmt: page.blurPct / 100
    LockBlur { id: myBlur; src: page.bgPath; pct: page.blurPct; isVideo: page.bgIsVideo }
    // Until this face's own copy is ready, the one LockTheme made ahead for the
    // saved settings (the real lock then shows it at once).
    readonly property string blurredUrl: myBlur.ready ? myBlur.url
        : (page.bgPath === LockTheme.bgPath && page.blurPct === LockTheme.blurPct) ? LockTheme.blurredUrl
        : myBlur.url
    Item {
        id: bgSource
        anchors.fill: parent
        // A video can only be blurred live (see the effect below).
        visible: !(page.bgIsVideo && page.blurAmt > 0)
        Image {
            anchors.fill: parent
            visible: !page.bgIsVideo
            // Blurred copy once it exists for THIS picture and blur; until then
            // (the first second after a change) the previous one or the original.
            source: page.bgIsVideo || page.bgPath === "" ? ""
                : (page.blurAmt > 0 && page.blurredUrl !== "") ? page.blurredUrl
                : "file://" + page.bgPath
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            cache: false
            smooth: true
        }
        VideoOutput {
            id: vout
            anchors.fill: parent
            visible: page.bgIsVideo
            fillMode: VideoOutput.PreserveAspectCrop
        }
        MediaPlayer {
            videoOutput: vout
            source: page.bgIsVideo ? "file://" + page.bgPath : ""
            loops: MediaPlayer.Infinite
            autoPlay: page.bgIsVideo && page.visible
        }
    }
    MultiEffect {
        anchors.fill: parent
        source: bgSource
        visible: page.bgIsVideo && page.blurAmt > 0
        blurEnabled: true
        blur: page.blurAmt
        blurMax: Math.max(8, Math.round(64 * page.u))
        autoPaddingEnabled: false
    }
    // Same shade as the login screen (sddm/PocketLogin.qml); Settings can turn it off.
    Rectangle {
        visible: page.cfg.lockShade
        anchors.fill: parent
        gradient: Gradient {
            orientation: Gradient.Vertical
            GradientStop { position: 0.0; color: Qt.rgba(0, 0, 0, 0.35) }
            GradientStop { position: 0.45; color: Qt.rgba(0, 0, 0, 0.05) }
            GradientStop { position: 1.0; color: Qt.rgba(0, 0, 0, 0.45) }
        }
    }
    // Extra shade, from Settings (0 = the login's look).
    Rectangle { anchors.fill: parent; color: "black"; opacity: page.cfg.lockDim / 100 }

    // ── the login screen's layout: clock top-left, user + underlined
    //    password in a bottom corner (FormPosition), power opposite ──
    readonly property real u: Math.min(width / 1920, height / 1080)
    // "left" | "right" | "center": where your name and the password go.
    readonly property string side: page.cfg.lockSide !== "" ? page.cfg.lockSide
        : (String(LockTheme.c("FormPosition", "left")) === "right" ? "right" : "left")
    readonly property bool onRight: page.side === "right"
    readonly property bool centred: page.side === "center"
    readonly property color accent: page.cfg.lockAccent === "wallpaper" ? Colors.onWallAccent
        : LockTheme.c("LoginButtonBackgroundColor", "#7aa2f7")
    readonly property color ink: LockTheme.c("PasswordFieldTextColor", "#ffffff")
    readonly property color soft: LockTheme.c("SystemButtonsIconsColor", "#c0c0c0")
    // Clock block: left (the login's), centred or right; its lines follow.
    readonly property string cpos: page.cfg.lockClockPos
    readonly property int calign: cpos === "center" ? Qt.AlignHCenter : cpos === "right" ? Qt.AlignRight : Qt.AlignLeft
    readonly property color dateInk: LockTheme.c("DateTextColor", "#aaaaaa")

    // A ColumnLayout, not a Column: right/centre anchors on a Column's children
    // fight its width (taken from those same children) and the clock vanished.
    ColumnLayout {
        id: clockCol
        x: page.cpos === "center" ? (page.width - width) / 2
         : page.cpos === "right" ? page.width - width - 104 * page.u : 104 * page.u
        // Height from Settings (% of the screen from the top); -1 = the login's 72 px.
        y: page.cfg.lockClockY >= 0 ? page.height * page.cfg.lockClockY / 100 : 72 * page.u
        spacing: 10 * page.u
        Text {
            id: timeLabel
            Layout.alignment: page.calign
            color: page.cfg.lockClockColor === "accent" ? page.accent
                 : page.cfg.lockClockColor === "white" ? "#ffffff"
                 : LockTheme.c("TimeTextColor", "#ffffff")
            font {
                family: page.cfg.lockClockFont !== "" ? page.cfg.lockClockFont : page.family
                pixelSize: 132 * page.u * page.cfg.lockClockSize / 100
                weight: ({ light: Font.Light, regular: Font.Normal, bold: Font.Bold })[page.cfg.lockClockWeight] ?? Font.Black
                letterSpacing: 2 * page.u
            }
        }
        // "pill": the date sits in a soft capsule (Material You-like).
        Item {
            id: dateBox
            visible: page.cfg.lockShowDate
            Layout.alignment: page.calign
            readonly property bool pill: page.cfg.lockDatePill === true
            Layout.topMargin: pill ? 6 * page.u : 0
            implicitWidth: dateRow.implicitWidth
            implicitHeight: dateRow.implicitHeight
            Rectangle {
                anchors.fill: parent
                visible: dateBox.pill
                radius: height / 2
                color: Qt.rgba(page.ink.r, page.ink.g, page.ink.b, 0.12)
            }
        Row {
            id: dateRow
            readonly property bool pill: dateBox.pill
            leftPadding: pill ? 20 * page.u : 0
            rightPadding: pill ? 20 * page.u : 0
            topPadding: pill ? 9 * page.u : 0
            bottomPadding: pill ? 9 * page.u : 0
            spacing: 14 * page.u
            Rectangle { visible: page.cpos === "left" && !dateRow.pill; width: 30 * page.u; height: 2; opacity: 0.8; color: page.dateInk; anchors.verticalCenter: parent.verticalCenter }
            Text {
                id: dateLabel
                color: LockTheme.c("DateTextColor", "#aaaaaa")
                font { family: page.family; pixelSize: 19 * page.u; weight: Font.DemiBold; letterSpacing: 4 * page.u; capitalization: Font.AllUppercase }
            }
        }
        }
        // Your own line, from Settings (empty = none).
        Text {
            visible: page.cfg.lockMessage !== ""
            Layout.alignment: page.calign
            topPadding: 10 * page.u
            text: page.cfg.lockMessage
            color: page.ink
            width: Math.min(implicitWidth, 900 * page.u)
            elide: Text.ElideRight
            horizontalAlignment: page.cpos === "center" ? Text.AlignHCenter : page.cpos === "right" ? Text.AlignRight : Text.AlignLeft
            font { family: page.family; pixelSize: 24 * page.u; weight: Font.Medium; letterSpacing: 1 * page.u }
        }
        // What is playing, from Settings (off by default).
        Row {
            Layout.alignment: page.calign
            readonly property var pl: ShellState.player
            visible: page.cfg.lockShowMedia && pl !== null && (pl.trackTitle || "") !== ""
            topPadding: 14 * page.u
            spacing: 12 * page.u
            Text {
                text: parent.pl && parent.pl.isPlaying ? "󰎆" : "󰏤"
                color: page.accent
                font { family: Appearance.font; pixelSize: 20 * page.u }
                anchors.verticalCenter: parent.verticalCenter
            }
            Text {
                text: parent.pl ? (parent.pl.trackTitle || "") + ((parent.pl.trackArtist || "") !== "" ? "  ·  " + parent.pl.trackArtist : "") : ""
                color: LockTheme.c("DateTextColor", "#aaaaaa")
                elide: Text.ElideRight
                width: Math.min(implicitWidth, 700 * page.u)
                font { family: page.family; pixelSize: 17 * page.u; weight: Font.DemiBold; letterSpacing: 2 * page.u }
                anchors.verticalCenter: parent.verticalCenter
            }
        }
    }
    Timer {
        interval: 1000; running: true; repeat: true; triggeredOnStart: true
        onTriggered: {
            const now = new Date(), loc = Qt.locale(Config.language === "pt" ? "pt_BR" : Config.language === "en" ? "en_US" : "es_ES");
            // Not the theme's HourFormat: login-pywal.sh writes the applied choice there.
            const hm = page.cfg.lock12h ? "h:mm" : "HH:mm";
            timeLabel.text = loc.toString(now, page.cfg.lockSeconds ? hm + ":ss" : hm);
            const en = Config.language === "en";
            dateLabel.text = page.cfg.lockDateFmt === "numeric" ? loc.toString(now, en ? "MM/dd/yyyy" : "dd/MM/yyyy")
                : page.cfg.lockDateFmt === "short" ? loc.toString(now, en ? "ddd, MMM d" : "ddd, d MMM")
                : loc.toString(now, "dddd") + "  ·  " + loc.toString(now, en ? "MMMM d" : "d 'de' MMMM");
        }
    }

    // "Panel" layout: one frosted panel holding the clock and the password.
    Rectangle {
        visible: page.cfg.lockPanel === true
        readonly property real pad: 48 * page.u
        x: Math.min(clockCol.x, form.x) - pad
        y: Math.min(clockCol.y, form.y) - pad
        width: Math.max(clockCol.x + clockCol.width, form.x + form.width) - x + pad
        height: Math.max(clockCol.y + clockCol.height, form.y + form.height) - y + pad
        radius: 32 * page.u
        color: Qt.rgba(page.ink.r, page.ink.g, page.ink.b, 0.07)
        border.width: Math.max(1, page.u)
        border.color: Qt.rgba(page.ink.r, page.ink.g, page.ink.b, 0.14)
    }

    // "Card" layout: a frosted card behind your name and the password.
    Rectangle {
        visible: page.cfg.lockCard === true
        x: form.x - 36 * page.u
        y: form.y - 32 * page.u
        width: form.width + 72 * page.u
        height: form.height + 56 * page.u
        radius: 28 * page.u
        color: Qt.rgba(page.ink.r, page.ink.g, page.ink.b, 0.07)
        border.width: Math.max(1, page.u)
        border.color: Qt.rgba(page.ink.r, page.ink.g, page.ink.b, 0.14)
    }

    Column {
        id: form
        width: 400 * page.u
        x: page.centred ? (page.width - width) / 2
         : page.onRight ? page.width - width - 58 * page.u : 104 * page.u
        anchors.bottom: parent.bottom
        // Height from Settings (% of the screen from the bottom); -1 = the login's 150 px.
        // ...but never up into the clock: it stops 40 px under the clock block.
        // (Only when they share a column: clock left + password right can sit level.)
        readonly property bool sharesColumn: x < clockCol.x + clockCol.width && clockCol.x < x + width
        anchors.bottomMargin: Math.min(page.cfg.lockFormY >= 0 ? page.height * page.cfg.lockFormY / 100 : 150 * page.u,
            sharesColumn ? page.height - (clockCol.y + clockCol.height) - 40 * page.u - height : page.height)
        spacing: 20 * page.u

        // Your picture (AccountsService), over the name.
        ClippingRectangle {
            visible: page.cfg.lockAvatar === true
            width: 88 * page.u; height: width; radius: width / 2
            x: page.centred ? (parent.width - width) / 2 : page.onRight ? parent.width - width : 0
            color: Qt.rgba(page.ink.r, page.ink.g, page.ink.b, 0.1)
            border.width: Math.max(1, 2 * page.u)
            border.color: Qt.rgba(page.ink.r, page.ink.g, page.ink.b, 0.25)
            Image {
                id: faceImg
                anchors.fill: parent
                source: "file:///var/lib/AccountsService/icons/" + LockTheme.user
                fillMode: Image.PreserveAspectCrop
                sourceSize: Qt.size(176, 176)
                asynchronous: true
            }
            Text {
                anchors.centerIn: parent
                visible: faceImg.status !== Image.Ready
                text: (LockTheme.fullName || LockTheme.user || "?").charAt(0).toUpperCase()
                color: page.ink
                font { family: page.family; pixelSize: 36 * page.u; weight: Font.DemiBold }
            }
        }

        Text {
            visible: page.cfg.lockShowName
            width: parent.width
            horizontalAlignment: page.centred ? Text.AlignHCenter : page.onRight ? Text.AlignRight : Text.AlignLeft
            text: LockTheme.fullName || LockTheme.user
            color: page.ink
            elide: Text.ElideRight
            font { family: page.family; pixelSize: 30 * page.u; weight: Font.ExtraBold; letterSpacing: 3 * page.u; capitalization: Font.AllUppercase }
        }

        Item {
            id: field
            width: parent.width
            height: (page.cfg.lockFieldStyle === "box" ? 52 : 44) * page.u
            // "box": a rounded glass box instead of the underline.
            Rectangle {
                anchors.fill: parent
                anchors.leftMargin: -14 * page.u
                anchors.rightMargin: -10 * page.u
                visible: page.cfg.lockFieldStyle === "box"
                radius: 14 * page.u
                color: Qt.rgba(page.ink.r, page.ink.g, page.ink.b, 0.08)
                border.width: Math.max(1, 1.5 * page.u)
                border.color: page.errorText !== "" ? "#ff6b6b" : (input.activeFocus ? page.accent : Qt.rgba(page.ink.r, page.ink.g, page.ink.b, 0.18))
                Behavior on border.color { ColorAnimation { duration: 160 } }
            }
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
                target: page.lock
                function onFailuresChanged() { if (page.lock.failures > 0) shakeAnim.restart(); }
                function onPasswordChanged() { if (input.text !== page.lock.password) input.text = page.lock.password; }
            }
            TextInput {
                id: input
                anchors.left: parent.left
                anchors.right: arrow.left
                anchors.rightMargin: 12 * page.u
                anchors.verticalCenter: parent.verticalCenter
                echoMode: TextInput.Password
                horizontalAlignment: page.centred ? TextInput.AlignHCenter : TextInput.AlignLeft
                passwordCharacter: page.cfg.lockChar || "✦"
                color: page.ink
                font { family: page.family; pixelSize: 20 * page.u; letterSpacing: 6 * page.u }
                focus: !page.preview
                enabled: !page.busy && !page.preview
                onTextChanged: if (page.lock && text !== page.lock.password) page.lock.password = text
                onAccepted: if (page.lock) page.lock.submit()
                Keys.onEscapePressed: if (page.lock) page.lock.password = ""
                Component.onCompleted: if (!page.preview) forceActiveFocus()
            }
            Text {
                anchors.left: parent.left
                anchors.right: input.right
                anchors.verticalCenter: parent.verticalCenter
                horizontalAlignment: page.centred ? Text.AlignHCenter : Text.AlignLeft
                visible: input.text === ""
                text: page.busy ? I18n.tr("Verificando…") : I18n.tr("Contraseña")
                color: LockTheme.c("PlaceholderTextColor", "#888888")
                font { family: page.family; pixelSize: 15 * page.u; weight: Font.DemiBold; letterSpacing: 4 * page.u ; capitalization: Font.AllUppercase }
            }
            Text {
                id: arrow
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                text: "→"
                color: arrowMa.containsMouse ? page.accent : page.soft
                font { family: page.family; pixelSize: 24 * page.u }
                MouseArea { id: arrowMa; anchors.fill: parent; anchors.margins: -8; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; enabled: !page.preview; onClicked: { page.lock.submit(); input.forceActiveFocus(); } }
            }
            Rectangle {
                visible: page.cfg.lockFieldStyle !== "box"
                anchors.left: parent.left; anchors.right: parent.right; anchors.bottom: parent.bottom
                height: 2
                radius: 1
                color: page.errorText !== "" ? "#ff6b6b" : (input.activeFocus ? page.accent : Qt.rgba(page.ink.r, page.ink.g, page.ink.b, 0.35))
                Behavior on color { ColorAnimation { duration: 160 } }
            }
        }

        Text {
            width: parent.width
            height: 16 * page.u
            horizontalAlignment: page.centred ? Text.AlignHCenter : page.onRight ? Text.AlignRight : Text.AlignLeft
            text: page.errorText
            color: "#ff8a80"
            font { family: page.family; pixelSize: 14 * page.u; letterSpacing: 2 * page.u; capitalization: Font.AllUppercase }
        }
    }

    // Where the login shows the session: here, that it is locked.
    Row {
        x: page.onRight ? page.width - width - 58 * page.u : 104 * page.u
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 72 * page.u
        spacing: 22 * page.u
        Text {
            text: "●  " + I18n.tr("Bloqueado")
            color: page.soft
            font { family: page.family; pixelSize: 16 * page.u; weight: Font.DemiBold; letterSpacing: 3 * page.u; capitalization: Font.AllUppercase }
        }
        // The battery, from Settings: the icon in the symbols font, the % in the theme's.
        Row {
            visible: page.cfg.lockShowBattery && ShellState.batt >= 0
            spacing: 6 * page.u
            anchors.verticalCenter: parent.verticalCenter
            Text {
                text: ShellState.battIcon
                color: page.soft
                font { family: Appearance.font; pixelSize: 17 * page.u }
                anchors.verticalCenter: parent.verticalCenter
            }
            Text {
                text: ShellState.batt + "%"
                color: page.soft
                font { family: page.family; pixelSize: 16 * page.u; weight: Font.DemiBold; letterSpacing: 2 * page.u; features: ({ "tnum": 1 }) }
                anchors.verticalCenter: parent.verticalCenter
            }
        }
    }

    Row {
        visible: page.cfg.lockShowPower
        x: page.onRight ? 104 * page.u : page.width - width - 58 * page.u
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 72 * page.u
        spacing: 40 * page.u
        Repeater {
            model: [
                { label: I18n.tr("Suspender"), cmd: "systemctl suspend" },
                { label: I18n.tr("Reiniciar"), cmd: "systemctl reboot" },
                { label: I18n.tr("Apagar"),    cmd: "systemctl poweroff" }
            ]
            Text {
                id: pwr
                required property var modelData
                text: pwr.modelData.label
                color: pwrMa.containsMouse ? page.accent : page.soft
                Behavior on color { ColorAnimation { duration: 160 } }
                font { family: page.family; pixelSize: 16 * page.u; weight: Font.DemiBold; letterSpacing: 3 * page.u; capitalization: Font.AllUppercase }
                MouseArea { id: pwrMa; anchors.fill: parent; anchors.margins: -8; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; enabled: !page.preview; onClicked: Quickshell.execDetached(["sh", "-c", pwr.modelData.cmd]) }
            }
        }
    }

    // A click anywhere gives the keyboard back to the field.
    TapHandler { enabled: !page.preview; onTapped: input.forceActiveFocus() }
}
