// ShellState.qml — data and state hub for the top surface.
//
// In caelestia's style (services/): all the logic and the data live here, and
// TopShell.qml stays pure UI. That way the bar and the notch read EXACTLY the
// same state and cannot fall out of sync.
//
// Parts with a life of their own live in their own singletons, so this file
// keeps what the whole notch shares: which panel is open, its face and size,
// the clock, the active window and the focused monitor. The others: Launcher,
// Satellite, BluetoothPairing, AudioSpectrum, Media, Audio, Brightness,
// SystemStats, NetworkState, BluetoothState, Updates, NotificationCenter,
// NightLight, Weather, GitHub, GameMode and Caffeine.

pragma Singleton

import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Networking
import Quickshell.Bluetooth
import Quickshell.Services.Mpris
import Quickshell.Services.Notifications
import Quickshell.Services.Pipewire
import Quickshell.Services.UPower
import QtQuick

Singleton {
    id: root

    readonly property string home: Quickshell.env("HOME")
    // The locale with which the WHOLE shell formats dates and numbers. It has
    // to follow the language: with the shell in English, a "miércoles" in the
    // notch sticks out as much as an untranslated label.
    //
    // en_GB and not en_US because this repo's English is the British of the
    // README ("recoloured", "licence", "centre"), and because the format fits:
    // en_GB puts the day before the month (3/9/2026) and the time in 24 h, just
    // like Spanish. With en_US the date would flip round (9/3/2026) and "PM"
    // would appear, which nobody here uses.
    readonly property var loc: Qt.locale(I18n.english ? "en_GB" : (I18n.lang === "pt" ? "pt_BR" : "es_ES"))

    // ═════════════════════════ notch state ══════════════════════════
    // The notch is the desktop's entry point: panels unfold from it.
    // "" = none. Adding a new one = one more value here, its size in
    // notchW/notchH, and its layer in NotchContent.qml.
    // Control Centre page to open on (0 painel, 1 wallpapers, 2 sistema);
    // read and reset by ControlPanel when it opens. See `notch controlPage`.
    property int controlPage: 0
    // Extra of the Sistema page to open on (its file name without .qml, from
    // ~/.local/share/glasstty/extras/); read and reset by ControlPanel. See
    // `notch extra`.
    property string controlExtra: ""
    property string panel: ""     // "" | "control" | "system" | "launcher" | "power" | "display" | "network" | "bluetooth" | "overview" | "calendar" | "github"
    readonly property bool open: panel !== ""

    // The edge-revealed organiser is independent of the notch and remembers
    // its enabled state across shell and session restarts.
    readonly property bool stageEnabled: Config.stageEnabled
    function toggleStage() {
        // niri already ships the thing the Stage Manager imitates: an overview
        // of every workspace with live windows. There the shortcut opens it
        // (see the niri notes in StageWindow.qml).
        if (Compositor.isNiri) { root.closePanel(); Compositor.toggleOverview(); return; }
        if (root.stageEnabled) { root.closeStage(); return; }
        root.closePanel();
        Config.stageEnabled = true;
        Compositor.refreshToplevels();
    }
    function closeStage() { Config.stageEnabled = false; }

    // The Settings app is NOT a notch panel (see SettingsWindow.qml), but it
    // is launched from it, so its state lives here.
    property bool settingsOpen: false
    function toggleSettings() { root.settingsOpen = !root.settingsOpen; }

    // Open Settings ALREADY ON a specific section, instead of the usual one.
    // Super+K is the first to use it; until now it launched a separate rofi
    // (~/.config/glasstty/list_keybinds.sh) to show a list of shortcuts taken
    // from the SAME hyprland.conf that SettingsShortcuts.qml already reads.
    // Another view was not needed: a door into the existing one was.
    //
    // It goes through a signal and not a property here because what decides
    // which section is shown is the Settings window; ShellState only knows
    // whether it is open or closed.
    signal settingsSection(string id)
    function openSettingsAt(id) { root.settingsSection(id); }

    // Settings search. It lives here and not in the window because what
    // decides whether a row is shown is the row itself (SettingsControls.Row_),
    // which is an inline component and cannot reach the window's id.
    property string settingsQuery: ""
    function settingsFold(value) {
        // Searching "bateria" must find "Batería": when typing fast it makes
        // no sense to demand exact accents in a settings search box.
        return String(value).toLowerCase().normalize("NFD").replace(/[\u0300-\u036f]/g, "");
    }
    function settingsMatch(label, hint) {
        const q = root.settingsFold(root.settingsQuery.trim());
        if (q.length === 0) return true;
        return root.settingsFold(String(label) + " " + String(hint)).indexOf(q) >= 0;
    }

    // A setting's description does NOT go under its label: it would always be
    // visible, would make every row three lines tall, and a 520 px window would
    // only fit seven settings. It goes to a fixed strip at the foot of the window,
    // which shows the one for the setting under the mouse. Zero reflow, zero
    // popups covering things, and not a single word is lost.
    property string settingsHint: ""

    function togglePanel(name) {
        // The launcher is the only panel that opens in several modes, so it has
        // its own door (openLauncher). Through here you ALWAYS enter "apps":
        // neither Super+R nor the Arch logo asks for the clipboard or windows.
        if (name === "launcher") { Launcher.openLauncher("apps"); return; }
        root.panel = (root.panel === name) ? "" : name;
    }
    function closePanel() { root.panel = ""; }

    // The transient dies with the panel, on opening it AND on closing it. It is
    // the other half of the fix above: flash() stops it being BORN covered, and
    // this stops it SURVIVING a panel that opens afterwards. It goes on the
    // property change and not in closePanel() because there are seven places
    // that assign `root.panel` by hand (the ">" mode actions, openLauncher, the
    // toggle) and all of them would have to remember.
    onPanelChanged: {
        if (root.panel !== "") {
            // A PANEL OPENS. Whatever expires with the gesture that caused it
            // -volume, brightness, workspace, song, notification- is dropped:
            // showing it later is noise. What is NOT dropped is frozen: the
            // "Copiado" (Copied) receipt, which was born of a gesture of yours
            // inside the panel.
            if (root.activity === "toast") {
                activityTimer.stop();
            } else if (root.activity !== "") {
                root.activity = "";
                activityTimer.stop();
            }
        } else {
            // IT CLOSES. Whatever was frozen starts now, with its full clock.
            if (root.activity !== "")
                activityTimer.restart();
        }
    }
    property bool hovered: false             // mouse over the notch
    property string activity: ""             // "" | "volume" | "brightness" | "track"
    property bool armed: false               // start-up is over: OSDs are allowed

    Timer { interval: 1500; running: true; onTriggered: root.armed = true }
    Timer { id: activityTimer; onTriggered: root.activity = "" }
    // Puts out the current face now (a notification closed by its app, say).
    function stopActivity(): void { root.activity = ""; activityTimer.stop(); }

    function flash(kind, ms) {
        // WITH A PANEL IN FRONT THERE IS NO NOTICE TO GIVE.
        //
        // `mode` puts `panel !== ""` first, so with any panel open the notice
        // is not seen. But the clock started anyway: you moved the volume in
        // the control centre, closed it, and the OSD came out AFTERWARDS, when
        // it was no longer relevant. With a notification it is worse, because
        // the clock is 4200 or 11000 ms. It is dropped at the source, as
        // impasto's IslandState.qml:96-107 does.
        //
        // The "Copiado" (Copied) receipt is spared on purpose: it was born of a
        // gesture of yours INSIDE the panel -clicking in the launcher's
        // clipboard- and seeing it a moment late is better than not seeing it.
        if (root.panel !== "" && kind !== "toast")
            return;
        root.activity = kind;
        // "ws" lasts less than the rest on purpose: it is not information you
        // have to read, it is the receipt of a gesture you have just made.
        // A volume OSD is looked at; this one is only checked out of the corner
        // of your eye. An explicit duration wins: today only notifications use
        // it, being the only ones that bring a time requested from outside (see
        // notifFlashMs). The other callers pass a single argument, so ms arrives
        // undefined and the notch lasts exactly as long as it did.
        activityTimer.interval = (ms !== undefined && ms > 0) ? ms
            : (kind === "track" || kind === "notif") ? 4200
            : kind === "toast" ? 1600
            : kind === "ws" ? 1100
            : kind === "charge" ? 2200
            : kind === "device" ? 2600
            : kind === "gamesum" ? 9000
            : 1800;
        // Covered does not count. The only one that gets here with a panel in
        // front is the "Copiado" receipt, and onPanelChanged starts its clock on
        // uncovering: that way it is read in full instead of arriving half spent.
        if (root.panel === "")
            activityTimer.restart();
    }

    // "There is music playing AND it rules the notch". The WHOLE music face
    // hangs off this: the resting width (restW), the face, the shifted clock,
    // the hidden date and battery and the cava visualiser. `mediaDrives`
    // —defined next to the MPRIS block— is what leaves the browser out.
    readonly property bool mediaLive: Media.player !== null && Media.player.isPlaying && Media.mediaDrives

    // btpair goes AHEAD of the open panel, and it is the only face that breaks
    // that rule. It is not a notice: it is a question with an expiry, with a
    // device waiting on the other side. If it stayed behind whatever panel you
    // had open, the pairing would expire without you ever seeing it.
    readonly property string mode: BluetoothPairing.btAsking ? "btpair"
        : panel !== "" ? panel
        : activity === "notif" ? "notif"
        : activity === "toast" ? "toast"
        : activity === "track" ? "track"
        : activity === "ws" ? "ws"
        : activity === "charge" ? "charge"
        : activity === "device" ? "device"
        : activity === "gamesum" ? "gamesum"
        : activity !== "" ? "activity"
        : hovered ? "peek"
        : mediaLive ? "media" : "idle"

    // Target geometry of the notch (a loose island stuck to the top edge).
    // RULE: at rest and with music the height is EXACTLY the reserved band
    // (barH) so that the notch never covers any window. It only sticks out
    // when you cause something: hover, OSD, song change or the panel.
    readonly property int bandH: Config.bandH

    // Gap between the screen edge and the pill in island mode. It lives here and
    // not only in TopShell because the panels that compute their exact height
    // have to subtract it: TopShell draws the notch with `height: notchH - gap`.
    readonly property int notchTopGap: Config.island ? Config.islandGap : 0

    // No panel can be wider than the screen it appears on. The widths below
    // were chosen looking at THIS laptop, where they fit with room to spare (the
    // fattest, the control centre, is 1080 on 1920: 420 px of air per side).
    // But they are fixed numbers, and on a narrower output the notch would spill
    // over both sides with its content cut off and no warning at all. 48 px of
    // breathing room on each side; if the screen is not known yet, nothing is
    // trimmed, which is how it has behaved until today.
    readonly property int notchW: Math.min(root.notchWWanted, root.maxNotchW)
    readonly property int maxNotchW: {
        const s = root.focusedScreen;
        return (s && s.width > 0) ? Math.max(220, s.width - 96) : 100000;
    }
    readonly property int notchWWanted: mode === "launcher" ? 660
        : mode === "btpair" ? 470
        : mode === "overview" ? ovW
        : mode === "control" ? 880
        : mode === "system" ? 920
        : mode === "network" || mode === "bluetooth" ? 470
        : mode === "power" ? 520
        : mode === "display" ? 560
        : mode === "calendar" ? 350
        // 53 columns of 9 px with 2 of air = 581, plus the column of weekday
        // initials and the margin. The whole year cannot get narrower without
        // shrinking the square, and below 9 px you can no longer tell which is which.
        : mode === "github" ? 640
        : mode === "notif" ? 430
        : mode === "toast" ? 330
        : mode === "ws" ? 220
        : mode === "charge" ? 260
        : mode === "device" ? 340
        : mode === "gamesum" ? 470
        : mode === "track" ? 400
        : mode === "peek" ? 380
        : mode === "activity" ? 330
        : mode === "media" ? root.mediaW : root.idleW

    readonly property int mediaW: 268

    // Width of the notch in its RESTING face: the time alone, or the music one
    // if something is playing. The PASSING faces (panels, OSD, the song-change
    // flash, the map) do not count: those really do have to swallow the
    // satellite bubble and give it back as they shrink, which is the metaphor.
    //
    // This used to be plain `idleW` and the bubble stayed under the notch for
    // the whole of playback: with music on -i.e. nearly always- a running
    // countdown was invisible.
    readonly property int restW: root.mediaLive ? root.mediaW : root.idleW

    // The launcher fits what there is: if you search for something and three apps
    // come up, or it is a sum, the panel shrinks upwards instead of leaving a
    // black hole. LauncherPanel publishes here how many rows it has after each search.
    property int launcherRows: 0
    property bool launcherCalc: false
    // The favourites row only exists with the field empty, so it too enters
    // and leaves the panel's height just like the calculator's.
    property bool launcherFavs: false

    // CAREFUL with these constants: they have to match LauncherPanel.qml's margins
    // EXACTLY. If they fall short, the list gets less height than its rows take
    // up and the last one is clipped at the bottom.
    //   4 (topMargin) + 50 (search box) + 1 + 6 (separator) + 12 (bottom margin)
    readonly property int launcherChrome: 73
    // The row height depends on the MODE, and it is the only one that departs
    // from 48: a clipboard entry shows a real thumbnail, not a 30 px icon, and at
    // 48 the images could not be told apart.
    readonly property int launcherRowH: Launcher.launcherMode === "clip" ? 60 : 48
    readonly property int launcherCalcH: 62      // 56 for the row + 6 of margin
    readonly property int launcherFavH: 70       // 58 for the row + 12 of margin
    readonly property int launcherMaxRows: 7     // beyond this, scrolling

    readonly property int launcherH: {
        const calc = root.launcherCalc ? root.launcherCalcH : 0;
        const favs = root.launcherFavs ? root.launcherFavH : 0;
        const rows = Math.min(root.launcherRows, root.launcherMaxRows) * root.launcherRowH;
        const vacio = (root.launcherRows === 0 && !root.launcherCalc) ? 46 : 0;  // "Sin resultados"
        // Island mode's gap is NOT usable height: TopShell lifts the pill off the
        // edge with `height: nh - gap`, so the content gets islandGap less than
        // this calculation asks for. Without adding it here, the list (fillHeight)
        // swallows the shortfall and clips the last row right at its rounded
        // corners — it shows most with a single result.
        // The island gap is NO longer added here: notchH adds it for all the
        // panel faces at once (see the carasDePanel block).
        return root.launcherChrome + calc + favs + rows + vacio;
    }

    // Config.idleW is the width for the time ALONE. If you turn the date or the
    // battery back on in Settings, the notch widens by itself: with a fixed
    // width, re-enabling them would leave the content clipped.
    readonly property int idleW: Config.idleW
        + (Config.showDate ? 92 : 0)
        + (Config.showBattery ? 64 : 0)
    // PANEL FACES ADD THE ISLAND GAP; NOTICE FACES DO NOT, AND IT IS NOT AN
    // OVERSIGHT.
    //
    // TopShell draws the notch with `y: gap` and `height: nh - gap`, so the
    // BOTTOM edge always lands at `nh` and the gap is eaten from the height. For
    // a panel face that matters: it declares the height its content needs and
    // without adding the gap it gets four pixels less -the control centre
    // measured 522 where it declared 526-. For the notice faces and the resting
    // one it is NOT added on purpose: there `nh` is the reserved band, and adding
    // the gap would push the bottom edge OUT of the band, i.e. the notch would
    // cover windows.
    //
    // Four faces added it by hand and seven had been left out (btpair,
    // overview, control, system, network, bluetooth and power), with the comment
    // next to them admitting it. It did not show today because those panels'
    // fillHeight spacers swallowed the 4 px; it was an inconsistency waiting for
    // someone to remove a spacer. Now there is a single list and it lives here,
    // so adding a panel face does not rely on remembering.
    readonly property var carasDePanel: ["launcher", "btpair", "overview", "control", "system",
                                         "network", "bluetooth", "power", "display", "calendar", "github"]
    readonly property int notchGapDeCara: root.carasDePanel.indexOf(root.mode) >= 0 ? root.notchTopGap : 0

    readonly property int notchH: root.notchBaseH + root.notchGapDeCara

    readonly property int notchBaseH: mode === "launcher" ? launcherH
        : mode === "btpair" ? (BluetoothPairing.btKind === "display" ? 96 : 112)
        : mode === "overview" ? ovH
        : mode === "control" ? 420
        : mode === "system" ? 420
        : mode === "network" || mode === "bluetooth" ? 412
        : mode === "power" ? 158
        : mode === "display" ? 158
        : mode === "calendar" ? 320
        : mode === "github" ? 318
        : mode === "notif" ? 66
        : mode === "toast" ? 44
        : mode === "ws" ? 44
        : mode === "charge" ? 46
        : mode === "device" ? 46
        : mode === "gamesum" ? 72
        : mode === "track" ? 52
        : mode === "peek" ? 44
        : mode === "activity" ? 42
        : bandH

    // ═════════════════════════ workspace overview ══════════════════════════
    // The overview grid (OverviewPanel.qml) sizes ITSELF from the monitor: each
    // cell is the screen's usable area to scale. It is here and not in the
    // panel because the notch has to know how big it will be BEFORE the panel
    // exists — the shape morph starts on the same frame as the layer.
    //
    // 5x2 is not a pretty number: it is exactly the ten workspaces that
    // hyprland.conf binds to Super+1..0. If one day there were twelve, this and
    // the shortcuts have to change together or the map would lie.
    readonly property int ovCols: 5
    readonly property int ovRows: 2
    readonly property int ovCount: ovCols * ovRows

    // The scale. 0.14 comes from a real constraint: 5 cells + gaps + air have
    // to fit comfortably in 1920 px, and a cell below ~250 px wide no longer
    // lets you recognise a window by its content, which is the only thing that
    // justifies capturing live instead of painting icons.
    readonly property real ovScale: 0.14
    readonly property real ovGap: 6          // gap between cells
    readonly property real ovPad: 14         // air at the sides and at the bottom
    readonly property real ovPadTop: 16
    readonly property real ovFooterH: 24     // the strip with the title of the pointed-at window

    // The reserved band (`reserved`) is subtracted, not the whole height: windows
    // are placed inside the USABLE area, so if the cell stood for the full screen
    // they would all come out shifted 32 px upwards.
    // It is looked up by NAME with the focus we already have seeded (see
    // focusedMon, further down) instead of trusting Hyprland.focusedMonitor: that
    // property is born empty and is only filled on the first event, so with the
    // shell freshly started the overview was drawn with the 1920x1080 fallback.
    // On this laptop it went unnoticed because the panel MEASURES 1920x1080; on
    // a screen of another size the cells come out with the wrong proportion and
    // the thumbnails do not match the real windows.
    readonly property var ovMon: {
        const ms = Compositor.monitors;
        for (let i = 0; i < ms.length; i++)
            if (ms[i] && ms[i].name === root.focusedMon) return ms[i].lastIpcObject;
        return ms.length > 0 && ms[0] ? ms[0].lastIpcObject : null;
    }
    // And if not even that, Quickshell's screen rather than a fixed number.
    readonly property real ovMonW: (ovMon && ovMon.width) ? ovMon.width
        : (root.focusedScreen ? root.focusedScreen.width : 1920)
    readonly property real ovMonH: (ovMon && ovMon.height) ? ovMon.height
        : (root.focusedScreen ? root.focusedScreen.height : 1080)
    readonly property var ovRes: (ovMon && ovMon.reserved) ? ovMon.reserved : [0, bandH, 0, 0]
    readonly property real ovCellW: (ovMonW - ovRes[0] - ovRes[2]) * ovScale
    readonly property real ovCellH: (ovMonH - ovRes[1] - ovRes[3]) * ovScale
    readonly property real ovGridW: ovCols * ovCellW + (ovCols - 1) * ovGap
    readonly property real ovGridH: ovRows * ovCellH + (ovRows - 1) * ovGap
    readonly property int ovW: Math.round(ovGridW + 2 * ovPad)
    readonly property int ovH: Math.round(ovPadTop + ovGridH + ovFooterH + ovPad)

    // ═══════════════════════ clock ═══════════════════════
    property var now: new Date()
    Timer { interval: 1000; running: true; repeat: true; onTriggered: root.now = new Date() }

    // ═══════════════════════ active window ════════════════════════
    readonly property var activeToplevel: ToplevelManager.activeToplevel
    readonly property bool fullscreen: activeToplevel ? activeToplevel.fullscreen : false
    readonly property string appName: {
        if (!activeToplevel || !activeToplevel.appId) return "";
        const a = String(activeToplevel.appId).split(".").pop();
        return a.charAt(0).toUpperCase() + a.slice(1);
    }
    readonly property string winTitle: activeToplevel ? (activeToplevel.title || "") : ""

    // ═══════════════════ horizontal wheel over the notch ═══════════════════
    // The idea comes from Tide-island (swiping over the island does something),
    // but there the gesture changes FACE and here that does not fit: in this
    // shell each face comes from a specific state or button, not from a
    // carousel. What was going spare was the horizontal axis, which did
    // nothing. Now it changes workspace.
    //
    // Two details that set it apart from "subtract and add one":
    //
    // · IT ACCUMULATES. A touchpad does not send one event per gesture, it sends
    //   a burst of dozens; without accumulating, a short drag would take you
    //   across all ten workspaces at once. 120 is the equivalent of one wheel
    //   notch, which is the unit Qt uses for "one step".
    //
    // · IT GOES TO `e+1`, NOT TO `id+1`. It is exactly what the vertical wheel
    //   with Super does in hyprland.lua: it jumps to the next workspace that
    //   EXISTS. Adding to the id would drop you into empty workspaces you had
    //   not created, and the overview map shows them anyway.
    property real wsAccum: 0
    Timer { id: wsAccumReset; interval: 350; onTriggered: root.wsAccum = 0 }

    function scrollWorkspace(dx) {
        root.wsAccum += dx;
        wsAccumReset.restart();
        while (Math.abs(root.wsAccum) >= 120) {
            const dir = root.wsAccum > 0 ? 1 : -1;
            root.wsAccum -= dir * 120;
            // `e+1` goes IN QUOTES. Since 0.55 the argument to `dispatch` is
            // a Lua expression (see the long note in OverviewPanel.qml), and
            // there the workspace target is of two kinds depending on what you
            // ask for: a bare number for "go to 3", but a STRING for symbolic
            // targets such as `e+1`. Without the quotes, Lua reads `e` as a
            // variable that does not exist and blows up with a syntax error.
            Compositor.focusWorkspaceRelative(dir);
            // The flash is requested AT ONCE, without waiting for Hyprland to
            // answer: the face reads the active workspace through a live binding,
            // so if the first frame arrives with the old number it corrects
            // itself on the next one, and that happens inside the entry
            // animation itself.
            root.flash("ws");
        }
    }

    // niri does not tell clients about exclusive zones; Compositor needs the
    // bar's to place tiled windows in the overview thumbnails.
    Binding { target: Compositor; property: "reservedTop"; value: Config.reserveSpace ? root.bandH : 0 }

    readonly property int activeWs: Compositor.focusedWorkspace ? Compositor.focusedWorkspace.id : 1

    // ───────────────── focused monitor ─────────────────
    // With several screens, the bar is drawn on ALL of them but the panels and
    // the overlays appear only on this one. Name of the output, e.g. "eDP-1".
    //
    // Hyprland.focusedMonitor is NOT used: in Quickshell 0.3.0 that property is
    // born empty —like focusedWorkspace and monitor.focused— and is only filled
    // when the first event arrives. With the shell freshly started it would not
    // know where the focus is until you changed monitor by hand, and until then
    // the panels would not appear anywhere. Checked with test instances:
    // neither refreshMonitors() nor refreshWorkspaces() seeds it. So hyprctl is
    // asked once and from then on the events rule.
    property string focusedMon: ""

    // The same idea but as a screen object, which is what the loose surfaces
    // (wallpaper picker, media controls) ask for in order to appear only where
    // you are looking. If the focus is not known yet, the first screen: better
    // that it appears somewhere than nowhere.
    readonly property var focusedScreen: {
        const ss = Quickshell.screens;
        for (let i = 0; i < ss.length; i++)
            if (ss[i].name === root.focusedMon) return ss[i];
        return ss.length > 0 ? ss[0] : null;
    }

    Process {
        id: monSeed
        command: ["sh", "-c", "niri msg --json focused-output | jq -r '.name // empty'"]
        stdout: SplitParser {
            onRead: function (line) {
                const n = String(line).trim();
                if (n !== "") root.focusedMon = n;
            }
        }
    }
    function reseedMonitor(): void { monSeed.running = false; monSeed.running = true; }
    Component.onCompleted: root.reseedMonitor()

    // One pass per burst of events, and with some slack: plugging in a screen
    // emits several events in a row, and awww needs the output to exist to be
    // able to paint it. The script does nothing if no output is blank, which is
    // the case for nearly every trigger.
    Timer {
        id: awwwHotplug
        interval: 700
        onTriggered: Quickshell.execDetached([root.home + "/.config/glasstty/awww-hotplug.sh"])
    }

    Connections {
        target: Compositor
        function onRawEvent(ev) {
            const n = String(ev.name);
            if (n === "focusedmon" || n === "focusedmonv2") {
                // data = "NAME,workspace" (v2 sends the workspace id)
                const m = String(ev.data).split(",")[0].trim();
                if (m !== "") root.focusedMon = m;
            } else if (n.indexOf("monitor") === 0) {
                // monitoradded / monitorremoved / their v2s: the list of
                // outputs changed, so we have to ask again who has the focus.
                root.reseedMonitor();
                // And the screen that has just come in needs a wallpaper. awww does
                // NOT repaint a reconnected output, and on purpose: its installed
                // README (0.12.1, :187-197) says they removed that and that
                // "you should use a program that lets you run commands when a
                // new output is connected". Here was the gap: a grep for awww over
                // ~/.config/quickshell did not return A SINGLE line, and the only
                // thing that knew how to do it -awww-start.sh- hangs off
                // hl.on("hyprland.start"), which does not repeat during the session.
                // It is the same as impasto's WallpaperService.qml:91-108.
                awwwHotplug.restart();
            }
        }
    }

    // ═════════════════════════ screen capture ══════════════════════════
    // Hyprland reports it on its event socket: "screencast>>state,owner".
    //
    // MEASURED on this laptop, and it is exactly what makes this non-trivial:
    //   grim (screenshot)      -> 1,monitor  …  0,monitor
    //   a region recording     -> 1,region
    //   YOUR OWN overview      -> 1,window, ONE PER WINDOW
    // So counting every event would light up the "you are being recorded"
    // notice every time you press Super+Tab. Only monitor and region count.
    //
    // And the delay is not for the sake of it either: a grim screenshot opens
    // and closes the capture in under half a second. Without waiting, the bar
    // would flash red every time you take a screenshot, which is exactly when
    // you least want a new element appearing on the screen.
    property int castCount: 0
    property bool casting: false
    Timer { id: castArm; interval: 1500; onTriggered: root.casting = root.castCount > 0 }

    Connections {
        target: Compositor
        function onRawEvent(ev) {
            if (String(ev.name) !== "screencast") return;
            const p = String(ev.data).split(",");
            if (p.length < 2) return;
            if (p[1] !== "monitor" && p[1] !== "region") return;
            root.castCount = Math.max(0, root.castCount + (p[0] === "1" ? 1 : -1));
            if (root.castCount > 0) {
                castArm.restart();
            } else {
                castArm.stop();
                root.casting = false;
            }
        }
    }

    // ══════════════════ python environment in the prompt ══════════════════
    // The (name) that opens the prompt when you have a venv or a conda active.
    // The preference is stored by ~/.local/bin/prompt-env and read by
    // ~/.config/p10k/diego-theme.zsh WHEN THE TERMINAL OPENS: the ones you
    // already have open stay as they were, which is why the setting warns you.
    property bool promptEnv: true
    function togglePromptEnv() {
        root.promptEnv = !root.promptEnv;
        Quickshell.execDetached([root.home + "/.local/bin/prompt-env",
            root.promptEnv ? "on" : "off"]);
    }
    Process {
        id: promptEnvProbe
        command: [root.home + "/.local/bin/prompt-env", "is-on"]
        running: true
        stdout: SplitParser {
            onRead: function (line) { root.promptEnv = line.trim() === "on"; }
        }
    }


}
