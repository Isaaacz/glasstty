// Launcher.qml — the launcher's data and logic: the app list and its search,
// the command centre (modes, actions, windows, clipboard), the calculator and
// the favourites. LauncherPanel.qml is the UI. Split out of ShellState.qml,
// which keeps the state the whole notch shares (which panel is open, its size).
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

    // ═══════════════════════ applications (launcher) ═══════════════════════
    // This fork: apps hidden from the launcher. Files is GNOME's Nautilus
    // (Super+E, and what "arquivos" finds); Thunar and its tools stay
    // installed but out of the way.
    readonly property var hiddenApps: ["thunar", "thunar-settings", "thunar-bulk-rename"]
    readonly property var allApps: {
        const out = [];
        const vs = DesktopEntries.applications ? DesktopEntries.applications.values : [];
        for (let i = 0; i < vs.length; i++)
            if (!vs[i].noDisplay && root.hiddenApps.indexOf(String(vs[i].id).replace(/\.desktop$/, "")) < 0)
                out.push(vs[i]);
        out.sort((a, b) => (a.name || "").localeCompare(b.name || ""));
        return out;
    }

    // Score: the closer to "the start of the name" it matches, the higher. The
    // last resort is a subsequence (typing "gimp" finds "GNU Image...").
    function scoreApp(app, q) {
        const name = (app.name || "").toLowerCase();
        if (name === q) return 1000;
        if (name.startsWith(q)) return 900 - name.length * 0.1;
        const words = name.split(/[\s\-_.]+/);
        for (let i = 0; i < words.length; i++)
            if (words[i].startsWith(q)) return 800 - name.length * 0.1;
        const idx = name.indexOf(q);
        if (idx >= 0) return 700 - idx - name.length * 0.1;
        if ((app.genericName || "").toLowerCase().indexOf(q) >= 0) return 500;
        if ((app.comment || "").toLowerCase().indexOf(q) >= 0) return 400;
        let kw = "";
        try { kw = (app.keywords || []).join(" ").toLowerCase(); } catch (e) {}
        if (kw.indexOf(q) >= 0) return 300;
        // subsequence
        let ti = 0;
        for (let i = 0; i < q.length; i++) {
            ti = name.indexOf(q[i], ti);
            if (ti < 0) return -1;
            ti++;
        }
        return 200 - name.length * 0.1;
    }

    function searchApps(query) {
        const q = (query || "").trim().toLowerCase();
        if (q.length === 0) {
            const apps = root.allApps.slice();
            if (Config.learnLauncher) apps.sort((a, b) => LauncherUsage.scoreOf(b.id)
                - LauncherUsage.scoreOf(a.id) || (a.name || "").localeCompare(b.name || ""));
            return apps;
        }
        const hits = [];
        for (let i = 0; i < root.allApps.length; i++) {
            const s = root.scoreApp(root.allApps[i], q);
            if (s > 0) hits.push({ app: root.allApps[i], score: s });
        }
        // Usage only orders equally strong matches: an exact name always wins.
        hits.sort((a, b) => Math.floor(b.score / 100) - Math.floor(a.score / 100)
            || (Config.learnLauncher ? LauncherUsage.scoreOf(b.app.id) - LauncherUsage.scoreOf(a.app.id) : 0)
            || b.score - a.score || (a.app.name || "").localeCompare(b.app.name || ""));
        return hits.map(h => h.app);
    }

    // ════════════════ the launcher as a command centre ═════════════════
    //
    // The launcher stops being "the list of applications" and becomes the only
    // box where you type. A character at the start decides WHAT is searched:
    //
    //   (none)  applications, plus the calculator and the timer thrown in
    //   #       clipboard history (text and images)
    //   >       system actions
    //   @       open windows
    //
    // WHY PREFIXES AND NOT FOUR SHORTCUTS. Shortcuts have to be remembered with
    // your fingers and each opens a different window that has to be learnt
    // separately. A prefix discovers itself (they are written in the panel
    // itself when it is empty), is corrected with one backspace, and above all:
    // the habit is a single one —Super+R and type—, which is exactly the one
    // there already was.
    //
    // IT IS THE SAME DOOR THE CALCULATOR OPENED. Typing "2+2" in the launcher
    // was already typing something that is not an application name; this just
    // finishes the idea. That is why the calculator and the timer still have no
    // prefix: they are not a mode, they are what happens when what you type
    // turns out to be a sum or a duration.
    //
    // With this the last two rofi menus of the rice are retired (the clipboard
    // history and the command menu); see README.
    property string launcherMode: "apps"     // "apps" | "clip" | "cmd" | "win"

    readonly property var launcherModes: [
        { key: "clip", prefix: "#", icon: Icons.clipboard, name: I18n.tr("Portapapeles"),
          hint: I18n.tr("Buscar en el portapapeles…") },
        { key: "cmd",  prefix: ">", icon: Icons.bolt,      name: I18n.tr("Acciones"),
          hint: I18n.tr("Buscar una acción del sistema…") },
        { key: "win",  prefix: "@", icon: Icons.windows,   name: I18n.tr("Ventanas"),
          hint: I18n.tr("Buscar una ventana abierta…") }
    ]

    readonly property var launcherAppsMode: ({ key: "apps", prefix: "", icon: "󰍉",
        name: I18n.tr("Aplicaciones"), hint: I18n.tr("Buscar aplicaciones…") })

    // "#" -> "clip". Returns "" if that character opens no mode.
    function launcherModeOf(ch) {
        for (let i = 0; i < root.launcherModes.length; i++)
            if (root.launcherModes[i].prefix === ch) return root.launcherModes[i].key;
        return "";
    }

    function launcherModeInfo(key) {
        for (let i = 0; i < root.launcherModes.length; i++)
            if (root.launcherModes[i].key === key) return root.launcherModes[i];
        return root.launcherAppsMode;
    }

    // Open the launcher ALREADY in a mode. Pressing the shortcut of the mode that
    // is already open closes it, just as togglePanel does with the other panels:
    // a shortcut that opens but does not close forces you to reach for Escape.
    function openLauncher(m) {
        const mode = m || "apps";
        if (ShellState.panel === "launcher" && root.launcherMode === mode) { ShellState.closePanel(); return; }
        root.launcherMode = mode;
        root.launcherPreload(mode);
        if (mode === "clip") root.clipRefresh();
        if (mode === "win") root.winRefresh();
        ShellState.panel = "launcher";
    }

    // The starting height. Without this the panel is born with the height of the
    // PREVIOUS SEARCH and corrects on the next frame: you see a double movement.
    // In "clip" there is no knowing how many rows there will be until the
    // process answers, so the maximum is requested and the panel shrinks
    // —upwards, which is its natural gesture— during the opening animation itself.
    function launcherPreload(mode) {
        ShellState.launcherCalc = false;
        ShellState.launcherFavs = mode === "apps" && root.favApps.length > 0;
        ShellState.launcherRows = mode === "apps" ? root.allApps.length
            : mode === "cmd" ? root.sysActions.length
            : mode === "win" ? root.winItems.length
            : root.clipItems.length > 0 ? root.clipItems.length : ShellState.launcherMaxRows;
    }

    // ──────────────── # clipboard ─────────────────
    // The data is served by scripts/cliphist-tool.sh, which replaces the pair of
    // rofi scripts. Nothing is decoded here: an image entry is binary, and
    // putting binaries into a QML string is asking for something to break
    // silently. The script delivers id, type, thumbnail path and label.
    readonly property string clipTool: ShellState.home + "/.config/quickshell/scripts/cliphist-tool.sh"

    property var clipItems: []
    property bool clipLoading: false

    Process {
        id: clipListProc
        command: [root.clipTool, "list"]
        stdout: StdioCollector {
            id: clipOut
            onStreamFinished: {
                const out = [];
                const lines = String(clipOut.text).split("\n");
                for (let i = 0; i < lines.length; i++) {
                    if (lines[i].length === 0) continue;
                    const p = lines[i].split("\t");
                    if (p.length < 4) continue;
                    out.push({
                        kind: "clip",
                        id: p[0],
                        image: p[1] === "image",
                        thumb: p[2] === "-" ? "" : p[2],
                        // join in case the label carried a tab the script had
                        // not cleaned: splitting on the first and joining the rest
                        // back loses no text.
                        label: p.slice(3).join("\t")
                    });
                }
                root.clipItems = out;
                root.clipLoading = false;
            }
        }
        // Safety net: if the process died without writing anything (script
        // deleted, cliphist uninstalled), without this the panel would stay for
        // ever on "Leyendo el portapapeles…" (Reading the clipboard…) with the
        // maximum height set.
        onExited: root.clipLoading = false
    }

    function clipRefresh() {
        if (clipListProc.running) return;
        root.clipLoading = true;
        clipListProc.running = true;
    }

    function searchClip(query) {
        const q = (query || "").trim().toLowerCase();
        if (q.length === 0) return root.clipItems;
        const out = [];
        for (let i = 0; i < root.clipItems.length; i++)
            if (root.clipItems[i].label.toLowerCase().indexOf(q) >= 0) out.push(root.clipItems[i]);
        return out;
    }

    // The notice cannot carry the preview's 200 characters: the "toast" face
    // is a fixed 330 px and the text would spill out of the notch at the sides.
    function clipShort(t) {
        const s = String(t).replace(/\s+/g, " ").trim();
        return s.length > 32 ? s.slice(0, 32) + "…" : s;
    }

    function clipCopy(item) {
        if (!item) return;
        Quickshell.execDetached([root.clipTool, "copy", String(item.id)]);
        ShellState.closePanel();
        root.toast(item.image ? Icons.image : "󰆏",
                   item.image ? I18n.tr("Imagen copiada")
                              : I18n.tr("Copiado: {0}", root.clipShort(item.label)));
    }

    function clipDelete(item) {
        if (!item) return;
        Quickshell.execDetached([root.clipTool, "delete", String(item.id)]);
        // It is removed from the list HERE instead of re-reading it whole:
        // re-reading is 150 lines and one more process to strike out a row the
        // user has just seen disappear. cliphist ids are not reused, so the local
        // copy cannot end up pointing at something else.
        const out = [];
        for (let i = 0; i < root.clipItems.length; i++)
            if (root.clipItems[i].id !== item.id) out.push(root.clipItems[i]);
        root.clipItems = out;
    }

    // ────────────────── > system actions ──────────────────
    // The list that was in ~/.config/glasstty/scripts/menu.sh, plus what that menu
    // could not offer because it lived outside the shell (settings, workspace
    // map, do not disturb, caffeine).
    //
    // The ones with a NATIVE equivalent in the notch no longer call an external
    // program: "Wifi" opened `kitty -e impala` and now opens NetworkPanel;
    // "Apagar" (Shut down) opened wlogout and now opens PowerPanel. Launching a
    // terminal to touch the wifi with the panel right there was a leftover from
    // an earlier era.
    //
    // Only `name` and `desc` are visible: `id` is what runAction() dispatches and
    // `keys` are the words you TYPE to find the action, which are not seen.
    // That is why `keys` does not go through tr(): the keys are not translated,
    // they ACCUMULATE. With the shell in English, `name` and `desc` already come
    // out translated and the search matches them, but someone typing "shutdown"
    // or "screenshot" would find nothing if the keys were still only in Spanish.
    // With both lists together, the search works in both languages at once and
    // without duplicating the table.
    readonly property var sysActions: [
        { kind: "cmd", id: "clip", icon: Icons.clipboard, name: I18n.tr("Portapapeles"),
          desc: I18n.tr("Historial de copiado"),
          keys: "clipboard cliphist copiar pegar historial copy paste history" },
        { kind: "cmd", id: "lock", icon: Icons.lock, name: I18n.tr("Bloquear pantalla"),
          desc: "hyprlock",
          keys: "lock bloquear candado lock screen padlock" },
        { kind: "cmd", id: "night", icon: Icons.moon, name: I18n.tr("Luz nocturna"),
          desc: "Alternar a luz noturna (wlsunset)",
          keys: "night light nocturna noturna calida azul wlsunset warm blue filter" },
        { kind: "cmd", id: "shot", icon: Icons.screenshot, name: I18n.tr("Captura + anotar"),
          desc: I18n.tr("Recorte y edición"),
          keys: "screenshot captura pantallazo anotar recortar screen shot annotate crop snip" },
        { kind: "cmd", id: "wall", icon: Icons.wallpaper, name: I18n.tr("Cambiar fondo"),
          desc: I18n.tr("Selector de fondos de pantalla"),
          keys: "wallpaper fondo escritorio papel background desktop change" },
        { kind: "cmd", id: "pick", icon: Icons.eyedropper, name: I18n.tr("Cuentagotas de color"),
          desc: I18n.tr("Copia el color del píxel"),
          keys: "color picker cuentagotas hex pipeta colour eyedropper dropper pixel" },
        { kind: "cmd", id: "ocr", icon: Icons.ocr, name: I18n.tr("OCR: extraer texto"),
          desc: I18n.tr("Texto de una zona de pantalla"),
          keys: "ocr texto reconocer leer imagen text recognise extract image" },
        { kind: "cmd", id: "rec", icon: Icons.video, name: I18n.tr("Grabar pantalla"),
          desc: I18n.tr("Iniciar o parar la grabación"),
          keys: "record grabar video captura recording screen capture" },
        { kind: "cmd", id: "wifi", icon: Icons.wifi, name: I18n.tr("Wifi"),
          desc: I18n.tr("Redes disponibles"),
          keys: "wifi red network internet wi-fi wireless networks" },
        { kind: "cmd", id: "bt", icon: Icons.bluetooth, name: I18n.tr("Bluetooth"),
          desc: I18n.tr("Dispositivos emparejados"),
          keys: "bluetooth bt auriculares mando headphones headset controller pair devices" },
        { kind: "cmd", id: "overview", icon: Icons.grid, name: I18n.tr("Mapa de escritorios"),
          desc: I18n.tr("Ver y mover ventanas"),
          keys: "overview escritorios workspaces mapa workspace map windows grid" },
        { kind: "cmd", id: "stage", icon: Icons.grid, name: I18n.tr("Organizador visual"),
          desc: I18n.tr("Stage Manager"),
          keys: "stage manager organizador visual apple escritorios workspaces lateral sidebar" },
        { kind: "cmd", id: "system", icon: Icons.cpu, name: I18n.tr("Tu máquina"),
          desc: I18n.tr("Actividad, temperatura y batería"),
          keys: "sistema monitor cpu ram memoria disco temperatura bateria rendimiento equipo system memory disk temperature battery performance machine" },
        { kind: "cmd", id: "settings", icon: Icons.cog, name: I18n.tr("Ajustes"),
          desc: I18n.tr("Apariencia, sonido, atajos…"),
          keys: "settings ajustes preferencias config preferences configuration" },
        { kind: "cmd", id: "keys", icon: Icons.keyboard, name: I18n.tr("Atajos de teclado"),
          desc: "Mapa vivo de teclas do niri",
          keys: "atajos teclas teclado keybinds shortcuts hotkeys mapa keyboard keys map" },
        { kind: "cmd", id: "dnd", icon: Icons.bellOff, name: I18n.tr("No molestar"),
          desc: I18n.tr("Silenciar notificaciones"),
          keys: "dnd molestar silencio notificaciones do not disturb silence notifications mute" },
        { kind: "cmd", id: "caffeine", icon: Icons.coffee, name: I18n.tr("Café"),
          desc: I18n.tr("Impedir que se apague la pantalla"),
          keys: "caffeine cafe insomnio despierto suspender coffee awake keep screen on sleep" },
        { kind: "cmd", id: "gamemode", icon: Icons.gamepad, name: I18n.tr("Modo juego"),
          desc: I18n.tr("FPS, CPU y GPU en la barra mientras juegas"),
          keys: "modo juego jogo game mode gaming fps steam mangohud rendimiento desempenho" },
        { kind: "cmd", id: "saver", icon: Icons.monitor, name: I18n.tr("Salvapantallas"),
          desc: I18n.tr("Arrancarlo ahora"),
          keys: "screensaver salvapantallas screen saver idle" },
        { kind: "cmd", id: "power", icon: Icons.power, name: I18n.tr("Apagar / salir"),
          desc: I18n.tr("Apagar, reiniciar, cerrar sesión"),
          keys: "power apagar reiniciar salir logout suspender shutdown shut down restart reboot log out sign out suspend hibernate" }
    ]

    function searchActions(query) {
        const q = (query || "").trim().toLowerCase();
        if (q.length === 0) return root.sysActions;
        const out = [];
        for (let i = 0; i < root.sysActions.length; i++) {
            const a = root.sysActions[i];
            const hay = (a.name + " " + a.desc + " " + a.keys).toLowerCase();
            if (hay.indexOf(q) >= 0) out.push(a);
        }
        return out;
    }

    function runAction(a) {
        if (!a) return;
        const S = ShellState.home + "/.config/glasstty/scripts/";

        // ── the ones that stay INSIDE the shell ──
        // They do not close the panel: they change face. Closing and reopening at
        // the same instant makes the whole notch flicker.
        switch (a.id) {
        case "clip":     root.openLauncher("clip"); return;
        case "wifi":     ShellState.panel = "network"; return;
        case "bt":       ShellState.panel = "bluetooth"; return;
        case "power":    ShellState.closePanel(); Quickshell.execDetached(["qs", "ipc", "call", "exit", "open"]); return;
        case "overview": Compositor.refreshToplevels(); ShellState.panel = "overview"; return;
        case "stage":    ShellState.closePanel(); ShellState.toggleStage(); return;
        case "system":   ShellState.panel = "system"; return;
        case "settings": ShellState.closePanel(); ShellState.settingsOpen = true; return;
        case "keys":     ShellState.closePanel(); ShellState.openSettingsAt("keys"); return;
        case "dnd":
            ShellState.dnd = !ShellState.dnd; ShellState.closePanel();
            root.toast(Icons.bell, ShellState.dnd ? I18n.tr("No molestar activado")
                                            : I18n.tr("No molestar desactivado"));
            return;
        case "caffeine":
            ShellState.caffeine = !ShellState.caffeine; ShellState.closePanel();
            root.toast(Icons.coffee, ShellState.caffeine ? I18n.tr("Café: la pantalla no se apaga")
                                                   : I18n.tr("Café desactivado"));
            return;
        case "gamemode":
            ShellState.closePanel(); ShellState.toggleGameMode();
            return;
        }

        // ── the ones that go outside: close first ──
        // Several of these freeze the screen or ask for a crop, and doing it with
        // the panel still up would leave it inside the picture.
        ShellState.closePanel();
        switch (a.id) {
        case "lock":  Quickshell.execDetached(["loginctl", "lock-session"]); break;
        // Through the same door as the control centre tile and
        // Super+Shift+N: that way the poll finds out at once in all three cases.
        case "night": ShellState.toggleNightLight(); break;
        case "shot":  Quickshell.execDetached([S + "screenshot-annotate.sh"]); break;
        case "pick":  Quickshell.execDetached([S + "colorpicker.sh"]); break;
        case "ocr":   Quickshell.execDetached([S + "ocr.sh"]); break;
        case "rec":   Quickshell.execDetached([S + "screenrecord.sh"]); break;
        case "saver": Quickshell.execDetached([S + "screensaver.sh"]); break;
        // The NATIVE wallpaper picker (WallpaperPicker.qml) is a separate
        // window, not a notch panel, and it only opens through its global
        // shortcut. It is the same call the Settings › Appearance button uses.
        case "wall":  Compositor.global("wallpaper"); break;
        }
    }

    // ───────────────── @ open windows ──────────────────
    // It is read from Hyprland and not from Wayland's ToplevelManager because we
    // need each window's WORKSPACE, and only the compositor knows that.
    //
    // winTick exists because `Hyprland.toplevels.values` notifies when a window
    // is born or dies, but NOT when its title changes: without it, searching
    // "github" would not find the tab you have just opened in a Chrome that was
    // already running.
    property int winTick: 0
    Timer {
        id: winPoll
        interval: 90
        onTriggered: { Compositor.refreshToplevels(); root.winTick++; }
    }
    function winRefresh() { Compositor.refreshToplevels(); root.winTick++; }
    Connections {
        target: Compositor
        // Only with the mode open: every refreshToplevels() is a query to
        // Hyprland's socket, and 99 % of the time this list is not being looked at.
        enabled: ShellState.panel === "launcher" && root.launcherMode === "win"
        function onRawEvent(ev) {
            const n = String(ev.name);
            if (n.indexOf("window") >= 0 || n.indexOf("title") >= 0 || n.indexOf("workspace") >= 0)
                winPoll.restart();
        }
    }

    readonly property var winItems: {
        root.winTick;   // dependency on purpose: see the note above
        const out = [];
        const ts = Compositor.toplevels;
        for (let i = 0; i < ts.length; i++) {
            const t = ts[i];
            if (!t || !t.workspace || t.workspace.id < 1) continue;   // leave out the special ones
            const c = t.lastIpcObject;
            const cls = c ? String(c["class"] || "") : "";
            out.push({
                kind: "win",
                // CAREFUL: `address` comes WITHOUT the "0x" and Hyprland's
                // dispatchers require it. Without the prefix, focus answers "no window"
                // and nothing happens, silently. Same trap as in OverviewPanel.
                addr: (function () {
                    const s = String(t.address || "");
                    return s.startsWith("0x") ? s : "0x" + s;
                })(),
                ws: t.workspace.id,
                cls: cls,
                title: (t.title && t.title.length > 0) ? String(t.title) : cls,
                icon: root.iconForClass(cls),
                tl: t
            });
        }
        out.sort((a, b) => a.ws - b.ws || a.title.localeCompare(b.title));
        return out;
    }

    // The .desktop is almost never named like the window class
    // ("org.gnome.Nautilus" vs "nautilus"), so Quickshell's heuristic lookup
    // does the work; if it finds nothing, the lower-case class is usually a
    // valid icon name in the theme.
    function iconForClass(cls) {
        if (!cls) return "";
        try {
            const e = DesktopEntries.heuristicLookup(cls);
            if (e && e.icon) return e.icon;
        } catch (err) {}
        return cls.toLowerCase();
    }

    function searchWins(query) {
        const q = (query || "").trim().toLowerCase();
        if (q.length === 0) return root.winItems;
        const out = [];
        for (let i = 0; i < root.winItems.length; i++) {
            const w = root.winItems[i];
            if ((w.title + " " + w.cls + " " + w.ws).toLowerCase().indexOf(q) >= 0) out.push(w);
        }
        return out;
    }

    // Close FIRST and ask for focus AFTERWARDS, with 60 ms in between. Closing
    // the panel releases the HyprlandFocusGrab and Hyprland gives focus back to
    // the window that had it before; if our request goes at the same instant it
    // is not guaranteed who arrives last, and if the give-back wins you stay
    // where you were — exactly what you have just asked not to happen. It is the
    // same remedy (and the same figure) that OverviewPanel uses when jumping to
    // a window.
    property string winPending: ""
    Timer {
        id: winFocusDefer
        interval: 60
        onTriggered: {
            if (root.winPending === "") return;
            Compositor.focusWindow(root.winPending);
            root.winPending = "";
        }
    }
    function focusWindow(w) {
        if (!w) return;
        root.winPending = w.addr;
        ShellState.closePanel();
        winFocusDefer.restart();
    }

    // ═════════════════════════ launcher calculator ══════════════════════════
    // Allowed names. Any other word in the expression rules it out:
    // that way "7zip" or "firefox 2" do not trigger the calculator.
    readonly property var calcWords: ["sqrt", "abs", "sin", "cos", "tan", "asin", "acos", "atan",
        "log", "log2", "log10", "exp", "round", "floor", "ceil", "min", "max", "pow", "pi", "e"]

    function calcEval(q) {
        let e = (q || "").trim();
        if (e.startsWith("=")) e = e.slice(1);      // "=" forces calculator mode
        if (e.length === 0) return null;
        if (!/\d/.test(e)) return null;                    // no numbers, no sum
        if (!/[+\-*\/^%()]/.test(e)) return null;           // no operator either: "5" is not a sum

        // expression characters only, and letters only inside known names
        if (!/^[0-9\s+\-*\/^%().,×÷a-zA-Z]+$/.test(e)) return null;
        const words = e.match(/[a-zA-Z]+/g) || [];
        for (let i = 0; i < words.length; i++)
            if (root.calcWords.indexOf(words[i].toLowerCase()) < 0) return null;

        // friendly syntax -> JavaScript
        let x = e.replace(/×/g, "*").replace(/÷/g, "/").replace(/\^/g, "**");
        x = x.replace(/(\d),(\d)/g, "$1.$2");               // decimal comma
        x = x.replace(/\bpi\b/gi, "Math.PI").replace(/\be\b/gi, "Math.E");
        x = x.replace(/\b(sqrt|abs|sin|cos|tan|asin|acos|atan|log2|log10|log|exp|round|floor|ceil|min|max|pow)\b/gi,
                      function (m) { return "Math." + m.toLowerCase(); });
        try {
            const v = Function('"use strict"; return (' + x + ')')();
            if (typeof v !== "number" || !isFinite(v)) return null;
            return v;
        } catch (err) {
            return null;
        }
    }

    // No floating-point noise: 0.1+0.2 must give 0.3, not 0.30000000000000004
    function calcFormat(v) {
        if (v === null || v === undefined) return "";
        const r = Math.round(v * 1e10) / 1e10;
        if (Number.isInteger(r) && Math.abs(r) < 1e15) return String(r);
        return String(parseFloat(r.toPrecision(12)));
    }

    function copyText(t) {
        Quickshell.clipboardText = String(t);
        root.toast("󰆏", I18n.tr("Copiado: {0}", t));
    }

    // Brief notice inside the notch. Here it IS needed: copying to the clipboard
    // has no other sign that it happened.
    property string toastIcon: ""
    property string toastText: ""
    function toast(icon, text) {
        root.toastIcon = icon;
        root.toastText = text;
        ShellState.flash("toast");
    }

    function launchApp(app) {
        if (!app) return;
        ShellState.closePanel();
        app.execute();
        if (Config.learnLauncher) LauncherUsage.record(app.id);
    }

    // ════════════════════════ launcher favourites ═════════════════════════
    // They are stored by the .desktop entry's `id`, which is constant, and NOT by
    // name: renaming the app or changing the desktop language must not lose you
    // the favourite. An id that no longer exists (app uninstalled) is ignored
    // when resolving, so the list cleans itself up without any notice.
    readonly property var favApps: {
        const out = [];
        const ids = Config.favApps;
        for (let i = 0; i < ids.length; i++) {
            const a = root.appById(ids[i]);
            if (a) out.push(a);
        }
        return out;
    }

    function appById(id) {
        const vs = root.allApps;
        for (let i = 0; i < vs.length; i++) if (vs[i].id === id) return vs[i];
        return null;
    }

    function isFav(app) { return !!app && Config.favApps.indexOf(app.id) >= 0; }

    function toggleFav(app) {
        if (!app) return;
        // slice() and not in-place mutation: changing the list from inside does not
        // fire the property change, so it neither repaints nor saves the file.
        const ids = Config.favApps.slice();
        const i = ids.indexOf(app.id);
        if (i >= 0) ids.splice(i, 1); else ids.push(app.id);
        Config.favApps = ids;
        Config.save();
    }
}
