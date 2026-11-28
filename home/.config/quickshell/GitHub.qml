// GitHub.qml — the GitHub stats for the GitHub door and panel. Split out of
// ShellState.qml.
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
}
