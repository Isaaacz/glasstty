// Satellite.qml — the small bubble that peeks out from behind the notch's
// right edge while something runs in the background: the countdown timer
// (typed in the launcher or `qs ipc call notch timer 10m`) and a forced
// update. TopShell.qml draws it. Split out of ShellState.qml.
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
    readonly property bool busy: Updates.updating

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
}
