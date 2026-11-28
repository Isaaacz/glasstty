// NotificationCenter.qml — glasstty's own notification server: history,
// do-not-disturb, the drops and the Control Centre list. Split out of
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

    // ══════════════════════════ notifications (own server) ══════════════════════════
    // Replaces swaync: its "control centre" is a GTK window of its own, it cannot
    // be put inside the notch. Here we are the D-Bus server and we paint both the
    // pop-up notice and the history ourselves.
    property bool dnd: false
    // Switch the open Control Centre to a page (qs ipc call notch page N).
    signal controlGo(int n)
    property var lastNotif: null

    // Some programs only speak English in their notifications (niri's own
    // screenshot action, for one). Known texts are shown translated; the
    // notification itself is not touched. tn(text) is used where they are drawn.
    readonly property var notifPt: ({
        "Screenshot captured": "Captura de tela feita",
        "You can paste the image from the clipboard.": "Você pode colar a imagem da área de transferência.",
        "Failed to save screenshot": "Não foi possível salvar a captura de tela"
    })
    function tn(text) {
        if (!text || Config.language !== "pt") return text || "";
        return root.notifPt[text] || text;
    }

    NotificationServer {
        id: notifServer
        keepOnReload: true
        bodySupported: true
        bodyMarkupSupported: true
        imageSupported: true
        actionsSupported: true
        actionIconsSupported: true

        onNotification: function (n) {
            n.tracked = true;               // stays in the history
            root.lastNotif = n;
            if (!n.lastGeneration) root.stampNotif(n);
            // ...but the history has a ceiling. With Qt.callLater and not
            // directly: here the server's list does not include `n` yet (the
            // long why, with the measurement, is in trimNotifs), so calling it
            // on the spot would leave the history at 51 instead of 50. As a
            // bonus, Qt.callLater collapses a burst of sixty into a single
            // pass, and trimNotifs already knows how to remove several at once.
            Qt.callLater(root.trimNotifs);
            // A shell reload hands back the notifications it kept (keepOnReload)
            // through here again: they go back to the history, but the notch
            // must not announce them a second time.
            if (!root.dnd && !n.lastGeneration) root.announce(n);
            // A card updated in place (`notch ... --replace ID`, notify-send -r)
            // keeps the same object: show it again with its new text.
            const again = function () {
                root.stampNotif(n);
                if (root.dnd) return;
                root.lastNotif = n;
                root.announce(n);
            };
            n.summaryChanged.connect(again);
            n.bodyChanged.connect(again);
        }
    }

    // How a new notification is shown: as a drop under the notch
    // (NotifDrops.qml, the default) or inside the notch itself.
    signal notifPopped(var n)
    function announce(n) {
        if (Config.notifStyle === "notch") ShellState.flash("notif", root.notifFlashMs(n));
        else root.notifPopped(n);
    }

    // ── how a notification looks, shared by the drops and the Control Centre ──
    // The kind's colour (the drops can turn it off: Config.dropKindColors).
    readonly property var kindColors: ({ ok: "#4ade80", warn: "#fbbf24", fail: "#f87171" })
    function notifKindColor(kind) { return root.kindColors[kind] || Colors.accent; }
    // A symbol instead of the icon for some notices: the screenshot ones get a
    // camera (glasstty's notify-shot.sh asks for it with a hint; niri's own
    // screenshot notice is recognised by its text).
    readonly property var notifGlyphs: ({ camera: "󰄀" })
    function notifGlyph(n) {
        const h = n && n.hints ? String(n.hints["x-glasstty-glyph"] || "") : "";
        if (root.notifGlyphs[h]) return root.notifGlyphs[h];
        const t = n ? String(n.summary || "") : "";
        if (t === "Screenshot captured" || t === "Failed to save screenshot") return root.notifGlyphs.camera;
        return "";
    }
    // The picture to show: the one the notification brings, else its app's
    // icon; "" when there is none (or the theme lacks it) or a symbol wins.
    function notifImage(n) {
        if (!n || root.notifGlyph(n) !== "") return "";
        if (n.image && n.image.length > 0) return n.image;
        const ic = n.appIcon || "";
        if (ic === "") return "";
        if (ic.startsWith("/")) return "file://" + ic;
        if (ic.startsWith("file:")) return ic;
        return Quickshell.iconPath(ic, true);
    }
    // The mark when there is no picture: the kind's, the symbol, or a bell.
    function notifMark(n) {
        const g = root.notifGlyph(n);
        if (g !== "") return g;
        const k = root.notifKind(n);
        return k === "ok" ? "󰄬" : k === "warn" ? "󰀦" : k === "fail" ? "󰅖" : k === "info" ? "󰋽" : "󰂚";
    }

    // When each one arrived (or was last updated), by id, for "5 min" in the
    // Control Centre. Ones handed back by a shell reload have no time.
    property var notifTimes: ({})
    function stampNotif(n) {
        const t = Object.assign({}, root.notifTimes);
        t[n.id] = Date.now();
        root.notifTimes = t;
    }
    property real notifNow: Date.now()
    Timer { interval: 30000; running: true; repeat: true; onTriggered: root.notifNow = Date.now() }
    function notifAgo(n) {
        const t = n ? root.notifTimes[n.id] : undefined;
        if (!t) return "";
        const s = Math.max(0, (root.notifNow - t) / 1000);
        if (s < 60) return I18n.tr("ahora");
        if (s < 3600) return I18n.tr("{0} min", Math.floor(s / 60));
        if (s < 86400) return I18n.tr("{0} h", Math.floor(s / 3600));
        return Qt.formatDate(new Date(t), "dd/MM");
    }

    // Identical notices (same app, title and text) are one row with a count:
    // five "Claude is done" are not five things to read. The row is the newest.
    function notifKey(n) { return (n.appName || "") + "\u0001" + (n.summary || "") + "\u0001" + (n.body || ""); }
    readonly property var notifHeads: {
        const seen = {}, out = [];
        for (const n of root.notifications) {
            const k = root.notifKey(n);
            if (seen[k]) continue;
            seen[k] = true;
            out.push(n);
        }
        return out;
    }
    function notifDupes(n) {
        const k = root.notifKey(n);
        return root.notifications.filter(m => root.notifKey(m) === k);
    }
    function dismissGroup(n) {
        const all = root.notifDupes(n);
        for (let i = 0; i < all.length; i++) all[i].dismiss();
    }

    // drip-style cards (~/.local/bin/notch): the kind comes in the
    // x-notch-kind hint — "ok", "warn", "fail" or "info". "" = a plain notification.
    function notifKind(n) {
        if (!n || !n.hints) return "";
        const k = String(n.hints["x-notch-kind"] || "");
        return ["ok", "warn", "fail", "info"].indexOf(k) >= 0 ? k : "";
    }
    // The buttons a card shows: its actions except "default" (a click on the card).
    function notifButtons(n) {
        if (!n || !n.actions) return [];
        const out = [];
        for (let i = 0; i < n.actions.length; i++)
            if (n.actions[i].identifier !== "default") out.push(n.actions[i]);
        return out;
    }

    // `lastNotif` holds an object that is NOT ours: the server destroys it when
    // the notification closes (the user closes it, the application withdraws
    // it, or clearNotifs sweeps it away). Without this the notch kept showing
    // an already dead notification, and pressing its actions did nothing,
    // without saying why. Same pattern as the Connections in NetworkPanel.
    Connections {
        target: root.lastNotif
        ignoreUnknownSignals: true
        function onClosed(reason) {
            root.lastNotif = null;
            // AND THE NOTICE GOES WITH IT.
            //
            // This Connections was left half done: it removed the dead
            // notification but not the notice showing it. Since `activityTimer`
            // is the only thing that clears `activity`, and `mode` comes from
            // `activity === "notif"` without looking at `lastNotif`, the pill
            // stayed open and EMPTY -no icon, no title, no application, 430 px
            // wide- until the clock ran out. With a `notify-send -u critical`
            // (no -t, expireTimeout -1, notifFlashMs 11000) that is eleven
            // seconds of blank pill in front of you. It is enough for the
            // application to close its own notification; no panel is needed.
            if (ShellState.activity === "notif") {
                ShellState.stopActivity();
            }
        }
    }

    // most recent first
    readonly property var notifications: {
        const vs = notifServer.trackedNotifications ? notifServer.trackedNotifications.values : [];
        return vs.slice().reverse();
    }
    readonly property int notifCount: notifications.length

    // History ceiling: 50. It does NOT expire on a clock, and on purpose: what
    // `trackedNotifications` holds are the server's LIVE objects -the panel
    // invokes THEIR actions-, so a notification that deleted itself would be a
    // button vanishing while you look at it. The oldest is only thrown out when
    // a new one comes in and there is no room left. And it is closed with
    // expire(), not dismiss(): the program that sent it has to be told that it
    // expired, not that you closed it.
    readonly property int notifMax: 50

    // MIND WHEN THIS IS CALLED. `trackedNotifications.values` does NOT yet
    // contain the incoming notification while onNotification runs, not even
    // after setting `n.tracked = true`. Measured with a test NotificationServer
    // on an isolated bus (dbus-run-session, quickshell 0.3.1, without touching
    // the live shell): when the first notification arrives the list gives 0,
    // and in the following Qt.callLater it gives 1. That is why onNotification
    // does not call this on the spot: with notifMax = 5 and twelve
    // notifications in a row the history stayed at 6, i.e. notifMax + 1. With
    // Qt.callLater it stays at exactly 5.
    function trimNotifs() {
        if (!notifServer.trackedNotifications) return;
        const vs = notifServer.trackedNotifications.values;
        const sobran = vs.length - root.notifMax;
        if (sobran <= 0) return;
        // slice() before closing anything: expire() modifies the live list -also
        // checked-, and we have to iterate over a copy. values[0] is the oldest:
        // the `notifications` property up here does reverse() because the panel
        // paints the recent ones first.
        const viejas = vs.slice(0, sobran);
        for (let i = 0; i < viejas.length; i++)
            if (viejas[i] !== root.lastNotif) viejas[i].expire();
    }

    // How long the pop-up notice lasts. The application asks for its time in
    // `expireTimeout` (-1 = "you decide", 0 = "never expire") and it is obeyed,
    // but with a ceiling. The ceiling is not stinginess: the notch's activity
    // slot is ONE and music, volume, workspace and pokémon share it, so an
    // eternal notice would not be a notice, it would be a hijacked notch. That
    // is why 0 is translated to the maximum, also for a critical one: the
    // notification remains whole in the history, which is where it waits for
    // as long as needed.
    //
    // UNITS: MILLISECONDS, and nothing is converted here. The
    // org.freedesktop.Notifications specification defines expire_timeout as
    // "the timeout time in milliseconds", and Quickshell passes it through as
    // is: it exposes it as a double, but does not divide it. Measured on this
    // machine, with a test NotificationServer on an isolated bus:
    //     notify-send -t 9000   ->  expireTimeout = 9000
    //     notify-send -t 60000  ->  expireTimeout = 60000
    //     notify-send -t 0      ->  expireTimeout = 0      (never expire)
    //     notify-send  (no -t)  ->  expireTimeout = -1     (you decide)
    // The property being a double and not an int does NOT mean seconds arrive.
    function notifFlashMs(n) {
        const crit = !!n && n.urgency === NotificationUrgency.Critical;
        // A critical one -battery at 5 %, disk full- asks to be looked at twice:
        // it does not go below 10 s or above 12. The rest, from 1.5 s to 15 s.
        const suelo = crit ? 10000 : 1500;
        const techo = crit ? 12000 : 15000;
        const porDefecto = crit ? 11000 : Math.round(Math.max(1.5, Math.min(15, Config.notifSeconds)) * 1000);
        if (!n) return porDefecto;
        // A card asking something (buttons) waits up to a minute for the answer:
        // the question is the point of it, and the script is waiting too.
        if (root.notifKind(n) !== "" && root.notifButtons(n).length > 0) {
            const tq = Number(n.expireTimeout);
            return (!isFinite(tq) || tq <= 0) ? 30000 : Math.max(3000, Math.min(60000, Math.round(tq)));
        }
        const t = Number(n.expireTimeout);
        if (!isFinite(t) || t < 0) return porDefecto;   // -1: you decide
        if (t === 0) return techo;                      // 0: never expire
        return Math.max(suelo, Math.min(techo, Math.round(t)));
    }

    function dismissNotif(n) { if (n) n.dismiss(); }
    function clearNotifs() {
        const vs = notifServer.trackedNotifications ? notifServer.trackedNotifications.values.slice() : [];
        for (let i = 0; i < vs.length; i++) vs[i].dismiss();
    }

    readonly property string notifIcon: dnd ? (notifCount > 0 ? "󰂠" : "󰪓")
        : (notifCount > 0 ? "󱅫" : "󰂜")
}
