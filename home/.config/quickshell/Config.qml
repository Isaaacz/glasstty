// Config.qml — the rice's persistent settings.
//
// Everything that used to be constants baked into TopShell/ShellState lives
// here and is saved to ~/.config/quickshell-rice.json. The Settings app writes
// to this and the bar and the notch react live.
//
// MIND the path: the file lives OUTSIDE ~/.config/quickshell/ on purpose.
// Quickshell watches its configuration directory to hot-reload, and saving in
// there every time you move a slider would trigger a reload for every pixel.
pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick
import "AppearanceProfiles.js" as Profiles

Singleton {
    id: root

    // ───────── language ─────────
    // "es" | "en" | "pt". I18n reads it and the whole interface hangs off that. The
    // installer writes it according to what you choose at install time
    // (./install.sh --lang en).
    property alias language: opts.language

    // Profiles per power source, independent of the appearance.
    property alias energyOnAC: opts.energyOnAC
    property alias energyOnBattery: opts.energyOnBattery
    property alias batteryAllowIdle: opts.batteryAllowIdle
    property alias dimOnSaver: opts.dimOnSaver
    property alias saverBrightness: opts.saverBrightness
    // Temporary state; it never modifies the saved appearance preference.
    property bool powerSaverActive: false
    onPowerSaverActiveChanged: root.applyEffects()

    // ───────── notch ─────────
    // "notch" = island stuck to the edge with inverted corners (MacBook).
    // "island" = floating pill detached from the edge (Dynamic Island).
    property alias notchStyle: opts.notchStyle
    property alias islandGap: opts.islandGap
    readonly property bool island: opts.notchStyle === "island"

    property alias notchColor: opts.notchColor
    property alias bandH: opts.bandH            // band height = notch height at rest
    property alias flare: opts.flare            // radius of the inverted top corner
    property alias roundMax: opts.roundMax      // maximum bottom radius
    property alias idleW: opts.idleW            // width at rest for the TIME ALONE; grows if you enable date or battery
    property alias hoverPreview: opts.hoverPreview
    property alias hoverDelay: opts.hoverDelay  // ms before the "peek" opens
    // Does a browser video count as "music playing"? Off: the notch only
    // changes face for real players. See ShellState.isBrowser.
    property alias browserMedia: opts.browserMedia
    property alias showDate: opts.showDate
    property alias showBattery: opts.showBattery
    property alias reserveSpace: opts.reserveSpace

    // ───────── bar ─────────
    // Colours: "wallpaper" (pywal decides) or "manual" (accent and, optionally,
    // background chosen in Settings > Aparência > Cores). See
    // ~/.config/glasstty/scripts/palette-override.py.
    property alias colorMode: opts.colorMode
    property alias manualAccent: opts.manualAccent
    property alias manualBg: opts.manualBg
    property alias barBlur: opts.barBlur          // niri: frosted band + translucent notch
    // Per rice (this fork; the rice command carries this file between rices):
    // the icon theme of the niri session ("" = GNOME's), folders in the
    // wallpaper's accent, and the login screen layout ("pocket" | "thyx").
    property alias iconTheme: opts.iconTheme
    property alias tintFolders: opts.tintFolders
    property alias loginLayout: opts.loginLayout
    property alias scrimAlpha: opts.scrimAlpha  // veil under the bar (0 = transparent)
    property alias sideMargin: opts.sideMargin
    property alias showArch: opts.showArch
    property alias showWorkspaces: opts.showWorkspaces
    property alias stageEnabled: opts.stageEnabled
    property alias showAppName: opts.showAppName
    property alias showTray: opts.showTray

    // ───────── launcher ─────────
    // Favourites, by .desktop entry `id` and IN ORDER: the position is what the
    // user arranges by dragging, so the list is the data, not a set.
    property alias favApps: opts.favApps
    property alias learnLauncher: opts.learnLauncher
    property alias appearanceProfiles: opts.appearanceProfiles

    // ───────── displays ─────────
    // One layout per SET of connected displays, not a global one: plugging in
    // the home monitor brings back the home layout, and unplugging it brings
    // back the laptop-alone one, without touching anything. The key is the set,
    // and displays go by description (manufacturer, model, serial number), not
    // by port: switching the cable from HDMI to DisplayPort should not lose the
    // arrangement. Displays.qml reads and writes it.
    property alias displays: opts.displays

    function appearanceSnapshot() { return Profiles.snapshot(root); }

    // TWO PROFILES WITH THE SAME NAME LOOK IDENTICAL, AND ONE GETS DELETED.
    //
    // saveProfile pushed without looking at the names in use and changeProfile
    // only required it not to be empty. The card does not show the id and the
    // notice says «Perfil guardado» (Profile saved) the same in both cases, so
    // you ended up with two identical «Focus» on screen and «Eliminar» (Delete)
    // could land on the wrong one. It is impasto's uniqueName from
    // ProfileService.qml:84-96, with the same numeric suffix and the same
    // lower-case comparison.
    function uniqueName(label, exceptId) {
        const usados = opts.appearanceProfiles
            .filter(p => p.id !== exceptId)
            .map(p => String(p.name || "").trim().toLowerCase());
        if (usados.indexOf(label.toLowerCase()) < 0) return label;
        for (let n = 2; n < 1000; n++) {
            const probe = (label + " " + n).slice(0, 48);
            if (usados.indexOf(probe.toLowerCase()) < 0) return probe;
        }
        return label;
    }

    function saveProfile(name) {
        if (!root.loaded) return false;
        const label = String(name || "").trim().slice(0, 48);
        if (!label) return false;
        const entries = opts.appearanceProfiles.slice();
        entries.push({ id: Date.now().toString(36) + Math.random().toString(36).slice(2, 8),
                       name: root.uniqueName(label, null), values: root.appearanceSnapshot() });
        opts.appearanceProfiles = entries;
        root.save();
        return true;
    }
    function changeProfile(id, name, replaceValues) {
        if (!root.loaded) return false;
        const entries = opts.appearanceProfiles.slice();
        const at = entries.findIndex(p => p.id === id);
        const label = String(name || "").trim().slice(0, 48);
        if (at < 0 || !label) return false;
        if (!replaceValues && entries[at].name === label) return true;
        entries[at] = { id: id, name: root.uniqueName(label, id),
            values: replaceValues ? root.appearanceSnapshot() : entries[at].values };
        opts.appearanceProfiles = entries;
        root.save();
        return true;
    }
    function removeProfile(id) {
        if (!root.loaded) return;
        opts.appearanceProfiles = opts.appearanceProfiles.filter(p => p.id !== id);
        root.save();
    }
    function applyProfile(values) {
        if (!root.loaded) return false;
        // complete(), not validate(), for the same reason as the thumbnail in
        // SettingsProfiles: whatever is missing is filled in with the factory
        // values instead of the whole profile silently failing to apply. What
        // gets applied is exactly what the thumbnail showed.
        const clean = Profiles.complete(values);
        if (!clean) return false;
        for (const key of Object.keys(clean)) root[key] = clean[key];
        root.applyEffects();
        root.save();
        return true;
    }

    // ───────── compositor effects ─────────
    // These two do not belong to the shell: they belong to Hyprland. They are
    // saved here like the rest so Settings stays a single place, but getting
    // them through to Hyprland is another matter entirely — see applyEffects()
    // further down.
    property alias windowRounding: opts.windowRounding
    // niri, written to ~/.config/niri/efeitos*.kdl by applyEffects() (this fork).
    property alias winOpacity: opts.winOpacity          // % focused windows
    property alias winOpacityInactive: opts.winOpacityInactive
    property alias termOpacity: opts.termOpacity        // % kitty
    property alias winBlur: opts.winBlur
    property alias winGaps: opts.winGaps
    property alias borderWidth: opts.borderWidth        // 0 = no border
    property alias winShadow: opts.winShadow
    property alias animations: opts.animations
    property alias animSpeed: opts.animSpeed            // % of niri's speed: 100 normal, 200 twice as fast

    // ───────── lock screen (Super+L) ─────────
    // LockScreen.qml reads the thyx theme.conf like the login does; these sit
    // on top of it. "" / -1 = what the login theme says.
    property alias lockBg: opts.lockBg                  // "login" | "wallpaper"
    property alias lockBlur: opts.lockBlur              // 0..100, -1 = the theme's
    property alias lockDim: opts.lockDim                // 0..80 % extra shade
    property alias lockClockSize: opts.lockClockSize    // % of the normal size
    property alias lockClockWeight: opts.lockClockWeight // "light" | "regular" | "bold" | "black"
    property alias lock12h: opts.lock12h
    property alias lockSide: opts.lockSide              // "" | "left" | "right"
    property alias lockAccent: opts.lockAccent          // "login" | "wallpaper"
    property alias lockShowDate: opts.lockShowDate
    property alias lockShowName: opts.lockShowName
    property alias lockShowPower: opts.lockShowPower
    property alias lockShowMedia: opts.lockShowMedia
    property alias lockChar: opts.lockChar
    property alias lockClockPos: opts.lockClockPos      // "left" | "center" | "right"
    property alias lockClockFont: opts.lockClockFont    // "" = the login theme's
    property alias lockClockColor: opts.lockClockColor  // "theme" | "accent" | "white"
    property alias lockSeconds: opts.lockSeconds
    property alias lockDateFmt: opts.lockDateFmt        // "full" | "short" | "numeric"
    property alias lockMessage: opts.lockMessage        // free text under the date
    property alias lockShowBattery: opts.lockShowBattery
    property alias lockFieldStyle: opts.lockFieldStyle  // "line" | "box"
    property alias lockShade: opts.lockShade            // the login's dark gradient
    property alias lockClockY: opts.lockClockY          // % from the top, -1 = the login's
    property alias lockFormY: opts.lockFormY            // % from the bottom, -1 = the login's
    property alias lockCard: opts.lockCard              // frosted card behind name + password
    property alias lockAvatar: opts.lockAvatar          // your picture over the name
    property alias lockPreset: opts.lockPreset          // last layout preset picked (label only)
    property alias lockPanel: opts.lockPanel            // one frosted panel around clock + password
    property alias lockDatePill: opts.lockDatePill      // the date in a capsule
    // Clock fonts for the lock: installed ones with some character (Qt.fontFamilies
    // filters out whatever a machine does not have).
    readonly property var lockFonts: ["Plus Jakarta Sans", "Inter Display", "Montserrat", "Comfortaa",
        "JetBrains Mono", "Iosevka", "Latin Modern Roman", "C059", "Grape Nuts", "Adwaita Sans"]
        .filter(f => Qt.fontFamilies().indexOf(f) >= 0)
    property alias motionBlur: opts.motionBlur
    property alias motionBlurSamples: opts.motionBlurSamples

    // ───────── typography ─────────
    property alias fontUI: opts.fontUI
    property alias clockSize: opts.clockSize

    readonly property var fontChoices: [
        "Adwaita Sans", "Google Sans Flex", "Rubik", "Red Hat Text",
        "Space Grotesk", "Readex Pro", "Noto Sans"
    ]

    // Coalesce writes as Impasto does: serialising repeatedly in one QML turn
    // can read stale JsonAdapter lists and lose favourites or profile values.
    property bool loaded: false
    function save() { if (root.loaded) saver.restart(); }
    Timer { id: saver; interval: 0; onTriggered: file.writeAdapter() }

    // niri does not read quickshell-rice.json: the effects are written to a
    // KDL file it includes (see the timer below).
    // The debounce lives here and not in the interface on purpose: the samples
    // slider emits on EVERY pixel of the drag and has no "released" signal, so
    // without this one drag launches a hundred processes and a hundred
    // rewrites of the file. The caller does not need to know — it just calls.
    function applyEffects() { debounce.restart(); }

    Timer {
        id: debounce
        interval: 180
        onTriggered: {
            // Everything goes into small KDL files that ~/.config/niri/config.kdl
            // pulls in with `include`; niri watches its config (includes too)
            // and reloads it live, so writing the files IS applying them.
            //   efeitos.kdl           at the end: layout, animations, rounding
            //   efeitos-janelas.kdl   after the global opacity rule (+ blur)
            //   efeitos-inativas.kdl  after the unfocused-window rule
            //   efeitos-terminal.kdl  after kitty's rule
            // Each one only repeats the rule it sits next to, with the new
            // value, so the order of the rules in config.kdl is kept.
            // niri has no motion blur: that setting is ignored.
            const head = "// Generated by Settings > Appearance > Effects. Rewritten automatically: do not edit by hand.";
            const pct = (v, lo) => (Math.max(lo, Math.min(100, Math.round(v))) / 100).toFixed(2);
            const r = Math.max(0, Math.round(opts.windowRounding));
            const g = Math.max(0, Math.round(opts.winGaps));
            const bw = Math.max(0, Math.round(opts.borderWidth));
            const blur = opts.winBlur ? "true" : "false";
            const slow = (100 / Math.max(25, Math.min(400, opts.animSpeed))).toFixed(2);
            const main = [head,
                "layout {",
                "    gaps " + g,
                "    border {", bw > 0 ? "        on" : "        off", "        width " + Math.max(1, bw), "    }",
                "    shadow {", opts.winShadow ? "        on" : "        off", "    }",
                "}",
                "animations {", opts.animations ? "    slowdown " + slow : "    off", "}",
                "window-rule {",
                "    geometry-corner-radius " + r,
                "    clip-to-geometry " + (r > 0 ? "true" : "false"),
                "}"].join("\n") + "\n";
            const janelas = [head,
                "window-rule {",
                "    opacity " + pct(opts.winOpacity, 30),
                "    background-effect {", "        blur " + blur, "        xray true", "    }",
                "}",
                "window-rule {",
                "    match app-id=\"^kitty$\"",
                "    match app-id=\"^com\\\\.microsoft\\\\.VSCode$\"",
                "    match app-id=\"^code$\"",
                "    background-effect {", "        blur " + blur, "        xray false", "    }",
                "}"].join("\n") + "\n";
            const inativas = [head,
                "window-rule {", "    match is-active=false",
                "    opacity " + pct(opts.winOpacityInactive, 30), "}"].join("\n") + "\n";
            const terminal = [head,
                "window-rule {", "    match app-id=\"^kitty$\"",
                "    opacity " + pct(opts.termOpacity, 30), "}"].join("\n") + "\n";
            fx.command = ["sh", "-c",
                "d=\"$HOME/.config/niri\"; mkdir -p \"$d\" && "
                + "printf '%s' \"$1\" > \"$d/efeitos-janelas.kdl\" && "
                + "printf '%s' \"$2\" > \"$d/efeitos-inativas.kdl\" && "
                + "printf '%s' \"$3\" > \"$d/efeitos-terminal.kdl\" && "
                + "printf '%s' \"$4\" > \"$d/efeitos.kdl\"",
                "sh", janelas, inativas, terminal, main];
            fx.running = true;
        }
    }

    Process { id: fx }

    // Re-theme the whole desktop with the current wallpaper + manual colours.
    // Debounced: clicking through swatches launches one pywal run, not ten.
    // The save goes first (its own timer runs at 0 ms), the run 450 ms later.
    function applyPalette() { root.save(); paletteDebounce.restart(); }
    Timer {
        id: paletteDebounce
        interval: 450
        onTriggered: { paletteProc.running = false; paletteProc.running = true; }
    }
    Process {
        id: paletteProc
        command: [Quickshell.env("HOME") + "/.config/glasstty/set-wallpaper.sh", "--so-cores"]
    }

    // Icons: regenerate the niri icon theme (folders-pywal.py reads iconTheme
    // and tintFolders from the JSON), after the save has hit the disk.
    function applyIcons() { root.save(); iconsDebounce.restart(); }
    Timer { id: iconsDebounce; interval: 300; onTriggered: { iconsProc.running = false; iconsProc.running = true; } }
    Process { id: iconsProc; command: [Quickshell.env("HOME") + "/.config/glasstty/scripts/gtk-pywal.sh"] }

    // Login layout: sddm-thyx.sh lives at the root of the repo this shell is
    // linked from. The theme folder belongs to the user, so no sudo.
    function applyLogin() { root.save(); loginProc.running = false; loginProc.running = true; }
    // The login's picture follows the lock's blur and darken (login-pywal.sh
    // reads them from this JSON). Debounced: dragging a slider remakes it once,
    // after the save has hit the disk. Does nothing unless the login follows
    // the wallpaper (the script checks its own flag).
    function applyLoginLook() { root.save(); loginLookDebounce.restart(); }
    Timer {
        id: loginLookDebounce
        interval: 900
        onTriggered: { loginLookProc.running = false; loginLookProc.running = true; }
    }
    Process {
        id: loginLookProc
        command: [Quickshell.env("HOME") + "/.config/glasstty/scripts/login-pywal.sh"]
    }
    Process {
        id: loginProc
        command: ["sh", "-c", 'r="$(readlink -f "$HOME/.config/quickshell")/../../.."; [ -w /usr/share/sddm/themes/thyx/metadata.desktop ] && "$r/sddm-thyx.sh" layout "$1"', "sh", opts.loginLayout]
    }

    // THE RECONCILIATION GOES IN onLoaded, NOT IN Component.onCompleted.
    //
    // When the shell starts there is nothing to apply: hyprland.lua has already
    // read efectos.lua. This exists for when the JSON has been touched from
    // outside —by hand, or by the installer— and the two files have drifted
    // apart.
    //
    // But placed in Component.onCompleted it did exactly the opposite: that
    // handler runs BEFORE the FileView has read the JSON, so it rewrote
    // efectos.lua with the FACTORY values and wiped the saved ones on every
    // start. It went unnoticed because the only effect there was the motion
    // blur, whose factory value was the one the user had anyway; it showed up
    // when window rounding was added, which does differ. See `windowRounding`.

    // The appearance defaults, in one place: reset() writes them, and Settings'
    // draft (AppearanceDraft.qml) loads them for a "Restore" you can still discard.
    function defaults() {
        return {
            notchStyle: "notch",
            islandGap: 4,
            notchColor: "#000000",
            bandH: 32,
            flare: 13,
            roundMax: 30,
            idleW: 140,
            hoverDelay: 240,
            hoverPreview: true,
            browserMedia: false,
            showDate: false,
            showBattery: false,
            reserveSpace: true,
            scrimAlpha: 0.0,
            sideMargin: 16,
            showArch: false,
            showWorkspaces: true,
            showAppName: false,
            showTray: false,
            fontUI: "Adwaita Sans",
            clockSize: 17,
            windowRounding: 12,
            winOpacity: 88,
            winOpacityInactive: 82,
            termOpacity: 87,
            winBlur: true,
            winGaps: 6,
            borderWidth: 1,
            winShadow: true,
            animations: true,
            animSpeed: 100,
            lockBg: "login",
            lockBlur: -1,
            lockDim: 0,
            lockClockSize: 100,
            lockClockWeight: "black",
            lock12h: false,
            lockSide: "",
            lockAccent: "login",
            lockShowDate: true,
            lockShowName: true,
            lockShowPower: true,
            lockShowMedia: false,
            lockChar: "✦",
            lockClockPos: "left",
            lockClockFont: "",
            lockClockColor: "theme",
            lockSeconds: false,
            lockDateFmt: "full",
            lockMessage: "",
            lockShowBattery: false,
            lockFieldStyle: "line",
            lockShade: true,
            lockClockY: -1,
            lockFormY: -1,
            lockCard: false,
            lockAvatar: false,
            lockPreset: "glasstty",
            lockPanel: false,
            lockDatePill: false,
            motionBlur: true,
            motionBlurSamples: 7
        };
    }

    function reset() {
        const d = root.defaults();
        for (const k in d) opts[k] = d[k];
        root.applyEffects();   // this one does not notice by itself: it has to be written for niri
        // favApps and language are NOT touched on purpose: "restore defaults"
        // is for the appearance, and neither the favourites nor the language
        // you read the screen in are a default worth handing back.
        root.save();
    }

    FileView {
        id: file
        path: Quickshell.env("HOME") + "/.config/quickshell-rice.json"
        watchChanges: true
        onFileChanged: reload()
        onAdapterUpdated: root.save()
        onLoaded: { root.loaded = true; root.applyEffects(); }
        // First time: it does not exist -> it is created with the defaults.
        onLoadFailed: function (error) {
            if (error === FileViewError.FileNotFound) { root.loaded = true; root.save(); root.applyEffects(); }
        }

        JsonAdapter {
            id: opts

            property string language: "es"

            property string energyOnAC: "performance"
            property string energyOnBattery: "power-saver"
            property bool batteryAllowIdle: true
            property bool dimOnSaver: true
            property int saverBrightness: 40

            property string notchStyle: "notch"
            property int islandGap: 4
            property string notchColor: "#000000"
            property bool barBlur: true
            property string iconTheme: ""
            property bool tintFolders: true
            property string loginLayout: "pocket"
            property string colorMode: "wallpaper"
            property string manualAccent: "#5e81ac"
            property string manualBg: ""
            property int bandH: 32
            property int flare: 13
            property int roundMax: 30
            property int idleW: 140
            property bool hoverPreview: true
            property int hoverDelay: 240
            property bool browserMedia: false
            property bool showDate: false   // at rest only time and battery; the full date appears on hover
            property bool showBattery: false
            property bool reserveSpace: true

            property real scrimAlpha: 0.0
            property int sideMargin: 16
            property bool showArch: false
            property bool showWorkspaces: true
            property bool stageEnabled: true
            property bool showAppName: false
            property bool showTray: false

            // On by default: it is one of the few things in the rice you see
            // without touching anything. The switch is there for the day the
            // battery matters more than the trail.
            // 0 = square corners, which is how this rice was born: focus is
            // expressed with light and not with a border, and roundness belonged
            // to the shell. It is still the factory value; now it can also be
            // changed.
            property int windowRounding: 12
            property int winOpacity: 88
            property int winOpacityInactive: 82
            property int termOpacity: 87
            property bool winBlur: true
            property int winGaps: 6
            property int borderWidth: 1
            property bool winShadow: true
            property bool animations: true
            property int animSpeed: 100
            property string lockBg: "login"
            property int lockBlur: -1
            property int lockDim: 0
            property int lockClockSize: 100
            property string lockClockWeight: "black"
            property bool lock12h: false
            property string lockSide: ""
            property string lockAccent: "login"
            property bool lockShowDate: true
            property bool lockShowName: true
            property bool lockShowPower: true
            property bool lockShowMedia: false
            property string lockChar: "✦"
            property string lockClockPos: "left"
            property string lockClockFont: ""
            property string lockClockColor: "theme"
            property bool lockSeconds: false
            property string lockDateFmt: "full"
            property string lockMessage: ""
            property bool lockShowBattery: false
            property string lockFieldStyle: "line"
            property bool lockShade: true
            property int lockClockY: -1
            property int lockFormY: -1
            property bool lockCard: false
            property bool lockAvatar: false
            property string lockPreset: "glasstty"
            property bool lockPanel: false
            property bool lockDatePill: false
            property bool motionBlur: true
            property int motionBlurSamples: 7

            property string fontUI: "Adwaita Sans"
            property int clockSize: 17

            property list<string> favApps: []
            property bool learnLauncher: true
            property var appearanceProfiles: []
            property var displays: ({})
        }
    }
}
