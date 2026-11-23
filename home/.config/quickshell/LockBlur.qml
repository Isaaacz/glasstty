// LockBlur.qml — a blurred copy of the lock screen's picture, made by
// ImageMagick like the login's (a real gaussian blur on a file; a live effect
// either stays light or loses quality). Used by LockTheme for the saved
// settings (so the lock has it ready the moment it locks) and by each LockFace
// for what it is showing — the Settings preview shows the draft's blur.
//
// Files are named after what they were made from (picture + blur + screen),
// so the same combination is never blurred twice; only the newest few stay.
// The strength curve puts 80 % at the login's sigma 28.
import Quickshell
import Quickshell.Io
import QtQuick

Scope {
    id: root
    property string src: ""
    property int pct: 0
    property bool isVideo: false
    property string url: ""                 // file://…, "" until the first one
    property string madeFor: ""
    readonly property string key: root.src + "|" + root.pct
    readonly property bool ready: root.madeFor === root.key && root.url !== ""
    onKeyChanged: debounce.restart()
    Component.onCompleted: debounce.restart()

    Timer {
        id: debounce
        interval: 350
        onTriggered: {
            if (root.isVideo || root.src === "" || root.pct <= 0) return;
            const sc = Quickshell.screens.length > 0 ? Quickshell.screens[0] : null;
            const w = sc ? Math.round(sc.width) : 1920, h = sc ? Math.round(sc.height) : 1080;
            const sigma = 28 * Math.pow(root.pct / 80, 1.3);
            // Big blurs are done on a smaller copy (same look, much faster).
            const f = Math.min(1, 6 / Math.max(sigma, 0.1));
            proc.key = root.key;
            proc.command = ["sh", "-c",
                // One at a time (flock): the Settings style drawer opens a dozen
                // faces at once with the same picture, and they must queue up
                // and reuse the first one's file, not blur it a dozen times.
                "d=\"$HOME/.cache/glasstty\"; mkdir -p \"$d\"; o=\"$d/lock-bg-$5.jpg\"; " +
                "exec 9>\"$d/.lock-bg.lock\"; flock 9; " +
                "if [ ! -s \"$o\" ]; then " +
                "magick \"$1\" -resize \"$2^\" -gravity center -extent \"$2\" -resize \"$3%\" -blur \"0x$4\" -resize \"$2!\" -quality 92 \"$o.$$.tmp.jpg\" && " +
                "mv -f \"$o.$$.tmp.jpg\" \"$o\" || exit 1; fi; touch \"$o\"; " +
                // keep the 6 most recently used
                "ls -1t \"$d\"/lock-bg-*.jpg 2>/dev/null | grep -v '\\.tmp\\.jpg$' | tail -n +7 | xargs -r rm -f; echo \"$o\"",
                "sh", root.src, w + "x" + h, (f * 100).toFixed(1), (sigma * f).toFixed(2),
                Qt.md5(root.key + "|" + w + "x" + h)];
            proc.running = false;
            proc.running = true;
        }
    }
    Process {
        id: proc
        property string key: ""
        stdout: StdioCollector {
            onStreamFinished: {
                const out = this.text.trim().split("\n").pop();
                if (out) { root.url = "file://" + out; root.madeFor = proc.key; }
            }
        }
    }
}
