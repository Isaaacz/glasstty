// TopShell.qml — the top surface: the notch as lead + a minimal bar.
//
// Philosophy:
//   · The notch is the ONLY shape on the screen. A loose black island, stuck to
//     the top edge, with the MacBook's inverted top corners.
//   · The bar is NOT a surface: it has no background, no strip, no islands.
//     They are loose glyphs over the wallpaper, aligned with the notch.
//   · At rest the notch measures EXACTLY the reserved band (32 px), so it
//     covers nothing. It only sticks out when you make it.
//   · The bar shows STATE; the notch panel holds the CONTROLS.
//
//        Arch  ●━● ●   Kitty          ╭──────╮        󰤨 󰕾 󰁹 50%  16:23
//                                     │      │
//                                     ╰──────╯
//
// One single window (caelestia/drawers approach): one state, one mask, one
// fullscreen handling. Data and state in ShellState.qml.
// Test in isolation:  qs -p ~/.config/quickshell/TopShell.qml
import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import Quickshell.Services.SystemTray
import QtQuick
import QtQuick.Shapes
import QtQuick.Effects
import QtQuick.Layouts

Scope {
    id: root

    // ═══════════════════════ aspecto ═══════════════════════
    readonly property int barH: ShellState.bandH       // reserved band = notch height at rest
    // Resolved here and not stored resolved: Config stores the "theme"
    // sentinel and whoever paints asks the live palette, so a wallpaper change
    // re-themes the notch too. See the Colors.notchTint() block.
    // GLASS (this fork, niri only): the compositor blurs what is behind the
    // band and the notch (niri 26.04 + ext-background-effect, see the
    // BackgroundEffect region on the window below), so the notch is painted
    // translucent instead of solid and the band gets a light tint, like a
    // frosted top panel. Config.barBlur turns it off. Per screen it is also
    // off while that screen shows an empty workspace (just the desktop), so
    // the wallpaper is seen clean -- see `win.glass`.
    // Game mode drops it too: games run maximised under the bar (so the fps
    // stay visible), and real blur behind the bar is redone on every game
    // frame, which on an iGPU shows up as stutter. The band goes solid.
    readonly property bool glassAllowed: Compositor.isNiri && Config.barBlur && !ShellState.gameMode
    readonly property color notchSolid: Colors.notchTint(Config.notchColor)
    readonly property int sideMargin: Config.sideMargin
    readonly property int flare: Config.flare           // radius of the inverted top corner
    readonly property int roundMax: Config.roundMax     // the notch's bottom radius
    // Island mode: the pill comes away from the edge and is rounded on all
    // four sides. The gap above comes out of the reserved band, so it still
    // covers no windows.
    readonly property bool island: Config.island
    // A single source: the panels that compute their exact height (the
    // launcher) subtract it via ShellState, so the gap is defined there.
    readonly property real topGap: ShellState.notchTopGap
    readonly property real kArc: 0.5523

    // Optional veil under the bar. 0 = bar 100 % transparent (the default).
    readonly property real scrimAlpha: Config.scrimAlpha

    readonly property int maxH: 546                    // Super+D is now the tallest face (526 px)

    property bool shown: true

    // The panels that ask for the keyboard. It lives up here because it governs
    // TWO things that had to go together and did not: the layer's
    // keyboardFocus and the re-arming of the "click outside = close" grab.
    readonly property var panelesConTeclado: ["launcher", "power", "network", "bluetooth",
                                              "overview", "system", "calendar", "github"]
    readonly property bool pideTeclado: root.panelesConTeclado.indexOf(ShellState.panel) >= 0

    // see the note on HyprlandFocusGrab further down
    property bool grabArmed: false
    // -1 = the notch was closed; 0/1 = it was open without/with keyboard.
    property int _tecladoPrevio: -1
    Timer { id: grabArm; interval: 400; onTriggered: root.grabArmed = true }
    Connections {
        target: ShellState
        function onPanelChanged() {
            if (ShellState.panel === "") {
                root.grabArmed = false;
                grabArm.stop();
                root._tecladoPrevio = -1;
                return;
            }
            // IT IS ONLY RELEASED IF THE LAYER IS REALLY GOING TO RECONFIGURE.
            //
            // The delay exists because opening a panel changes keyboardFocus,
            // the layer reconfigures and Hyprland cancels the grab instantly.
            // But this used to disarm on EVERY panel change, even when
            // keyboardFocus did not move: going from network to Bluetooth with
            // the bar icons, or from the launcher to network with the ">" mode
            // actions, there were 400 ms in which a click outside closed
            // nothing. And there releasing the grab cured nothing, because there
            // was nothing to cure.
            const teclado = root.pideTeclado ? 1 : 0;
            if (teclado !== root._tecladoPrevio) {
                root.grabArmed = false;
                grabArm.restart();
            }
            root._tecladoPrevio = teclado;
        }
    }

    // ═══════════════════════ IPC ═══════════════════════
    // niri has no global-shortcut protocol: config.kdl binds keys to
    // `qs ipc call notch <function>`.
    IpcHandler {
        target: "notch"
        function toggle(): void { ShellState.togglePanel("control"); }
        // These mirror the GlobalShortcuts above. Under niri there is no
        // global-shortcut protocol: config.kdl binds keys to
        // `qs ipc call notch <function>` instead.
        function actions(): void { ShellState.openLauncher("cmd"); }
        function calendar(): void { ShellState.togglePanel("calendar"); }
        function bar(): void { root.shown = !root.shown; }
        function control(): void { ShellState.togglePanel("control"); }
        // The Control Centre straight on a page: 0 painel, 1 wallpapers, 2 sistema, 3 cores.
        function controlPage(n: int): void {
            ShellState.controlPage = Math.max(0, Math.min(4, n));
            if (ShellState.panel !== "control") ShellState.togglePanel("control");
        }
        // The Control Centre straight on an extra of the Sistema page: a QML
        // file in ~/.local/share/glasstty/extras/, named without ".qml".
        function extra(name: string): void {
            ShellState.controlExtra = name;
            if (ShellState.panel !== "control") ShellState.togglePanel("control");
        }
        // The power menu is now the full-screen ExitScreen.qml.
        function power(): void { ShellState.closePanel(); Quickshell.execDetached(["qs", "ipc", "call", "exit", "toggle"]); }
        function network(): void { ShellState.togglePanel("network"); }
        function bluetooth(): void { ShellState.togglePanel("bluetooth"); }
        function system(): void { ShellState.togglePanel("system"); }
        function github(): void { ShellState.togglePanel("github"); }
        function settings(): void { ShellState.toggleSettings(); }
        // Settings opened straight on the shortcut map: the same as Super+K.
        function keys(): void { ShellState.openSettingsAt("keys"); }
        function style(): void { Config.notchStyle = Config.island ? "notch" : "island"; }
        function launcher(): void { ShellState.togglePanel("launcher"); }
        // The launcher in a specific mode: "apps" | "clip" | "cmd" | "win".
        // Anything else lands in "apps", which is the usual door.
        function open(mode: string): void {
            const ok = ["apps", "clip", "cmd", "win"];
            ShellState.openLauncher(ok.indexOf(mode) >= 0 ? mode : "apps");
        }
        function clipboard(): void { ShellState.openLauncher("clip"); }
        function overview(): void { ShellState.togglePanel("overview"); }
        function stage(): void { ShellState.toggleStage(); }
        function close(): void { ShellState.closePanel(); }
        // Page of the open Control Centre (0 painel … 4 rices), and do-not-disturb.
        function page(n: int): void { ShellState.controlGo(n); }
        function dnd(state: string): void { ShellState.dnd = state === "on"; }

        // Note down and give back the open panel. Used by the screenshot tool
        // (~/.config/glasstty/scripts/capture-region.sh): to photograph the notch
        // the screen has to be frozen, freezing sends the focus away, and that
        // cancels the HyprlandFocusGrab -> the panel closes underneath the
        // shot. Which one it was gets noted down and reopened at the end, so
        // taking a screenshot no longer closes whatever you were looking at.
        function current(): string { return ShellState.panel; }
        function restore(name: string): void {
            if (name !== "" && ShellState.panel !== name) ShellState.togglePanel(name);
        }
        function bright(dir: string): void { ShellState.stepBrightness(dir); }
        // It now accepts any of the transient faces by name, not just three.
        // Useful for triggering them from a script and, above all, for being
        // able to SEE them while working on the design without having to plug
        // in a charger or wait for the song to change.
        function osd(kind: string): void {
            const ok = ["volume", "brightness", "track", "charge", "ws", "toast", "notif"];
            ShellState.flash(ok.indexOf(kind) >= 0 ? kind : "volume");
        }
        // Bluetooth pairing. Called by scripts/bt-agent.py, which is what
        // receives BlueZ's questions (QML cannot export D-Bus objects).
        //   kind: "confirm" | "display" | "authorize"
        //   entered: digits already typed, only in "display"; -1 otherwise
        function btask(kind: string, name: string, code: string, entered: int): void {
            const ok = ["confirm", "display", "authorize"];
            if (ok.indexOf(kind) < 0) return;
            ShellState.btAsk(kind, name, code, entered);
        }
        function btclear(): void { ShellState.btClear(); }

        // Timer: "10m", "1h30", "90s"… and "stop" to cancel it.
        // The same as typing it in the launcher, but from a script: at the end
        // of a `make`, of a backup, of whatever.
        function timer(spec: string): void {
            if (spec === "stop" || spec === "off" || spec === "") { ShellState.timerClear(); return; }
            const secs = ShellState.parseDuration(spec);
            if (secs > 0) ShellState.timerStart(secs);
        }
    }

    // ═══════════════════════ la ventana ═══════════════════════
    // One surface PER SCREEN. Variants instantiates the delegate once per
    // monitor and destroys it when it is unplugged, so plugging in or removing
    // a screen does not need a shell reload.
    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: win

            // ── this window belongs to ONE screen ──────────────────────────────
            // Variants creates one copy per monitor; modelData is this one's screen.
            required property var modelData
            screen: modelData

            // The screen with the focus is the one in charge: only there does the
            // notch unfold, do the panels come out and is the keyboard requested.
            // On the others the bar and the notch are still there, but at rest.
            readonly property bool primary: modelData.name === ShellState.focusedMon

            // Glass only while this screen's workspace has windows: on a bare
            // desktop the band and the notch go back to clean wallpaper / solid.
            readonly property bool glass: root.glassAllowed && Compositor.outputHasWindows(modelData.name)
            property real glassAmt: win.glass ? 1 : 0
            Behavior on glassAmt { NumberAnimation { duration: Appearance.mIn; easing.type: Easing.OutQuad } }
            readonly property color notchColor: Qt.rgba(root.notchSolid.r, root.notchSolid.g,
                root.notchSolid.b, 1 - 0.38 * win.glassAmt)

            // The Hyprland monitor that matches THIS screen. It is looked up by
            // name inside Hyprland.monitors (which is a live model) and NOT with
            // Hyprland.monitorFor(): monitorFor is a method, so a binding on it
            // is not re-evaluated when an output is plugged in or removed and
            // would be left pointing at a monitor that no longer exists.
            readonly property var hlMon: {
                const ms = Compositor.monitors;
                for (let i = 0; i < ms.length; i++)
                    if (ms[i] && ms[i].name === modelData.name) return ms[i];
                return null;
            }

            // The face this screen paints. Those without the focus always stay on
            // the resting one (the clock, or the music one if something is
            // playing), so they show the time without inheriting the other
            // screen's unfoldings.
            readonly property string faceMode: win.primary ? ShellState.mode
                : (ShellState.mediaLive ? "media" : "idle")
            readonly property int faceW: win.primary ? ShellState.notchW : ShellState.restW
            readonly property int faceH: win.primary ? ShellState.notchH : ShellState.bandH

            // Stepping aside for fullscreen belongs to the screen that has it, not
            // to all of them: a fullscreen video here must not wipe out the bar on
            // the other screen.
            property real fsProg: (ShellState.fullscreen && win.primary) ? 1 : 0
            Behavior on fsProg { NumberAnimation { duration: Appearance.mIn; easing.type: Easing.OutCubic } }
            readonly property bool fsHidden: ShellState.fullscreen && win.primary
            visible: root.shown
            anchors { top: true; left: true; right: true }
            implicitHeight: win.primary ? root.maxH + 40 : root.barH + 40
            // `fsHidden` does NOT go in here: in real fullscreen Hyprland ignores
            // the reserved area and the window takes the whole monitor anyway
            // (measured: exactly 1920x1080 with and without this term). What it
            // did do was drop and re-take the reservation on entering and
            // leaving, and each of those two changes rearranges EVERY tiled
            // window. The `mask` further down still looks at fsHidden, which is
            // needed there: it is what stops the bar eating the clicks.
            exclusiveZone: Config.reserveSpace ? root.barH : 0
            color: "transparent"
            // Top, not Overlay: rofi, wlogout and hyprlock must come out on top.
            // EXCEPT under niri: there "click outside" is a catcher surface on
            // Top (FocusGrab.qml), and the bar must sit above it. The lock
            // screen is a session lock on niri, which is above every layer anyway.
            WlrLayershell.layer: Compositor.isNiri ? WlrLayer.Overlay : WlrLayer.Top
            WlrLayershell.namespace: "quickshell:bar"
            // Keyboard only for the panels that need it; the rest of the time the
            // layer must not steal focus from the windows.
            // OnDemand, NOT Exclusive: with Exclusive the focus stays stuck and
            // Hyprland no longer cancels the HyprlandFocusGrab, so a click outside
            // did not close the panel and you were trapped inside. With OnDemand
            // it is the grab itself that forces the keyboard focus, and clicking
            // outside cancels it and the panel closes.
            // The list lives up top, in root.panelesConTeclado: it was written
            // twice -here and, in effect, in the head of whoever touched the
            // grab's re-arming- and both were the same rule. A single source.
            WlrLayershell.keyboardFocus: (win.primary && root.pideTeclado)
                ? (Compositor.isNiri ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.OnDemand)
                : WlrKeyboardFocus.None
            // niri: OnDemand only gets the keyboard after a click on the layer,
            // so the launcher would open deaf. Exclusive is safe there because
            // the catcher closes the panel (and drops the focus) on any click
            // outside — the trap described above was Hyprland's grab.

            // The mask covers ONLY the notch and the two groups of glyphs. The rest
            // of the band lets the mouse through: the bar is not a surface.
            mask: win.fsHidden ? nothing : shellRegion

            Region { id: nothing; width: 0; height: 0 }

            // Where niri blurs (glass mode): the whole band, plus the notch body
            // below it with its rounded bottom corners. Follows the notch as it
            // opens into a panel and slides away with the bar in fullscreen.
            BackgroundEffect.blurRegion: (win.glass && !win.fsHidden) ? glassRegion : null
            Region {
                id: glassRegion
                x: 0; y: Math.round(surface.y)
                width: win.width; height: root.barH
                Region {
                    intersection: Intersection.Combine
                    x: Math.round(notch.x + (root.island ? 0 : notch.fl))
                    y: Math.round(surface.y + notch.y)
                    width: Math.round(root.island ? notch.width : notch.nw)
                    height: Math.round(notch.height)
                    readonly property int pill: Math.round(Math.min(root.roundMax, notch.height / 2))
                    topLeftRadius: root.island ? pill : 0
                    topRightRadius: root.island ? pill : 0
                    bottomLeftRadius: root.island ? pill : Math.round(notch.rb)
                    bottomRightRadius: root.island ? pill : Math.round(notch.rb)
                }
            }
            Region {
                id: shellRegion
                item: notch
                Region { item: leftGroup; intersection: Intersection.Combine }
                Region { item: rightGroup; intersection: Intersection.Combine }
                // The bubble goes by coordinates and not by `item:` because it needs
                // to MEASURE ZERO when there is nothing to show. With `item:` the
                // mouse area would still be there even with the bubble invisible,
                // and you would lose your clicks on a 28 px patch of desktop next to
                // the notch without seeing why.
                Region {
                    intersection: Intersection.Combine
                    x: Math.floor(bubble.x); y: Math.floor(bubble.y)
                    width: ShellState.bubbleOn ? Math.ceil(bubble.width) : 0
                    height: ShellState.bubbleOn ? Math.ceil(bubble.height) : 0
                }
            }

            // "Click outside = close".
            // CAREFUL: opening a panel changes keyboardFocus, the layer reconfigures
            // and Hyprland cancels the grab instantly -> the panel closed itself
            // the moment it opened. That is why the grab is armed with a delay,
            // once the layer has settled.
            FocusGrab {
                windows: [win]
                active: ShellState.open && root.grabArmed && win.primary
                onCleared: ShellState.closePanel()
            }

            IdleInhibitor { window: win; enabled: ShellState.caffeine && win.primary }

            Item {
                id: surface
                width: parent.width
                height: root.maxH
                y: -(root.maxH) * win.fsProg
                opacity: 1 - win.fsProg

                // Frosted band (glass mode): the tint over the blurred strip.
                Rectangle {
                    anchors { left: parent.left; right: parent.right; top: parent.top }
                    height: root.barH
                    visible: win.glassAmt > 0.01
                    opacity: win.glassAmt
                    color: Qt.rgba(0, 0, 0, 0.22)
                }

                // Soft veil (off by default)
                Rectangle {
                    anchors { left: parent.left; right: parent.right; top: parent.top }
                    height: root.barH + 12
                    visible: root.scrimAlpha > 0
                    gradient: Gradient {
                        GradientStop { position: 0.0; color: Qt.rgba(0, 0, 0, root.scrimAlpha) }
                        GradientStop { position: 1.0; color: "transparent" }
                    }
                }

                // ══════════════ barra: izquierda ══════════════
                RowLayout {
                    id: leftGroup
                    anchors { left: parent.left; leftMargin: root.sideMargin; top: parent.top }
                    height: root.barH
                    spacing: 2

                    BarItem {
                        visible: Config.showArch
                        icon: Icons.arch
                        iconSize: Appearance.fsL
                        iconColor: Colors.accent
                        hpad: 7
                        onClicked: ShellState.togglePanel("launcher")
                        onScrolled: function (d) { ShellState.nudgeVolume(d); }
                    }

                    // The workspace indicator TRAVELS.
                    //
                    // Each dot used to animate its own width on its own: jumping
                    // from 1 to 3, one shrank and another grew at the same time
                    // and there was no gesture joining them — two loose animations
                    // happening near each other, not a journey.
                    //
                    // Now there is ONE single pill that stretches towards the
                    // target and gathers itself up on arrival, covering the dots
                    // it skips on the way. The dots have a FIXED width, so the row
                    // does not rearrange mid-animation (that was what kept the
                    // pill from travelling: the floor moved under its feet).
                    Item {
                        id: wsGroup
                        visible: Config.showWorkspaces
                        Layout.alignment: Qt.AlignVCenter
                        Layout.leftMargin: 0
                        property int hovered: -1        // which dot the mouse points at
                        // The pill is narrower and the dots further apart than
                        // before, and it is not aesthetics: it is what makes the
                        // fluid possible. With pill 22 and spacing 8 there was 1 px
                        // between the pill and the neighbouring dot, so they were
                        // MERGED AT REST -- and if they are already stuck together,
                        // there is nothing to merge on the way past. Now there are
                        // ~7 px of air: separate bodies that only join when the pill
                        // arrives.
                        readonly property int pill: 18
                        readonly property int pad: (pill - 8) / 2   // how far the pill sticks out at the ends
                        implicitWidth: wsRow.implicitWidth + pill - 8
                        implicitHeight: 8

                        Row {
                            id: wsRow
                            x: wsGroup.pad
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 12
                            Repeater {
                                id: wsRepeater
                                // Hyprland puts the SPECIAL workspaces in this
                                // list (scratchpads, e.g. the AI panel's
                                // special:ia). They have a NEGATIVE id, and since
                                // the list comes sorted by id they came out FIRST:
                                // that was the stray dot on the left that was not
                                // any workspace. On top of that it could not be
                                // clicked, because `dispatch workspace -98` is NOT
                                // "go to -98": to Hyprland a bare negative number
                                // is a RELATIVE jump (98 workspaces back). A
                                // special one only opens with
                                // togglespecialworkspace, and it already has its
                                // shortcut for that. Here we only paint workspaces.
                                // And with TWO screens, each bar talks about ITS
                                // OWN. Unfiltered, both bars painted the whole
                                // list of workspaces and the pill on the
                                // right-hand screen pointed at one that was on the
                                // left-hand one: an indicator pointing somewhere
                                // else is worse than none.
                                //
                                // The fallback is NOT superfluous: when the shell
                                // starts, workspaces arrive before monitors, so
                                // `ws.monitor` is null for an instant and without
                                // it the row of dots would flicker empty. If
                                // nobody knows whose any of them is, they are all
                                // painted — which is exactly what there was with a
                                // single screen.
                                model: ScriptModel {
                                    values: {
                                        const all = Compositor.workspaces.filter(ws => ws.id > 0);
                                        const mine = all.filter(ws => ws.monitor && ws.monitor.name === win.modelData.name);
                                        return mine.length > 0 ? mine : all;
                                    }
                                }
                                Item {
                                    id: dot
                                    required property var modelData
                                    required property int index
                                    // The active one on THIS screen, not the one
                                    // with keyboard focus: with two monitors each
                                    // shows one workspace at a time, and both are
                                    // "the current one" of their bar. Only if it is
                                    // not yet known which monitor this is does the
                                    // global focus decide, since it is all there is.
                                    readonly property bool isActive: win.hlMon
                                        ? (win.hlMon.activeWorkspace && win.hlMon.activeWorkspace.id === modelData.id)
                                        : (Compositor.focusedWorkspace && Compositor.focusedWorkspace.id === modelData.id)
                                    // It is no longer drawn: it only holds its
                                    // place in the row and listens to the mouse.
                                    // The shader PAINTS it, as one more body of the
                                    // same fluid. Drawing it here would also be
                                    // counterproductive: two separate shapes
                                    // cannot merge, and merging is exactly the
                                    // effect.
                                    width: 8
                                    height: 8
                                    anchors.verticalCenter: parent.verticalCenter

                                    // The active dot tells the pill where to go.
                                    // Also when it moves: if you create or destroy a
                                    // workspace the row shifts and the target changes.
                                    function aim() { if (isActive) worm.target = x + width / 2; }
                                    onIsActiveChanged: aim()
                                    onXChanged: aim()
                                    Component.onCompleted: aim()

                                    MouseArea {
                                        id: wsMa
                                        anchors.fill: parent
                                        anchors.margins: -5
                                        hoverEnabled: true
                                        acceptedButtons: Qt.LeftButton | Qt.RightButton
                                        cursorShape: Qt.PointingHandCursor
                                        // Lua syntax (Hyprland 0.55+): here the
                                        // target is a specific id, so it goes as a
                                        // NUMBER, without quotes. ShellState's
                                        // horizontal wheel does need them because it
                                        // sends `e+1`, which is a string.
                                        onClicked: (mouse) => {
                                            if (mouse.button === Qt.RightButton) ShellState.toggleStage();
                                            else Compositor.focusWorkspace(dot.modelData.id);
                                        }
                                        onContainsMouseChanged: wsGroup.hovered = containsMouse ? dot.index : -1
                                    }
                                }
                            }
                        }

                        // The "worm" is no longer drawn: it is only the PHYSICS.
                        // It works out where the pill's two ends are and how
                        // thick, and the shader below takes care of painting it
                        // merged with the dots.
                        Item {
                            id: worm
                            visible: false
                            property real target: 0
                            // Two followers of the SAME target at different
                            // speeds: the leading edge arrives in mIn and the
                            // trailing one in mInScale, bouncing. While one waits
                            // for the other the pill is stretched — that stretch
                            // IS the effect. One target, two timings.
                            property real lead: 0
                            property real trail: 0
                            onTargetChanged: { lead = target; trail = target; }
                            // SPRINGS, and here is why. With a fixed duration,
                            // switching workspace twice quickly in a row cut the
                            // journey short and restarted it from zero: the pill
                            // jerked. A spring keeps the velocity it had, so the
                            // second jump CONTINUES the first. Exactly the case
                            // where it shows most, because it is what you do
                            // without thinking.
                            // The stretch comes from the two springs pulling
                            // differently: the leading one strong and contained,
                            // the trailing one slack and with a tail. One gets
                            // ahead of the other and that gap IS the stretched
                            // pill.
                            // The leading edge shoots off as soon as the target
                            // changes.
                            Behavior on lead {
                                SpringAnimation {
                                    spring: Appearance.sprTight
                                    damping: Appearance.dmpTight
                                    epsilon: Appearance.eppPx
                                }
                            }

                            // The trailing one HOLDS ON AND THEN LETS GO, and that
                            // is the whole animation.
                            //
                            // Both used to be springs with only their stiffness
                            // differing, on the idea that the softer one would lag
                            // behind. MEASURED: on a two-workspace jump (40 px of
                            // travel) the pill stretched 4 PX. Nothing. What I took
                            // for stretch was almost all the metaball merging with
                            // the neighbouring dot. Two different springs do not
                            // produce a ligament; they produce two things that
                            // arrive almost together.
                            //
                            // A liquid does not stretch because its tail is slower:
                            // it stretches because the tail STAYS STUCK where it
                            // was until the tension overcomes it, and then it lets
                            // go all at once. That is a pause and then a yank, not
                            // a different stiffness. During the pause the stretch is
                            // the WHOLE journey, and on release the stiff spring
                            // with little damping gives the whiplash and the
                            // arrival tremor.
                            Behavior on trail {
                                SequentialAnimation {
                                    PauseAnimation { duration: Appearance.mStagger }
                                    SpringAnimation {
                                        spring: Appearance.sprSquash
                                        // Squash stiffness but panel damping, not
                                        // squash damping. With 0.20 the trailing
                                        // edge kept oscillating and the pill pulsed
                                        // after arriving: a tremor is fine in the
                                        // THICKNESS, where it reads as matter, and
                                        // is a bug in the POSITION, where it reads
                                        // as not knowing where to stop.
                                        damping: Appearance.dmpPanel
                                        epsilon: Appearance.eppPx
                                    }
                                }
                            }

                            // SQUASH & STRETCH. There is no separate "squash"
                            // animation: the deformation COMES from the journey
                            // itself. 'fly' is how stretched it is right now, and
                            // with that the pill THINS while it flies (8 -> 4.4 px)
                            // and gets its thickness back as it lands. A body that
                            // lengthens without narrowing gains mass on the way and
                            // the eye reads it as a drawing being distorted;
                            // narrowing, it reads as something elastic tensing.
                            // It is the difference between stretching an image and
                            // stretching a rubber band.
                            readonly property real stretch: Math.abs(lead - trail)

                            // Normalised TO THE GAP BETWEEN TWO DOTS, not to a fixed
                            // number. It was at 45 px, which is a jump of two or
                            // three workspaces; but the jump you always make is to
                            // the next one, 20 px, and there the deformation stayed
                            // halfway. The normal case has to be the one that looks
                            // right, not the rare one.
                            readonly property real fly: Math.min(1, stretch / (8 + wsRow.spacing))

                            // The thickness comes STRAIGHT from the stretch, with no
                            // spring of its own. I tried a spring so it would
                            // overshoot on landing and IT CANNOT BE DONE THAT WAY: a
                            // Behavior on a property whose binding changes every
                            // frame restarts the spring 60 times a second, so it
                            // never gets to simulate anything, and when the binding
                            // stops changing it stays FROZEN at the last value. It
                            // looked like a pill that thinned and never got its
                            // thickness back. Springs are for targets that change on
                            // EVENTS, not for following a continuous signal.
                            //
                            // The arrival tremor comes out anyway, for free: the
                            // trailing edge overshoots as it brakes, so the stretch
                            // ticks up a little after landing and the thickness with
                            // it. An emergent bounce, not a painted one.
                            readonly property real thick: 8 - 3.4 * fly

                            readonly property bool live: target > 0
                            x: wsGroup.pad + Math.min(lead, trail) - wsGroup.pill / 2
                            width: stretch + wsGroup.pill
                            height: thick
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        // ── THE FLUID ──
                        // No shapes are drawn here, ONE FIELD is solved. The dots
                        // and the pill go in as bodies and are joined with a smooth
                        // union, so as they approach they merge through a NECK
                        // before touching and as they separate the thread stretches
                        // and snaps. That is surface tension, and it is what the eye
                        // recognises as liquid: it cannot be faked by animating
                        // scales or opacities of loose shapes.
                        //
                        // It has a margin (m) because the neck BULGES outside the
                        // bodies' box; with no air around it, exactly the part that
                        // makes the effect would be clipped.
                        // SHADOW, which is not the same as OUTLINE. The shader warns
                        // —rightly— that a LIGHT halo stuck to the edge is what
                        // makes something look dirty. A dark shadow BEHIND is the
                        // opposite: on a dark background it does not exist (black
                        // on black) and it only shows where the wallpaper is light,
                        // which is exactly where the bodies were dissolving. With
                        // this the bar can stay without a surface of its own and
                        // still read on any background.
                        MultiEffect {
                            anchors.fill: liquid
                            source: liquid
                            shadowEnabled: true
                            shadowColor: "#000000"
                            shadowOpacity: 0.5
                            shadowBlur: 0.45
                            shadowScale: 1.04
                        }

                        ShaderEffect {
                            id: liquid
                            readonly property real m: 10
                            anchors.centerIn: parent
                            width: wsGroup.implicitWidth + 2 * m
                            height: 24
                            // painted by the MultiEffect above, not the normal tree
                            layer.enabled: true
                            visible: false

                            // MIND THE VERSIONED NAME: Qt CACHES the compiled shader
                            // by URL. Recompiling the .qsb over the same name and
                            // reloading the QML does NOT reload it -- the old one
                            // keeps being painted, without any warning. When the
                            // shader changes, bump the number here and in the file
                            // name, or restart qs.
                            fragmentShader: Qt.resolvedUrl("shaders/liquid.v5.frag.qsb")

                            // Counts the dots ACTUALLY in the row, not the
                            // workspaces Hyprland reports: since we filter out the
                            // special ones they are no longer the same, and if the
                            // shader painted one too many there would be a ghost dot
                            // at the end with nothing clickable underneath.
                            property real count: wsRepeater.count
                            property real stepX: 8 + wsRow.spacing
                            property real first: m + wsGroup.pad + 4
                            property real dotR: 4
                            property real pillR: Math.max(0.5, worm.height / 2)
                            property real pillA: m + worm.x + pillR
                            property real pillB: m + worm.x + worm.width - pillR
                            property real hasPill: worm.live ? 1 : 0
                            property real hoverIdx: wsGroup.hovered
                            // 'k' is how wet it is: the size of the neck. Below ~4
                            // the bodies ignore each other until they touch (and
                            // then it is a collision, not a merge); far above it
                            // everything stays permanently stuck and the row is lost.
                            property real k: 4.5
                            property real w: width
                            property real h: height
                            // Both come from Colors with the contrast already worked
                            // out against the wallpaper: see the big block in
                            // Colors.qml. With a fixed 50 % white and bare
                            // Colors.accent, a monochrome wallpaper left the unlit
                            // dots LIGHTER than the lit pill.
                            property color dotColor: Colors.onWallDim
                            property color pillColor: Colors.onWallAccent
                        }
                    }

                    BarItem {
                        Layout.leftMargin: 6
                        visible: Config.showAppName && ShellState.appName.length > 0
                        label: ShellState.appName
                        labelBold: true
                        interactive: false
                        hpad: 4
                    }
                }

                // ══════════════ barra: derecha ══════════════
                // Only state worth a glance. Conditional things appear and
                // disappear; the controls live in the notch panel.
                RowLayout {
                    id: rightGroup
                    anchors { right: parent.right; rightMargin: root.sideMargin; top: parent.top }
                    height: root.barH
                    spacing: 1

                    // This fork: the right side shows ONLY the battery. The
                    // conditional indicators of the original (screen capture,
                    // minimise, caffeine, updates, do-not-disturb, tray,
                    // bluetooth, offline, mute) are gone; that state lives in
                    // the Control Centre (Super+D). Click: the system panel.
                    // Game mode (Control Centre / launcher). With a game running
                    // under MangoHud: fps, CPU and GPU. Without one, just the
                    // icon, so the mode is never on without you seeing it.
                    // Click turns the mode off.
                    BarItem {
                        id: gameItem
                        visible: ShellState.gameMode
                        readonly property bool low: ShellState.gameRunning && ShellState.gameFps < 30
                        icon: Icons.gamepad
                        iconColor: Colors.accent
                        label: !ShellState.gameRunning ? ""
                            : ShellState.gameFps + " fps  ·  CPU " + ShellState.gameCpu + "%"
                              + "  ·  GPU " + ShellState.gameGpu + "%"
                              + (ShellState.gameCpuTemp > 0 ? "  ·  " + ShellState.gameCpuTemp + "°" : "")
                        labelColor: gameItem.low ? Colors.crit : Colors.fg
                        onClicked: ShellState.toggleGameMode()
                    }

                    BarItem {
                        id: battItem
                        visible: ShellState.batt >= 0
                        readonly property bool low: !ShellState.ac && ShellState.batt <= 15
                        icon: ShellState.battIcon
                        label: ShellState.batt + "%"
                        iconColor: battItem.low ? Colors.crit : (ShellState.ac ? Colors.accent : Colors.fg)
                        labelColor: battItem.low ? Colors.crit : Colors.fg
                        onClicked: ShellState.togglePanel("system")
                    }
                }

                // ══════════════ la burbuja satélite ══════════════
                // A small body that peeks out from BEHIND the notch's right edge
                // while something is running in the background (a countdown, a
                // sync). The data and the priority, in ShellState.bubble*.
                //
                // THREE DECISIONS, and none of them is where to put it:
                //
                // 1. IT IS DECLARED BEFORE THE NOTCH, which means the notch PAINTS
                //    OVER it. It is not an oversight: when the notch grows (an OSD,
                //    a panel) it swallows the bubble, and when it shrinks the
                //    bubble peeks out again. It is exactly the metaphor — something
                //    that was behind — and it comes for free, without a single line
                //    hiding anything.
                //
                // 2. ITS SPOT IS MEASURED AGAINST THE NOTCH AT REST, not against
                //    the current notch. If it followed the live edge, opening the
                //    workspace map (1396 px) would send it flying to the other end
                //    of the screen and back. Staying still behind is right.
                //
                // 3. IT FITS INSIDE THE RESERVED BAND (28 of 32 px). A countdown
                //    lasts minutes: if it stuck out, it would cover a window's
                //    corner for minutes, and that is exactly the rule the whole
                //    notch exists not to break.
                Item {
                    id: bubble

                    readonly property bool on: ShellState.bubbleOn
                    readonly property real h: 28
                    // The notch's right edge AT REST (see decision 2).
                    readonly property real restRight: (surface.width
                        + (root.island ? ShellState.restW : ShellState.restW + 2 * root.flare)) / 2
                    readonly property real hiddenX: restRight - h * 0.62
                    readonly property real shownX: restRight + 8

                    // A single number governs entry and exit: 0 = hidden behind,
                    // 1 = fully out. On a spring, so if the timer is cancelled
                    // while it is still coming out, it does not cut: it carries
                    // the movement back inwards with the velocity it had.
                    property real reveal: on ? 1 : 0
                    Behavior on reveal {
                        SpringAnimation { spring: Appearance.sprPanel; damping: Appearance.dmpPanel; epsilon: Appearance.eppScale }
                    }

                    readonly property bool wide: bubbleMa.containsMouse || ShellState.bubbleAlert

                    x: hiddenX + (shownX - hiddenX) * reveal
                    y: notch.gap + (root.barH - notch.gap - h) / 2
                    height: h
                    width: h + (wide ? label.implicitWidth + 16 : 0)
                    Behavior on width { SpringAnimation { spring: Appearance.sprTight; damping: Appearance.dmpTight; epsilon: Appearance.eppPx } }

                    opacity: reveal
                    scale: 0.55 + 0.45 * reveal
                    transformOrigin: Item.Left
                    visible: reveal > 0.01

                    Rectangle {
                        anchors.fill: parent
                        radius: height / 2
                        color: win.notchColor
                    }

                    // ── the ring ──
                    // With known progress it draws what is LEFT (it empties
                    // clockwise); without it, it spins. A spinning arc says "still
                    // going" without lying about how much is left, which is what an
                    // indeterminate bar faking a percentage does.
                    Shape {
                        id: ring
                        width: bubble.h; height: bubble.h
                        preferredRendererType: Shape.CurveRenderer
                        antialiasing: true
                        readonly property real det: ShellState.bubbleProgress
                        readonly property real r: bubble.h / 2 - 2.5

                        ShapePath {
                            strokeColor: Colors.fill1
                            strokeWidth: 2
                            fillColor: "transparent"
                            capStyle: ShapePath.RoundCap
                            PathAngleArc {
                                centerX: bubble.h / 2; centerY: bubble.h / 2
                                radiusX: ring.r; radiusY: ring.r
                                startAngle: 0; sweepAngle: 360
                            }
                        }
                        ShapePath {
                            strokeColor: ShellState.bubbleAlert ? Colors.crit : Colors.accent
                            strokeWidth: 2.5
                            fillColor: "transparent"
                            capStyle: ShapePath.RoundCap
                            PathAngleArc {
                                centerX: bubble.h / 2; centerY: bubble.h / 2
                                radiusX: ring.r; radiusY: ring.r
                                startAngle: -90
                                // 300 degrees and not 360 in indeterminate mode: a
                                // full circle spinning is a circle standing still.
                                sweepAngle: ring.det >= 0 ? 360 * ring.det : 300
                            }
                        }
                        // The spin is the whole arc's and only exists without progress.
                        RotationAnimation on rotation {
                            running: ring.det < 0 && bubble.on
                            from: 0; to: 360
                            duration: 1100
                            loops: Animation.Infinite
                        }
                        onDetChanged: if (det >= 0) rotation = 0
                    }

                    Text {
                        x: (bubble.h - implicitWidth) / 2
                        anchors.verticalCenter: parent.verticalCenter
                        text: ShellState.bubbleIcon
                        color: ShellState.bubbleAlert ? Colors.crit : Colors.label
                        font.family: Appearance.font
                        font.pixelSize: Appearance.fsS
                    }

                    Text {
                        id: label
                        x: bubble.h + 2
                        anchors.verticalCenter: parent.verticalCenter
                        text: ShellState.bubbleLabel
                        color: Colors.label
                        font.family: Appearance.fontUI
                        font.pixelSize: Appearance.fsS
                        font.weight: Font.DemiBold
                        font.features: ({ "tnum": 1 })   // the seconds must not move the pill
                        opacity: bubble.wide ? 1 : 0
                        visible: opacity > 0.01
                        Behavior on opacity { NumberAnimation { duration: Appearance.mQuick } }
                    }

                    MouseArea {
                        id: bubbleMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        acceptedButtons: Qt.LeftButton | Qt.RightButton
                        onClicked: function (m) {
                            if (ShellState.bubbleKind !== "timer") return;
                            if (m.button === Qt.RightButton) ShellState.timerClear();
                            else ShellState.timerToggle();
                        }
                    }
                }

                // ══════════════ el notch ══════════════
                Item {
                    id: notch
                    readonly property real gap: root.topGap
                    // Safety net: if a panel does not handle Escape, the key bubbles
                    // up to here and it closes anyway. No panel can leave you
                    // trapped.
                    focus: true
                    Keys.onEscapePressed: function (e) { ShellState.closePanel(); e.accepted = true; }

                    width: root.island ? nw : nw + 2 * root.flare
                    height: nh - notch.gap
                    x: (surface.width - width) / 2
                    y: notch.gap

                    property real nw: win.faceW
                    property real nh: win.faceH
                    // Both axes used to share the SAME duration and the same
                    // curve, and that is why the notch rescaled like a box
                    // instead of deforming. Now each axis has its own spring:
                    // the width pulls hard and arrives first, the height is
                    // slack, follows it and overshoots a little on landing. The
                    // notch OPENS -- first it widens, then it drops -- instead of
                    // inflating all at once. It is textbook squash & stretch,
                    // and rb (the rounding of the bottom corners) is computed
                    // from height too, so the shape curves by itself along the
                    // way.
                    Behavior on nw { SpringAnimation { spring: Appearance.sprTight; damping: Appearance.dmpTight; epsilon: Appearance.eppPx } }
                    Behavior on nh { SpringAnimation { spring: Appearance.sprLoose; damping: Appearance.dmpLoose; epsilon: Appearance.eppPx } }

                    readonly property real fl: root.flare
                    readonly property real rb: Math.max(6, Math.min(root.roundMax, height - fl - 1))

                    // ---- island mode: a pill rounded on all four sides ----
                    Rectangle {
                        anchors.fill: parent
                        visible: root.island
                        radius: Math.min(root.roundMax, height / 2)
                        color: win.notchColor
                    }

                    // ---- notch mode: top corners INVERTED against the edge ----
                    Shape {
                        anchors.fill: parent
                        visible: !root.island
                        preferredRendererType: Shape.CurveRenderer
                        antialiasing: true

                        ShapePath {
                            id: sp
                            fillColor: win.notchColor
                            strokeWidth: 0
                            strokeColor: "transparent"

                            readonly property real fl: notch.fl
                            readonly property real rb: notch.rb
                            readonly property real w: notch.nw
                            readonly property real h: notch.height
                            readonly property real k: root.kArc
                            readonly property real ik: 1 - k

                            startX: 0; startY: 0
                            // inverted top-left corner
                            PathCubic {
                                control1X: sp.fl * sp.k; control1Y: 0
                                control2X: sp.fl;        control2Y: sp.fl * sp.ik
                                x: sp.fl;                y: sp.fl
                            }
                            PathLine { x: sp.fl; y: sp.h - sp.rb }
                            PathCubic {
                                control1X: sp.fl;                 control1Y: sp.h - sp.rb * sp.ik
                                control2X: sp.fl + sp.rb * sp.ik; control2Y: sp.h
                                x: sp.fl + sp.rb;                 y: sp.h
                            }
                            PathLine { x: sp.fl + sp.w - sp.rb; y: sp.h }
                            PathCubic {
                                control1X: sp.fl + sp.w - sp.rb * sp.ik; control1Y: sp.h
                                control2X: sp.fl + sp.w;                 control2Y: sp.h - sp.rb * sp.ik
                                x: sp.fl + sp.w;                         y: sp.h - sp.rb
                            }
                            PathLine { x: sp.fl + sp.w; y: sp.fl }
                            // inverted top-right corner
                            PathCubic {
                                control1X: sp.fl + sp.w;                control1Y: sp.fl * sp.ik
                                control2X: sp.fl + sp.w + sp.fl * sp.k; control2Y: 0
                                x: sp.fl + sp.w + sp.fl;                y: 0
                            }
                            PathLine { x: 0; y: 0 }
                        }
                    }

                    // Delay before opening the "peek": if you only pass the mouse
                    // over it, the notch does not move.
                    Connections {
                        target: Config
                        function onHoverPreviewChanged() {
                            if (!Config.hoverPreview) { dwell.stop(); ShellState.hovered = false; }
                        }
                    }
                    Timer { id: dwell; interval: Config.hoverDelay; onTriggered: if (Config.hoverPreview) ShellState.hovered = true }

                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        acceptedButtons: Qt.LeftButton | Qt.RightButton
                        cursorShape: Qt.PointingHandCursor
                        onEntered: if (Config.hoverPreview) dwell.restart()
                        onExited: { dwell.stop(); ShellState.hovered = false; }
                        onClicked: function (m) {
                            if (m.button === Qt.RightButton && ShellState.player)
                                ShellState.player.isPlaying ? ShellState.player.pause() : ShellState.player.play();
                            else ShellState.togglePanel("control");
                        }
                        // Two axes, two things. The vertical one was all there was
                        // and it is unchanged (volume); the horizontal one did
                        // nothing and now switches workspace. The absolute values
                        // are compared to decide which wins: a touchpad always sends
                        // something on both axes, and without this a vertical
                        // gesture a hair off course would switch your workspace as
                        // you turned the volume up.
                        // Only with the notch at rest: with a panel open the wheel
                        // belongs to the panel (a scrolling list, a drag).
                        onWheel: function (w) {
                            const dx = w.angleDelta.x, dy = w.angleDelta.y;
                            if (Math.abs(dx) > Math.abs(dy)) {
                                // The workspace gesture only with the notch at rest:
                                // with a panel open the wheel belongs to the panel.
                                if (!ShellState.open) ShellState.scrollWorkspace(dx);
                                return;
                            }
                            // The `dy !== 0` is not superfluous: `dy > 0 ? 1 : -1`
                            // turns a zero into -1, so a purely horizontal gesture
                            // turned the volume down without anyone asking.
                            if (dy !== 0) ShellState.nudgeVolume(dy > 0 ? 1 : -1);
                        }
                    }

                    NotchContent {
                        mode: win.faceMode
                        x: root.island ? 0 : notch.fl
                        y: 0
                        width: notch.nw
                        height: notch.height
                        clip: true
                    }
                }
            }
        }
    }
}
