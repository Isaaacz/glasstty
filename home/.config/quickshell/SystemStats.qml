// SystemStats.qml — CPU, memory, disk, temperature and battery, polled for the
// Control Centre, Settings and the performance panel. Split out of
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
        command: [ShellState.home + "/.config/quickshell/scripts/sysstats.sh"]
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
                if (Brightness.bright < 0) Brightness.bright = parseInt(p[4]);   // only the initial value
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
    onAcChanged: if (ShellState.armed) ShellState.flash("charge")

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
}
