// Updates.qml — pending system updates and running them (the forced update
// shows in the satellite bubble). Split out of ShellState.qml.
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
    // A forced update is running (right-click): the satellite bubble shows it.
    readonly property bool updating: pacmanProc.running && pacmanProc.forceSync

    Process {
        id: pacmanProc
        // true = right-click: invalidates the timestamp and forces a sync.
        property bool forceSync: false
        command: forceSync
            ? [ShellState.home + "/.config/glasstty/scripts/updates.sh", "--refresh"]
            : [ShellState.home + "/.config/glasstty/scripts/updates.sh"]
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
}
