// Screenshot.qml — the capture screen, the way GNOME does it.
//
// Print freezes the screen and dims it. You drag the area straight on the
// screen (move it by dragging inside, resize it by the corners), or switch to
// the whole screen or to a window, and choose photo or video in the toolbar at
// the bottom. The round button (or Enter) captures.
//
//   photo  cropped from the frozen frame, saved to ~/Pictures/screenshots,
//          copied, and announced by notify-shot.sh (click it to edit in satty)
//   video  screenrecord.sh records that area; Print again stops it
//
// Keys: S area · C screen · W window · V photo/video · Enter capture · Esc close.
//   qs ipc call shot open
import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import QtQuick
import QtQuick.Layouts
import QtQuick.Effects

Scope {
    id: root
    property bool open: false
    property string mode: "area"      // area | screen | window
    property bool video: false
    property bool recording: false

    // logical px of the screen being captured
    property real scale: 1
    property var wins: []             // [{x, y, w, h, title}] on the focused workspace
    property int hoverWin: -1
    property int pickedWin: -1
    // the area, kept between captures like GNOME does
    property real ax: -1
    property real ay: 0
    property real aw: 0
    property real ah: 0

    readonly property string scripts: Quickshell.env("HOME") + "/.config/glasstty/scripts/"
    readonly property string frozen: (Quickshell.env("XDG_RUNTIME_DIR") || "/tmp") + "/glasstty-shot.png"
    property int stamp: 0
    function tx(pt, en, es) { return Config.language === "pt" ? pt : Config.language === "en" ? en : es; }

    // The rectangle that will be captured, in logical px.
    readonly property var target: {
        if (root.mode === "screen") return { x: 0, y: 0, w: win.width, h: win.height };
        if (root.mode === "window") {
            const i = root.hoverWin >= 0 ? root.hoverWin : root.pickedWin;
            const w = root.wins[i];
            return w ? { x: w.x, y: w.y, w: w.w, h: w.h } : { x: 0, y: 0, w: 0, h: 0 };
        }
        return { x: root.ax, y: root.ay, w: root.aw, h: root.ah };
    }

    // ── open: stop a recording, or freeze the screen and read the windows ──
    function toggle() {
        if (root.open) { root.open = false; return; }
        if (prep.running) return;
        prep.running = true;
    }
    Process {
        id: prep
        command: ["sh", "-c",
            "f=\"${XDG_RUNTIME_DIR:-/tmp}/hypr-tools/screenrecord.state\"; " +
            "if [ -s \"$f\" ]; then echo REC; exit 0; fi; " +
            "o=$(niri msg -j focused-output); n=$(printf '%s' \"$o\" | sed -n 's/.*\"name\":\"\\([^\"]*\\)\".*/\\1/p'); " +
            "grim -o \"$n\" \"$1\" || exit 1; echo \"$o\"; niri msg -j workspaces; niri msg -j windows", "sh", root.frozen]
        stdout: StdioCollector { id: prepOut }
        onExited: (code) => {
            const lines = prepOut.text.split("\n").filter(l => l.trim() !== "");
            if (lines[0] === "REC") { Quickshell.execDetached([root.scripts + "screenrecord.sh"]); return; }
            if (code !== 0 || lines.length < 3) return;
            try {
                const out = JSON.parse(lines[0]);
                const ws = JSON.parse(lines[1]).find(w => w.is_focused);
                root.scale = (out.logical && out.logical.scale) || 1;
                root.wins = JSON.parse(lines[2])
                    .filter(w => ws && w.workspace_id === ws.id && w.layout && w.layout.tile_pos_in_workspace_view)
                    .map(w => ({
                        x: w.layout.tile_pos_in_workspace_view[0] + w.layout.window_offset_in_tile[0],
                        y: w.layout.tile_pos_in_workspace_view[1] + w.layout.window_offset_in_tile[1],
                        w: w.layout.window_size[0], h: w.layout.window_size[1], title: w.title || ""
                    }));
            } catch (e) { root.wins = []; }
            root.hoverWin = -1;
            root.pickedWin = root.wins.length > 0 ? 0 : -1;
            root.stamp++;
            root.open = true;
        }
    }

    // ── capture ──
    function capture() {
        const t = root.target;
        if (t.w < 4 || t.h < 4) return;
        root.open = false;
        const s = root.scale;
        if (root.video) {
            // wf-recorder takes logical coordinates, like slurp gives them.
            later.cmd = ["env", "CAPTURE_GEOM=" + Math.round(t.x) + "," + Math.round(t.y) + " " + Math.round(t.w) + "x" + Math.round(t.h),
                         root.scripts + "screenrecord.sh"];
        } else {
            const geom = Math.round(t.w * s) + "x" + Math.round(t.h * s) + "+" + Math.round(t.x * s) + "+" + Math.round(t.y * s);
            later.cmd = ["sh", "-c",
                "d=\"$(xdg-user-dir PICTURES 2>/dev/null || echo \"$HOME/Pictures\")/screenshots\"; mkdir -p \"$d\"; " +
                "f=\"$d/screenshot-$(date +%Y%m%d_%H%M%S).png\"; " +
                "magick \"$1\" -crop \"$2\" +repage \"$f\" && wl-copy --type image/png < \"$f\" && " +
                "{ \"$3\" \"$f\" & }", "sh", root.frozen, geom, root.scripts + "notify-shot.sh"];
        }
        later.restart();
    }
    // The screen must be clear of the overlay before a recording starts.
    Timer { id: later; property var cmd: []; interval: 220; onTriggered: Quickshell.execDetached(cmd) }

    IpcHandler {
        target: "shot"
        function open(): void { root.toggle(); }
    }

    PanelWindow {
        id: win
        screen: ShellState.focusedScreen
        visible: root.open
        color: "transparent"
        anchors { top: true; bottom: true; left: true; right: true }
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: root.open ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
        WlrLayershell.namespace: "quickshell:shot"

        onVisibleChanged: if (visible && root.ax < 0) {
            root.aw = Math.round(width * 0.4); root.ah = Math.round(height * 0.4);
            root.ax = Math.round((width - root.aw) / 2); root.ay = Math.round((height - root.ah) / 2);
        }

        Item {
            id: stage
            anchors.fill: parent
            focus: root.open
            property real fadeIn: root.open ? 1 : 0
            Behavior on fadeIn { NumberAnimation { duration: Appearance.mInScale; easing.type: Easing.OutCubic } }
            readonly property var t: root.target
            // The dim is the palette's background, darkened, not plain black.
            readonly property color shade: Qt.rgba(Colors.bg.r * 0.5, Colors.bg.g * 0.5, Colors.bg.b * 0.5, 0.55 * stage.fadeIn)
            Keys.onPressed: (e) => {
                if (e.key === Qt.Key_Escape) root.open = false;
                else if (e.key === Qt.Key_Return || e.key === Qt.Key_Enter || e.key === Qt.Key_Space || e.key === Qt.Key_Print) root.capture();
                else if (e.key === Qt.Key_S) root.mode = "area";
                else if (e.key === Qt.Key_C) root.mode = "screen";
                else if (e.key === Qt.Key_W) root.mode = "window";
                else if (e.key === Qt.Key_V) root.video = !root.video;
                else return;
                e.accepted = true;
            }

            // The frozen frame (photo). For video the live screen shows instead.
            Item {
                id: backdrop
                anchors.fill: parent
            Image {
                id: frozenImg
                anchors.fill: parent
                visible: !root.video
                source: root.open ? "file://" + root.frozen + "?" + root.stamp : ""
                cache: false
                smooth: false
            }

            // ── dim everything but the target ──
            Rectangle { color: stage.shade; x: 0; y: 0; width: parent.width; height: Math.max(0, stage.t.y) }
            Rectangle { color: stage.shade; x: 0; y: stage.t.y + stage.t.h; width: parent.width; height: Math.max(0, parent.height - stage.t.y - stage.t.h) }
            Rectangle { color: stage.shade; x: 0; y: stage.t.y; width: Math.max(0, stage.t.x); height: stage.t.h }
            Rectangle { color: stage.shade; x: stage.t.x + stage.t.w; y: stage.t.y; width: Math.max(0, parent.width - stage.t.x - stage.t.w); height: stage.t.h }
            }

            // ── area: drag to draw, drag inside to move, corners to resize ──
            MouseArea {
                anchors.fill: parent
                enabled: root.mode === "area"
                property real px: 0
                property real py: 0
                property bool moving: false
                property real ox: 0
                property real oy: 0
                onPressed: (m) => {
                    px = m.x; py = m.y;
                    moving = m.x >= root.ax && m.x <= root.ax + root.aw && m.y >= root.ay && m.y <= root.ay + root.ah;
                    ox = root.ax; oy = root.ay;
                    if (!moving) { root.ax = m.x; root.ay = m.y; root.aw = 0; root.ah = 0; }
                }
                onPositionChanged: (m) => {
                    // With hoverEnabled this also fires just moving the mouse:
                    // only a drag may change the area.
                    if (!pressed) return;
                    if (moving) {
                        root.ax = Math.max(0, Math.min(width - root.aw, ox + m.x - px));
                        root.ay = Math.max(0, Math.min(height - root.ah, oy + m.y - py));
                    } else {
                        const x = Math.max(0, Math.min(width, m.x)), y = Math.max(0, Math.min(height, m.y));
                        root.ax = Math.min(px, x); root.ay = Math.min(py, y);
                        root.aw = Math.abs(x - px); root.ah = Math.abs(y - py);
                    }
                }
                onDoubleClicked: root.capture()
                // A cross to draw, the four arrows inside the area to move it.
                // hoverEnabled: without it the shape only changed once pressed.
                hoverEnabled: true
                readonly property bool overArea: mouseX >= root.ax && mouseX <= root.ax + root.aw
                    && mouseY >= root.ay && mouseY <= root.ay + root.ah && root.aw > 0
                cursorShape: (pressed ? moving : overArea) ? Qt.SizeAllCursor : Qt.CrossCursor
            }
            // ── window: hover to point, click to pick ──
            MouseArea {
                anchors.fill: parent
                enabled: root.mode === "window"
                hoverEnabled: true
                function at(x, y) {
                    for (let i = root.wins.length - 1; i >= 0; i--) {
                        const w = root.wins[i];
                        if (x >= w.x && x <= w.x + w.w && y >= w.y && y <= w.y + w.h) return i;
                    }
                    return -1;
                }
                onPositionChanged: (m) => { const i = at(m.x, m.y); if (i >= 0) root.hoverWin = i; }
                onClicked: (m) => { const i = at(m.x, m.y); if (i >= 0) { root.pickedWin = i; root.hoverWin = i; } }
                onDoubleClicked: root.capture()
                cursorShape: Qt.PointingHandCursor
            }

            // outline of the target
            Rectangle {
                x: stage.t.x - 1; y: stage.t.y - 1; width: stage.t.w + 2; height: stage.t.h + 2
                visible: stage.t.w > 0 && root.mode !== "screen"
                color: "transparent"
                border.width: 2
                border.color: Colors.onWallAccent
                radius: root.mode === "window" ? Appearance.radM : 0
            }
            // size readout
            Rectangle {
                visible: root.mode === "area" && root.aw > 0
                x: Math.min(parent.width - width - 8, root.ax)
                y: root.ay > 34 ? root.ay - 30 : root.ay + 6
                width: dims.implicitWidth + 16; height: 24; radius: 12
                color: Qt.rgba(stage.tint.r, stage.tint.g, stage.tint.b, 0.85)
                border.width: 1; border.color: Colors.hairline
                Text {
                    id: dims
                    anchors.centerIn: parent
                    text: Math.round(root.aw * root.scale) + " × " + Math.round(root.ah * root.scale)
                    color: Colors.label2; font.family: Appearance.fontUI; font.pixelSize: 12
                    font.features: ({ "tnum": 1 })
                }
            }
            // corner handles
            Repeater {
                model: root.mode === "area" && root.aw > 0 ? 4 : 0
                Rectangle {
                    required property int index
                    readonly property bool isRight: index === 1 || index === 3
                    readonly property bool isBottom: index >= 2
                    width: 16; height: 16; radius: 8
                    color: Colors.onWallAccent
                    border.width: 3; border.color: Colors.bg
                    x: (isRight ? root.ax + root.aw : root.ax) - 8
                    y: (isBottom ? root.ay + root.ah : root.ay) - 8
                    MouseArea {
                        anchors.fill: parent
                        anchors.margins: -6
                        cursorShape: (parent.isRight !== parent.isBottom) ? Qt.SizeBDiagCursor : Qt.SizeFDiagCursor
                        property real fx: 0
                        property real fy: 0
                        onPressed: {
                            fx = parent.isRight ? root.ax : root.ax + root.aw;
                            fy = parent.isBottom ? root.ay : root.ay + root.ah;
                        }
                        onPositionChanged: (m) => {
                            const p = mapToItem(stage, m.x, m.y);
                            const x = Math.max(0, Math.min(stage.width, p.x)), y = Math.max(0, Math.min(stage.height, p.y));
                            root.ax = Math.min(fx, x); root.ay = Math.min(fy, y);
                            root.aw = Math.abs(x - fx); root.ah = Math.abs(y - fy);
                        }
                    }
                }
            }

            // ── toolbar: the notch's glass ──
            // The notch's tint, translucent over a blur. Over the frozen frame
            // the blur is drawn here (the compositor would only blur what is
            // under the overlay, which is the same frame); in video mode the
            // screen is live and niri blurs it for real (blurRegion below).
            readonly property color tint: Colors.notchTint(Config.notchColor)
            Item {
                id: bar
                anchors.horizontalCenter: parent.horizontalCenter
                y: parent.height - height - 36 + (1 - stage.fadeIn) * 40
                opacity: stage.fadeIn
                scale: 0.96 + 0.04 * stage.fadeIn
                width: tools.implicitWidth + 28
                height: tools.implicitHeight + 24
                readonly property real r: Appearance.radL + 10

                Item {
                    anchors.fill: parent
                    visible: !root.video
                    layer.enabled: true
                    layer.effect: MultiEffect {
                        maskEnabled: true
                        maskSource: barMask
                        maskThresholdMin: 0.5
                        maskSpreadAtMin: 1.0
                    }
                    ShaderEffectSource {
                        id: under
                        anchors.fill: parent
                        sourceItem: backdrop
                        sourceRect: Qt.rect(bar.x, bar.y, bar.width, bar.height)
                        visible: false
                    }
                    MultiEffect {
                        anchors.fill: parent
                        source: under
                        blurEnabled: true
                        blur: 1.0
                        blurMax: 48
                        saturation: 0.2
                    }
                }
                Rectangle {
                    id: barMask
                    anchors.fill: parent
                    radius: bar.r
                    visible: false
                    layer.enabled: true
                }
                Rectangle {
                    id: barBody
                    anchors.fill: parent
                    radius: bar.r
                    color: Qt.rgba(stage.tint.r, stage.tint.g, stage.tint.b, 0.62)
                    border.width: 1; border.color: Colors.hairline
                }
                MouseArea { anchors.fill: parent }      // clicks here do not draw an area

                component Seg: Rectangle {
                    id: seg
                    property string icon
                    property string label
                    property string key
                    property bool on
                    signal hit()
                    implicitWidth: 88; implicitHeight: 62
                    radius: Appearance.radL
                    color: on ? Colors.fill1 : segHover.hovered ? Colors.fill2 : "transparent"
                    Behavior on color { ColorAnimation { duration: 120 } }
                    Column {
                        anchors.centerIn: parent
                        spacing: 4
                        Text { anchors.horizontalCenter: parent.horizontalCenter; text: seg.icon; color: seg.on ? Colors.accentInk : Colors.label2; font.family: Appearance.font; font.pixelSize: 22 }
                        Text { anchors.horizontalCenter: parent.horizontalCenter; text: seg.label; color: seg.on ? Colors.label : Colors.label3; font.family: Appearance.fontUI; font.pixelSize: 12; font.weight: seg.on ? Font.DemiBold : Font.Normal }
                    }
                    Text {
                        anchors { top: parent.top; right: parent.right; topMargin: 6; rightMargin: 8 }
                        text: seg.key; color: Colors.label4
                        font.family: Appearance.fontUI; font.pixelSize: 9
                    }
                    HoverHandler { id: segHover; cursorShape: Qt.PointingHandCursor }
                    TapHandler { onTapped: seg.hit() }
                }
                component Pill: Rectangle {
                    id: pill
                    property string icon
                    property bool on
                    signal hit()
                    implicitWidth: 44; implicitHeight: 32; radius: 16
                    color: on ? Colors.accent : pillHover.hovered ? Colors.fill2 : "transparent"
                    Behavior on color { ColorAnimation { duration: 120 } }
                    Text { anchors.centerIn: parent; text: pill.icon; color: pill.on ? Colors.accentText : Colors.label2; font.family: Appearance.font; font.pixelSize: 17 }
                    HoverHandler { id: pillHover; cursorShape: Qt.PointingHandCursor }
                    TapHandler { onTapped: pill.hit() }
                }
                component Sep: Rectangle { implicitWidth: 1; implicitHeight: 36; color: Colors.hairline }

                RowLayout {
                    id: tools
                    anchors.centerIn: parent
                    spacing: 14

                    // photo / video
                    Rectangle {
                        implicitWidth: kind.implicitWidth + 6; implicitHeight: 38; radius: 19
                        color: Colors.fill3
                        Row {
                            id: kind
                            anchors.centerIn: parent
                            spacing: 2
                            Pill { icon: "󰄀"; on: !root.video; onHit: root.video = false }
                            Pill { icon: "󰕧"; on: root.video; onHit: root.video = true }
                        }
                    }
                    Sep {}
                    Row {
                        spacing: 4
                        Seg { icon: "󰩭"; key: "S"; label: root.tx("Área", "Area", "Área"); on: root.mode === "area"; onHit: root.mode = "area" }
                        Seg { icon: "󰹑"; key: "C"; label: root.tx("Tela", "Screen", "Pantalla"); on: root.mode === "screen"; onHit: root.mode = "screen" }
                        Seg { icon: "󰖯"; key: "W"; label: root.tx("Janela", "Window", "Ventana"); on: root.mode === "window"; onHit: root.mode = "window" }
                    }
                    Sep {}
                    // the capture button: a ring with the accent (photo) or red (video)
                    Rectangle {
                        implicitWidth: 60; implicitHeight: 60; radius: 30
                        color: "transparent"
                        border.width: 3; border.color: Colors.label
                        Rectangle {
                            anchors.centerIn: parent
                            width: shotTap.pressed ? 38 : shotHover.hovered ? 46 : 42
                            height: width; radius: width / 2
                            color: root.video ? Colors.crit : Colors.accent
                            Behavior on width { NumberAnimation { duration: 110; easing.type: Easing.OutQuad } }
                            Behavior on color { ColorAnimation { duration: 160 } }
                        }
                        HoverHandler { id: shotHover; cursorShape: Qt.PointingHandCursor }
                        TapHandler { id: shotTap; onTapped: root.capture() }
                    }
                    // close
                    Rectangle {
                        implicitWidth: 36; implicitHeight: 36; radius: 18
                        color: closeHover.hovered ? Colors.fill2 : "transparent"
                        Text { anchors.centerIn: parent; text: "󰅖"; color: Colors.label3; font.family: Appearance.font; font.pixelSize: 18 }
                        HoverHandler { id: closeHover; cursorShape: Qt.PointingHandCursor }
                        TapHandler { onTapped: root.open = false }
                    }
                }
            }
        }

        // Video mode shows the live screen: let niri blur it behind the toolbar.
        BackgroundEffect.blurRegion: root.video ? barRegion : null
        Region {
            id: barRegion
            x: Math.round(bar.x); y: Math.round(bar.y)
            width: Math.round(bar.width); height: Math.round(bar.height)
            radius: Math.round(bar.r)
        }
    }
}
