// NightLight.qml — the night light (hyprsunset or wlsunset), read from what is
// actually running. Split out of ShellState.qml.
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
    readonly property string sunsetTool: ShellState.home + "/.config/glasstty/scripts/night-light.sh"
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
}
