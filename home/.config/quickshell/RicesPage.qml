// RicesPage.qml — the Control Centre's "Rices" page (this fork).
//
// Left: the saved rices (git branches of this repo: main and rice/NAME, through the
// `rice` command), with a button to switch and a field to save the current
// look under a new name. Right: what belongs to THIS rice beyond the files in
// the repo: the icon theme of the niri session, folders in the wallpaper's
// accent, and the login screen layout. They are stored in
// ~/.config/quickshell-rice.json, which `rice` saves and restores per rice.
//
// Switching restarts the shell (rice usar kills qs and starts it again), so it
// runs detached: the command has to outlive the panel that launched it.
import Quickshell
import Quickshell.Io
import QtQuick
import QtQuick.Layouts

RowLayout {
    id: page
    spacing: 14

    readonly property string riceBin: Quickshell.env("HOME") + "/.local/bin/rice"
    property var rices: []               // [{name, current, when}]
    property var iconThemes: []          // installed icon theme folder names
    property string busy: ""             // "" | message while a command runs
    readonly property bool loginOk: loginProbe.ok

    function refresh() { listProc.running = false; listProc.running = true; }
    function quando(ts) {
        const s = Math.max(0, Date.now() / 1000 - ts);
        if (s < 60) return "agora";
        if (s < 3600) return "há " + Math.floor(s / 60) + " min";
        if (s < 86400) return "há " + Math.floor(s / 3600) + " h";
        const d = Math.floor(s / 86400);
        return d === 1 ? "ontem" : "há " + d + " dias";
    }
    readonly property string current: {
        for (const r of page.rices) if (r.current) return r.name;
        return "";
    }

    Component.onCompleted: { refresh(); themesProc.running = true; loginProbe.running = true; }
    onVisibleChanged: if (visible) refresh()

    Process {
        id: listProc
        command: [page.riceBin, "tsv"]
        stdout: StdioCollector {
            onStreamFinished: {
                const out = [];
                for (const line of text.split("\n")) {
                    const f = line.split("\t");
                    if (f.length >= 3 && f[0] !== "") out.push({ name: f[0], current: f[1] === "1", when: parseInt(f[2]) });
                }
                page.rices = out;
            }
        }
    }
    // Icon themes: folders with an index.theme that has icon directories
    // (cursor-only themes have none). The generated ones are left out.
    Process {
        id: themesProc
        command: ["sh", "-c", 'for d in "$HOME/.local/share/icons" "$HOME/.icons" /usr/share/icons; do for t in "$d"/*/index.theme; do [ -f "$t" ] && grep -q "^Directories=" "$t" && basename "$(dirname "$t")"; done; done 2>/dev/null | grep -v -e "^pywal-" -e "^hicolor$" -e "^locolor$" -e "^default$" -e "^AdwaitaLegacy$" | sort -u']
        stdout: StdioCollector { onStreamFinished: page.iconThemes = text.split("\n").filter(s => s !== "") }
    }
    Process {
        id: loginProbe
        property bool ok: false
        command: ["test", "-w", "/usr/share/sddm/themes/thyx/metadata.desktop"]
        onExited: function (code) { ok = code === 0; }
    }
    Process {
        id: saveProc
        onExited: { page.busy = ""; page.refresh(); }
    }
    function salvar(nome) {
        if (!/^[a-z0-9][a-z0-9._-]*$/.test(nome)) { nomeErr.visible = true; return; }
        nomeErr.visible = false;
        page.busy = "Salvando " + nome + "…";
        saveProc.command = [page.riceBin, "salvar", nome];
        saveProc.running = true;
    }
    function usar(nome) {
        page.busy = "Trocando para " + nome + "…";
        Quickshell.execDetached([page.riceBin, "usar", nome]);
    }

    component Pill: Rectangle {
        id: pl
        property string text: ""
        property bool on: false
        property bool enabled_: true
        signal chosen()
        implicitHeight: 30
        implicitWidth: plT.implicitWidth + 26
        radius: 15
        opacity: pl.enabled_ ? 1 : 0.45
        color: pl.on ? Qt.rgba(Colors.accent.r, Colors.accent.g, Colors.accent.b, 0.85) : (plMa.containsMouse ? Colors.fill2 : Colors.fill3)
        Behavior on color { ColorAnimation { duration: Appearance.mQuick } }
        // On the accent: black or white by its lightness (same rule as the Cores page).
        readonly property bool lightAccent: (0.2126 * Colors.accent.r + 0.7152 * Colors.accent.g + 0.0722 * Colors.accent.b) > 0.45
        Text { id: plT; anchors.centerIn: parent; text: pl.text; color: pl.on ? (pl.lightAccent ? "#111111" : "#ffffff") : Colors.label
               font.family: Appearance.fontUI; font.pixelSize: Appearance.fsXS; font.weight: Font.DemiBold }
        MouseArea { id: plMa; anchors.fill: parent; hoverEnabled: true; enabled: pl.enabled_
                    cursorShape: Qt.PointingHandCursor; onClicked: pl.chosen() }
    }
    component Heading: Text {
        color: Colors.label2
        font.family: Appearance.fontUI; font.pixelSize: Appearance.fsS; font.weight: Font.DemiBold
    }

    // ═════════ left: the saved rices ═════════
    ColumnLayout {
        Layout.preferredWidth: 330
        Layout.fillHeight: true
        spacing: 8

        RowLayout {
            Heading { text: "Rices salvos" }
            Item { Layout.fillWidth: true }
            Text {
                text: page.busy
                visible: page.busy !== ""
                color: Colors.accent
                font.family: Appearance.fontUI; font.pixelSize: Appearance.fsXS
            }
        }

        ListView {
            id: list
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            spacing: 6
            model: page.rices
            delegate: Rectangle {
                required property var modelData
                width: list.width
                height: 48
                radius: 14
                color: modelData.current ? Qt.rgba(Colors.accent.r, Colors.accent.g, Colors.accent.b, 0.16) : Colors.fill3
                border.width: modelData.current ? 1 : 0
                border.color: Colors.accent
                ColumnLayout {
                    anchors { left: parent.left; leftMargin: 14; verticalCenter: parent.verticalCenter }
                    spacing: 1
                    Text { text: modelData.name; color: Colors.label
                           font.family: Appearance.fontUI; font.pixelSize: Appearance.fsS; font.weight: Font.DemiBold }
                    Text { text: (modelData.current ? "em uso · " : "") + "salvo " + page.quando(modelData.when)
                           color: Colors.label3; font.family: Appearance.fontUI; font.pixelSize: Appearance.fsXXS }
                }
                Pill {
                    anchors { right: parent.right; rightMargin: 10; verticalCenter: parent.verticalCenter }
                    text: modelData.current ? "Salvar" : "Usar"
                    on: !modelData.current
                    enabled_: page.busy === ""
                    onChosen: modelData.current ? page.salvar(modelData.name) : page.usar(modelData.name)
                }
            }
            Text {
                anchors.centerIn: parent
                visible: page.rices.length === 0
                text: "Nenhum rice salvo ainda"
                color: Colors.label3
                font.family: Appearance.fontUI; font.pixelSize: Appearance.fsXS
            }
        }

        // save the current look under a new name
        RowLayout {
            spacing: 8
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 32
                radius: 16
                color: Colors.fill3
                border.width: 1
                border.color: nome.activeFocus ? Colors.accent : Colors.hairline
                TextInput {
                    id: nome
                    anchors.fill: parent; anchors.leftMargin: 14; anchors.rightMargin: 12
                    verticalAlignment: TextInput.AlignVCenter
                    color: Colors.fg
                    font.family: Appearance.fontUI; font.pixelSize: Appearance.fsXS
                    maximumLength: 32
                    selectByMouse: true
                    onTextEdited: text = text.toLowerCase().replace(/ /g, "-")
                    onAccepted: if (text !== "") { page.salvar(text); text = ""; }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        visible: nome.text === "" && !nome.activeFocus
                        text: "nome do novo rice"
                        color: Colors.label3
                        font: nome.font
                    }
                }
            }
            Pill {
                text: "Salvar como novo"
                enabled_: page.busy === "" && nome.text !== ""
                onChosen: { page.salvar(nome.text); nome.text = ""; }
            }
        }
        Text {
            id: nomeErr
            visible: false
            text: "Use letras minúsculas, números, - _ ."
            color: Colors.crit
            font.family: Appearance.fontUI; font.pixelSize: Appearance.fsXXS
        }
    }

    Rectangle { Layout.fillHeight: true; width: 1; color: Colors.hairline }

    // ═════════ right: what this rice carries besides the repo ═════════
    ColumnLayout {
        Layout.fillWidth: true
        Layout.fillHeight: true
        spacing: 10

        Heading { text: "Neste rice" + (page.current !== "" ? " (" + page.current + ")" : "") }

        Text { text: "Ícones"; color: Colors.label3; font.family: Appearance.fontUI; font.pixelSize: Appearance.fsXS }
        Flickable {
            Layout.fillWidth: true
            Layout.preferredHeight: Math.min(icFlow.implicitHeight, 108)
            contentHeight: icFlow.implicitHeight
            clip: true
            Flow {
                id: icFlow
                width: parent.width
                spacing: 6
                Pill { text: "Do GNOME"; on: Config.iconTheme === ""; onChosen: { Config.iconTheme = ""; Config.applyIcons(); } }
                Repeater {
                    model: page.iconThemes
                    Pill {
                        required property string modelData
                        text: modelData
                        on: Config.iconTheme === modelData
                        onChosen: { Config.iconTheme = modelData; Config.applyIcons(); }
                    }
                }
            }
        }

        RowLayout {
            spacing: 8
            Text { text: "Pastas na cor do tema"; color: Colors.label3; Layout.fillWidth: true
                   font.family: Appearance.fontUI; font.pixelSize: Appearance.fsXS }
            Pill { text: "Sim"; on: Config.tintFolders; onChosen: { Config.tintFolders = true; Config.applyIcons(); } }
            Pill { text: "Não"; on: !Config.tintFolders; onChosen: { Config.tintFolders = false; Config.applyIcons(); } }
        }

        RowLayout {
            spacing: 8
            Text { text: "Tela de login"; color: Colors.label3; Layout.fillWidth: true
                   font.family: Appearance.fontUI; font.pixelSize: Appearance.fsXS }
            Pill { text: "Pocket"; enabled_: page.loginOk; on: Config.loginLayout === "pocket"
                   onChosen: { Config.loginLayout = "pocket"; Config.applyLogin(); } }
            Pill { text: "thyx"; enabled_: page.loginOk; on: Config.loginLayout === "thyx"
                   onChosen: { Config.loginLayout = "thyx"; Config.applyLogin(); } }
        }

        Item { Layout.fillHeight: true }
        Text {
            Layout.fillWidth: true
            wrapMode: Text.WordWrap
            text: (page.loginOk ? "" : "Tela de login: o tema thyx do SDDM não está instalado. ")
                + "Cada rice guarda o visual inteiro: shell, cores, wallpaper, ícones e login. "
                + "Trocar salva antes as mudanças do rice em uso. Os ícones valem para as janelas abertas depois; o login, no próximo login."
            color: Colors.label3
            font.family: Appearance.fontUI; font.pixelSize: Appearance.fsXXS
        }
    }
}
