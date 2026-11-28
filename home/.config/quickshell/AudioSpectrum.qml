// AudioSpectrum.qml — the eight bars of the music visualiser: cava's output,
// smoothed and given a range per band, running only while something plays.
// The notch and the media panel paint `levels`. Split out of ShellState.qml.
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

    // ──────────────── audio spectrum (cava) ─────────────────
    // The notch's little bars. This used to be a PwNodePeakMonitor: ONE single
    // number (the sink's global peak) shifted along the array. That is not a
    // spectrum, it is the same signal repeated 14 times —all the bars rose and
    // fell together— and since the linear peak nearly always brushes 1, they
    // stayed pinned to the ceiling (barcode effect). Worse: onPeakChanged only
    // fires when the value CHANGES, so in a compressed stretch the signal
    // stopped arriving and the bars FROZE.
    //
    // cava does do an FFT: it gives `bands` independent values per frame, from
    // bass to treble, and with its own autosens (quiet music fills just the
    // same, loud music does not saturate). "raw" output in ascii, one line per
    // frame: "0;312;…;\n". The configuration lives in scripts/cava.conf.
    // Few and thick. With 14 the strip read as a pattern of stripes rather than
    // as an equaliser: at 2.5 px wide you cannot tell one bar from its
    // neighbour. If you change this, change `bars` in scripts/cava.conf.
    readonly property int bands: 8

    // WHY CAVA'S VALUE IS NOT PAINTED AS IT COMES. Because cava's values JUMP:
    // a single band goes from 2 to 1000 and back in a handful of frames.
    // Painting that directly is not an equaliser, it is a strobe — and it was
    // exactly the jitter you could see. Measured by recording the notch at 60
    // fps and measuring the PAINTED bars:
    //
    //                             max jump   jerks
    //   painting the raw value     16.7 px   0.200
    //   with this follower          1.3 px   0.079
    //
    // So cava only sets the TARGET, and what MOVES the bar is the screen's
    // clock: a FrameAnimation that on every frame brings it a little closer,
    // according to the REAL time elapsed (frameTime). It is what caelestia does
    // (Internal/visualiserbars.cpp: alpha = 1 - exp(-dt/tau)), which is where
    // this bar's architecture comes from.
    //
    // Exponential on purpose: advancing a FRACTION of what is left gives no
    // jumps or sudden stops —the speed is continuous— and being tied to real
    // time it does not matter if a frame is dropped: the bar is always where it
    // should be.
    //
    // What does NOT work, tried and measured: smoothing in cava
    // (noise_reduction), smoothing the received value, or quantising the height
    // into steps. All of that touches the NUMBERS, and what has to be
    // continuous is the MOTION.
    //
    // IT RISES FAST AND FALLS SLOWLY, like a VU meter. With a single constant
    // for both directions the bar COLLAPSES as fast as it rises: at tau 35 it
    // eats 38% of what is left on every frame, so a peak comes apart in three
    // frames (~50 ms). That does not read as a bar going down, it reads as a
    // bar switching off — a blink.
    //
    // With attack and decay separated, the hit still lands just as crisply
    // (it is what marks the rhythm) but the return is a glide of ~1/3 of a
    // second, which is plenty of time for the eye to follow it as continuous
    // motion.
    //
    // tau = ms it takes to eat 63% of what is left. Lower = more glued to the
    // music and more nervous; higher = smoother and lazier. The decay cannot go
    // above ~150: beyond that, two consecutive kick-drum hits at 120 bpm
    // overlap and the bar stops marking the beat.
    readonly property int cavaSube: 32    // attack
    readonly property int cavaBaja: 110   // decay

    property var cavaTarget: new Array(bands).fill(0)   // what cava says

    // WHY EVERY BAND HAS ITS OWN RANGE. With dense music no band ever goes
    // below 200-400 out of 1000, so mapping 0-1000 straight onto the bar left
    // all eight half-to-two-thirds high, travelling 2-3 px out of 18 in half a
    // second: an equaliser that looks frozen. Each band keeps a window that
    // jumps at once to a new peak or valley and forgets it slowly, and the bar
    // is painted inside that window, so every beat goes from floor to ceiling
    // whatever the band's loudness. Simulated on the same cava output: travel
    // 2.7 -> 8.4 px every half second, at the ceiling 23% of the time.
    //
    // cavaRango = ms it takes to forget 63% of a peak or valley. Lower = more
    // nervous, it stretches even the quiet passages; higher = slower to adapt
    // when the song changes section.
    // cavaRangoMin = the narrowest window, so a near-silent band does not get
    // its noise blown up to full height.
    readonly property int cavaRango: 2500
    readonly property real cavaRangoMin: 0.25
    property var cavaHi: new Array(bands).fill(0.5)
    property var cavaLo: new Array(bands).fill(0.3)
    property real cavaUltima: 0
    property var levels: new Array(bands).fill(0)       // what gets painted
    property bool cavaQuieto: true

    FrameAnimation {
        // Keeps running after the music stops until the bars have come down
        // completely: that way they glide to the floor instead of vanishing at once.
        running: cavaProc.running || !root.cavaQuieto
        onTriggered: {
            // smoothFrameTime and not frameTime: the real gap between frames
            // fluctuates (16.7 · 12 · 21 · 16…), and since the follower's step
            // is computed from that gap, using the raw one makes the bar advance
            // in fits and starts even when the signal is perfect. Qt averages
            // that measurement precisely for this; the position error it
            // introduces corrects itself on the next frame, because the follower
            // chases the target, it does not accumulate.
            const dt = smoothFrameTime * 1000;
            const aSube = 1 - Math.exp(-dt / root.cavaSube);
            const aBaja = 1 - Math.exp(-dt / root.cavaBaja);
            const out = new Array(root.bands);
            let quieto = true;
            for (let i = 0; i < root.bands; i++) {
                const falta = root.cavaTarget[i] - root.levels[i];
                if (Math.abs(falta) > 0.001) {
                    out[i] = root.levels[i] + falta * (falta > 0 ? aSube : aBaja);
                    quieto = false;
                } else {
                    out[i] = root.cavaTarget[i];
                }
            }
            root.levels = out;
            root.cavaQuieto = quieto;
        }
    }

    // Starts and stops cava with the music, and BRINGS IT BACK if it dies.
    //
    // `running: ShellState.mediaLive` is NOT used here, which is the natural thing and
    // was so until 7 Aug 2026: when the process dies (it crashes, or someone
    // kills it), quickshell writes running=false, and that write BREAKS the
    // binding. From then on cava never starts again —not even reloading the
    // config— and the visualiser is left with eight flat bars even though music
    // is playing. It is driven by hand: the timer reasserts the state every 3 s,
    // so at most it takes that long to get back up by itself. triggeredOnStart
    // = it starts at once when playback begins, without waiting for the first tick.
    Timer {
        interval: 3000
        repeat: true
        triggeredOnStart: true
        // not while you play: the notch steps aside in fullscreen, so the
        // bars would be drawn for nobody and cava's FFT would cost for nothing
        running: ShellState.mediaLive && !GameMode.playing
        onTriggered: cavaProc.running = true
    }
    Connections {
        target: ShellState
        function onMediaLiveChanged() { if (!ShellState.mediaLive) cavaProc.running = false; }
    }
    Connections {
        target: GameMode
        function onPlayingChanged() { if (GameMode.playing) cavaProc.running = false; }
    }

    Process {
        id: cavaProc
        command: ["cava", "-p", ShellState.home + "/.config/quickshell/scripts/cava.conf"]
        stdout: SplitParser {
            onRead: function (line) {
                const parts = line.split(";");
                const now = Date.now();
                const dt = root.cavaUltima ? Math.min(100, now - root.cavaUltima) : 16.7;
                root.cavaUltima = now;
                const olvido = 1 - Math.exp(-dt / root.cavaRango);
                const hi = root.cavaHi.slice();
                const lo = root.cavaLo.slice();
                const out = new Array(root.bands);
                for (let i = 0; i < root.bands; i++) {
                    const v = Math.max(0, Math.min(1, (+parts[i] || 0) / 1000));
                    hi[i] = v > hi[i] ? v : hi[i] + (v - hi[i]) * olvido;
                    lo[i] = v < lo[i] ? v : lo[i] + (v - lo[i]) * olvido;
                    // A window narrower than the minimum grows downwards, so a
                    // loud band still reaches the ceiling.
                    const span = Math.max(hi[i] - lo[i], root.cavaRangoMin);
                    const base = Math.min(lo[i], Math.max(0, hi[i] - span));
                    out[i] = Math.max(0, Math.min(1, (v - base) / span));
                }
                root.cavaHi = hi;
                root.cavaLo = lo;
                root.cavaTarget = out;   // only the target; moving is the FrameAnimation's job
                root.cavaQuieto = false;
            }
        }
        // On pause, cava dies and the target would keep the last snapshot:
        // bars at half height through the whole fade-out.
        onRunningChanged: if (!running) {
            root.cavaTarget = new Array(root.bands).fill(0);
            root.cavaUltima = 0;
        }
    }
}
