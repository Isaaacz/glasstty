// GameMode.qml — game mode: while it is on, the bar shows the running game's
// fps, CPU and GPU (from MangoHud). Split out of ShellState.qml.
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
        command: [ShellState.home + "/.config/quickshell/scripts/gamestats.sh"]
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
}
