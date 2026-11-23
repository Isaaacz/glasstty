// SettingsAppearance.qml — what until now you had to change by editing QML.
// Everything writes into Config.qml and is saved on its own to
// ~/.config/quickshell-rice.json; the bar and the notch react live while you
// move the sliders.
//
// The descriptions are NOT painted here: they go in `hint` and the window shows
// them in the footer strip when you hover over them (see SettingsControls.qml).
// Nor is the "Restablecer" (Reset) button: the window's fixed header paints it
// from `actionText`.
import Quickshell
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Effects

Flickable {
    id: root
    property string tab: "notch"

    // Settings > Appearance > Lock > Style: each preset sets a group of the lock
    // options at once (through the draft, so it shows live and is kept on Apply).
    readonly property var lockPresets: ({
        glasstty: { lockClockPos: "left", lockClockY: -1, lockClockSize: 100, lockClockWeight: "black", lockClockFont: "", lockDateFmt: "full", lockSide: "", lockFormY: -1, lockFieldStyle: "line", lockCard: false, lockAvatar: false, lockShowName: true, lockPanel: false, lockDatePill: false },
        central: { lockClockPos: "center", lockClockY: 22, lockClockSize: 130, lockClockWeight: "light", lockClockFont: "Inter Display", lockDateFmt: "full", lockSide: "center", lockFormY: 16, lockFieldStyle: "box", lockCard: false, lockAvatar: true, lockShowName: true, lockPanel: false, lockDatePill: false },
        minimal: { lockClockPos: "center", lockClockY: 8, lockClockSize: 55, lockClockWeight: "regular", lockClockFont: "JetBrains Mono", lockDateFmt: "short", lockSide: "center", lockFormY: 10, lockFieldStyle: "line", lockCard: false, lockAvatar: false, lockShowName: false, lockPanel: false, lockDatePill: false },
        cartao: { lockClockPos: "center", lockClockY: 10, lockClockSize: 90, lockClockWeight: "bold", lockClockFont: "Montserrat", lockDateFmt: "full", lockSide: "center", lockFormY: 24, lockFieldStyle: "box", lockCard: true, lockAvatar: true, lockShowName: true, lockPanel: false, lockDatePill: false },
        gigante: { lockClockPos: "center", lockClockY: 20, lockClockSize: 150, lockClockWeight: "black", lockClockFont: "Montserrat", lockDateFmt: "full", lockSide: "right", lockFormY: 9, lockFieldStyle: "line", lockCard: false, lockAvatar: false, lockShowName: true, lockPanel: false, lockDatePill: false },
        lateral: { lockClockPos: "left", lockClockY: 22, lockClockSize: 110, lockClockWeight: "light", lockClockFont: "Latin Modern Roman", lockDateFmt: "full", lockSide: "left", lockFormY: 22, lockFieldStyle: "box", lockCard: true, lockAvatar: true, lockShowName: true, lockPanel: false, lockDatePill: false },
        rodape: { lockClockPos: "left", lockClockY: 64, lockClockSize: 80, lockClockWeight: "bold", lockClockFont: "Iosevka", lockDateFmt: "short", lockSide: "right", lockFormY: 9, lockFieldStyle: "line", lockCard: false, lockAvatar: false, lockShowName: true, lockPanel: false, lockDatePill: false },
        dividido: { lockClockPos: "left", lockClockY: 36, lockClockSize: 140, lockClockWeight: "regular", lockClockFont: "Inter Display", lockDateFmt: "full", lockSide: "right", lockFormY: 38, lockFieldStyle: "box", lockCard: false, lockAvatar: true, lockShowName: true, lockPanel: false, lockDatePill: true },
        painel: { lockClockPos: "left", lockClockY: 30, lockClockSize: 80, lockClockWeight: "bold", lockClockFont: "Comfortaa", lockDateFmt: "full", lockSide: "left", lockFormY: 34, lockFieldStyle: "box", lockCard: false, lockAvatar: false, lockShowName: true, lockPanel: true, lockDatePill: true },
        inverno: { lockClockPos: "center", lockClockY: 11, lockClockSize: 120, lockClockWeight: "light", lockClockFont: "", lockDateFmt: "full", lockSide: "center", lockFormY: 38, lockFieldStyle: "box", lockCard: true, lockAvatar: true, lockShowName: true, lockPanel: false, lockDatePill: false },
        direita: { lockClockPos: "right", lockClockY: 28, lockClockSize: 110, lockClockWeight: "bold", lockClockFont: "Montserrat", lockDateFmt: "full", lockSide: "right", lockFormY: 30, lockFieldStyle: "line", lockCard: false, lockAvatar: false, lockShowName: true, lockPanel: false, lockDatePill: false },
        perfil: { lockClockPos: "center", lockClockY: 5, lockClockSize: 50, lockClockWeight: "regular", lockClockFont: "", lockDateFmt: "short", lockSide: "center", lockFormY: 36, lockFieldStyle: "box", lockCard: false, lockAvatar: true, lockShowName: true, lockPanel: false, lockDatePill: false }
    })
    readonly property var lockPresetList: [{ id: "glasstty", label: I18n.tr("glasstty") }, { id: "central", label: I18n.tr("Central") }, { id: "minimal", label: I18n.tr("Minimalista") }, { id: "cartao", label: I18n.tr("Tarjeta") }, { id: "gigante", label: I18n.tr("Reloj gigante") }, { id: "lateral", label: I18n.tr("Lateral") }, { id: "rodape", label: I18n.tr("Pie de página") }, { id: "dividido", label: I18n.tr("Dividido") }, { id: "painel", label: I18n.tr("Panel") }, { id: "inverno", label: I18n.tr("Invierno") }, { id: "direita", label: I18n.tr("A la derecha") }, { id: "perfil", label: I18n.tr("Perfil") }]
    function lockPreset(id) {
        const p = root.lockPresets[id];
        if (!p) return;
        for (const k in p) {
            let v = p[k];
            // a font this machine does not have falls back to the login's
            if (k === "lockClockFont" && v !== "" && Config.lockFonts.indexOf(v) < 0) v = "";
            AppearanceDraft.set(k, v);
        }
        AppearanceDraft.set("lockPreset", id);
    }
    readonly property bool searching: ShellState.settingsQuery.trim().length > 0

    // contract with SettingsWindow: header button and default footer text
    property string actionText: I18n.tr("Restablecer")
    property bool actionDanger: true
    property bool actionConfirm: true
    property string note: I18n.tr("Se guarda solo en ~/.config/quickshell-rice.json")
    readonly property int matchCount: cLang.visibleRows + cNotch.visibleRows
        + cBehav.visibleRows + cBar.visibleRows + cFont.visibleRows + cFx.visibleRows
        + cWall.visibleRows + cColors.visibleRows
    signal actionRun
    onActionRun: AppearanceDraft.restoreDefaults()

    // A colour swatch for the Cores card.
    component Swatch: Rectangle {
        id: sw
        property color swatch: "#000000"
        property bool selected: false
        property string caption: ""
        signal chosen()
        width: 26; height: 26; radius: 13
        color: sw.swatch
        border.width: sw.selected ? 2 : 1
        border.color: sw.selected ? Colors.fg : Colors.hairline
        scale: swMa.containsMouse ? 1.12 : 1
        Behavior on scale { NumberAnimation { duration: Appearance.mQuick } }
        Text {
            anchors.centerIn: parent
            visible: sw.caption !== ""
            text: sw.caption
            color: Colors.label2
            font.pixelSize: 11
        }
        MouseArea {
            id: swMa
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: sw.chosen()
        }
    }


    contentHeight: col.implicitHeight + 34
    clip: true
    boundsBehavior: Flickable.StopAtBounds
    ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded; width: 5 }
    // coming back to a section with the scroll halfway down is disorienting
    onVisibleChanged: if (visible) contentY = 0

    ColumnLayout {
        id: col
        width: root.width - 48
        x: 24
        y: 16
        spacing: 10

        SettingsBarPreview {
            Layout.fillWidth: true
            Layout.preferredHeight: 112
            visible: !root.searching && (root.tab === "notch" || root.tab === "bar")
        }

        // ─────────────────── language ───────────────────
        // It comes first because it is the only thing on this page that changes the
        // rest of the page. The two labels are each in their own language on purpose:
        // if you open the shell in a language you cannot read, "English" is
        // recognisable.
        SettingsControls.Card_ {
            id: cLang
            visible: visibleRows > 0 && (root.searching || root.tab === "type")
            title: I18n.tr("Idioma")

            SettingsControls.Row_ {
                label: I18n.tr("Idioma del shell")
                hint: I18n.tr("Cambia la barra, el notch, los paneles y esta ventana. No toca el idioma del sistema ni el de las aplicaciones: es solo el shell. El cambio es inmediato, no hay que reiniciar nada.")
                SettingsControls.Choice_ {
                    options: I18n.labels
                    current: I18n.labelFor(Config.language)
                    onPicked: function (v) { Config.language = I18n.codeFor(v); Config.save(); }
                }
            }
        }

        // ─────────────────── colours (this fork) ───────────────────
        // "Do wallpaper": pywal decides, as always. "Manual": the accent (and,
        // if chosen, the background) replace pywal's, and pywal regenerates
        // every template with them: shell, niri borders, login and lock
        // screen, GTK apps, terminal. palette-override.py does the swap.
        SettingsControls.Card_ {
            id: cColors
            visible: visibleRows > 0 && (root.searching || root.tab === "colors")
            title: "Cores"

            SettingsControls.Row_ {
                label: "Origem das cores"
                hint: "Do wallpaper: as cores saem da imagem (pywal), como sempre. Manual: você escolhe a cor de destaque e, se quiser, o fundo, e elas passam a valer para o desktop inteiro (barra, notch, bordas das janelas, tela de login e de bloqueio, apps GTK e terminal), em qualquer wallpaper."
                SettingsControls.Choice_ {
                    options: ["Do wallpaper", "Manual"]
                    current: AppearanceDraft.v.colorMode === "manual" ? "Manual" : "Do wallpaper"
                    onPicked: function (v) {
                        AppearanceDraft.set("colorMode", (v === "Manual") ? "manual" : "wallpaper");
                       
                    }
                }
            }

            SettingsControls.Row_ {
                label: "Cor de destaque"
                hint: "Botões, seleção, a pílula das áreas de trabalho, as bordas das janelas, o botão de entrar no login. Clique numa amostra ou digite um código (#rrggbb) e Enter."
                shown: AppearanceDraft.v.colorMode === "manual" || root.searching
                ColumnLayout {
                    Layout.preferredWidth: 270
                    spacing: 8
                    Flow {
                        Layout.fillWidth: true
                        spacing: 7
                        Repeater {
                            model: ["#5e81ac", "#3b82f6", "#06b6d4", "#14b8a6", "#22c55e", "#84cc16",
                                    "#eab308", "#f97316", "#ef4444", "#ec4899", "#a855f7", "#8b5cf6"]
                            Swatch {
                                required property string modelData
                                swatch: modelData
                                selected: AppearanceDraft.v.manualAccent.toLowerCase() === modelData
                                onChosen: { AppearanceDraft.set("manualAccent", modelData); AppearanceDraft.set("colorMode", "manual"); }
                            }
                        }
                    }
                    Rectangle {
                        Layout.preferredWidth: 130
                        Layout.preferredHeight: 28
                        radius: 8
                        color: Colors.fill3
                        border.width: 1
                        border.color: hexIn.activeFocus ? Colors.accent : Colors.hairline
                        Rectangle {
                            x: 6; anchors.verticalCenter: parent.verticalCenter
                            width: 16; height: 16; radius: 8
                            color: /^#[0-9a-fA-F]{6}$/.test(hexIn.text) ? hexIn.text : AppearanceDraft.v.manualAccent
                        }
                        TextInput {
                            id: hexIn
                            anchors.fill: parent
                            anchors.leftMargin: 28; anchors.rightMargin: 8
                            verticalAlignment: TextInput.AlignVCenter
                            text: AppearanceDraft.v.manualAccent
                            color: Colors.fg
                            font.family: Appearance.font
                            font.pixelSize: 12
                            maximumLength: 7
                            selectByMouse: true
                            onAccepted: {
                                let v = text.trim();
                                if (!v.startsWith("#")) v = "#" + v;
                                if (!/^#[0-9a-fA-F]{6}$/.test(v)) { text = AppearanceDraft.v.manualAccent; return; }
                                AppearanceDraft.set("manualAccent", v.toLowerCase());
                                AppearanceDraft.set("colorMode", "manual");
                               
                            }
                        }
                    }
                }
            }

            SettingsControls.Row_ {
                label: "Fundo"
                hint: "O tom dos painéis, do notch no modo tema, dos apps e do terminal. 'W' mantém o fundo que vem do wallpaper."
                shown: AppearanceDraft.v.colorMode === "manual" || root.searching
                Flow {
                    Layout.preferredWidth: 270
                    spacing: 7
                    Repeater {
                        // "" = keep the wallpaper's background.
                        model: ["", "#0b0b0d", "#16171b", "#1e2128", "#0f1724", "#131a14", "#1d1216", "#241a12", "#eceff4"]
                        Swatch {
                            required property string modelData
                            swatch: modelData === "" ? Colors.bg : modelData
                            caption: modelData === "" ? "W" : ""
                            selected: AppearanceDraft.v.manualBg.toLowerCase() === modelData
                            onChosen: { AppearanceDraft.set("manualBg", modelData); AppearanceDraft.set("colorMode", "manual"); }
                        }
                    }
                }
            }
        }

        // ─────────────────── notch shape ───────────────────
        SettingsControls.Card_ {
            id: cNotch
            visible: visibleRows > 0 && (root.searching || root.tab === "notch")
            title: I18n.tr("Notch")

            SettingsControls.Row_ {
                label: I18n.tr("Estilo")
                hint: I18n.tr("Notch: pegado al borde con las esquinas invertidas del MacBook. Isla: píldora flotante, redonda por los cuatro lados, como el Dynamic Island.")
                RowLayout {
                    Layout.preferredWidth: 270
                    spacing: 8
                    Repeater {
                        model: ["notch", "island"]
                        SettingsPreviewTile {
                            required property string modelData
                            caption: modelData === "notch" ? "Notch" : I18n.tr("Isla")
                            selected: AppearanceDraft.v.notchStyle === modelData
                            onPicked: AppearanceDraft.set("notchStyle", modelData)
                            SettingsBarPreview {
                                anchors.fill: parent
                                attached: modelData === "notch"
                                compact: true
                            }
                        }
                    }
                }
            }

            SettingsControls.Row_ {
                label: I18n.tr("Color")
                hint: I18n.tr("El negro puro es el que imita al MacBook; el del tema sigue a pywal.")
                SettingsControls.Choice_ {
                    options: [I18n.tr("Negro"), I18n.tr("Tema")]
                    current: AppearanceDraft.v.notchColor.toString().toLowerCase() === "#000000" ? I18n.tr("Negro") : I18n.tr("Tema")
                    // The INTENTION is saved, not today's hex. This used to
                    // write Colors.bg.toString() and the notch kept the colour
                    // of the old palette as soon as you changed wallpaper, with
                    // Settings showing «Tema» (Theme) all the same. See
                    // Colors.notchTint().
                    onPicked: function (v) { AppearanceDraft.set("notchColor", (v === I18n.tr("Negro") ? "#000000" : Colors.notchTheme)); }
                }
            }

            SettingsControls.Row_ {
                label: I18n.tr("Alto de la banda")
                hint: I18n.tr("También es el alto del notch en reposo, y el espacio que se reserva arriba.")
                SettingsControls.Slider_ {
                    value: AppearanceDraft.v.bandH; from: 24; to: 48; suffix: " px"
                    onMoved: function (v) { AppearanceDraft.set("bandH", Math.round(v)); }
                }
            }

            SettingsControls.Row_ {
                label: I18n.tr("Ancho en reposo")
                hint: I18n.tr("Para la hora sola. Si enciendes la fecha o la batería, el notch se ensancha solo.")
                SettingsControls.Slider_ {
                    value: AppearanceDraft.v.idleW; from: 110; to: 380; suffix: " px"
                    onMoved: function (v) { AppearanceDraft.set("idleW", Math.round(v)); }
                }
            }

            SettingsControls.Row_ {
                shown: AppearanceDraft.v.notchStyle === "island"
                label: I18n.tr("Separación del borde")
                hint: I18n.tr("Cuánto se despega la isla del borde de la pantalla. Sale de la banda reservada, así que no tapa nada.")
                SettingsControls.Slider_ {
                    value: AppearanceDraft.v.islandGap; from: 0; to: 14; suffix: " px"
                    onMoved: function (v) { AppearanceDraft.set("islandGap", Math.round(v)); }
                }
            }

            SettingsControls.Row_ {
                shown: AppearanceDraft.v.notchStyle !== "island"
                label: I18n.tr("Esquina invertida")
                hint: I18n.tr("El vuelo cóncavo con el que el notch se une al borde de la pantalla.")
                SettingsControls.Slider_ {
                    value: AppearanceDraft.v.flare; from: 0; to: 22; suffix: " px"
                    onMoved: function (v) { AppearanceDraft.set("flare", Math.round(v)); }
                }
            }

            SettingsControls.Row_ {
                label: AppearanceDraft.v.notchStyle === "island" ? I18n.tr("Redondeo") : I18n.tr("Redondeo inferior")
                hint: I18n.tr("Cuánto se redondean las esquinas del notch cuando está desplegado.")
                SettingsControls.Slider_ {
                    value: AppearanceDraft.v.roundMax; from: 8; to: 40; suffix: " px"
                    onMoved: function (v) { AppearanceDraft.set("roundMax", Math.round(v)); }
                }
            }
        }

        // ─────────────────── what it shows and when ───────────────────
        SettingsControls.Card_ {
            id: cBehav
            visible: visibleRows > 0 && (root.searching || root.tab === "notch")
            title: I18n.tr("Comportamiento")

            SettingsControls.Row_ {
                label: I18n.tr("Vista al pasar el ratón")
                hint: I18n.tr("Desactívala para abrir el notch solo al hacer clic. Los avisos y los atajos siguen funcionando.")
                SettingsControls.Switch_ {
                    checked: AppearanceDraft.v.hoverPreview
                    onToggled: function (v) { AppearanceDraft.set("hoverPreview", v); }
                }
            }
            SettingsControls.Row_ {
                shown: AppearanceDraft.v.hoverPreview
                label: I18n.tr("Retardo del hover")
                hint: I18n.tr("Cuánto hay que quedarse encima antes de que se despliegue. A 0 se abre al cruzar el ratón.")
                SettingsControls.Slider_ {
                    value: AppearanceDraft.v.hoverDelay; from: 0; to: 900; suffix: " ms"
                    onMoved: function (v) { AppearanceDraft.set("hoverDelay", Math.round(v)); }
                }
            }

            SettingsControls.Row_ {
                label: I18n.tr("Fecha en reposo")
                hint: I18n.tr("En reposo el notch enseña solo la hora. Con esto añade también la fecha, y se ensancha solo para que quepa.")
                SettingsControls.Switch_ {
                    checked: AppearanceDraft.v.showDate
                    onToggled: function (v) { AppearanceDraft.set("showDate", v); }
                }
            }

            SettingsControls.Row_ {
                label: I18n.tr("Batería en el notch")
                hint: I18n.tr("La batería sale siempre al pasar el ratón; esto la deja fija también en reposo.")
                SettingsControls.Switch_ {
                    checked: AppearanceDraft.v.showBattery
                    onToggled: function (v) { AppearanceDraft.set("showBattery", v); }
                }
            }

            // It goes after the date and the battery on purpose: they are the two things
            // the music face hides, so the setting that decides when that face appears
            // sits right next to what it pushes out of the way.
            SettingsControls.Row_ {
                label: I18n.tr("Música del navegador")
                hint: I18n.tr("Apagado, el notch solo cambia de cara con reproductores de música: un vídeo del navegador ya no lo ensancha ni esconde la fecha y la batería. Sigue saliendo en el panel de música, así que puedes pausarlo desde ahí igual.")
                SettingsControls.Switch_ {
                    checked: AppearanceDraft.v.browserMedia
                    onToggled: function (v) { AppearanceDraft.set("browserMedia", v); }
                }
            }

            SettingsControls.Row_ {
                label: I18n.tr("Reservar espacio")
                hint: I18n.tr("Si lo apagas, las ventanas suben hasta el borde y el notch queda por encima.")
                SettingsControls.Switch_ {
                    checked: AppearanceDraft.v.reserveSpace
                    onToggled: function (v) { AppearanceDraft.set("reserveSpace", v); }
                }
            }
        }

        // ─────────────────── bar ───────────────────
        SettingsControls.Card_ {
            id: cBar
            visible: visibleRows > 0 && (root.searching || root.tab === "bar")
            title: I18n.tr("Barra")

            SettingsControls.Row_ {
                label: I18n.tr("Velo de fondo")
                hint: I18n.tr("A 0 la barra es del todo transparente. Súbelo si con fondos claros no lees los glifos.")
                SettingsControls.Slider_ {
                    value: AppearanceDraft.v.scrimAlpha; from: 0; to: 0.7; decimals: 2
                    onMoved: function (v) { AppearanceDraft.set("scrimAlpha", v); }
                }
            }

            SettingsControls.Row_ {
                label: I18n.tr("Margen lateral")
                hint: I18n.tr("Cuánto se separan del borde de la pantalla las islas de los extremos.")
                SettingsControls.Slider_ {
                    value: AppearanceDraft.v.sideMargin; from: 4; to: 48; suffix: " px"
                    onMoved: function (v) { AppearanceDraft.set("sideMargin", Math.round(v)); }
                }
            }

            SettingsControls.Row_ {
                label: I18n.tr("Logo de Arch")
                hint: I18n.tr("El glifo de Arch en el extremo izquierdo de la barra.")
                SettingsControls.Switch_ { checked: AppearanceDraft.v.showArch; onToggled: function (v) { AppearanceDraft.set("showArch", v); } }
            }
            SettingsControls.Row_ {
                label: I18n.tr("Workspaces")
                hint: I18n.tr("Los puntos de escritorio, con el activo alargado.")
                SettingsControls.Switch_ { checked: AppearanceDraft.v.showWorkspaces; onToggled: function (v) { AppearanceDraft.set("showWorkspaces", v); } }
            }
            SettingsControls.Row_ {
                label: I18n.tr("Organizador visual")
                hint: I18n.tr("Muestra miniaturas de tus escritorios al acercar el cursor al borde izquierdo.")
                SettingsControls.Switch_ { checked: AppearanceDraft.v.stageEnabled; onToggled: function (v) { AppearanceDraft.set("stageEnabled", v); } }
            }
            SettingsControls.Row_ {
                label: I18n.tr("Nombre de la app")
                hint: I18n.tr("El nombre de la ventana que tienes enfocada.")
                SettingsControls.Switch_ { checked: AppearanceDraft.v.showAppName; onToggled: function (v) { AppearanceDraft.set("showAppName", v); } }
            }
            SettingsControls.Row_ {
                label: I18n.tr("Bandeja del sistema")
                hint: I18n.tr("Los iconos que publican las apps: nm-applet, rustdesk, etc.")
                SettingsControls.Switch_ { checked: AppearanceDraft.v.showTray; onToggled: function (v) { AppearanceDraft.set("showTray", v); } }
            }
        }

        // ─────────────────── typography ───────────────────
        SettingsControls.Card_ {
            id: cFont
            visible: visibleRows > 0 && (root.searching || root.tab === "type")
            title: I18n.tr("Tipografía")

            SettingsControls.Row_ {
                label: I18n.tr("Fuente del notch")
                hint: I18n.tr("Proporcional, solo para el texto de dentro del notch. Los iconos van siempre en la Nerd Font.")
                SettingsControls.Choice_ {
                    options: Config.fontChoices
                    current: AppearanceDraft.v.fontUI
                    onPicked: function (v) { AppearanceDraft.set("fontUI", v); }
                }
            }

            SettingsControls.Row_ {
                label: I18n.tr("Tamaño de la hora")
                hint: I18n.tr("El reloj del notch en reposo.")
                SettingsControls.Slider_ {
                    // THE SLIDER SHOWS THE SIZE THE CLOCK USES, NOT THE ONE
                    // YOU DRAG.
                    //
                    // It had thirteen positions and the clock only knew two: with
                    // the Game Boy font on, Appearance.clockPixelSize() quantises to
                    // multiples of 8 (and rightly so, see Appearance.qml:24-38),
                    // so 12-19 were all painted at 16 and 20-24 at 24. You moved
                    // the number from 12 to 24, the preview grew smoothly and the
                    // notch clock did not budge. Right now it is at 17 and is
                    // painted at 16.
                    //
                    // The clock is not quantised: it is quantised HERE, which is
                    // where the lie was. And the minimum comes from Appearance, so
                    // if fontClock goes back to being the interface font this
                    // turns back into a continuous slider by itself.
                    value: Appearance.clockPixelSize(AppearanceDraft.v.clockSize)
                    from: Appearance.clockQuantum > 1 ? 16 : 12
                    to: 24
                    stepSize: Appearance.clockQuantum
                    suffix: " px"
                    onMoved: function (v) { AppearanceDraft.set("clockSize", Appearance.clockPixelSize(v)); }
                }
            }
        }

        // ─────────────────── compositor effects ───────────────────
        // The only card on the page that does not govern something the shell paints:
        // this belongs to niri. That is why the settings also go out to
        // ~/.config/niri/efeitos*.kdl and not only to the JSON the footer announces;
        // the how is in Config.applyEffects().
        SettingsControls.Card_ {
            id: cFx
            visible: visibleRows > 0 && (root.searching || root.tab === "effects")
            title: I18n.tr("Efectos")

            SettingsControls.Row_ {
                label: I18n.tr("Esquinas de las ventanas")
                hint: I18n.tr("Cuánto se redondean las esquinas de las ventanas. A 0 salen cuadradas.")
                SettingsControls.Slider_ {
                    value: AppearanceDraft.v.windowRounding
                    from: 0; to: 24
                    stepSize: 1
                    suffix: " px"
                    onMoved: function (v) { AppearanceDraft.set("windowRounding", Math.round(v)); }
                }
            }

            SettingsControls.Row_ {
                label: I18n.tr("Transparencia de las ventanas")
                hint: I18n.tr("Cuánto se ve el fondo a través de la ventana con el foco. Al 100 % son opacas.")
                SettingsControls.Slider_ {
                    value: AppearanceDraft.v.winOpacity; from: 50; to: 100; stepSize: 1; suffix: " %"
                    onMoved: function (v) { AppearanceDraft.set("winOpacity", Math.round(v)); }
                }
            }

            SettingsControls.Row_ {
                label: I18n.tr("Ventanas sin foco")
                hint: I18n.tr("Las ventanas que no están en uso, un paso más transparentes. Igual a la de arriba para no distinguirlas.")
                SettingsControls.Slider_ {
                    value: AppearanceDraft.v.winOpacityInactive; from: 50; to: 100; stepSize: 1; suffix: " %"
                    onMoved: function (v) { AppearanceDraft.set("winOpacityInactive", Math.round(v)); }
                }
            }

            SettingsControls.Row_ {
                label: I18n.tr("Terminal")
                hint: I18n.tr("La terminal tiene su propia transparencia, con o sin foco.")
                SettingsControls.Slider_ {
                    value: AppearanceDraft.v.termOpacity; from: 50; to: 100; stepSize: 1; suffix: " %"
                    onMoved: function (v) { AppearanceDraft.set("termOpacity", Math.round(v)); }
                }
            }

            SettingsControls.Row_ {
                label: I18n.tr("Vidrio esmerilado")
                hint: I18n.tr("Desenfoca lo que hay detrás de las ventanas transparentes. Apagado se ve el fondo nítido y gasta menos.")
                SettingsControls.Switch_ {
                    checked: AppearanceDraft.v.winBlur
                    onToggled: function (v) { AppearanceDraft.set("winBlur", v); }
                }
            }

            SettingsControls.Row_ {
                label: I18n.tr("Espacio entre ventanas")
                hint: I18n.tr("El hueco entre ventanas y hasta el borde de la pantalla.")
                SettingsControls.Slider_ {
                    value: AppearanceDraft.v.winGaps; from: 0; to: 32; stepSize: 1; suffix: " px"
                    onMoved: function (v) { AppearanceDraft.set("winGaps", Math.round(v)); }
                }
            }

            SettingsControls.Row_ {
                label: I18n.tr("Borde")
                hint: I18n.tr("El grosor del borde con los colores del fondo. A 0 no hay borde.")
                SettingsControls.Slider_ {
                    value: AppearanceDraft.v.borderWidth; from: 0; to: 6; stepSize: 1; suffix: " px"
                    onMoved: function (v) { AppearanceDraft.set("borderWidth", Math.round(v)); }
                }
            }

            SettingsControls.Row_ {
                label: I18n.tr("Sombra")
                hint: I18n.tr("Una sombra suave bajo la ventana con el foco.")
                SettingsControls.Switch_ {
                    checked: AppearanceDraft.v.winShadow
                    onToggled: function (v) { AppearanceDraft.set("winShadow", v); }
                }
            }

            SettingsControls.Row_ {
                label: I18n.tr("Animaciones")
                hint: I18n.tr("Ventanas, áreas de trabajo y la vista general se mueven en vez de saltar.")
                SettingsControls.Switch_ {
                    checked: AppearanceDraft.v.animations
                    onToggled: function (v) { AppearanceDraft.set("animations", v); }
                }
            }

            SettingsControls.Row_ {
                shown: AppearanceDraft.v.animations
                label: I18n.tr("Velocidad de las animaciones")
                hint: I18n.tr("100 % es la velocidad normal; más es más rápido.")
                SettingsControls.Slider_ {
                    value: AppearanceDraft.v.animSpeed; from: 50; to: 200; stepSize: 10; suffix: " %"
                    onMoved: function (v) { AppearanceDraft.set("animSpeed", Math.round(v)); }
                }
            }
        }

        // ─────────────────── lock screen (Super+L) ───────────────────
        // LockFace.qml draws it (and the preview, pinned above the options by
        // SettingsWindow.qml so it stays in view); LockTheme.qml reads the
        // login's theme. Left untouched, the lock looks exactly like the login.
        SettingsControls.Card_ {
            id: cLock
            visible: visibleRows > 0 && (root.searching || root.tab === "lock")
            title: I18n.tr("Pantalla de bloqueo")

            // Layout presets: arrangements in the spirit of qylock's themes
            // (github.com/Darkkal44/qylock), built from the options below. A
            // drawer of live miniatures; pick one, then fine-tune anything.
            SettingsControls.Action_ {
                label: I18n.tr("Estilo")
                hint: I18n.tr("Arreglos listos de reloj, contraseña y fuentes. Después puedes ajustar cualquier opción de abajo.")
                icon: "󰕰"
                value: (root.lockPresetList.find(p => p.id === AppearanceDraft.v.lockPreset) || { label: "" }).label
                onTriggered: styleDrawer.open = !styleDrawer.open
            }
            Item {
                id: styleDrawer
                property bool open: false
                Layout.fillWidth: true
                Layout.preferredHeight: open ? grid.implicitHeight + 16 : 0
                Behavior on Layout.preferredHeight { NumberAnimation { duration: Appearance.mInScale; easing.type: Easing.OutCubic } }
                clip: true
                visible: Layout.preferredHeight > 0
                Grid {
                    id: grid
                    x: 6; y: 8
                    readonly property int cols: 3
                    readonly property real tileW: (styleDrawer.width - 12 - (cols - 1) * spacing) / cols
                    columns: cols
                    spacing: 10
                    Repeater {
                        // only built while the drawer is open (each tile is a live lock face)
                        model: styleDrawer.open ? root.lockPresetList : []
                        Column {
                            id: tile
                            required property var modelData
                            readonly property bool sel: AppearanceDraft.v.lockPreset === tile.modelData.id
                            spacing: 6
                            Item {
                                width: grid.tileW; height: Math.round(width * 9 / 16)
                                Item {
                                    anchors.fill: parent
                                    layer.enabled: true
                                    layer.effect: MultiEffect { maskEnabled: true; maskSource: tileMask; maskThresholdMin: 0.5; maskSpreadAtMin: 1.0 }
                                    LockFace {
                                        anchors.fill: parent
                                        cfg: Object.assign({}, AppearanceDraft.v, root.lockPresets[tile.modelData.id])
                                    }
                                }
                                Rectangle { id: tileMask; anchors.fill: parent; radius: 12; visible: false; layer.enabled: true }
                                Rectangle {
                                    anchors.fill: parent; radius: 12; color: "transparent"
                                    border.width: tile.sel ? 2 : (tileMa.containsMouse ? 1 : 0)
                                    border.color: tile.sel ? Colors.accent : Colors.label3
                                }
                                MouseArea {
                                    id: tileMa
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: root.lockPreset(tile.modelData.id)
                                }
                            }
                            Text {
                                width: grid.tileW
                                horizontalAlignment: Text.AlignHCenter
                                text: tile.modelData.label
                                color: tile.sel ? Colors.label : Colors.label2
                                font.family: Appearance.fontUI; font.pixelSize: Appearance.fsXS
                                font.weight: tile.sel ? Font.DemiBold : Font.Normal
                            }
                        }
                    }
                }
            }

            SettingsControls.Action_ {
                label: I18n.tr("Probar")
                hint: I18n.tr("Bloquea ahora para ver cómo queda. Se desbloquea con tu contraseña.")
                icon: Icons.lock
                value: "Super+L"
                onTriggered: Quickshell.execDetached([Quickshell.env("HOME") + "/.config/quickshell/scripts/lock.sh"])
            }
        }

        SettingsControls.Card_ {
            visible: visibleRows > 0 && (root.searching || root.tab === "lock")
            title: I18n.tr("Fondo")

            SettingsControls.Row_ {
                shown: !LockTheme.loginSynced
                label: I18n.tr("Fondo")
                hint: I18n.tr("La imagen de la pantalla de inicio de sesión, o el fondo de pantalla que tienes ahora.")
                SettingsControls.Choice_ {
                    readonly property var vals: ["login", "wallpaper"]
                    options: [I18n.tr("El del inicio de sesión"), I18n.tr("Fondo de pantalla")]
                    current: options[Math.max(0, vals.indexOf(AppearanceDraft.v.lockBg))]
                    onPicked: function (v) { AppearanceDraft.set("lockBg", vals[options.indexOf(v)]); }
                }
            }

            SettingsControls.Row_ {
                label: I18n.tr("Desenfoque del fondo")
                hint: I18n.tr("De 0 % (la imagen tal cual) a 100 % (el máximo). Vale también para la pantalla de inicio de sesión.")
                SettingsControls.Slider_ {
                    value: AppearanceDraft.v.lockBlur >= 0 ? AppearanceDraft.v.lockBlur : LockTheme.defaultBlur; from: 0; to: 100; stepSize: 5; suffix: " %"
                    onMoved: function (v) { AppearanceDraft.set("lockBlur", Math.round(v)); }
                }
            }

            SettingsControls.Row_ {
                label: I18n.tr("Oscurecer")
                hint: I18n.tr("Una capa oscura sobre el fondo, para que el texto se lea mejor. Vale también para el inicio de sesión.")
                SettingsControls.Slider_ {
                    value: AppearanceDraft.v.lockDim; from: 0; to: 80; stepSize: 5; suffix: " %"
                    onMoved: function (v) { AppearanceDraft.set("lockDim", Math.round(v)); }
                }
            }

            SettingsControls.Row_ {
                label: I18n.tr("Degradado oscuro")
                hint: I18n.tr("Una sombra suave arriba y abajo, como en el inicio de sesión, que ayuda a leer el reloj y la contraseña.")
                SettingsControls.Switch_ {
                    checked: AppearanceDraft.v.lockShade
                    onToggled: function (v) { AppearanceDraft.set("lockShade", v); }
                }
            }

        }

        SettingsControls.Card_ {
            visible: visibleRows > 0 && (root.searching || root.tab === "lock")
            title: I18n.tr("Reloj")

            SettingsControls.Row_ {
                label: I18n.tr("Posición del reloj")
                hint: I18n.tr("Arriba a la izquierda como el inicio de sesión, centrado o a la derecha.")
                SettingsControls.Choice_ {
                    readonly property var vals: ["left", "center", "right"]
                    options: [I18n.tr("Izquierda"), I18n.tr("Centro"), I18n.tr("Derecha")]
                    current: options[Math.max(0, vals.indexOf(AppearanceDraft.v.lockClockPos))]
                    onPicked: function (v) { AppearanceDraft.set("lockClockPos", vals[options.indexOf(v)]); }
                }
            }

            SettingsControls.Row_ {
                label: I18n.tr("Altura del reloj")
                hint: I18n.tr("A qué altura va el reloj, contando desde arriba. Vale también para el inicio de sesión.")
                SettingsControls.Slider_ {
                    value: AppearanceDraft.v.lockClockY >= 0 ? AppearanceDraft.v.lockClockY : 7
                    from: 2; to: 60; stepSize: 1; suffix: " %"
                    onMoved: function (v) { AppearanceDraft.set("lockClockY", Math.round(v)); }
                }
            }

            SettingsControls.Row_ {
                label: I18n.tr("Tamaño del reloj")
                hint: I18n.tr("100 % es el tamaño del inicio de sesión.")
                SettingsControls.Slider_ {
                    value: AppearanceDraft.v.lockClockSize; from: 50; to: 150; stepSize: 5; suffix: " %"
                    onMoved: function (v) { AppearanceDraft.set("lockClockSize", Math.round(v)); }
                }
            }

            SettingsControls.Row_ {
                label: I18n.tr("Grosor del reloj")
                hint: I18n.tr("De trazo fino a muy grueso.")
                SettingsControls.Choice_ {
                    readonly property var vals: ["light", "regular", "bold", "black"]
                    options: [I18n.tr("Fino"), I18n.tr("Normal"), I18n.tr("Negrita"), I18n.tr("Muy grueso")]
                    current: options[Math.max(0, vals.indexOf(AppearanceDraft.v.lockClockWeight))]
                    onPicked: function (v) { AppearanceDraft.set("lockClockWeight", vals[options.indexOf(v)]); }
                }
            }

            SettingsControls.Row_ {
                label: I18n.tr("Fuente del reloj")
                hint: I18n.tr("La del inicio de sesión o una de las fuentes de la interfaz.")
                SettingsControls.Choice_ {
                    options: [I18n.tr("Del inicio de sesión")].concat(Config.lockFonts)
                    current: AppearanceDraft.v.lockClockFont !== "" ? AppearanceDraft.v.lockClockFont : options[0]
                    onPicked: function (v) { AppearanceDraft.set("lockClockFont", v === options[0] ? "" : v); }
                }
            }

            SettingsControls.Row_ {
                label: I18n.tr("Color del reloj")
                hint: I18n.tr("El del inicio de sesión, el color del fondo de pantalla o blanco.")
                SettingsControls.Choice_ {
                    readonly property var vals: ["theme", "accent", "white"]
                    options: [I18n.tr("Del inicio de sesión"), I18n.tr("Acento"), I18n.tr("Blanco")]
                    current: options[Math.max(0, vals.indexOf(AppearanceDraft.v.lockClockColor))]
                    onPicked: function (v) { AppearanceDraft.set("lockClockColor", vals[options.indexOf(v)]); }
                }
            }

            SettingsControls.Row_ {
                label: I18n.tr("Reloj de 12 horas")
                hint: I18n.tr("Apagado, la hora va de 00 a 23. Vale también para el inicio de sesión.")
                SettingsControls.Switch_ {
                    checked: AppearanceDraft.v.lock12h
                    onToggled: function (v) { AppearanceDraft.set("lock12h", v); }
                }
            }

            SettingsControls.Row_ {
                label: I18n.tr("Mostrar segundos")
                hint: I18n.tr("El reloj cuenta también los segundos.")
                SettingsControls.Switch_ {
                    checked: AppearanceDraft.v.lockSeconds
                    onToggled: function (v) { AppearanceDraft.set("lockSeconds", v); }
                }
            }

            SettingsControls.Row_ {
                label: I18n.tr("Mostrar la fecha")
                hint: I18n.tr("Debajo del reloj.")
                SettingsControls.Switch_ {
                    checked: AppearanceDraft.v.lockShowDate
                    onToggled: function (v) { AppearanceDraft.set("lockShowDate", v); }
                }
            }

            SettingsControls.Row_ {
                label: I18n.tr("Formato de la fecha")
                hint: I18n.tr("Completa (lunes · 23 de noviembre), corta (lun, 23 nov) o en números.")
                SettingsControls.Choice_ {
                    readonly property var vals: ["full", "short", "numeric"]
                    options: [I18n.tr("Completa"), I18n.tr("Corta"), I18n.tr("Números")]
                    current: options[Math.max(0, vals.indexOf(AppearanceDraft.v.lockDateFmt))]
                    onPicked: function (v) { AppearanceDraft.set("lockDateFmt", vals[options.indexOf(v)]); }
                }
            }

        }

        SettingsControls.Card_ {
            visible: visibleRows > 0 && (root.searching || root.tab === "lock")
            title: I18n.tr("Contraseña")

            SettingsControls.Row_ {
                label: I18n.tr("Lado de la contraseña")
                hint: I18n.tr("Dónde van tu nombre y la contraseña: abajo a la izquierda, al centro o a la derecha. Vale también para el inicio de sesión.")
                SettingsControls.Choice_ {
                    readonly property var vals: ["left", "center", "right"]
                    readonly property string cur: AppearanceDraft.v.lockSide !== "" ? AppearanceDraft.v.lockSide
                        : (["left", "right", "center"].indexOf(String(LockTheme.c("FormPosition", "left"))) >= 0
                            ? String(LockTheme.c("FormPosition", "left")) : "left")
                    options: [I18n.tr("Izquierda"), I18n.tr("Centro"), I18n.tr("Derecha")]
                    current: options[vals.indexOf(cur)]
                    onPicked: function (v) { AppearanceDraft.set("lockSide", vals[options.indexOf(v)]); }
                }
            }

            SettingsControls.Row_ {
                label: I18n.tr("Altura de la contraseña")
                hint: I18n.tr("A qué altura van tu nombre y la contraseña, contando desde abajo. Vale también para el inicio de sesión.")
                SettingsControls.Slider_ {
                    value: AppearanceDraft.v.lockFormY >= 0 ? AppearanceDraft.v.lockFormY : 14
                    from: 9; to: 70; stepSize: 1; suffix: " %"
                    onMoved: function (v) { AppearanceDraft.set("lockFormY", Math.round(v)); }
                }
            }

            SettingsControls.Row_ {
                label: I18n.tr("Estilo del campo")
                hint: I18n.tr("Una línea debajo, como el inicio de sesión, o una caja redondeada.")
                SettingsControls.Choice_ {
                    readonly property var vals: ["line", "box"]
                    options: [I18n.tr("Línea"), I18n.tr("Caja")]
                    current: options[Math.max(0, vals.indexOf(AppearanceDraft.v.lockFieldStyle))]
                    onPicked: function (v) { AppearanceDraft.set("lockFieldStyle", vals[options.indexOf(v)]); }
                }
            }

            SettingsControls.Row_ {
                label: I18n.tr("Tarjeta de vidrio")
                hint: I18n.tr("Una tarjeta translúcida detrás de tu nombre y la contraseña.")
                SettingsControls.Switch_ {
                    checked: AppearanceDraft.v.lockCard === true
                    onToggled: function (v) { AppearanceDraft.set("lockCard", v); }
                }
            }

            SettingsControls.Row_ {
                label: I18n.tr("Mostrar tu foto")
                hint: I18n.tr("Tu foto de usuario encima del nombre.")
                SettingsControls.Switch_ {
                    checked: AppearanceDraft.v.lockAvatar === true
                    onToggled: function (v) { AppearanceDraft.set("lockAvatar", v); }
                }
            }

            SettingsControls.Row_ {
                label: I18n.tr("Carácter de la contraseña")
                hint: I18n.tr("Lo que aparece en lugar de cada letra.")
                SettingsControls.Choice_ {
                    options: ["✦", "•", "*", "●", "◆"]
                    current: AppearanceDraft.v.lockChar
                    onPicked: function (v) { AppearanceDraft.set("lockChar", v); }
                }
            }

            SettingsControls.Row_ {
                shown: !LockTheme.loginSynced
                label: I18n.tr("Color de acento")
                hint: I18n.tr("El color de la línea de la contraseña y de los botones al pasar el ratón.")
                SettingsControls.Choice_ {
                    readonly property var vals: ["login", "wallpaper"]
                    options: [I18n.tr("El del inicio de sesión"), I18n.tr("El del fondo de pantalla")]
                    current: options[Math.max(0, vals.indexOf(AppearanceDraft.v.lockAccent))]
                    onPicked: function (v) { AppearanceDraft.set("lockAccent", vals[options.indexOf(v)]); }
                }
            }

        }

        SettingsControls.Card_ {
            visible: visibleRows > 0 && (root.searching || root.tab === "lock")
            title: I18n.tr("Qué aparece")

            SettingsControls.Row_ {
                label: I18n.tr("Mensaje")
                hint: I18n.tr("Una frase tuya debajo de la fecha, por ejemplo «Vuelvo enseguida». Vacío, no aparece nada.")
                SettingsControls.Text_ {
                    text: AppearanceDraft.v.lockMessage
                    placeholder: I18n.tr("Ninguno")
                    onEdited: function (v) { AppearanceDraft.set("lockMessage", v.trim()); }
                }
            }

            SettingsControls.Row_ {
                label: I18n.tr("Mostrar lo que suena")
                hint: I18n.tr("La canción que está sonando, debajo de la fecha.")
                SettingsControls.Switch_ {
                    checked: AppearanceDraft.v.lockShowMedia
                    onToggled: function (v) { AppearanceDraft.set("lockShowMedia", v); }
                }
            }

            SettingsControls.Row_ {
                label: I18n.tr("Mostrar la batería")
                hint: I18n.tr("El porcentaje de la batería junto a «Bloqueado».")
                SettingsControls.Switch_ {
                    checked: AppearanceDraft.v.lockShowBattery
                    onToggled: function (v) { AppearanceDraft.set("lockShowBattery", v); }
                }
            }

            SettingsControls.Row_ {
                label: I18n.tr("Mostrar tu nombre")
                hint: I18n.tr("Encima de la contraseña.")
                SettingsControls.Switch_ {
                    checked: AppearanceDraft.v.lockShowName
                    onToggled: function (v) { AppearanceDraft.set("lockShowName", v); }
                }
            }

            SettingsControls.Row_ {
                label: I18n.tr("Botones de energía")
                hint: I18n.tr("Suspender, reiniciar y apagar sin desbloquear.")
                SettingsControls.Switch_ {
                    checked: AppearanceDraft.v.lockShowPower
                    onToggled: function (v) { AppearanceDraft.set("lockShowPower", v); }
                }
            }

        }

        // ─────────────────── wallpaper ───────────────────
        SettingsControls.Card_ {
            id: cWall
            visible: visibleRows > 0 && (root.searching || root.tab === "effects")
            title: I18n.tr("Fondo")

            SettingsControls.Action_ {
                label: I18n.tr("Cambiar fondo de pantalla")
                hint: I18n.tr("Abre el selector: tus fondos y búsqueda en la web. Al aplicar uno, pywal retematiza el escritorio entero.")
                icon: Icons.image
                value: "Super+Shift+W"
                // This button has already broken TWICE for the same reason —the
                // text being sent is not the one Hyprland expects— and both
                // times it failed silently, doing NOTHING when pressed. It is
                // worth keeping both written down, because the symptom is identical:
                //
                // 1. It sent "global,quickshell:wallpaper", copying the comma
                //    from `bind =`. Over IPC the comma separates nothing: the first
                //    token IS the dispatcher name, and "global," does not exist.
                // 2. With a space instead, "global quickshell:wallpaper" stopped
                //    working in Hyprland 0.55: the argument of `dispatch` becomes a
                //    LUA EXPRESSION, and as such `global quickshell:wallpaper` is
                //    a syntax error. Now the real dispatcher is called,
                //    `hl.dsp.global`, with the name of the global shortcut that
                //    WallpaperPicker.qml's GlobalShortcut declares.
                //
                // The moral of both: if this button does not respond, the first
                // thing is to look at `journalctl --user -u quickshell` or try the
                // same text with `hyprctl dispatch '...'`, because the error stays
                // in Hyprland and never reaches the interface.
                onTriggered: Compositor.global("wallpaper")
            }
        }

        SettingsControls.Note_ {
            Layout.topMargin: 10
            visible: ShellState.settingsQuery.length > 0
                     && !cLang.visible && !cNotch.visible && !cBehav.visible && !cBar.visible
                     && !cFont.visible && !cFx.visible && !cWall.visible
            text: I18n.tr("Ningún ajuste de Apariencia coincide con «{0}».", ShellState.settingsQuery)
        }
    }
}
