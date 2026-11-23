// LockTheme.qml — what the lock screen is dressed with: the thyx theme.conf
// the login uses, the current wallpaper, and your name. A singleton so the
// real lock (LockScreen.qml) and its preview in Settings read the same thing.
pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick

Singleton {
    id: root

    readonly property string home: Quickshell.env("HOME")
    readonly property string user: Quickshell.env("USER") || ""
    // Full name from passwd ("Isaac Inacio Alves"), as the login shows it.
    property string fullName: ""
    Process {
        running: true
        command: ["sh", "-c", "getent passwd \"$USER\" | cut -d: -f5 | cut -d, -f1"]
        stdout: StdioCollector { onStreamFinished: root.fullName = this.text.trim() }
    }

    // ─── the thyx theme (installed one first, repo clone as fallback) ───
    property string themeDir: "/usr/share/sddm/themes/thyx"
    property var cfg: ({})
    function c(key, fallback) { const v = root.cfg[key]; return (v === undefined || v === "") ? fallback : v; }
    function parseIni(text) {
        const out = {};
        for (const raw of String(text).split("\n")) {
            const line = raw.trim();
            if (line === "" || line[0] === "#" || line[0] === ";" || line[0] === "[") continue;
            const i = line.indexOf("=");
            if (i < 0) continue;
            let v = line.slice(i + 1).trim();
            if (v.length >= 2 && v[0] === '"' && v[v.length - 1] === '"') v = v.slice(1, -1);
            out[line.slice(0, i).trim()] = v;
        }
        return out;
    }
    FileView {
        id: themeFile
        path: root.themeDir + "/theme.conf"
        watchChanges: true
        onFileChanged: reload()
        onLoaded: root.cfg = root.parseIni(text())
        // SDDM theme not installed yet: use the thyx clone. A new `path` is not
        // read by itself after a failed load, hence the explicit reload.
        onLoadFailed: if (root.themeDir.indexOf("/usr/share") === 0) {
            root.themeDir = root.home + "/Projetos/thyx";
            Qt.callLater(themeFile.reload);
        }
    }
    // Settings > Appearance > Lock screen can swap the login's background for
    // the current wallpaper (pywal writes its path to ~/.cache/wal/wal).
    // The ORIGINAL picture (set-wallpaper.sh notes it in pocket-dots/wallpaper);
    // pywal's own note can be the small copy it took the colours from, which
    // looks soft at low blur.
    property string walNote: ""
    property string origNote: ""
    readonly property string wallPath: root.origNote !== "" ? root.origNote : root.walNote
    FileView {
        path: root.home + "/.cache/wal/wal"
        watchChanges: true
        onFileChanged: reload()
        onLoaded: root.walNote = text().trim()
    }
    FileView {
        path: root.home + "/.cache/pocket-dots/wallpaper"
        watchChanges: true
        onFileChanged: reload()
        onLoaded: root.origNote = text().trim()
    }
    readonly property string themeBg: root.c("Background", "") === "" ? "" : root.themeDir + "/" + root.c("Background", "")
    // When the login follows the wallpaper (login-pywal.sh), its background is a
    // copy of the wallpaper ALREADY blurred hard, so a blur slider over it
    // could never go below "very blurred". The lock starts from the sharp
    // wallpaper instead and does all the blurring itself: 0 % is the picture as
    // it is, 100 % the most. defaultBlur is what matches the login's look.
    readonly property bool loginSynced: /pocket-wallpaper\.jpg$/.test(root.themeBg)
    readonly property bool useWall: root.wallPath !== ""
        && (Config.lockBg === "wallpaper" || root.loginSynced || root.themeBg === "")
    readonly property int defaultBlur: (root.loginSynced || root.themeBg === "") ? 80
        : Math.round(100 * Math.max(0, Math.min(1, Number(root.c("Blur", 0.4)))))
    readonly property string bgPath: root.useWall ? root.wallPath : root.themeBg
    readonly property bool bgIsVideo: /\.(mp4|webm|mkv|mov|m4v|avi)$/i.test(root.bgPath)

    // ─── the blurred background for the saved settings (see LockBlur.qml) ───
    // Made ahead of time so the lock shows it the moment it locks.
    readonly property int blurPct: Config.lockBlur >= 0 ? Config.lockBlur : root.defaultBlur
    readonly property string blurredUrl: savedBlur.url
    LockBlur { id: savedBlur; src: root.bgPath; pct: root.blurPct; isVideo: root.bgIsVideo }

    // The picture for a given "Fundo" choice (the real lock uses Config's, the
    // Settings preview the draft's).
    function bgFor(choice) {
        // No login theme installed (no SDDM/thyx, or no picture in it): the
        // wallpaper, rather than a black screen.
        const wall = root.wallPath !== "" && (choice === "wallpaper" || root.loginSynced || root.themeBg === "");
        return wall ? root.wallPath : root.themeBg;
    }
}
