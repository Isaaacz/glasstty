// GameMode.qml — game mode: while it is on, the bar shows the running game's
// name, fps, CPU and GPU (from MangoHud). It also turns itself on with a Steam
// game, keeps notices quiet while you play, keeps the session's numbers for a
// summary when the game closes, warns when the machine runs hot and feeds the
// performance overlay (GameOverlay.qml). Split out of ShellState.qml.
pragma Singleton

import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtQuick

Singleton {
    id: root

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
    property real gameRam: 0             // GiB, from MangoHud
    property real gameVram: 0            // GiB
    property var fpsHistory: []          // the last minute, one value a second, for the overlay
    onGameModeChanged: if (!gameMode) gameRunning = false
    function toggleGameMode() {
        root.gameMode = !root.gameMode;
        root.autoOn = false;          // your hand wins: auto no longer turns it off
        Launcher.toast(Icons.gamepad, root.gameMode ? I18n.tr("Modo juego activado")
                                                : I18n.tr("Modo juego desactivado"));
    }
    Process {
        id: gamestatsProc
        command: [ShellState.home + "/.config/quickshell/scripts/gamestats.sh"]
        // the overlay reads it too, game mode on or not
        running: root.gameMode || root.overlayOn
        // Same breather as sysstats: a broken script must not respawn at full speed.
        onExited: function (exitCode, exitStatus) {
            if (root.gameMode || root.overlayOn) gamestatsRestart.restart();
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
                root.gameRam = p.length > 7 ? parseFloat(p[7]) : 0;
                root.gameVram = p.length > 8 ? parseFloat(p[8]) : 0;
                root.gameRunning = true;
                root.sample();
            }
        }
    }
    Timer {
        id: gamestatsRestart
        interval: 2000
        repeat: false
        onTriggered: if ((root.gameMode || root.overlayOn) && !gamestatsProc.running) gamestatsProc.running = true;
    }

    // ───── automatic: on while a Steam game runs ─────
    // scripts/steamgame.sh finds Steam's `reaper SteamLaunch AppId=N` and the
    // game's name. Nothing is polled: a game opening or closing means a window
    // appearing or going, so the check runs only when the window list changes
    // (and once at start). Off again when the game is gone. A game that opens
    // with the mode already on (left on from earlier) is adopted the same
    // way; only switching it yourself WHILE the game runs keeps it as you set it.
    // (Before, a mode left on stayed on forever after the game: 2026-11-28.)
    property bool steamGame: false
    property string gameName: ""
    property bool autoOn: false
    onSteamGameChanged: {
        if (!Config.gameAuto) return;
        if (root.steamGame) {
            if (!root.gameMode) {
                root.gameMode = true;
                Launcher.toast(Icons.gamepad, I18n.tr("Modo juego activado"));
            }
            root.autoOn = true;
        } else if (!root.steamGame && root.gameMode && root.autoOn) {
            root.gameMode = false;
            root.autoOn = false;
        }
    }
    Connections {
        target: ToplevelManager.toplevels
        function onValuesChanged() { steamCheckDelay.restart(); }
    }
    // a game's window can open a moment before / close a moment after reaper
    Timer { id: steamCheckDelay; interval: 1500; onTriggered: if (!steamCheck.running) steamCheck.running = true }
    Timer { interval: 3000; running: true; onTriggered: steamCheck.running = true }
    Process {
        id: steamCheck
        command: [ShellState.home + "/.config/quickshell/scripts/steamgame.sh"]
        stdout: StdioCollector {
            onStreamFinished: {
                const t = this.text.trim().split("\t");
                if (t.length > 1 && t[1] !== "") root.gameName = t[1];
            }
        }
        onExited: function (code) { root.steamGame = code === 0; }
    }

    // ───── the session: from the game opening to it closing ─────
    // A session is live while a Steam game runs or MangoHud is logging one.
    // It ends 8 s after both stop (a loading screen can pause the log), and if
    // it lasted a minute or more the notch shows a summary of it.
    readonly property bool playing: root.steamGame || root.gameRunning
    property bool sessionLive: false
    property real sessionStart: 0
    property int sessionSamples: 0
    property real sessionFpsSum: 0
    property int sessionFpsMin: 0
    property int sessionCpuMax: 0
    property int sessionGpuMax: 0
    property var lastSession: null       // what the summary face shows
    onPlayingChanged: {
        if (root.playing) {
            sessionEnd.stop();
            if (!root.sessionLive) root.startSession();
        } else if (root.sessionLive) {
            sessionEnd.restart();
        }
    }
    Timer { id: sessionEnd; interval: 8000; onTriggered: root.endSession() }

    function startSession() {
        root.sessionLive = true;
        root.sessionStart = Date.now();
        root.sessionSamples = 0;
        root.sessionFpsSum = 0;
        root.sessionFpsMin = 0;
        root.sessionCpuMax = 0;
        root.sessionGpuMax = 0;
        root.fpsHistory = [];
        NotificationCenter.missedWhilePlaying = 0;
    }
    function sample() {
        const h = root.fpsHistory.slice(-59);
        h.push(root.gameFps);
        root.fpsHistory = h;
        if (!root.sessionLive) return;
        // menus and loading screens sit near 0 fps: they are not how it played
        if (root.gameFps >= 5) {
            root.sessionSamples++;
            root.sessionFpsSum += root.gameFps;
            root.sessionFpsMin = root.sessionFpsMin === 0 ? root.gameFps : Math.min(root.sessionFpsMin, root.gameFps);
        }
        root.sessionCpuMax = Math.max(root.sessionCpuMax, root.gameCpuTemp);
        root.sessionGpuMax = Math.max(root.sessionGpuMax, root.gameGpuTemp);
        root.checkHeat();
    }
    function endSession() {
        if (!root.sessionLive) return;
        root.sessionLive = false;
        const mins = Math.round((Date.now() - root.sessionStart) / 60000);
        const missed = NotificationCenter.missedWhilePlaying;
        NotificationCenter.missedWhilePlaying = 0;
        if (mins >= 1) {
            root.lastSession = {
                name: root.gameName || I18n.tr("Partida"),
                mins: mins,
                avg: root.sessionSamples > 0 ? Math.round(root.sessionFpsSum / root.sessionSamples) : 0,
                min: root.sessionFpsMin,
                cpu: root.sessionCpuMax,
                gpu: root.sessionGpuMax,
                missed: missed
            };
            ShellState.flash("gamesum", 9000);
        } else if (missed > 0) {
            Launcher.toast("󰂚", I18n.tr("{0} avisos mientras jugabas", missed));
        }
        root.gameName = "";
    }
    // "1 h 12 min" / "48 min"
    function duration(mins) {
        const h = Math.floor(mins / 60), m = mins % 60;
        return h > 0 ? (m > 0 ? h + " h " + m + " min" : h + " h") : m + " min";
    }

    // ───── running hot ─────
    // 90° on the CPU or the GPU: a short warning drawn over the game by
    // GameOverlay.qml (the notch steps aside in fullscreen). At most once every
    // five minutes, so a game that lives at 90° is not nagged about forever.
    readonly property int heatLimit: 90
    property string heatAlert: ""
    property real lastHeat: 0
    function checkHeat() {
        const hot = Math.max(root.gameCpuTemp, root.gameGpuTemp);
        if (hot < root.heatLimit || Date.now() - root.lastHeat < 300000) return;
        root.lastHeat = Date.now();
        root.heatAlert = root.gameCpuTemp >= root.gameGpuTemp
            ? I18n.tr("CPU a {0}° · está caliente", root.gameCpuTemp)
            : I18n.tr("GPU a {0}° · está caliente", root.gameGpuTemp);
        heatClear.restart();
    }
    Timer { id: heatClear; interval: 7000; onTriggered: root.heatAlert = "" }

    // ───── performance overlay ─────
    // Drawn over the game by GameOverlay.qml; Mod+Shift+G (niri) toggles it.
    property bool overlayOn: false

    // `qs ipc call gamemode toggle` — for a niri keybind or a script.
    IpcHandler {
        target: "gamemode"
        function toggle(): void { root.toggleGameMode(); }
        // the performance overlay over the game
        function overlay(): void { root.overlayOn = !root.overlayOn; }
        // look for a running Steam game now (the window list changing does it too)
        function check(): void { steamCheck.running = true; }
        function status(): string {
            if (!root.gameMode) return "off" + (root.steamGame ? " (steam game, auto " + (Config.gameAuto ? "on" : "off") + ")" : "");
            if (!root.gameRunning) return "on (no game)";
            return "on " + root.gameFps + "fps cpu=" + root.gameCpu + "% gpu=" + root.gameGpu
                + "% temp=" + root.gameCpuTemp;
        }
    }
}
