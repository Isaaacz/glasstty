// Media.qml — the music player the notch follows (MPRIS), which player may
// change the notch's face, and what played last when nothing plays now. Split
// out of ShellState.qml.
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

    // ═══════════════════════ media (MPRIS) ═══════════════════════
    readonly property var player: {
        const ps = Mpris.players.values;
        if (!ps || ps.length === 0) return null;
        for (let i = 0; i < ps.length; i++) if (ps[i].isPlaying) return ps[i];
        // With everything paused the first in the list won, and that is usually
        // a browser media session with nothing loaded any more: the panel said
        // "Sin reproducción" (Nothing playing) with Spotify right beside it, its
        // song loaded and paused, and the buttons controlled nothing.
        for (let i = 0; i < ps.length; i++) if (ps[i].trackTitle) return ps[i];
        return ps[0];
    }

    // ─────────── who may change the notch's face? ───────────
    //
    // Any video in a tab registers its MPRIS session just like Spotify, so the
    // notch widened to 268, hid the date and the battery and flashed for 4.2 s
    // for anything that made a sound in the browser. For Spotify that is fine;
    // for a background video, it is a nuisance.
    //
    // CAREFUL: this does NOT take the browser out of the player. `player` still
    // returns it and the music panel still shows it, which is what lets you
    // pause it from there. All it loses is ruling the notch's face at REST.
    //
    // All three fields are checked because each browser fills in different
    // ones: Chromium publishes `org.mpris.MediaPlayer2.chromium.instance<pid>`
    // and on some versions leaves `desktopEntry` empty, while others can only
    // be told apart by `identity`.
    readonly property var browserHints: ["chrome", "chromium", "brave", "edge",
                                         "opera", "vivaldi", "firefox"]
    function isBrowser(p) {
        if (!p) return false;
        const campos = [p.dbusName, p.desktopEntry, p.identity];
        for (let i = 0; i < campos.length; i++) {
            const v = String(campos[i] || "").toLowerCase();
            if (v.length === 0) continue;
            for (let j = 0; j < root.browserHints.length; j++)
                if (v.indexOf(root.browserHints[j]) >= 0) return true;
        }
        return false;
    }

    // "Hay reproductor Y tiene derecho a cambiar la cara del notch."
    // ("There is a player AND it has the right to change the notch's face.")
    readonly property bool mediaDrives: root.player !== null
        && (Config.browserMedia || !root.isBrowser(root.player))

    // The music accent is born from the cover art, not the wallpaper.
    // ColorQuantizer is asynchronous: while a new palette arrives it keeps the
    // previous accent and, if there is no image or the cover is practically grey,
    // it falls back to pywal. The lightness is normalised because the colour is
    // used on dark backgrounds: a faithful but almost black tone would be no use
    // for a 4 px bar.
    readonly property string mediaArtUrl: (player && player.trackArtUrl)
        ? String(player.trackArtUrl) : ""
    ColorQuantizer {
        id: mediaQuantizer
        source: root.mediaArtUrl
        depth: 3
        rescaleSize: 48
    }
    function mediaHsl(c) {
        const r = Number(c.r), g = Number(c.g), b = Number(c.b);
        const hi = Math.max(r, g, b), lo = Math.min(r, g, b);
        const d = hi - lo, l = (hi + lo) / 2;
        let h = 0, s = 0;
        if (d > 0.0001) {
            s = d / (1 - Math.abs(2 * l - 1));
            if (hi === r) h = ((g - b) / d) % 6;
            else if (hi === g) h = (b - r) / d + 2;
            else h = (r - g) / d + 4;
            h /= 6;
            if (h < 0) h += 1;
        }
        return { h: h, s: isFinite(s) ? s : 0, l: l };
    }
    readonly property color mediaAccent: {
        if (root.mediaArtUrl.length === 0) return Colors.accent;
        const cs = mediaQuantizer.colors;
        if (!cs || cs.length === 0) return Colors.accent;

        let best = null, bestScore = -100;
        for (let i = 0; i < cs.length; i++) {
            const hsl = root.mediaHsl(cs[i]);
            // Rewards colour and legibility; penalises cover whites and blacks.
            const score = hsl.s * 1.75 - Math.abs(hsl.l - 0.56) * 1.35
                - (hsl.l < 0.12 || hsl.l > 0.90 ? 1.5 : 0) + (i === 0 ? 0.04 : 0);
            if (score > bestScore) { bestScore = score; best = hsl; }
        }
        if (!best || best.s < 0.15) return Colors.accent;
        const saturation = Math.max(0.45, Math.min(0.90, best.s * 1.12));
        const lightness = Math.max(0.48, Math.min(0.67, best.l));
        return Qt.hsla(best.h, saturation, lightness, 1);
    }
    property real pos: 0
    readonly property real len: (player && player.lengthSupported) ? player.length : 0
    Timer {
        interval: 500; repeat: true; running: root.player !== null && (ShellState.open || ShellState.mediaLive)
        onTriggered: root.pos = (root.player && root.player.positionSupported) ? root.player.position : 0
    }
    // Only the first letter. Qt's Font.Capitalize capitalises EVERY word
    // and in Spanish leaves things like "Martes, 4 De Agosto".
    function capitalize(s) { return s ? s.charAt(0).toUpperCase() + s.slice(1) : ""; }

    function fmt(sec) {
        if (!sec || sec < 0) return "0:00";
        const m = Math.floor(sec / 60), s = Math.floor(sec % 60);
        return m + ":" + (s < 10 ? "0" + s : s);
    }
    // The song-change flash does NOT hang off `mediaLive`, so it has to be
    // filtered separately: without `mediaDrives`, the notch would keep opening
    // to 400 px for 4.2 s every time the browser changed video, which is
    // exactly what we want to avoid.
    Connections {
        target: root.player
        ignoreUnknownSignals: true
        function onTrackTitleChanged() {
            if (ShellState.armed && root.mediaDrives && root.player && root.player.trackTitle) ShellState.flash("track");
            root.recordarTema();
        }
        function onIsPlayingChanged() { if (ShellState.armed && root.mediaDrives && root.player && root.player.isPlaying) ShellState.flash("track"); }
    }

    // ══════════════════ whatever played last ══════════════════
    // When the player closes, MPRIS ceases to exist and the left column of the
    // control centre was left as 260x486 px saying "Sin reproducción" (Nothing
    // playing) inside an empty circle. Remembering the last track keeps that
    // column telling you something, and above all lets you GO BACK to what you
    // were listening to, which is the only thing you can really ask of it there.
    //
    // It goes to disk and not just to memory because the shell reloads every
    // time a .qml is touched, and a "last thing" that is forgotten on every
    // reload is not the last of anything.
    property string ultimoTitulo: ""
    property string ultimoArtista: ""
    property string ultimoArte: ""
    property string ultimoAppId: ""
    readonly property bool hayUltimo: root.player === null && root.ultimoTitulo.length > 0

    FileView {
        id: ultimoFile
        path: ShellState.home + "/.cache/quickshell/ultimo-tema.json"
        // watchChanges is NOT optional even though nobody is going to touch the
        // file from outside: without it, FileView does not even do the INITIAL read
        // and onLoaded never fires. No errors and no warnings -- it just stays
        // empty, which is what this panel did until it was discovered.
        watchChanges: true
        onFileChanged: reload()
        printErrors: false      // the first time it does not exist, and that is not a failure
        onLoaded: {
            try {
                const d = JSON.parse(ultimoFile.text());
                root.ultimoTitulo = d.titulo || "";
                root.ultimoArtista = d.artista || "";
                root.ultimoArte = d.arte || "";
                root.ultimoAppId = d.app || "";
            } catch (e) {
                // Same rule as the team and github: with rubbish, touch
                // nothing. An invented "last track" is worse than none.
            }
        }
    }

    function recordarTema(): void {
        const p = root.player;
        if (!p || !p.trackTitle)
            return;
        root.ultimoTitulo = p.trackTitle;
        root.ultimoArtista = p.trackArtist || "";
        root.ultimoArte = p.trackArtUrl ? String(p.trackArtUrl) : "";
        root.ultimoAppId = p.desktopEntry || "";
        ultimoFile.setText(JSON.stringify({
            titulo: root.ultimoTitulo,
            artista: root.ultimoArtista,
            arte: root.ultimoArte,
            app: root.ultimoAppId
        }));
    }

    // It is also remembered when a player APPEARS, not only on a song change:
    // if you open the player and close it without skipping a track, without this
    // nothing would have been saved.
    onPlayerChanged: if (root.player) root.recordarTema()

    // The app that was playing it, if it is still installed. It is compared
    // without the trailing ".desktop" because MPRIS gives it sometimes with it
    // and sometimes without.
    readonly property var ultimaApp: {
        if (!root.ultimoAppId.length)
            return null;
        const pela = s => String(s || "").toLowerCase().replace(/\.desktop$/, "");
        const id = pela(root.ultimoAppId);
        const vs = DesktopEntries.applications ? DesktopEntries.applications.values : [];
        for (let i = 0; i < vs.length; i++)
            if (pela(vs[i].id) === id)
                return vs[i];
        return null;
    }
}
