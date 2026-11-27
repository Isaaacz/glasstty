// ShellState.qml — data and state hub for the top surface.
//
// In caelestia's style (services/): all the logic and the data live here, and
// TopShell.qml stays pure UI. That way the bar and the notch read EXACTLY the
// same state and cannot fall out of sync.
//
// Parts with a life of their own live in their own singletons: Launcher.qml
// (the launcher's apps, modes, calculator and favourites).
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
    property string panel: ""     // "" | "control" | "system" | "launcher" | "power" | "network" | "bluetooth" | "overview" | "calendar" | "github"
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
    readonly property bool mediaLive: player !== null && player.isPlaying && root.mediaDrives

    // btpair goes AHEAD of the open panel, and it is the only face that breaks
    // that rule. It is not a notice: it is a question with an expiry, with a
    // device waiting on the other side. If it stayed behind whatever panel you
    // had open, the pairing would expire without you ever seeing it.
    readonly property string mode: btAsking ? "btpair"
        : panel !== "" ? panel
        : activity === "notif" ? "notif"
        : activity === "toast" ? "toast"
        : activity === "track" ? "track"
        : activity === "ws" ? "ws"
        : activity === "charge" ? "charge"
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
        : mode === "calendar" ? 350
        // 53 columns of 9 px with 2 of air = 581, plus the column of weekday
        // initials and the margin. The whole year cannot get narrower without
        // shrinking the square, and below 9 px you can no longer tell which is which.
        : mode === "github" ? 640
        : mode === "notif" ? 430
        : mode === "toast" ? 330
        : mode === "ws" ? 220
        : mode === "charge" ? 260
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
                                         "network", "bluetooth", "power", "calendar", "github"]
    readonly property int notchGapDeCara: root.carasDePanel.indexOf(root.mode) >= 0 ? root.notchTopGap : 0

    readonly property int notchH: root.notchBaseH + root.notchGapDeCara

    readonly property int notchBaseH: mode === "launcher" ? launcherH
        : mode === "btpair" ? (btKind === "display" ? 96 : 112)
        : mode === "overview" ? ovH
        : mode === "control" ? 420
        : mode === "system" ? 420
        : mode === "network" || mode === "bluetooth" ? 412
        : mode === "power" ? 158
        : mode === "calendar" ? 320
        : mode === "github" ? 318
        : mode === "notif" ? 66
        : mode === "toast" ? 44
        : mode === "ws" ? 44
        : mode === "charge" ? 46
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

    // ═══════════════════════ media (MPRIS) ═══════════════════════
    readonly property var player: {
        const ps = Mpris.players.values;
        if (!ps || ps.length === 0) return null;
        for (let i = 0; i < ps.length; i++) if (ps[i].isPlaying) return ps[i];
        // With everything paused the first in the list won, and that is usually
        // a browser media session with nothing loaded any more: the panel said
        // "Sin reproducción" (Nothing playing) with Spotify right beside it, its
        // song loaded and paused, and the buttons controlled nothing.
        for (let i = 0; i < ps.length; i++) if (ps[i].trackTitle) return ps[i];
        return ps[0];
    }

    // ─────────── who may change the notch's face? ───────────
    //
    // Any video in a tab registers its MPRIS session just like Spotify, so the
    // notch widened to 268, hid the date and the battery and flashed for 4.2 s
    // for anything that made a sound in the browser. For Spotify that is fine;
    // for a background video, it is a nuisance.
    //
    // CAREFUL: this does NOT take the browser out of the player. `player` still
    // returns it and the music panel still shows it, which is what lets you
    // pause it from there. All it loses is ruling the notch's face at REST.
    //
    // All three fields are checked because each browser fills in different
    // ones: Chromium publishes `org.mpris.MediaPlayer2.chromium.instance<pid>`
    // and on some versions leaves `desktopEntry` empty, while others can only
    // be told apart by `identity`.
    readonly property var browserHints: ["chrome", "chromium", "brave", "edge",
                                         "opera", "vivaldi", "firefox"]
    function isBrowser(p) {
        if (!p) return false;
        const campos = [p.dbusName, p.desktopEntry, p.identity];
        for (let i = 0; i < campos.length; i++) {
            const v = String(campos[i] || "").toLowerCase();
            if (v.length === 0) continue;
            for (let j = 0; j < root.browserHints.length; j++)
                if (v.indexOf(root.browserHints[j]) >= 0) return true;
        }
        return false;
    }

    // "Hay reproductor Y tiene derecho a cambiar la cara del notch."
    // ("There is a player AND it has the right to change the notch's face.")
    readonly property bool mediaDrives: root.player !== null
        && (Config.browserMedia || !root.isBrowser(root.player))

    // The music accent is born from the cover art, not the wallpaper.
    // ColorQuantizer is asynchronous: while a new palette arrives it keeps the
    // previous accent and, if there is no image or the cover is practically grey,
    // it falls back to pywal. The lightness is normalised because the colour is
    // used on dark backgrounds: a faithful but almost black tone would be no use
    // for a 4 px bar.
    readonly property string mediaArtUrl: (player && player.trackArtUrl)
        ? String(player.trackArtUrl) : ""
    ColorQuantizer {
        id: mediaQuantizer
        source: root.mediaArtUrl
        depth: 3
        rescaleSize: 48
    }
    function mediaHsl(c) {
        const r = Number(c.r), g = Number(c.g), b = Number(c.b);
        const hi = Math.max(r, g, b), lo = Math.min(r, g, b);
        const d = hi - lo, l = (hi + lo) / 2;
        let h = 0, s = 0;
        if (d > 0.0001) {
            s = d / (1 - Math.abs(2 * l - 1));
            if (hi === r) h = ((g - b) / d) % 6;
            else if (hi === g) h = (b - r) / d + 2;
            else h = (r - g) / d + 4;
            h /= 6;
            if (h < 0) h += 1;
        }
        return { h: h, s: isFinite(s) ? s : 0, l: l };
    }
    readonly property color mediaAccent: {
        if (root.mediaArtUrl.length === 0) return Colors.accent;
        const cs = mediaQuantizer.colors;
        if (!cs || cs.length === 0) return Colors.accent;

        let best = null, bestScore = -100;
        for (let i = 0; i < cs.length; i++) {
            const hsl = root.mediaHsl(cs[i]);
            // Rewards colour and legibility; penalises cover whites and blacks.
            const score = hsl.s * 1.75 - Math.abs(hsl.l - 0.56) * 1.35
                - (hsl.l < 0.12 || hsl.l > 0.90 ? 1.5 : 0) + (i === 0 ? 0.04 : 0);
            if (score > bestScore) { bestScore = score; best = hsl; }
        }
        if (!best || best.s < 0.15) return Colors.accent;
        const saturation = Math.max(0.45, Math.min(0.90, best.s * 1.12));
        const lightness = Math.max(0.48, Math.min(0.67, best.l));
        return Qt.hsla(best.h, saturation, lightness, 1);
    }
    property real pos: 0
    readonly property real len: (player && player.lengthSupported) ? player.length : 0
    Timer {
        interval: 500; repeat: true; running: root.player !== null && (root.open || root.mediaLive)
        onTriggered: root.pos = (root.player && root.player.positionSupported) ? root.player.position : 0
    }
    // Only the first letter. Qt's Font.Capitalize capitalises EVERY word
    // and in Spanish leaves things like "Martes, 4 De Agosto".
    function capitalize(s) { return s ? s.charAt(0).toUpperCase() + s.slice(1) : ""; }

    function fmt(sec) {
        if (!sec || sec < 0) return "0:00";
        const m = Math.floor(sec / 60), s = Math.floor(sec % 60);
        return m + ":" + (s < 10 ? "0" + s : s);
    }
    // The song-change flash does NOT hang off `mediaLive`, so it has to be
    // filtered separately: without `mediaDrives`, the notch would keep opening
    // to 400 px for 4.2 s every time the browser changed video, which is
    // exactly what we want to avoid.
    Connections {
        target: root.player
        ignoreUnknownSignals: true
        function onTrackTitleChanged() {
            if (root.armed && root.mediaDrives && root.player && root.player.trackTitle) root.flash("track");
            root.recordarTema();
        }
        function onIsPlayingChanged() { if (root.armed && root.mediaDrives && root.player && root.player.isPlaying) root.flash("track"); }
    }

    // ══════════════════ whatever played last ══════════════════
    // When the player closes, MPRIS ceases to exist and the left column of the
    // control centre was left as 260x486 px saying "Sin reproducción" (Nothing
    // playing) inside an empty circle. Remembering the last track keeps that
    // column telling you something, and above all lets you GO BACK to what you
    // were listening to, which is the only thing you can really ask of it there.
    //
    // It goes to disk and not just to memory because the shell reloads every
    // time a .qml is touched, and a "last thing" that is forgotten on every
    // reload is not the last of anything.
    property string ultimoTitulo: ""
    property string ultimoArtista: ""
    property string ultimoArte: ""
    property string ultimoAppId: ""
    readonly property bool hayUltimo: root.player === null && root.ultimoTitulo.length > 0

    FileView {
        id: ultimoFile
        path: root.home + "/.cache/quickshell/ultimo-tema.json"
        // watchChanges is NOT optional even though nobody is going to touch the
        // file from outside: without it, FileView does not even do the INITIAL read
        // and onLoaded never fires. No errors and no warnings -- it just stays
        // empty, which is what this panel did until it was discovered.
        watchChanges: true
        onFileChanged: reload()
        printErrors: false      // the first time it does not exist, and that is not a failure
        onLoaded: {
            try {
                const d = JSON.parse(ultimoFile.text());
                root.ultimoTitulo = d.titulo || "";
                root.ultimoArtista = d.artista || "";
                root.ultimoArte = d.arte || "";
                root.ultimoAppId = d.app || "";
            } catch (e) {
                // Same rule as the team and github: with rubbish, touch
                // nothing. An invented "last track" is worse than none.
            }
        }
    }

    function recordarTema(): void {
        const p = root.player;
        if (!p || !p.trackTitle)
            return;
        root.ultimoTitulo = p.trackTitle;
        root.ultimoArtista = p.trackArtist || "";
        root.ultimoArte = p.trackArtUrl ? String(p.trackArtUrl) : "";
        root.ultimoAppId = p.desktopEntry || "";
        ultimoFile.setText(JSON.stringify({
            titulo: root.ultimoTitulo,
            artista: root.ultimoArtista,
            arte: root.ultimoArte,
            app: root.ultimoAppId
        }));
    }

    // It is also remembered when a player APPEARS, not only on a song change:
    // if you open the player and close it without skipping a track, without this
    // nothing would have been saved.
    onPlayerChanged: if (root.player) root.recordarTema()

    // The app that was playing it, if it is still installed. It is compared
    // without the trailing ".desktop" because MPRIS gives it sometimes with it
    // and sometimes without.
    readonly property var ultimaApp: {
        if (!root.ultimoAppId.length)
            return null;
        const pela = s => String(s || "").toLowerCase().replace(/\.desktop$/, "");
        const id = pela(root.ultimoAppId);
        const vs = DesktopEntries.applications ? DesktopEntries.applications.values : [];
        for (let i = 0; i < vs.length; i++)
            if (pela(vs[i].id) === id)
                return vs[i];
        return null;
    }

    // ═══════════════════════ audio (Pipewire) ═══════════════════════
    PwObjectTracker { objects: [Pipewire.defaultAudioSink] }
    readonly property var sink: Pipewire.defaultAudioSink
    readonly property int vol: (sink && sink.audio) ? Math.round(sink.audio.volume * 100) : 0
    readonly property bool muted: (sink && sink.audio) ? sink.audio.muted : false

    // THE OSD MUST NOT APPEAR BECAUSE OF AN OUTPUT CHANGE.
    //
    // `vol` is derived from `sink`, so plugging in headphones, switching off the
    // radio or choosing another output in Settings made `vol` jump without
    // anybody having touched the volume, and an OSD you had not asked for
    // appeared.
    //
    // Listening to onSinkChanged and lowering a flag is not enough: the order in
    // which QML notifies `sink` and the `vol` that depends on it is not
    // guaranteed, and if `vol` arrived first the notice would appear anyway.
    // Comparing the sink against the last one we saw makes the result
    // independent of the order. The grace window covers the burst of changes
    // that arrives while the new output settles. It is what impasto calls
    // suppressAudio() (OsdService.qml:33-35, called from
    // ControlsService.qml:164-165).
    property var _sinkVisto: null
    Timer { id: sinkGracia; interval: 500 }

    // The two paths, and both are needed. This one seeds the reference as soon
    // as the output changes, so that the FIRST volume change after a shell
    // reload does not swallow the notice. And the comparison in _audioEsTuyo()
    // is the safety net in case QML notified `vol` before `sink`, which is an
    // order that is not guaranteed.
    onSinkChanged: {
        root._sinkVisto = root.sink;
        sinkGracia.restart();
    }

    function _audioEsTuyo() {
        if (root.sink !== root._sinkVisto) {
            root._sinkVisto = root.sink;
            sinkGracia.restart();
            return false;
        }
        return !sinkGracia.running;
    }

    onVolChanged: if (armed && _audioEsTuyo()) flash("volume")
    onMutedChanged: if (armed && _audioEsTuyo()) flash("volume")

    function setVolume(pct) {
        if (!sink || !sink.audio) return;
        sink.audio.muted = false;
        sink.audio.volume = Math.max(0, Math.min(1.4, pct / 100));
    }
    function nudgeVolume(dir) {
        if (!sink || !sink.audio) return;
        // Unmutes, same as setVolume. Without this, the wheel over the notch
        // with the sound muted left the bar pinned at 0 while the real level
        // climbed behind its back up to 140%: you unmuted and got slapped in
        // the face. Moving the volume IS asking to hear.
        sink.audio.muted = false;
        sink.audio.volume = Math.max(0, Math.min(1.4, sink.audio.volume + dir * 0.02));
    }
    function toggleMute() { if (sink && sink.audio) sink.audio.muted = !sink.audio.muted; }

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

    // ──────────────── audio spectrum (cava) ─────────────────
    // The notch's little bars. This used to be a PwNodePeakMonitor: ONE single
    // number (the sink's global peak) shifted along the array. That is not a
    // spectrum, it is the same signal repeated 14 times —all the bars rose and
    // fell together— and since the linear peak nearly always brushes 1, they
    // stayed pinned to the ceiling (barcode effect). Worse: onPeakChanged only
    // fires when the value CHANGES, so in a compressed stretch the signal
    // stopped arriving and the bars FROZE.
    //
    // cava does do an FFT: it gives `bands` independent values per frame, from
    // bass to treble, and with its own autosens (quiet music fills just the
    // same, loud music does not saturate). "raw" output in ascii, one line per
    // frame: "0;312;…;\n". The configuration lives in scripts/cava.conf.
    // Few and thick. With 14 the strip read as a pattern of stripes rather than
    // as an equaliser: at 2.5 px wide you cannot tell one bar from its
    // neighbour. If you change this, change `bars` in scripts/cava.conf.
    readonly property int bands: 8

    // WHY CAVA'S VALUE IS NOT PAINTED AS IT COMES. Because cava's values JUMP:
    // a single band goes from 2 to 1000 and back in a handful of frames.
    // Painting that directly is not an equaliser, it is a strobe — and it was
    // exactly the jitter you could see. Measured by recording the notch at 60
    // fps and measuring the PAINTED bars:
    //
    //                             max jump   jerks
    //   painting the raw value     16.7 px   0.200
    //   with this follower          1.3 px   0.079
    //
    // So cava only sets the TARGET, and what MOVES the bar is the screen's
    // clock: a FrameAnimation that on every frame brings it a little closer,
    // according to the REAL time elapsed (frameTime). It is what caelestia does
    // (Internal/visualiserbars.cpp: alpha = 1 - exp(-dt/tau)), which is where
    // this bar's architecture comes from.
    //
    // Exponential on purpose: advancing a FRACTION of what is left gives no
    // jumps or sudden stops —the speed is continuous— and being tied to real
    // time it does not matter if a frame is dropped: the bar is always where it
    // should be.
    //
    // What does NOT work, tried and measured: smoothing in cava
    // (noise_reduction), smoothing the received value, or quantising the height
    // into steps. All of that touches the NUMBERS, and what has to be
    // continuous is the MOTION.
    //
    // IT RISES FAST AND FALLS SLOWLY, like a VU meter. With a single constant
    // for both directions the bar COLLAPSES as fast as it rises: at tau 35 it
    // eats 38% of what is left on every frame, so a peak comes apart in three
    // frames (~50 ms). That does not read as a bar going down, it reads as a
    // bar switching off — a blink.
    //
    // With attack and decay separated, the hit still lands just as crisply
    // (it is what marks the rhythm) but the return is a glide of ~1/3 of a
    // second, which is plenty of time for the eye to follow it as continuous
    // motion.
    //
    // tau = ms it takes to eat 63% of what is left. Lower = more glued to the
    // music and more nervous; higher = smoother and lazier. The decay cannot go
    // above ~150: beyond that, two consecutive kick-drum hits at 120 bpm
    // overlap and the bar stops marking the beat.
    readonly property int cavaSube: 32    // attack
    readonly property int cavaBaja: 110   // decay

    property var cavaTarget: new Array(bands).fill(0)   // what cava says

    // WHY EVERY BAND HAS ITS OWN RANGE. With dense music no band ever goes
    // below 200-400 out of 1000, so mapping 0-1000 straight onto the bar left
    // all eight half-to-two-thirds high, travelling 2-3 px out of 18 in half a
    // second: an equaliser that looks frozen. Each band keeps a window that
    // jumps at once to a new peak or valley and forgets it slowly, and the bar
    // is painted inside that window, so every beat goes from floor to ceiling
    // whatever the band's loudness. Simulated on the same cava output: travel
    // 2.7 -> 8.4 px every half second, at the ceiling 23% of the time.
    //
    // cavaRango = ms it takes to forget 63% of a peak or valley. Lower = more
    // nervous, it stretches even the quiet passages; higher = slower to adapt
    // when the song changes section.
    // cavaRangoMin = the narrowest window, so a near-silent band does not get
    // its noise blown up to full height.
    readonly property int cavaRango: 2500
    readonly property real cavaRangoMin: 0.25
    property var cavaHi: new Array(bands).fill(0.5)
    property var cavaLo: new Array(bands).fill(0.3)
    property real cavaUltima: 0
    property var levels: new Array(bands).fill(0)       // what gets painted
    property bool cavaQuieto: true

    FrameAnimation {
        // Keeps running after the music stops until the bars have come down
        // completely: that way they glide to the floor instead of vanishing at once.
        running: cavaProc.running || !root.cavaQuieto
        onTriggered: {
            // smoothFrameTime and not frameTime: the real gap between frames
            // fluctuates (16.7 · 12 · 21 · 16…), and since the follower's step
            // is computed from that gap, using the raw one makes the bar advance
            // in fits and starts even when the signal is perfect. Qt averages
            // that measurement precisely for this; the position error it
            // introduces corrects itself on the next frame, because the follower
            // chases the target, it does not accumulate.
            const dt = smoothFrameTime * 1000;
            const aSube = 1 - Math.exp(-dt / root.cavaSube);
            const aBaja = 1 - Math.exp(-dt / root.cavaBaja);
            const out = new Array(root.bands);
            let quieto = true;
            for (let i = 0; i < root.bands; i++) {
                const falta = root.cavaTarget[i] - root.levels[i];
                if (Math.abs(falta) > 0.001) {
                    out[i] = root.levels[i] + falta * (falta > 0 ? aSube : aBaja);
                    quieto = false;
                } else {
                    out[i] = root.cavaTarget[i];
                }
            }
            root.levels = out;
            root.cavaQuieto = quieto;
        }
    }

    // Starts and stops cava with the music, and BRINGS IT BACK if it dies.
    //
    // `running: root.mediaLive` is NOT used here, which is the natural thing and
    // was so until 7 Aug 2026: when the process dies (it crashes, or someone
    // kills it), quickshell writes running=false, and that write BREAKS the
    // binding. From then on cava never starts again —not even reloading the
    // config— and the visualiser is left with eight flat bars even though music
    // is playing. It is driven by hand: the timer reasserts the state every 3 s,
    // so at most it takes that long to get back up by itself. triggeredOnStart
    // = it starts at once when playback begins, without waiting for the first tick.
    Timer {
        interval: 3000
        repeat: true
        triggeredOnStart: true
        running: root.mediaLive
        onTriggered: cavaProc.running = true
    }
    onMediaLiveChanged: if (!root.mediaLive) cavaProc.running = false

    Process {
        id: cavaProc
        command: ["cava", "-p", root.home + "/.config/quickshell/scripts/cava.conf"]
        stdout: SplitParser {
            onRead: function (line) {
                const parts = line.split(";");
                const now = Date.now();
                const dt = root.cavaUltima ? Math.min(100, now - root.cavaUltima) : 16.7;
                root.cavaUltima = now;
                const olvido = 1 - Math.exp(-dt / root.cavaRango);
                const hi = root.cavaHi.slice();
                const lo = root.cavaLo.slice();
                const out = new Array(root.bands);
                for (let i = 0; i < root.bands; i++) {
                    const v = Math.max(0, Math.min(1, (+parts[i] || 0) / 1000));
                    hi[i] = v > hi[i] ? v : hi[i] + (v - hi[i]) * olvido;
                    lo[i] = v < lo[i] ? v : lo[i] + (v - lo[i]) * olvido;
                    // A window narrower than the minimum grows downwards, so a
                    // loud band still reaches the ceiling.
                    const span = Math.max(hi[i] - lo[i], root.cavaRangoMin);
                    const base = Math.min(lo[i], Math.max(0, hi[i] - span));
                    out[i] = Math.max(0, Math.min(1, (v - base) / span));
                }
                root.cavaHi = hi;
                root.cavaLo = lo;
                root.cavaTarget = out;   // only the target; moving is the FrameAnimation's job
                root.cavaQuieto = false;
            }
        }
        // On pause, cava dies and the target would keep the last snapshot:
        // bars at half height through the whole fade-out.
        onRunningChanged: if (!running) {
            root.cavaTarget = new Array(root.bands).fill(0);
            root.cavaUltima = 0;
        }
    }

    // ═════════════════════ brightness ═════════════════════
    property int bright: -1
    Process {
        id: brightProc
        stdout: SplitParser {
            onRead: function (line) {
                const v = parseInt(line.trim());
                if (!isNaN(v)) { root.bright = v; root.flash("brightness"); }
            }
        }
    }
    // `-c backlight` on EVERY call, and not for the sake of it: without a class,
    // brightnessctl walks backlight and then leds, and settles on the first one
    // that has something. On a machine with no internal panel there is no
    // backlight, so the XF86MonBrightness keys would end up switching the
    // caps-lock LED on and off and the notch OSD would show you that 0/100 as
    // if it were the screen brightness. With the class pinned there is no
    // device, no output, no flash: the key does nothing, which is the truth.
    function stepBrightness(dir) {
        brightProc.command = ["bash", "-c",
            "brightnessctl -c backlight -m set 5%" + (dir === "down" ? "-" : "+") + " >/dev/null 2>&1; " +
            // Never all the way down: at 0 the panel goes black and looks off.
            "p=$(brightnessctl -c backlight -m 2>/dev/null | awk -F, '{gsub(\"%\",\"\",$4); print $4}'); " +
            "if [ -n \"$p\" ] && [ \"$p\" -lt " + root.brightMin + " ]; then brightnessctl -c backlight -q set " + root.brightMin + "%; p=" + root.brightMin + "; fi; echo \"$p\""];
        brightProc.running = false;
        brightProc.running = true;
    }
    // A floor, so the lowest brightness is still a lit screen: at 0 the panel's
    // backlight switches off and the screen looks dead (this fork; the keys,
    // the Control Centre slider and Settings all stop here).
    readonly property int brightMin: 1
    function setBrightness(pct) {
        // With no panel there is nothing to move, and without this guard the
        // slider (no longer drawn, but the function is still public) would write
        // to the first LED it found.
        if (root.bright < 0) return;
        const v = Math.max(root.brightMin, Math.min(100, Math.round(pct)));
        Quickshell.execDetached(["brightnessctl", "-c", "backlight", "-q", "set", v + "%"]);
        root.bright = v;
    }

    // ═══════════════════════ system ════════════════════════
    property int cpu: 0
    property int mem: 0
    property int batt: -1
    property int disk: 0
    property bool ac: false
    property real memUsedKib: 0
    property real memTotalKib: 0
    property real diskUsedBytes: 0
    property real diskTotalBytes: 0
    property real cpuTemp: -1
    property real cpuLoad: 0
    property int uptimeSeconds: 0
    property int cpuThreads: 1

    // Sixty samples at 1.5 s: a minute and a half of context. The arrays are
    // replaced whole (instead of mutated) so that Canvas gets valuesChanged and
    // repaints the curves even if the current percentage matches the previous one.
    property var cpuHistory: []
    property var memHistory: []
    property var tempHistory: []
    function appendMetric(history, value) {
        const next = history.slice(Math.max(0, history.length - 59));
        next.push(isFinite(value) ? value : 0);
        return next;
    }
    // 2026-09-14: this Process had neither an `id` nor an `onExited`, so if the
    // script died NOBODY relaunched it. And it is the ONLY source of cpu, mem,
    // batt, ac, disk, memUsedKib, memTotalKib, diskUsedBytes, diskTotalBytes,
    // cpuTemp, cpuLoad, uptimeSeconds and cpuThreads: the bar, the control
    // centre and the performance panel kept showing the LAST SNAPSHOT as if it
    // were the current state, with no warning at all. Lying quietly is worse
    // than saying nothing, above all in the panel you look at when the laptop
    // is acting up. The realistic case is not hypothetical: systemd-oomd kills
    // user processes under memory pressure, and this machine froze because of
    // that the very same day.
    Process {
        id: sysstatsProc
        command: [root.home + "/.config/quickshell/scripts/sysstats.sh"]
        running: true
        // Relaunch with a 2 s breather. The breather matters: if the script
        // were really broken (a syntax error, a missing binary) without it we
        // would enter a relaunch loop at full speed, which is exactly what you
        // do not want on a machine that has just run out of memory. With 2 s,
        // a permanent failure costs half a process per second instead of
        // thousands.
        onExited: function (exitCode, exitStatus) {
            console.warn(I18n.tr("sysstats.sh murio (code={0}, status={1}); relanzando en 2 s", exitCode, exitStatus));
            sysstatsRestart.restart();
        }
        stdout: SplitParser {
            onRead: function (line) {
                const p = line.trim().split(/\s+/);
                if (p.length < 8) return;
                root.cpu = parseInt(p[0]); root.mem = parseInt(p[1]);
                root.batt = parseInt(p[2]); root.ac = p[3] === "1";
                if (p.length >= 9) root.disk = parseInt(p[8]);
                if (p.length >= 17) {
                    root.memUsedKib = parseFloat(p[9]);
                    root.memTotalKib = parseFloat(p[10]);
                    root.diskUsedBytes = parseFloat(p[11]);
                    root.diskTotalBytes = parseFloat(p[12]);
                    const milliC = parseFloat(p[13]);
                    root.cpuTemp = milliC >= 0 ? milliC / 1000 : -1;
                    root.cpuLoad = parseFloat(p[14]);
                    root.uptimeSeconds = parseInt(p[15]);
                    root.cpuThreads = Math.max(1, parseInt(p[16]));
                }
                root.cpuHistory = root.appendMetric(root.cpuHistory, root.cpu);
                root.memHistory = root.appendMetric(root.memHistory, root.mem);
                if (root.cpuTemp >= 0)
                    root.tempHistory = root.appendMetric(root.tempHistory, root.cpuTemp);
                if (root.bright < 0) root.bright = parseInt(p[4]);   // only the initial value
            }
        }
    }

    // Companion to the onExited above. Outside the Process on purpose: a Timer
    // inside the very object being restarted is fragile.
    Timer {
        id: sysstatsRestart
        interval: 2000
        repeat: false
        onTriggered: if (!sysstatsProc.running) sysstatsProc.running = true;
    }
    // PLUGGING IN AND UNPLUGGING are among the very few things that happen to
    // the laptop WITHOUT you touching anything and that you want to know about
    // right away. Everything else that appears in the notch is caused by you;
    // this is caused by the world, and that is why it deserves its own face
    // instead of one more icon in the bar.
    //
    // The `armed` is not redundant: sysstats.sh spits out the first line a few
    // milliseconds after starting and that first value is NOT a change, it is
    // the initial state. Without the guard, every shell restart would greet you
    // with a "Cargando" (Charging) you had not asked for.
    onAcChanged: if (root.armed) root.flash("charge")

    readonly property string battIcon: ac ? "󰂄"
        : batt < 0 ? "󰂑"
        : batt >= 90 ? "󰁹" : batt >= 70 ? "󰂂" : batt >= 50 ? "󰁿"
        : batt >= 30 ? "󰁼" : batt >= 15 ? "󰁻" : "󰁺"

    // UPower exposes the electrical data already normalised (Wh, W and seconds).
    // sysstats still carries the notch's fast percentage; this layer adds the
    // information that deserves a Settings screen: wear, capacity, cycles and
    // time estimate.
    readonly property var batteryDevice: {
        const ds = UPower.devices ? UPower.devices.values : [];
        for (let i = 0; i < ds.length; i++)
            if (ds[i] && ds[i].isLaptopBattery && ds[i].isPresent) return ds[i];
        const display = UPower.displayDevice;
        return (display && display.isPresent) ? display : null;
    }
    readonly property real battHealth: batteryDevice && batteryDevice.ready
        && batteryDevice.healthSupported ? batteryDevice.healthPercentage : -1
    readonly property real battFullWh: batteryDevice && batteryDevice.ready
        ? batteryDevice.energyCapacity : -1
    readonly property real battDesignWh: battHealth > 0 && battFullWh > 0
        ? battFullWh / (battHealth / 100) : -1
    readonly property real battRateW: batteryDevice && batteryDevice.ready
        ? Math.abs(batteryDevice.changeRate) : -1
    readonly property real battEstimateSeconds: {
        if (!batteryDevice || !batteryDevice.ready) return -1;
        const seconds = root.ac ? batteryDevice.timeToFull : batteryDevice.timeToEmpty;
        return seconds > 0 ? seconds : -1;
    }
    property int battCycles: -1

    function fmtBatteryTime(seconds) {
        if (!isFinite(seconds) || seconds <= 0) return "";
        const mins = Math.max(1, Math.round(seconds / 60));
        const h = Math.floor(mins / 60), m = mins % 60;
        if (h <= 0) return I18n.tr("{0} min", m);
        return m > 0 ? I18n.tr("{0} h {1} min", h, m) : I18n.tr("{0} h", h);
    }
    function fmtWh(value) { return value > 0 ? I18n.tr("{0} Wh", value.toFixed(1)) : ""; }
    readonly property string battEstimateText: {
        if (root.batt < 0) return I18n.tr("sin batería");
        if (root.ac && root.batt >= 99 && root.battEstimateSeconds < 0) return I18n.tr("completa");
        const time = root.fmtBatteryTime(root.battEstimateSeconds);
        if (time.length === 0) return I18n.tr("calculando…");
        // A whole sentence and not `time + suffix`: in English the order need not
        // be the same, and each branch needs its own translation.
        return root.ac ? I18n.tr("{0} para completar", time) : I18n.tr("{0} restantes", time);
    }

    Process {
        id: battCyclesProc
        stdout: SplitParser {
            onRead: function (line) {
                const cycles = parseInt(line.trim());
                if (!isNaN(cycles) && cycles >= 0) root.battCycles = cycles;
            }
        }
    }
    function refreshBatteryCycles() {
        if (!root.batteryDevice || battCyclesProc.running) return;
        const nativeName = String(root.batteryDevice.nativePath || "");
        if (!/^[A-Za-z0-9._-]+$/.test(nativeName)) return;
        battCyclesProc.command = ["cat", "/sys/class/power_supply/" + nativeName + "/cycle_count"];
        battCyclesProc.running = true;
    }
    onBatteryDeviceChanged: root.refreshBatteryCycles()
    Timer {
        interval: 3600000
        repeat: true
        running: true
        triggeredOnStart: true
        onTriggered: root.refreshBatteryCycles()
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

    // ══════════════════════ the satellite bubble ═══════════════════════
    // A small body that peeks out from BEHIND the notch's right edge when
    // something is running in the background.
    //
    // Why a satellite and not one more face: the resting notch measures exactly
    // the reserved band and cannot grow by itself — that is the rule that keeps
    // it from ever covering a window. A countdown lasts minutes, so it does not
    // fit there without breaking the rule. A separate body does: it is born
    // behind the edge, stays INSIDE the band, and the notch stays the same size.
    //
    // This is a SLOT, not a timer. Today two things fill it, and adding a third
    // (a download, a build) is one more line in bubbleKind. The timer wins over
    // background work because you asked for the timer and the other just happens.
    readonly property string bubbleKind: timerTotal > 0 ? "timer" : (busy ? "busy" : "")
    readonly property bool bubbleOn: bubbleKind !== ""
    // -1 = indeterminate: we know it is still going, not how much is left.
    readonly property real bubbleProgress: (bubbleKind === "timer" && timerTotal > 0)
        ? Math.max(0, Math.min(1, timerLeft / timerTotal)) : -1
    readonly property string bubbleIcon: bubbleKind === "timer"
        ? (timerDone ? Icons.alarm : (timerRunning ? Icons.timer : Icons.pause))
        : Icons.sync
    readonly property string bubbleLabel: bubbleKind === "timer"
        ? (timerDone ? I18n.tr("¡Tiempo!") : timerClock(timerLeft))
        : I18n.tr("Sincronizando")
    readonly property bool bubbleAlert: timerDone

    // "I am doing something and it is taking a while." Only the sync you ask
    // for with a right-click on the updates, not the automatic check every five
    // minutes: that one happens by itself, and lighting up a new body on the
    // screen every five minutes is noise, not information.
    readonly property bool busy: pacmanProc.running && pacmanProc.forceSync

    // ── the timer ──
    property int timerTotal: 0        // seconds requested; 0 = no timer
    property int timerLeft: 0
    property bool timerRunning: false
    property bool timerDone: false    // already went off and you have not dismissed it yet

    Timer {
        interval: 1000
        repeat: true
        running: root.timerRunning
        onTriggered: {
            root.timerLeft = Math.max(0, root.timerLeft - 1);
            if (root.timerLeft > 0) return;
            root.timerRunning = false;
            root.timerDone = true;
            // We ARE the notification server (see further down), so this
            // notify-send comes round and back to our own notch. There is no
            // need to invent a notice: the existing one is used, and along the
            // way it stays in the control centre's history.
            Quickshell.execDetached(["notify-send", "-u", "critical",
                                     "-a", I18n.tr("Temporizador"),
                                     I18n.tr("Temporizador"),
                                     I18n.tr("{0} cumplidos", root.timerSpoken(root.timerTotal))]);
        }
    }

    function timerStart(seconds) {
        if (seconds <= 0) return;
        root.timerTotal = seconds;
        root.timerLeft = seconds;
        root.timerDone = false;
        root.timerRunning = true;
    }
    // A click on the bubble: if it already went off, it dismisses it; if not, pause and resume.
    function timerToggle() {
        if (root.timerDone) { root.timerClear(); return; }
        if (root.timerTotal <= 0) return;
        root.timerRunning = !root.timerRunning;
    }
    function timerClear() {
        root.timerRunning = false;
        root.timerTotal = 0;
        root.timerLeft = 0;
        root.timerDone = false;
    }

    // mm:ss, and hh:mm:ss only if there really are hours. A "00:09:59" for ten
    // minutes is two digits that say nothing taking up room in a 28 px body.
    function timerClock(sec) {
        const h = Math.floor(sec / 3600), m = Math.floor((sec % 3600) / 60), x = sec % 60;
        const two = n => (n < 10 ? "0" + n : String(n));
        return h > 0 ? (h + ":" + two(m) + ":" + two(x)) : (m + ":" + two(x));
    }
    // How it is said out loud, for the notice: "25 min", "1 h 30 min".
    function timerSpoken(sec) {
        const h = Math.floor(sec / 3600), m = Math.floor((sec % 3600) / 60), x = sec % 60;
        const parts = [];
        if (h > 0) parts.push(I18n.tr("{0} h", h));
        if (m > 0) parts.push(I18n.tr("{0} min", m));
        if (x > 0 && h === 0) parts.push(I18n.tr("{0} s", x));
        return parts.join(" ");
    }

    // ── from what you type to seconds ──
    // Recognises "10m", "25 min", "1h", "90s", "1h30", "1h 5 min".
    //
    // It DEMANDS A UNIT on purpose. A bare "5" is a search, and if the launcher
    // offered a countdown every time you typed a number it would get in the way
    // of every search that starts with a digit. It is the same rule the
    // calculator already uses so as not to fire on "7zip".
    function parseDuration(text) {
        const t = String(text || "").trim().toLowerCase().replace(/\s+/g, "");
        if (t.length === 0) return -1;
        // "1h30" = an hour and a half. It is how everybody writes it and it
        // does not fit the form with units, so it goes separately.
        const hm = t.match(/^(\d+)h(\d{1,2})$/);
        if (hm) return parseInt(hm[1]) * 3600 + parseInt(hm[2]) * 60;
        // Units in both languages, because the timer follows the shell's: in
        // English "5 minutes" used to be rejected and only "5 min" got through.
        const m = t.match(/^(?:(\d+)(?:horas?|hours?|hrs?|h))?(?:(\d+)(?:minutos?|minutes?|mins?|m))?(?:(\d+)(?:segundos?|seconds?|segs?|secs?|s))?$/);
        if (!m || (!m[1] && !m[2] && !m[3])) return -1;
        const sec = parseInt(m[1] || 0) * 3600 + parseInt(m[2] || 0) * 60 + parseInt(m[3] || 0);
        return (sec > 0 && sec <= 86400) ? sec : -1;
    }

    // ═════════════════════ network ═════════════════════
    readonly property var wifiDev: {
        const ds = Networking.devices ? Networking.devices.values : [];
        for (let i = 0; i < ds.length; i++) if (ds[i].type === DeviceType.Wifi) return ds[i];
        return null;
    }
    readonly property var wiredDev: {
        const ds = Networking.devices ? Networking.devices.values : [];
        for (let i = 0; i < ds.length; i++) if (ds[i].type === DeviceType.Wired && ds[i].connected) return ds[i];
        return null;
    }
    readonly property var wifiNet: {
        if (!wifiDev || !wifiDev.networks) return null;
        const ns = wifiDev.networks.values;
        for (let i = 0; i < ns.length; i++) if (ns[i].connected) return ns[i];
        return null;
    }
    readonly property bool online: wiredDev !== null || wifiNet !== null

    // Whether the machine HAS a wifi radio. A tower on a cable has none, and
    // without this the shell could not tell "there is no adapter" from "the
    // adapter is off": it showed a wifi switch that switched nothing on and an
    // empty list captioned "Wi-Fi apagado" (Wi-Fi off), as if pressing it were
    // enough. The device is checked, not wifiEnabled, because NetworkManager
    // reports the radio as disabled also when there simply is none.
    readonly property bool hasWifi: wifiDev !== null

    // ---- wifi list for the network panel ----
    // READ-ONLY mirror of NetworkManager's real state.
    //
    // It used to be a normal property bound to Networking.wifiEnabled PLUS an
    // onWifiOnChanged that rewrote it. Two consequences, both observed live on
    // 2026-08-05:
    //   1. on shell start-up, wifiEnabled reads false before NetworkManager's
    //      data arrives; the handler wrote that false back and THE SHELL
    //      SWITCHED YOUR WIFI OFF BY ITSELF. It is in NM's audit log:
    //      op="radio-control" arg="wireless-enabled:off" pid=<qs's>, with
    //      the off/on/off seesaw of a loop. And since systemd-rfkill persists
    //      the block, the laptop booted WITHOUT WIFI on the following days.
    //   2. assigning to a bound property DESTROYS the binding, so on the first
    //      click the switch stopped reflecting reality for ever.
    // That is why it is now readonly and every change goes through
    // setWifi/toggleWifi, which are only called from an explicit user gesture.
    readonly property bool wifiOn: Networking.wifiEnabled
    function setWifi(on) { Networking.wifiEnabled = on; }
    function toggleWifi() { root.setWifi(!root.wifiOn); }

    // The scanner is only on while the network panel is open: otherwise
    // NetworkManager is sweeping the airwaves all the time for nothing.
    // Scan/discover only while the corresponding panel is open: otherwise
    // NetworkManager and Bluez sweep the airwaves all the time for nothing.
    //
    // A declarative Binding and NOT an onPanelChanged: the imperative handler
    // only fired on a panel change, so if you turned bluetooth on from inside
    // its own panel discovery never started. This way it is also re-evaluated
    // when the adapter's state changes.
    Binding {
        target: root.wifiDev
        property: "scannerEnabled"
        value: root.panel === "network"
        when: root.wifiDev !== null
        restoreMode: Binding.RestoreNone
    }
    // The Bluetooth section of Settings also wants to discover while it is
    // open. It asks through here instead of writing `discovering` by hand: two
    // places writing the same property (one with a Binding and the other
    // imperatively) is a race, and the loser was Settings as soon as the notch
    // panel changed.
    property bool btScanWanted: false
    Binding {
        target: root.btAdapter
        property: "discovering"
        value: (root.panel === "bluetooth" || root.btScanWanted) && root.btOn
        when: root.btAdapter !== null
        restoreMode: Binding.RestoreNone
    }

    // The same SSID can appear several times (several access points): the one
    // with the best signal is kept. Order: connected, then saved, then signal.
    readonly property var wifiNetworks: {
        if (!wifiDev || !wifiDev.networks) return [];
        const ns = wifiDev.networks.values;
        const best = {};
        for (let i = 0; i < ns.length; i++) {
            const n = ns[i];
            const k = n.name || "";
            if (k.length === 0) continue;
            const prev = best[k];
            if (!prev || (n.signalStrength || 0) > (prev.signalStrength || 0)) best[k] = n;
        }
        const out = [];
        for (const k in best) out.push(best[k]);
        out.sort(function (a, b) {
            if (a.connected !== b.connected) return a.connected ? -1 : 1;
            if (a.known !== b.known) return a.known ? -1 : 1;
            return (b.signalStrength || 0) - (a.signalStrength || 0);
        });
        return out;
    }

    // Thresholds squeezed on purpose: in practice signals fall between 30 and
    // 60, and with the "classic" split (75/50/25) they all came out with the
    // same icon.
    function wifiIconFor(s) {
        return s >= 72 ? "󰤨" : s >= 48 ? "󰤥" : s >= 24 ? "󰤢" : "󰤟";
    }
    function isSecured(net) {
        if (!net) return false;
        return net.security !== WifiSecurityType.Open && net.security !== WifiSecurityType.Unknown;
    }
    function isEnterprise(net) {
        if (!net) return false;
        return net.security === WifiSecurityType.WpaEap
            || net.security === WifiSecurityType.Wpa2Eap
            || net.security === WifiSecurityType.Wpa3SuiteB192
            || net.security === WifiSecurityType.DynamicWep
            || net.security === WifiSecurityType.Leap;
    }
    function editEnterprise(net) {
        if (!net || !net.name) return;
        const known = Boolean(net.known);
        root.closePanel();
        Quickshell.execDetached([
            root.home + "/.config/glasstty/scripts/wifi-enterprise.sh",
            known ? "edit" : "create", String(net.name)
        ]);
        Launcher.toast(Icons.wifiLock, known
            ? I18n.tr("Abriendo credenciales de {0}", String(net.name))
            : I18n.tr("Nueva red empresarial: {0}", String(net.name)));
    }
    function openNetworkProfiles() {
        root.settingsOpen = false;
        root.closePanel();
        Quickshell.execDetached(["nm-connection-editor", "--show"]);
    }
    readonly property string netIcon: {
        if (wiredDev) return "󰈀";
        if (!wifiNet) return "󰤭";
        const s = wifiNet.signalStrength;
        return s >= 75 ? "󰤨" : s >= 50 ? "󰤥" : s >= 25 ? "󰤢" : "󰤟";
    }

    // ═══════════════════════ bluetooth ═══════════════════════
    readonly property var btAdapter: Bluetooth.defaultAdapter
    readonly property bool btOn: btAdapter ? btAdapter.enabled : false
    readonly property int btConnected: {
        const ds = Bluetooth.devices ? Bluetooth.devices.values : [];
        let n = 0;
        for (let i = 0; i < ds.length; i++) if (ds[i].connected) n++;
        return n;
    }
    readonly property string btIcon: btBlocked ? "󰂲" : !btOn ? "󰂲" : (btConnected > 0 ? "󰂱" : "󰂯")

    // Blocked by rfkill: the switch can do nothing and that has to be said,
    // instead of pressing it coming to nothing with no explanation.
    readonly property bool btBlocked: btAdapter !== null && btAdapter.state === BluetoothAdapterState.Blocked

    // connected ones first, then the rest of the paired ones
    readonly property var btPaired: {
        const vs = Bluetooth.devices ? Bluetooth.devices.values : [];
        const out = [];
        for (let i = 0; i < vs.length; i++) if (vs[i].paired || vs[i].bonded) out.push(vs[i]);
        out.sort(function (a, b) { return (b.connected ? 1 : 0) - (a.connected ? 1 : 0); });
        return out;
    }
    readonly property var btNearby: {
        const vs = Bluetooth.devices ? Bluetooth.devices.values : [];
        const out = [];
        for (let i = 0; i < vs.length; i++) if (!vs[i].paired && !vs[i].bonded) out.push(vs[i]);
        return out;
    }
    function btLabel(d) {
        if (!d) return "";
        return d.deviceName || d.name || d.address || "";
    }
    // Pending intent: `rfkill unblock` is asynchronous, so the adapter is not
    // ready at the same instant. We store that the user wanted it on and switch
    // it on as soon as it stops being blocked.
    property bool btPendingOn: false

    // 2026-09-14: this used to be a single line that only did
    //     btAdapter.enabled = !btAdapter.enabled
    // and with an rfkill soft-block Bluez IGNORES that `enabled`, so the notch
    // switch did absolutely nothing. And that is the NORMAL state at boot: TLP
    // blocks the radio on every boot
    // (DEVICES_TO_DISABLE_ON_STARTUP="bluetooth" in /etc/tlp.d/01-diego.conf).
    // So switching off was automatic and switching on, impossible from where
    // you would expect. That breaks the house rule —the same as for wifi—:
    // switching on has to be as easy as switching off. TLP's own comment
    // promised that "the notch switch turns it back on with one click".
    // No sudo is needed: diego has a write ACL on /dev/rfkill.
    // SettingsBluetooth.qml already had this same unblock on a separate button;
    // here it is unified into the switch, which is where you look for it.
    function toggleBt() {
        if (!btAdapter) return;
        if (btBlocked) {
            btPendingOn = true;
            Quickshell.execDetached(["rfkill", "unblock", "bluetooth"]);
            return;
        }
        btAdapter.enabled = !btAdapter.enabled;
    }

    // One-shot: as soon as the radio is unblocked, the intent is carried out.
    onBtBlockedChanged: {
        if (!btBlocked && btPendingOn) {
            btPendingOn = false;
            if (btAdapter) btAdapter.enabled = true;
        }
    }

    // ═══════════════════════════ updates ═══════════════════════════
    // The cadence is kept by the Timer below, NOT by a loop in bash. This used
    // to be a `bash -c "while true; do ...; sleep 300; done"` with running: true,
    // and that loop OUTLIVED quickshell: if qs dies without being able to clean
    // up (a segfault, or a kill -9 while you tinker with the config) the bash is
    // left orphaned, systemd --user adopts it and it keeps launching
    // checkupdates every 5 min FOR EVER. That is how 7 piled up on 5 Aug 2026.
    //
    // And note the detail of why ONLY this one hung around and not sysstats.sh,
    // which is the same pattern: sysstats writes to stdout every 1.5 s, so as
    // soon as the pipe closes it gets SIGPIPE and dies by itself. Here the one
    // writing was the inner script; the outer loop never wrote —it only slept—,
    // so the SIGPIPE that would have killed it never reached it.
    //
    // Now the process is ONE-SHOT: it lasts as long as the query and ends. Even
    // if qs dies in the worst possible way, the most that can be left loose is
    // a checkupdates that closes by itself (the script already launches it with
    // timeout 60), not an immortal loop.
    property string pacman: ""
    // The script already computes these two and until now they were thrown
    // away: the tooltip carries the long count and the time of the last sync
    // ("3 actualizaciones disponibles · repos sincronizados a las 18:40", i.e.
    // "3 updates available · repos synced at 18:40"), and class says what kind
    // of number it is -- "updates", "none" or "error" -- without having to guess
    // it from the text. Both arrive already translated by lang.sh, so they do
    // not go through I18n.tr.
    property string pacmanTip: ""
    property string pacmanClass: ""
    Process {
        id: pacmanProc
        // true = right-click: invalidates the timestamp and forces a sync.
        property bool forceSync: false
        command: forceSync
            ? [root.home + "/.config/glasstty/scripts/updates.sh", "--refresh"]
            : [root.home + "/.config/glasstty/scripts/updates.sh"]
        stdout: SplitParser {
            onRead: function (line) {
                try {
                    const j = JSON.parse(line);
                    root.pacman = String(j.text || "");
                    root.pacmanTip = String(j.tooltip || "");
                    root.pacmanClass = String(j.class || "");
                } catch (e) {}
            }
        }
        onExited: forceSync = false
    }
    Timer {
        interval: 300000
        running: true
        repeat: true
        triggeredOnStart: true   // like the old loop: query right away at start-up
        onTriggered: if (!pacmanProc.running) pacmanProc.running = true
    }
    function pacmanRefresh() {
        if (pacmanProc.running) return;
        pacmanProc.forceSync = true;
        pacmanProc.running = true;
    }

    // ══════════════════════════ notifications (own server) ══════════════════════════
    // Replaces swaync: its "control centre" is a GTK window of its own, it cannot
    // be put inside the notch. Here we are the D-Bus server and we paint both the
    // pop-up notice and the history ourselves.
    property bool dnd: false
    // Switch the open Control Centre to a page (qs ipc call notch page N).
    signal controlGo(int n)
    property var lastNotif: null

    // Some programs only speak English in their notifications (niri's own
    // screenshot action, for one). Known texts are shown translated; the
    // notification itself is not touched. tn(text) is used where they are drawn.
    readonly property var notifPt: ({
        "Screenshot captured": "Captura de tela feita",
        "You can paste the image from the clipboard.": "Você pode colar a imagem da área de transferência.",
        "Failed to save screenshot": "Não foi possível salvar a captura de tela"
    })
    function tn(text) {
        if (!text || Config.language !== "pt") return text || "";
        return root.notifPt[text] || text;
    }

    NotificationServer {
        id: notifServer
        keepOnReload: true
        bodySupported: true
        bodyMarkupSupported: true
        imageSupported: true
        actionsSupported: true
        actionIconsSupported: true

        onNotification: function (n) {
            n.tracked = true;               // stays in the history
            root.lastNotif = n;
            if (!n.lastGeneration) root.stampNotif(n);
            // ...but the history has a ceiling. With Qt.callLater and not
            // directly: here the server's list does not include `n` yet (the
            // long why, with the measurement, is in trimNotifs), so calling it
            // on the spot would leave the history at 51 instead of 50. As a
            // bonus, Qt.callLater collapses a burst of sixty into a single
            // pass, and trimNotifs already knows how to remove several at once.
            Qt.callLater(root.trimNotifs);
            // A shell reload hands back the notifications it kept (keepOnReload)
            // through here again: they go back to the history, but the notch
            // must not announce them a second time.
            if (!root.dnd && !n.lastGeneration) root.announce(n);
            // A card updated in place (`notch ... --replace ID`, notify-send -r)
            // keeps the same object: show it again with its new text.
            const again = function () {
                root.stampNotif(n);
                if (root.dnd) return;
                root.lastNotif = n;
                root.announce(n);
            };
            n.summaryChanged.connect(again);
            n.bodyChanged.connect(again);
        }
    }

    // How a new notification is shown: as a drop under the notch
    // (NotifDrops.qml, the default) or inside the notch itself.
    signal notifPopped(var n)
    function announce(n) {
        if (Config.notifStyle === "notch") root.flash("notif", root.notifFlashMs(n));
        else root.notifPopped(n);
    }

    // ── how a notification looks, shared by the drops and the Control Centre ──
    // The kind's colour (the drops can turn it off: Config.dropKindColors).
    readonly property var kindColors: ({ ok: "#4ade80", warn: "#fbbf24", fail: "#f87171" })
    function notifKindColor(kind) { return root.kindColors[kind] || Colors.accent; }
    // A symbol instead of the icon for some notices: the screenshot ones get a
    // camera (glasstty's notify-shot.sh asks for it with a hint; niri's own
    // screenshot notice is recognised by its text).
    readonly property var notifGlyphs: ({ camera: "󰄀" })
    function notifGlyph(n) {
        const h = n && n.hints ? String(n.hints["x-glasstty-glyph"] || "") : "";
        if (root.notifGlyphs[h]) return root.notifGlyphs[h];
        const t = n ? String(n.summary || "") : "";
        if (t === "Screenshot captured" || t === "Failed to save screenshot") return root.notifGlyphs.camera;
        return "";
    }
    // The picture to show: the one the notification brings, else its app's
    // icon; "" when there is none (or the theme lacks it) or a symbol wins.
    function notifImage(n) {
        if (!n || root.notifGlyph(n) !== "") return "";
        if (n.image && n.image.length > 0) return n.image;
        const ic = n.appIcon || "";
        if (ic === "") return "";
        if (ic.startsWith("/")) return "file://" + ic;
        if (ic.startsWith("file:")) return ic;
        return Quickshell.iconPath(ic, true);
    }
    // The mark when there is no picture: the kind's, the symbol, or a bell.
    function notifMark(n) {
        const g = root.notifGlyph(n);
        if (g !== "") return g;
        const k = root.notifKind(n);
        return k === "ok" ? "󰄬" : k === "warn" ? "󰀦" : k === "fail" ? "󰅖" : k === "info" ? "󰋽" : "󰂚";
    }

    // When each one arrived (or was last updated), by id, for "5 min" in the
    // Control Centre. Ones handed back by a shell reload have no time.
    property var notifTimes: ({})
    function stampNotif(n) {
        const t = Object.assign({}, root.notifTimes);
        t[n.id] = Date.now();
        root.notifTimes = t;
    }
    property real notifNow: Date.now()
    Timer { interval: 30000; running: true; repeat: true; onTriggered: root.notifNow = Date.now() }
    function notifAgo(n) {
        const t = n ? root.notifTimes[n.id] : undefined;
        if (!t) return "";
        const s = Math.max(0, (root.notifNow - t) / 1000);
        if (s < 60) return I18n.tr("ahora");
        if (s < 3600) return I18n.tr("{0} min", Math.floor(s / 60));
        if (s < 86400) return I18n.tr("{0} h", Math.floor(s / 3600));
        return Qt.formatDate(new Date(t), "dd/MM");
    }

    // Identical notices (same app, title and text) are one row with a count:
    // five "Claude is done" are not five things to read. The row is the newest.
    function notifKey(n) { return (n.appName || "") + "\u0001" + (n.summary || "") + "\u0001" + (n.body || ""); }
    readonly property var notifHeads: {
        const seen = {}, out = [];
        for (const n of root.notifications) {
            const k = root.notifKey(n);
            if (seen[k]) continue;
            seen[k] = true;
            out.push(n);
        }
        return out;
    }
    function notifDupes(n) {
        const k = root.notifKey(n);
        return root.notifications.filter(m => root.notifKey(m) === k);
    }
    function dismissGroup(n) {
        const all = root.notifDupes(n);
        for (let i = 0; i < all.length; i++) all[i].dismiss();
    }

    // drip-style cards (~/.local/bin/notch): the kind comes in the
    // x-notch-kind hint — "ok", "warn", "fail" or "info". "" = a plain notification.
    function notifKind(n) {
        if (!n || !n.hints) return "";
        const k = String(n.hints["x-notch-kind"] || "");
        return ["ok", "warn", "fail", "info"].indexOf(k) >= 0 ? k : "";
    }
    // The buttons a card shows: its actions except "default" (a click on the card).
    function notifButtons(n) {
        if (!n || !n.actions) return [];
        const out = [];
        for (let i = 0; i < n.actions.length; i++)
            if (n.actions[i].identifier !== "default") out.push(n.actions[i]);
        return out;
    }

    // `lastNotif` holds an object that is NOT ours: the server destroys it when
    // the notification closes (the user closes it, the application withdraws
    // it, or clearNotifs sweeps it away). Without this the notch kept showing
    // an already dead notification, and pressing its actions did nothing,
    // without saying why. Same pattern as the Connections in NetworkPanel.
    Connections {
        target: root.lastNotif
        ignoreUnknownSignals: true
        function onClosed(reason) {
            root.lastNotif = null;
            // AND THE NOTICE GOES WITH IT.
            //
            // This Connections was left half done: it removed the dead
            // notification but not the notice showing it. Since `activityTimer`
            // is the only thing that clears `activity`, and `mode` comes from
            // `activity === "notif"` without looking at `lastNotif`, the pill
            // stayed open and EMPTY -no icon, no title, no application, 430 px
            // wide- until the clock ran out. With a `notify-send -u critical`
            // (no -t, expireTimeout -1, notifFlashMs 11000) that is eleven
            // seconds of blank pill in front of you. It is enough for the
            // application to close its own notification; no panel is needed.
            if (root.activity === "notif") {
                root.activity = "";
                activityTimer.stop();
            }
        }
    }

    // most recent first
    readonly property var notifications: {
        const vs = notifServer.trackedNotifications ? notifServer.trackedNotifications.values : [];
        return vs.slice().reverse();
    }
    readonly property int notifCount: notifications.length

    // History ceiling: 50. It does NOT expire on a clock, and on purpose: what
    // `trackedNotifications` holds are the server's LIVE objects -the panel
    // invokes THEIR actions-, so a notification that deleted itself would be a
    // button vanishing while you look at it. The oldest is only thrown out when
    // a new one comes in and there is no room left. And it is closed with
    // expire(), not dismiss(): the program that sent it has to be told that it
    // expired, not that you closed it.
    readonly property int notifMax: 50

    // MIND WHEN THIS IS CALLED. `trackedNotifications.values` does NOT yet
    // contain the incoming notification while onNotification runs, not even
    // after setting `n.tracked = true`. Measured with a test NotificationServer
    // on an isolated bus (dbus-run-session, quickshell 0.3.1, without touching
    // the live shell): when the first notification arrives the list gives 0,
    // and in the following Qt.callLater it gives 1. That is why onNotification
    // does not call this on the spot: with notifMax = 5 and twelve
    // notifications in a row the history stayed at 6, i.e. notifMax + 1. With
    // Qt.callLater it stays at exactly 5.
    function trimNotifs() {
        if (!notifServer.trackedNotifications) return;
        const vs = notifServer.trackedNotifications.values;
        const sobran = vs.length - root.notifMax;
        if (sobran <= 0) return;
        // slice() before closing anything: expire() modifies the live list -also
        // checked-, and we have to iterate over a copy. values[0] is the oldest:
        // the `notifications` property up here does reverse() because the panel
        // paints the recent ones first.
        const viejas = vs.slice(0, sobran);
        for (let i = 0; i < viejas.length; i++)
            if (viejas[i] !== root.lastNotif) viejas[i].expire();
    }

    // How long the pop-up notice lasts. The application asks for its time in
    // `expireTimeout` (-1 = "you decide", 0 = "never expire") and it is obeyed,
    // but with a ceiling. The ceiling is not stinginess: the notch's activity
    // slot is ONE and music, volume, workspace and pokémon share it, so an
    // eternal notice would not be a notice, it would be a hijacked notch. That
    // is why 0 is translated to the maximum, also for a critical one: the
    // notification remains whole in the history, which is where it waits for
    // as long as needed.
    //
    // UNITS: MILLISECONDS, and nothing is converted here. The
    // org.freedesktop.Notifications specification defines expire_timeout as
    // "the timeout time in milliseconds", and Quickshell passes it through as
    // is: it exposes it as a double, but does not divide it. Measured on this
    // machine, with a test NotificationServer on an isolated bus:
    //     notify-send -t 9000   ->  expireTimeout = 9000
    //     notify-send -t 60000  ->  expireTimeout = 60000
    //     notify-send -t 0      ->  expireTimeout = 0      (never expire)
    //     notify-send  (no -t)  ->  expireTimeout = -1     (you decide)
    // The property being a double and not an int does NOT mean seconds arrive.
    function notifFlashMs(n) {
        const crit = !!n && n.urgency === NotificationUrgency.Critical;
        // A critical one -battery at 5 %, disk full- asks to be looked at twice:
        // it does not go below 10 s or above 12. The rest, from 1.5 s to 15 s.
        const suelo = crit ? 10000 : 1500;
        const techo = crit ? 12000 : 15000;
        const porDefecto = crit ? 11000 : Math.round(Math.max(1.5, Math.min(15, Config.notifSeconds)) * 1000);
        if (!n) return porDefecto;
        // A card asking something (buttons) waits up to a minute for the answer:
        // the question is the point of it, and the script is waiting too.
        if (root.notifKind(n) !== "" && root.notifButtons(n).length > 0) {
            const tq = Number(n.expireTimeout);
            return (!isFinite(tq) || tq <= 0) ? 30000 : Math.max(3000, Math.min(60000, Math.round(tq)));
        }
        const t = Number(n.expireTimeout);
        if (!isFinite(t) || t < 0) return porDefecto;   // -1: you decide
        if (t === 0) return techo;                      // 0: never expire
        return Math.max(suelo, Math.min(techo, Math.round(t)));
    }

    function dismissNotif(n) { if (n) n.dismiss(); }
    function clearNotifs() {
        const vs = notifServer.trackedNotifications ? notifServer.trackedNotifications.values.slice() : [];
        for (let i = 0; i < vs.length; i++) vs[i].dismiss();
    }

    readonly property string notifIcon: dnd ? (notifCount > 0 ? "󰂠" : "󰪓")
        : (notifCount > 0 ? "󱅫" : "󰂜")

    // ═══════════════════════ night light ════════════════════════
    // THE STATE IS OBSERVED, NOT GUESSED.
    //
    // `nightLight` was a bare bool -not readonly, not derived, not polled, and
    // outside Config, so it did not survive a reload either- that was flipped
    // blindly. And there were THREE paths onto the same filter that did not
    // talk to each other: Super+Shift+N launched night-light.sh without
    // telling the shell, the ">" mode called the same script without touching
    // the bool, and the control centre flipped the bool and launched
    // `pgrep ... || hyprsunset &`. That `||` was the finishing touch: if
    // hyprsunset WAS already running it executed nothing and the tile was left
    // lying. You switched it on with the key, opened the control centre and the
    // tile said off; you pressed it and nothing changed.
    //
    // Now the three paths come in through the same door -the script- and the
    // state comes from `pgrep`, like the reading mode down here. It is what
    // impasto's SunsetService.qml does with `readonly property bool on:
    // filter.running`, adapted to the fact that here the shell does not own the
    // process.
    readonly property string sunsetTool: root.home + "/.config/glasstty/scripts/night-light.sh"
    property bool nightLight: false

    Process {
        id: sunsetProbe
        command: ["pgrep", "-x", "hyprsunset|wlsunset"]
        onExited: function (exitCode) { root.nightLight = (exitCode === 0); }
    }
    // Every 3 s, the same pace as the reading-mode poll: it is a pgrep, and
    // the filter is switched on by hand, not a hundred times a minute.
    Timer {
        interval: 3000
        repeat: true
        running: true
        triggeredOnStart: true
        onTriggered: if (!sunsetProbe.running) sunsetProbe.running = true
    }
    // And an immediate pass after each toggle, so that the tile does not
    // take three seconds to reflect what you have just pressed.
    Timer { id: sunsetTrasToggle; interval: 350; onTriggered: sunsetProbe.running = true }

    function toggleNightLight() {
        Quickshell.execDetached([root.sunsetTool]);
        sunsetTrasToggle.restart();
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

    // ══════════════════════ the weather ══════════════════════
    // Inherited from the Sidebar when it was retired. Refreshes every half hour.
    //
    // Timer + one-shot process, for the same reason as the updates above: a
    // `while true` in bash outlives quickshell if it dies suddenly. This one
    // never got to be immortal —writing to stdout every half hour it ended up
    // eating a SIGPIPE and dying—, but until its turn to write came it stayed
    // loose for up to 30 min making a network request for nobody. It was the
    // last place with this pattern.
    // THE WEATHER. It used to ask for plain "%t·%C" and paint the raw text,
    // with two faults that had been there from the start: the condition ALWAYS
    // arrived in English ("Clear") in a shell that is otherwise entirely in
    // whatever language is set, and the icon next to it was the BRIGHTNESS
    // slider's, whatever the weather.
    //
    // Now the language goes in the URL and wttr.in translates, which it does
    // better than we would here: there are 48 descriptions with nuances
    // ("Patchy light drizzle") and translating them by hand would be a huge
    // table that ends up lame. And "%x" is requested too, a symbol of one to
    // three letters that does NOT depend on the language, which is what picks
    // the icon.
    property string weatherTemp: ""
    property string weatherCond: ""
    property string weatherSym: ""
    readonly property string weather: root.weatherTemp.length
        ? root.weatherTemp + "  ·  " + root.weatherCond : "…"

    // wttr.in's symbol (inherited from wego) to Material Design Icons. It is
    // checked from the MOST specific to the least, and the order matters: "!/"
    // is a thunderstorm with rain, so checking rain first would show an umbrella
    // in the middle of a storm. Checked against the service: o=clear,
    // m/mm/mmm=clouds, .=showers, !=thunderstorm, x=freezing rain, ?=haze.
    readonly property string weatherIcon: {
        const x = root.weatherSym;
        if (!x.length) return "󰖐";
        if (x.indexOf("!") >= 0) return "󰖓";
        if (x.indexOf("*") >= 0) return "󰖘";
        if (x.indexOf("x") >= 0) return "󰙿";
        if (x.indexOf("=") >= 0) return "󰖑";
        // Haze has no icon of its own in wego and arrives as "?". Fog is the
        // closest there is: both are "you cannot see".
        if (x.indexOf("?") >= 0) return "󰖑";
        if (".,'/\\".split("").some(c => x.indexOf(c) >= 0)) return "󰖗";
        if (x === "m") return "󰖕";
        if (x === "o") return "󰖙";
        return "󰖐";
    }

    Process {
        id: weatherProc
        // The trailing `echo` is NOT redundant: wttr.in with ?format= answers
        // WITHOUT a newline, and SplitParser splits precisely on newlines. Without
        // it the reading stays in the buffer and the weather never updates.
        command: ["bash", "-c", "curl -s --max-time 8 'wttr.in/?lang=" + I18n.lang
                  + "&format=%t·%C·%x' 2>/dev/null; echo"]
        stdout: SplitParser {
            onRead: function (line) {
                const t = line.trim();
                if (!t.length)
                    return;
                const trozos = t.split("·");
                root.weatherTemp = (trozos[0] || "").trim();
                root.weatherCond = (trozos[1] || "").trim();
                root.weatherSym = (trozos[2] || "").trim();
            }
        }
    }

    // Changing language has to request it again: the condition is translated by
    // the server, so the one already on screen would stay in the previous
    // language until the next turn of the clock -- half an hour of a half-done
    // shell, which is exactly what the language layer exists to prevent.
    Connections {
        target: I18n
        function onLangChanged(): void {
            if (!weatherProc.running)
                weatherProc.running = true;
        }
    }
    Timer {
        interval: 1800000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: if (!weatherProc.running) weatherProc.running = true
    }

    // ═══════════════════════ GitHub ═══════════════════════
    // What GithubPanel.qml paints: the contribution grid for the last year, the
    // streak and the latest commits. The script makes ONE single API call and
    // saves the response in ~/.cache/quickshell/github.json, so when there is no
    // network the panel shows last time's data with `stale: true` instead of
    // staying blank.
    //
    // StdioCollector and not SplitParser: the output is a single-piece JSON and
    // it is needed whole to parse it, not line by line.
    property var github: ({ weeks: [], commits: [], total: 0, streak: 0,
                            today: 0, login: "", stale: false })
    property bool githubLoading: false
    Process {
        id: githubProc
        command: [Quickshell.env("HOME") + "/.config/quickshell/scripts/github-stats.py"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    root.github = JSON.parse(text);
                } catch (e) {
                    // The script promises JSON always, even when it fails. If
                    // rubbish arrives even so, better to keep what was there
                    // than to empty the panel.
                }
                root.githubLoading = false;
            }
        }
        // Safety net, same as in the clipboard: if the script is missing or
        // blows up before writing, the panel does not get stuck on «Cargando…»
        // (Loading…).
        onExited: root.githubLoading = false
    }
    function githubRefresh() {
        if (githubProc.running)
            return;
        root.githubLoading = true;
        githubProc.running = true;
    }
    Timer {
        // 15 min. Commits do not arrive faster than that, and the panel also
        // refreshes by itself when opened, which is when it really matters.
        interval: 900000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: root.githubRefresh()
    }

    // ══════════════════════ game mode ═══════════════════════
    // A switch, not a detector: while it is off nothing is polled at all. While
    // it is on, scripts/gamestats.sh reads the CSV that MangoHud writes (hidden)
    // for the running game, and the bar shows fps / CPU / GPU next to the
    // battery. MangoHud is on for every VULKAN Steam game at once (Proton's
    // DXVK/VKD3D, native Vulkan), Afterburner style: the Steam Flatpak carries
    // MANGOHUD=1 as a `flatpak override` (see docs/modo-jogo.md). OpenGL games
    // still need the launch option `.../MangoHud/bin/mangohud %command%`:
    // a global LD_PRELOAD of the shim hangs steam-runtime-launch-client at
    // 100 % CPU and no game starts (tried 2026-11-22). Without a log to read,
    // the bar only shows the mode's icon.
    property bool gameMode: false
    property bool gameRunning: false
    property int gameFps: 0
    property real gameFrametime: 0
    property int gameCpu: 0
    property int gameGpu: 0
    property int gameCpuTemp: 0
    property int gameGpuTemp: 0
    onGameModeChanged: if (!gameMode) gameRunning = false
    function toggleGameMode() {
        root.gameMode = !root.gameMode;
        Launcher.toast(Icons.gamepad, root.gameMode ? I18n.tr("Modo juego activado")
                                                : I18n.tr("Modo juego desactivado"));
    }
    Process {
        id: gamestatsProc
        command: [root.home + "/.config/quickshell/scripts/gamestats.sh"]
        running: root.gameMode
        // Same breather as sysstats: a broken script must not respawn at full speed.
        onExited: function (exitCode, exitStatus) {
            if (root.gameMode) gamestatsRestart.restart();
        }
        stdout: SplitParser {
            onRead: function (line) {
                const p = line.trim().split(/\s+/);
                if (p[0] !== "1" || p.length < 7) { root.gameRunning = false; return; }
                root.gameFps = parseInt(p[1]);
                root.gameFrametime = parseFloat(p[2]);
                root.gameCpu = parseInt(p[3]);
                root.gameGpu = parseInt(p[4]);
                root.gameCpuTemp = parseInt(p[5]);
                root.gameGpuTemp = parseInt(p[6]);
                root.gameRunning = true;
            }
        }
    }
    Timer {
        id: gamestatsRestart
        interval: 2000
        repeat: false
        onTriggered: if (root.gameMode && !gamestatsProc.running) gamestatsProc.running = true;
    }
    // `qs ipc call gamemode toggle` — for a niri keybind or a script.
    IpcHandler {
        target: "gamemode"
        function toggle(): void { root.toggleGameMode(); }
        function status(): string {
            if (!root.gameMode) return "off";
            if (!root.gameRunning) return "on (no game)";
            return "on " + root.gameFps + "fps cpu=" + root.gameCpu + "% gpu=" + root.gameGpu
                + "% temp=" + root.gameCpuTemp;
        }
    }

    // ══════════════════════ caffeine ═══════════════════════
    // Off by default, on the charger too: the screen locks at 5 min and turns
    // off at 10 (swayidle) unless you switch caffeine on for a film or a game.
    // On battery it is also forced off; the notch button still overrides it.
    property bool caffeine: false
    property bool caffeineBeforeBattery: false
    property bool batteryIdleApplied: false
    function updateBatteryIdle() {
        if (!Config.loaded) return;
        if (Energy.onBattery && Config.batteryAllowIdle) {
            if (!root.batteryIdleApplied) {
                root.caffeineBeforeBattery = root.caffeine;
                root.batteryIdleApplied = true;
                root.caffeine = false;
            }
        } else if (root.batteryIdleApplied) {
            root.batteryIdleApplied = false;
            root.caffeine = root.caffeineBeforeBattery;
        }
    }
    Connections {
        target: Energy
        function onOnBatteryChanged() { root.updateBatteryIdle(); }
    }
    Connections {
        target: Config
        function onLoadedChanged() { root.updateBatteryIdle(); }
        function onBatteryAllowIdleChanged() { root.updateBatteryIdle(); }
    }
    Timer { interval: 1800; running: true; onTriggered: root.updateBatteryIdle() }

    // ══════════════════════════ bluetooth pairing ═══════════════════════════
    // Quickshell knows how to pair (Bluetooth.pair()) but NOT how to answer what
    // BlueZ asks halfway through pairing: "does this code match?", "type these
    // six digits". Those questions arrive at a D-Bus object that has to be
    // EXPORTED, and QML cannot export D-Bus objects. That is why there is a
    // separate process (scripts/bt-agent.py) that does, and that talks to the
    // notch over IPC. Only what has to be shown and the answer live here.
    //
    // Without this headphones pair just the same (they ask nothing) but a
    // keyboard or a controller fails SILENTLY, which is the worst of all: there
    // is no error, it simply never pairs.
    property string btKind: ""     // "" | "confirm" | "display" | "authorize"
    property string btName: ""     // name of the device
    property string btCode: ""     // the six digits, "" if there are none
    property int btEntered: -1     // digits already typed (only in "display")
    readonly property bool btAsking: root.btKind !== ""

    function btAsk(kind, name, code, entered) {
        root.btKind = kind;
        root.btName = name;
        root.btCode = code;
        root.btEntered = entered;
    }

    function btClear() {
        root.btKind = ""; root.btName = ""; root.btCode = ""; root.btEntered = -1;
    }

    function btReply(accept) {
        // ALWAYS cleared, whatever the agent answers: if the process had died,
        // the face would stay stuck in the notch covering everything else
        // (btpair goes ahead even of the panels).
        btReplyProc.command = ["busctl", "--user", "call",
            "org.quickshell.BtAgent", "/org/quickshell/btagent",
            "org.quickshell.BtAgent1", "Reply", "b", accept ? "true" : "false"];
        btReplyProc.running = true;
        root.btClear();
    }

    Process { id: btReplyProc }

    // Reorder by dragging: `to` is the insertion SLOT (0..n), not an element's
    // index, which is why one has to be subtracted when moving to the right
    // (taking the element out shifts everything behind it one position).
    function moveFav(from, to) {
        const ids = Config.favApps.slice();
        if (from < 0 || from >= ids.length) return;
        let t = Math.max(0, Math.min(ids.length, to));
        if (t > from) t -= 1;
        if (t === from) return;
        ids.splice(t, 0, ids.splice(from, 1)[0]);
        Config.favApps = ids;
        Config.save();
    }
}
