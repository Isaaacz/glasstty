// Brightness.qml — screen brightness (brightnessctl) for the Control Centre
// slider and the OSD. Split out of ShellState.qml.
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

    // ═════════════════════ brightness ═════════════════════
    property int bright: -1
    Process {
        id: brightProc
        stdout: SplitParser {
            onRead: function (line) {
                const v = parseInt(line.trim());
                if (!isNaN(v)) { root.bright = v; ShellState.flash("brightness"); }
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
}
