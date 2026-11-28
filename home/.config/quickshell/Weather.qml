// Weather.qml — the weather for the Control Centre, from wttr.in every half
// hour. Split out of ShellState.qml.
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

    // ══════════════════════ the weather ══════════════════════
    // Inherited from the Sidebar when it was retired. Refreshes every half hour.
    //
    // Timer + one-shot process, for the same reason as the updates above: a
    // `while true` in bash outlives quickshell if it dies suddenly. This one
    // never got to be immortal —writing to stdout every half hour it ended up
    // eating a SIGPIPE and dying—, but until its turn to write came it stayed
    // loose for up to 30 min making a network request for nobody. It was the
    // last place with this pattern.
    // THE WEATHER. It used to ask for plain "%t·%C" and paint the raw text,
    // with two faults that had been there from the start: the condition ALWAYS
    // arrived in English ("Clear") in a shell that is otherwise entirely in
    // whatever language is set, and the icon next to it was the BRIGHTNESS
    // slider's, whatever the weather.
    //
    // Now the language goes in the URL and wttr.in translates, which it does
    // better than we would here: there are 48 descriptions with nuances
    // ("Patchy light drizzle") and translating them by hand would be a huge
    // table that ends up lame. And "%x" is requested too, a symbol of one to
    // three letters that does NOT depend on the language, which is what picks
    // the icon.
    property string weatherTemp: ""
    property string weatherCond: ""
    property string weatherSym: ""
    readonly property string weather: root.weatherTemp.length
        ? root.weatherTemp + "  ·  " + root.weatherCond : "…"

    // wttr.in's symbol (inherited from wego) to Material Design Icons. It is
    // checked from the MOST specific to the least, and the order matters: "!/"
    // is a thunderstorm with rain, so checking rain first would show an umbrella
    // in the middle of a storm. Checked against the service: o=clear,
    // m/mm/mmm=clouds, .=showers, !=thunderstorm, x=freezing rain, ?=haze.
    readonly property string weatherIcon: {
        const x = root.weatherSym;
        if (!x.length) return "󰖐";
        if (x.indexOf("!") >= 0) return "󰖓";
        if (x.indexOf("*") >= 0) return "󰖘";
        if (x.indexOf("x") >= 0) return "󰙿";
        if (x.indexOf("=") >= 0) return "󰖑";
        // Haze has no icon of its own in wego and arrives as "?". Fog is the
        // closest there is: both are "you cannot see".
        if (x.indexOf("?") >= 0) return "󰖑";
        if (".,'/\\".split("").some(c => x.indexOf(c) >= 0)) return "󰖗";
        if (x === "m") return "󰖕";
        if (x === "o") return "󰖙";
        return "󰖐";
    }

    Process {
        id: weatherProc
        // The trailing `echo` is NOT redundant: wttr.in with ?format= answers
        // WITHOUT a newline, and SplitParser splits precisely on newlines. Without
        // it the reading stays in the buffer and the weather never updates.
        command: ["bash", "-c", "curl -s --max-time 8 'wttr.in/?lang=" + I18n.lang
                  + "&format=%t·%C·%x' 2>/dev/null; echo"]
        stdout: SplitParser {
            onRead: function (line) {
                const t = line.trim();
                if (!t.length)
                    return;
                const trozos = t.split("·");
                root.weatherTemp = (trozos[0] || "").trim();
                root.weatherCond = (trozos[1] || "").trim();
                root.weatherSym = (trozos[2] || "").trim();
            }
        }
    }

    // Changing language has to request it again: the condition is translated by
    // the server, so the one already on screen would stay in the previous
    // language until the next turn of the clock -- half an hour of a half-done
    // shell, which is exactly what the language layer exists to prevent.
    Connections {
        target: I18n
        function onLangChanged(): void {
            if (!weatherProc.running)
                weatherProc.running = true;
        }
    }
    Timer {
        interval: 1800000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: if (!weatherProc.running) weatherProc.running = true
    }
}
