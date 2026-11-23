// SettingsShortcuts.qml — the keyboard shortcuts, read live from the
// `binds { }` block of ~/.config/niri/config.kdl.
//
// WHY READ THEM RATHER THAN WRITE THEM BY HAND: a list written here falls out
// of sync the first day you touch a bind. This parses the real file and
// reloads only when it changes, so it cannot lie. Super+K opens it.
//
// READ-ONLY: reassigning keys would mean rewriting config.kdl with the risk of
// mangling comments and order, and that file is the rice's source of truth.
import Quickshell
import Quickshell.Io
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Flickable {
    id: root

    // This fork: under niri the list comes from ~/.config/niri/config.kdl.
    property string note: "Lidos de ~/.config/niri/config.kdl. Super+K abre esta mesma lista."
    property var binds: []
    readonly property int matchCount: cShell.visibleRows + cWin.visibleRows + cWs.visibleRows
        + cApps.visibleRows + cSys.visibleRows

    contentHeight: col.implicitHeight + 34
    clip: true
    boundsBehavior: Flickable.StopAtBounds
    ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded; width: 5 }
    onVisibleChanged: if (visible) contentY = 0

    FileView {
        id: conf
        path: ShellState.home + "/.config/niri/config.kdl"
        watchChanges: true
        onFileChanged: reload()
        onLoaded: root.binds = root.parseKdl(text())
    }

    // The list is built ONCE, when the file is read: it is not a binding.
    // Since the key and dispatcher labels ARE translated, a language change
    // has to parse again, or they would stay in the previous language until
    // someone touched hyprland.conf.
    Connections {
        target: I18n
        function onLangChanged() {
            const t = conf.text();
            if (t && t.length > 0) root.binds = root.parseKdl(t);
        }
    }

    // ─────────── parsing ──────────
    // One bind per line inside `binds { }`:
    //   Mod+Shift+Left  hotkey-overlay-title="…" { move-column-left; }
    // The title, when there is one, is the description; otherwise the action
    // is described from the tables below (in Portuguese, the language of this
    // fork's niri config).
    readonly property var nKeys: ({
        "Comma": ",", "Period": ".", "Slash": "/", "Space": "Espaço", "Tab": "Tab",
        "Left": "←", "Right": "→", "Up": "↑", "Down": "↓",
        "Page_Down": "PgDn", "Page_Up": "PgUp", "BracketLeft": "[", "BracketRight": "]",
        "Print": "Print Screen", "Return": "Enter", "Escape": "Esc",
        "WheelScrollDown": "roda ↓", "WheelScrollUp": "roda ↑",
        "XF86AudioRaiseVolume": "Volume +", "XF86AudioLowerVolume": "Volume −",
        "XF86AudioMute": "Mudo", "XF86AudioMicMute": "Microfone mudo",
        "XF86AudioNext": "Próxima", "XF86AudioPrev": "Anterior",
        "XF86AudioPlay": "Play", "XF86AudioPause": "Pausa",
        "XF86MonBrightnessUp": "Brilho +", "XF86MonBrightnessDown": "Brilho −",
        "XF86PowerOff": "Botão de ligar"
    })
    readonly property var nMods: ({ "Mod": "Super", "Super": "Super", "Ctrl": "Ctrl", "Control": "Ctrl",
                                    "Shift": "Shift", "Alt": "Alt" })
    // qs ipc call <target> <function> [arg]
    readonly property var nIpc: ({
        "notch control": "Central de Controle", "notch launcher": "Launcher (apps)",
        "notch settings": "Ajustes", "notch overview": "Mapa de áreas de trabalho",
        "notch system": "Monitor do sistema", "notch power": "Menu de energia",
        "notch keys": "Esta lista de atalhos", "notch bar": "Esconder/mostrar a barra",
        "notch style": "Notch ou ilha", "notch clipboard": "Histórico da área de transferência",
        "notch actions": "Ações rápidas", "notch calendar": "Calendário",
        "notch bright up": "Mais brilho", "notch bright down": "Menos brilho",
        "wallpaper toggle": "Escolher wallpaper", "media toggle": "Player de música", "shot open": "Capturar tela"
    })
    readonly property var nActions: ({
        "show-hotkey-overlay": "Atalhos do niri", "toggle-overview": "Overview do niri",
        "close-window": "Fechar janela", "toggle-window-floating": "Janela flutuante sim/não",
        "maximize-column": "Maximizar coluna", "maximize-window-to-edges": "Maximizar até as bordas",
        "fullscreen-window": "Tela cheia",
        "switch-preset-column-width": "Alternar largura da coluna",
        "focus-column-left": "Foco na janela à esquerda", "focus-column-right": "Foco na janela à direita",
        "focus-window-up": "Foco na janela de cima", "focus-window-down": "Foco na janela de baixo",
        "move-column-left": "Mover janela para a esquerda", "move-column-right": "Mover janela para a direita",
        "move-window-up": "Mover janela para cima", "move-window-down": "Mover janela para baixo",
        "focus-monitor-left": "Foco no monitor à esquerda", "focus-monitor-right": "Foco no monitor à direita",
        "focus-monitor-up": "Foco no monitor de cima", "focus-monitor-down": "Foco no monitor de baixo",
        "focus-workspace-down": "Área de trabalho de baixo", "focus-workspace-up": "Área de trabalho de cima",
        "move-column-to-workspace-down": "Levar janela para a área de baixo",
        "move-column-to-workspace-up": "Levar janela para a área de cima",
        "consume-or-expel-window-left": "Juntar/separar janela à esquerda",
        "consume-or-expel-window-right": "Juntar/separar janela à direita",
        "quit": "Sair do niri", "power-off-monitors": "Desligar a tela"
    })
    // spawn-sh: by the script's name or the command's start.
    readonly property var nScripts: ({
        "screenshot-region.sh": "Captura de uma área", "screenshot-full.sh": "Captura da tela inteira",
        "screenshot-annotate.sh": "Captura com anotação", "colorpicker.sh": "Conta-gotas",
        "night-light.sh": "Luz noturna", "ocr.sh": "Copiar texto da tela (OCR)",
        "screenrecord.sh": "Gravar a tela", "screenrecord.sh --sonido": "Gravar a tela com som",
        "lock.sh": "Bloquear", "reload.sh": "Recarregar o shell"
    })

    function parseKdl(txt) {
        if (!txt || txt.length === 0) return [];
        const out = [];
        const lines = txt.split("\n");
        let inBinds = false;
        for (let i = 0; i < lines.length; i++) {
            const line = lines[i].trim();
            if (!inBinds) { if (/^binds\s*\{/.test(line)) inBinds = true; continue; }
            if (line === "}") break;
            if (line.startsWith("//")) continue;
            const m = line.match(/^(\S+)\s*(.*?)\{\s*(.*?);?\s*\}\s*$/);
            if (!m) continue;
            const props = m[2], action = m[3].trim();
            const t = props.match(/hotkey-overlay-title="([^"]*)"/);
            const d = root.nDescribe(action);
            out.push({ combo: root.nCombo(m[1]), what: t ? t[1] : d.what, group: d.group });
        }
        return out;
    }

    function nCombo(c) {
        const parts = c.split("+");
        const key = parts.pop();
        const out = parts.map(p => root.nMods[p] !== undefined ? root.nMods[p] : p);
        out.push(root.nKeys[key] !== undefined ? root.nKeys[key] : (key.length === 1 ? key.toUpperCase() : key));
        return out.join(" + ");
    }

    function nDescribe(action) {
        const args = (action.match(/"[^"]*"/g) || []).map(a => a.slice(1, -1));
        const verb = action.split(/\s+/)[0];
        if (verb === "spawn" && args[0] === "qs" && args[1] === "ipc" && args[2] === "call") {
            const k = args.slice(3).join(" ");
            const what = root.nIpc[k] !== undefined ? root.nIpc[k] : k;
            return { what: what, group: k.startsWith("compositor") ? "win" : "shell" };
        }
        if (verb === "spawn") {
            const cmd = args.join(" ");
            const media = { "playerctl next": "Próxima música", "playerctl previous": "Música anterior",
                            "playerctl play-pause": "Tocar/pausar" };
            if (media[cmd] !== undefined) return { what: media[cmd], group: "sys" };
            return { what: "Abrir " + args[0], group: "apps" };
        }
        if (verb === "spawn-sh") {
            const cmd = args[0] || "";
            if (cmd.startsWith("wpctl")) {
                const what = cmd.indexOf("SOURCE") >= 0 ? "Microfone mudo"
                    : cmd.indexOf("set-mute") >= 0 ? "Som mudo"
                    : cmd.indexOf("%+") >= 0 ? "Mais volume" : "Menos volume";
                return { what: what, group: "sys" };
            }
            const base = cmd.split("/").pop();
            if (root.nScripts[base] !== undefined) {
                const g = (base === "lock.sh" || base === "reload.sh") ? "sys" : "apps";
                return { what: root.nScripts[base], group: g };
            }
            return { what: base, group: "apps" };
        }
        if (verb === "focus-workspace" || verb === "move-column-to-workspace") {
            const n = parseInt(action.split(/\s+/)[1]);
            const area = isNaN(n) ? "" : String(n);
            return { what: (verb === "focus-workspace" ? "Ir para a área " : "Levar janela para a área ") + area,
                     group: "ws" };
        }
        const what = root.nActions[verb] !== undefined ? root.nActions[verb] : verb;
        const group = verb.indexOf("workspace") >= 0 ? "ws"
            : (verb === "quit" || verb === "power-off-monitors" || verb === "show-hotkey-overlay"
               || verb === "toggle-overview") ? "sys" : "win";
        return { what: what, group: group };
    }

    function ofGroup(g) {
        const out = [];
        for (let i = 0; i < root.binds.length; i++) if (root.binds[i].group === g) out.push(root.binds[i]);
        return out;
    }

    ColumnLayout {
        id: col
        width: root.width - 48
        x: 24
        y: 16
        spacing: 10

        SettingsControls.Card_ {
            id: cShell
            title: I18n.tr("El shell")
            Repeater {
                model: root.ofGroup("shell")
                onItemAdded: cShell.recount()
                onItemRemoved: cShell.recount()
                KeyRow {}
            }
        }

        SettingsControls.Card_ {
            id: cWin
            title: I18n.tr("Ventanas")
            Repeater {
                model: root.ofGroup("win")
                onItemAdded: cWin.recount()
                onItemRemoved: cWin.recount()
                KeyRow {}
            }
        }

        SettingsControls.Card_ {
            id: cWs
            title: I18n.tr("Escritorios")
            Repeater {
                model: root.ofGroup("ws")
                onItemAdded: cWs.recount()
                onItemRemoved: cWs.recount()
                KeyRow {}
            }
        }

        SettingsControls.Card_ {
            id: cApps
            title: I18n.tr("Apps y scripts")
            Repeater {
                model: root.ofGroup("apps")
                onItemAdded: cApps.recount()
                onItemRemoved: cApps.recount()
                KeyRow {}
            }
        }

        SettingsControls.Card_ {
            id: cSys
            title: I18n.tr("Sistema")
            Repeater {
                model: root.ofGroup("sys")
                onItemAdded: cSys.recount()
                onItemRemoved: cSys.recount()
                KeyRow {}
            }
        }

        SettingsControls.Note_ {
            Layout.topMargin: 10
            visible: root.binds.length === 0
            text: "Não foi possível ler nenhum atalho do config.kdl."
        }

        SettingsControls.Note_ {
            Layout.topMargin: 10
            visible: root.binds.length > 0 && ShellState.settingsQuery.length > 0
                     && !cShell.visible && !cWin.visible && !cWs.visible && !cApps.visible && !cSys.visible
            text: I18n.tr("Ningún atajo coincide con «{0}».", ShellState.settingsQuery)
        }
    }

    // ─────────── shortcut row ────────────
    component KeyRow: Rectangle {
        id: kr
        required property var modelData

        readonly property bool isSettingsRow: true
        readonly property bool matches: ShellState.settingsMatch(kr.modelData.combo, kr.modelData.what)
        function _recount() {
            let p = kr.parent;
            while (p) { if (p.isSettingsCard) { p.recount(); return; } p = p.parent; }
        }
        onMatchesChanged: kr._recount()
        Component.onCompleted: kr._recount()

        Layout.fillWidth: true
        Layout.preferredHeight: 34
        visible: kr.matches
        radius: Appearance.radS
        color: krHover.hovered ? Colors.fill2 : "transparent"
        Behavior on color { ColorAnimation { duration: Appearance.mQuick; easing.type: Easing.OutQuad } }

        HoverHandler {
            id: krHover
            onHoveredChanged: {
                if (hovered) ShellState.settingsHint = kr.modelData.what;
                else if (ShellState.settingsHint === kr.modelData.what) ShellState.settingsHint = "";
            }
        }

        RowLayout {
            anchors { fill: parent; leftMargin: 12; rightMargin: 12 }
            spacing: 14

            Rectangle {
                Layout.preferredWidth: 152
                Layout.preferredHeight: 22
                radius: 7
                color: Colors.fill3
                Text {
                    anchors { fill: parent; leftMargin: 8; rightMargin: 8 }
                    verticalAlignment: Text.AlignVCenter
                    text: kr.modelData.combo
                    color: Colors.label
                    elide: Text.ElideRight
                    font.family: Appearance.fontUI
                    font.pixelSize: Appearance.fsXS
                }
            }

            Text {
                Layout.fillWidth: true
                text: kr.modelData.what
                color: Colors.label2
                elide: Text.ElideRight
                font.family: Appearance.fontUI
                font.pixelSize: Appearance.fsXS
            }
        }
    }
}
