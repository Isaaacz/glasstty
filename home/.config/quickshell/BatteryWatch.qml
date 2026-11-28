// BatteryWatch.qml — low-battery warnings.
//
// Reads SystemStats.batt / SystemStats.ac (already polled for the notch) and
// sends one notification per level as the battery drains: 20 %, 10 %, 5 %.
// Plugging the charger in, or the charge climbing back above a level, re-arms
// it. Power saver needs nothing here: Energy.qml already switches to the
// "on battery" profile (power saver by default) when the charger comes out.
import Quickshell
import Quickshell.Io
import QtQuick

Scope {
    id: root
    readonly property var levels: [20, 10, 5]
    property int warned: 101        // lowest level already warned about

    function txt(pt, en, es) {
        return Config.language === "pt" ? pt : Config.language === "en" ? en : es;
    }
    function warn(level, pct) {
        const critical = level <= 10;
        const title = critical ? root.txt("Bateria muito fraca", "Battery very low", "Batería muy baja")
                               : root.txt("Bateria fraca", "Battery low", "Batería baja");
        const body = level <= 5
            ? root.txt("{0}% · conecte o carregador agora", "{0}% · plug in the charger now", "{0}% · conecta el cargador ya")
            : root.txt("{0}% restantes · conecte o carregador", "{0}% left · plug in the charger", "{0}% restante · conecta el cargador");
        Quickshell.execDetached(["notify-send", "-a", root.txt("Bateria", "Battery", "Batería"),
            "-u", critical ? "critical" : "normal", "-i", critical ? "battery-caution" : "battery-low",
            title, body.replace("{0}", pct ?? SystemStats.batt)]);
    }
    function check() {
        const b = SystemStats.batt;
        if (b < 0) return;
        if (SystemStats.ac) { root.warned = 101; return; }
        // Climbing back above a level (a short charge) re-arms that level.
        while (root.warned <= 20 && b > root.warned) {
            const i = root.levels.indexOf(root.warned);
            root.warned = i > 0 ? root.levels[i - 1] : 101;
        }
        for (const l of root.levels) {
            if (b <= l && l < root.warned) {
                root.warned = l;
                const deepest = root.levels.filter(x => b <= x).pop();
                if (l === deepest) root.warn(l);    // one notification, for the lowest level crossed
            }
        }
    }

    Connections {
        target: SystemStats
        function onBattChanged() { root.check(); }
        function onAcChanged() { root.check(); }
    }
    IpcHandler {
        target: "battery"
        // For testing: qs ipc call battery test 10 (shows "10%", not the real charge)
        function test(level: int): void { root.warn(level, level); }
        function status(): string { return "batt=" + SystemStats.batt + " ac=" + SystemStats.ac + " warned=" + root.warned; }
    }
}
