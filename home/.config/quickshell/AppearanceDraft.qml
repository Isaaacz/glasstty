// AppearanceDraft.qml — Settings > Appearance changes show live, but only
// stay if you press "Aplicar".
//
// When Settings opens, the current values are noted down. Every control on
// those tabs writes through set(): the desktop changes at once (bar, notch,
// niri's window effects, the colours), and the change is counted. "Aplicar"
// keeps them and does the one thing that is not live (the login picture).
// "Descartar" — or closing Settings without applying — puts the noted values
// back, and redoes the effects and colours if those had changed.
//
// The language is NOT here on purpose: it changes the Settings window itself.
pragma Singleton

import Quickshell
import QtQuick

Singleton {
    id: root

    // Everything on the Appearance tabs except the language.
    readonly property var keys: [
        "notchStyle", "notchColor", "bandH", "idleW", "islandGap", "flare", "roundMax",
        "hoverPreview", "hoverDelay", "showDate", "showBattery", "browserMedia", "reserveSpace",
        "scrimAlpha", "sideMargin", "showArch", "showWorkspaces", "stageEnabled", "showAppName", "showTray",
        "fontUI", "clockSize",
        "colorMode", "manualAccent", "manualBg",
        "windowRounding", "winOpacity", "winOpacityInactive", "termOpacity", "winBlur", "winGaps",
        "borderWidth", "winShadow", "animations", "animSpeed",
        "lockBg", "lockBlur", "lockDim", "lockShade", "lockClockPos", "lockClockY", "lockClockSize",
        "lockClockWeight", "lockClockFont", "lockClockColor", "lock12h", "lockSeconds", "lockShowDate",
        "lockDateFmt", "lockSide", "lockFormY", "lockFieldStyle", "lockChar", "lockAccent",
        "lockMessage", "lockShowMedia", "lockShowBattery", "lockShowName", "lockShowPower",
        "lockCard", "lockAvatar", "lockPreset", "lockPanel", "lockDatePill"
    ]
    // What has to run after applying, by group.
    readonly property var effectKeys: ["windowRounding", "winOpacity", "winOpacityInactive", "termOpacity",
        "winBlur", "winGaps", "borderWidth", "winShadow", "animations", "animSpeed"]
    readonly property var loginKeys: ["lockBlur", "lockDim", "lockClockY", "lock12h", "lockSide", "lockFormY"]
    readonly property var paletteKeys: ["colorMode", "manualAccent", "manualBg"]

    property var v: ({})              // the values the controls show (= Config while open)
    property var before: ({})         // what was there when Settings opened
    property var changed: ({})        // key -> true for what differs from `before`
    readonly property int count: Object.keys(root.changed).length
    readonly property bool dirty: root.count > 0

    function load() {
        const o = {};
        for (const k of root.keys) o[k] = Config[k];
        root.v = o;
        root.before = Object.assign({}, o);
        root.changed = {};
    }
    function sideEffects(ks, withLogin) {
        const any = (group) => ks.some(k => group.indexOf(k) >= 0);
        if (any(root.effectKeys)) Config.applyEffects();
        if (any(root.paletteKeys)) Config.applyPalette();
        if (withLogin && any(root.loginKeys)) Config.applyLoginLook();
    }
    function set(k, val) {
        const o = Object.assign({}, root.v);
        o[k] = val;
        root.v = o;
        Config[k] = val;                       // live
        const c = Object.assign({}, root.changed);
        if (val === root.before[k]) delete c[k]; else c[k] = true;
        root.changed = c;
        root.sideEffects([k], false);
    }
    // "Restaurar": the defaults, live, to be applied or discarded like any change.
    function restoreDefaults() {
        const d = Config.defaults();
        for (const k in d) if (root.keys.indexOf(k) >= 0) root.set(k, d[k]);
    }
    function apply() {
        const ks = Object.keys(root.changed);
        if (ks.length === 0) return;
        Config.save();
        // Effects and colours are already live; only the login picture is made here.
        if (ks.some(k => root.loginKeys.indexOf(k) >= 0)) Config.applyLoginLook();
        root.load();
    }
    function discard() {
        const ks = Object.keys(root.changed);
        if (ks.length === 0) return;
        for (const k of ks) Config[k] = root.before[k];
        Config.save();
        root.sideEffects(ks, false);
        root.load();
    }

    // Noted down every time Settings opens.
    Connections {
        target: ShellState
        // Closing without "Aplicar" undoes what was tried.
        function onSettingsOpenChanged() { if (ShellState.settingsOpen) root.load(); else root.discard(); }
    }
    Connections {
        target: Config
        function onLoadedChanged() { if (Config.loaded) root.load(); }
    }
    Component.onCompleted: root.load()
}
