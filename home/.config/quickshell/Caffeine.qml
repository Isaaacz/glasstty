// Caffeine.qml — caffeine: keeps the screen from locking or sleeping while on.
// Split out of ShellState.qml.
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
}
