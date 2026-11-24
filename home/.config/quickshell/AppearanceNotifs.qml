// AppearanceNotifs.qml — Settings › Appearance › Pop-ups: how notifications
// show up.
//
// The style (drops falling out of the notch, or the notch stretching) and,
// for the drops (NotifDrops.qml), their size, colour, time and stacking.
// Like the rest of Appearance it edits the draft (AppearanceDraft): every
// change shows live, "Aplicar" keeps it, "Descartar" or closing undoes it,
// and "Volver a lo predeterminado" puts this tab's options back.
import Quickshell
import QtQuick
import QtQuick.Layouts

ColumnLayout {
    id: root

    property string tab: ""
    property bool searching: false
    readonly property bool here: root.searching || root.tab === "notifs"
    readonly property int matchCount: cStyle.visibleRows + cSize.visibleRows + cColor.visibleRows
        + cTime.visibleRows + cStack.visibleRows

    readonly property var v: AppearanceDraft.v
    readonly property bool drops: root.v.notifStyle !== "notch"

    // The options of this tab, for "back to the defaults".
    readonly property var keys: ["notifStyle", "notifSeconds", "dropHeight", "dropWidth", "dropColor",
        "dropOpacity", "dropMax", "dropGap", "dropRing", "dropHoverPause", "dropBody", "dropKindColors", "dropMotion"]

    Layout.fillWidth: true
    spacing: 10

    function set(key, val) { AppearanceDraft.set(key, val); }
    function restore() {
        const d = Config.defaults();
        for (const k of root.keys) if (d[k] !== undefined) AppearanceDraft.set(k, d[k]);
    }

    // Three cards of different kinds, through the same `notch` command scripts use.
    function example() {
        const q = function (s) { return "'" + String(s).replace(/'/g, "'\\''") + "'"; };
        Quickshell.execDetached(["sh", "-c",
            "notch ok " + q(I18n.tr("Compilación lista")) + " " + q(I18n.tr("sin errores en 12 s")) + "; " +
            "sleep 0.35; notch info " + q(I18n.tr("Copia de seguridad")) + " " + q(I18n.tr("128 archivos subidos")) + "; " +
            "sleep 0.35; notch warn " + q(I18n.tr("Disco casi lleno")) + " " + q(I18n.tr("92 % usado en /"))]);
    }

    // A still card with the options of now, so a change is seen before trying it.
    Item {
        Layout.fillWidth: true
        Layout.preferredHeight: 104
        visible: root.tab === "notifs" && !root.searching
        Rectangle {
            anchors.fill: parent
            radius: Appearance.radL
            color: Colors.fill3
        }
        Rectangle {
            id: pv
            readonly property bool on: root.drops
            readonly property int h: Math.max(40, Math.min(80, root.v.dropHeight || 58))
            readonly property color base: root.v.dropColor === "black" ? "#000000"
                : root.v.dropColor === "theme" ? Colors.bg : Colors.notchTint(Config.notchColor)
            readonly property color ink: Colors.inkOn(base)
            readonly property color kc: root.v.dropKindColors ? "#4ade80" : Colors.accent
            readonly property int iconSz: Math.round(h * 0.42)
            readonly property int titlePx: Math.max(11, Math.min(16, Math.round(h * 0.21)))
            anchors.centerIn: parent
            visible: on
            height: root.v.dropBody ? h : Math.max(36, h - 12)
            width: Math.min(parent.width - 24, pvRow.implicitWidth + 28)
            radius: height / 2
            color: Qt.rgba(base.r, base.g, base.b, Math.max(0.3, Math.min(1, (root.v.dropOpacity || 100) / 100)))
            border.width: 1
            border.color: Qt.rgba(ink.r, ink.g, ink.b, 0.05)
            RowLayout {
                id: pvRow
                anchors { left: parent.left; verticalCenter: parent.verticalCenter; leftMargin: 12 }
                spacing: 10
                Rectangle {
                    Layout.preferredWidth: pv.iconSz; Layout.preferredHeight: pv.iconSz
                    radius: pv.iconSz / 2
                    color: pv.kc
                    Text {
                        anchors.centerIn: parent
                        text: "󰄬"; color: "#101010"
                        font.family: Appearance.font; font.pixelSize: Math.round(pv.iconSz * 0.58)
                    }
                }
                ColumnLayout {
                    spacing: 1
                    Text {
                        text: I18n.tr("Compilación lista")
                        color: pv.ink
                        font.family: Appearance.fontUI; font.pixelSize: pv.titlePx; font.weight: Font.DemiBold
                    }
                    Text {
                        visible: root.v.dropBody
                        text: I18n.tr("sin errores en 12 s")
                        color: Qt.rgba(pv.ink.r, pv.ink.g, pv.ink.b, 0.6)
                        font.family: Appearance.fontUI; font.pixelSize: Math.max(10, pv.titlePx - 2)
                    }
                }
                Item {
                    visible: root.v.dropRing
                    Layout.preferredWidth: 18; Layout.preferredHeight: 18
                    Rectangle {
                        anchors.fill: parent; anchors.margins: 2
                        radius: width / 2
                        color: "transparent"
                        border.width: 2.2
                        border.color: pv.kc
                    }
                }
            }
        }
        Text {
            anchors.centerIn: parent
            visible: !root.drops
            text: I18n.tr("En el estilo Notch, el propio notch se estira para mostrar el aviso.")
            color: Colors.label3
            font.family: Appearance.fontUI; font.pixelSize: Appearance.fsXS
        }
    }

    // ─────────────────── style ───────────────────
    SettingsControls.Card_ {
        id: cStyle
        visible: visibleRows > 0 && root.here
        title: I18n.tr("Estilo")

        SettingsControls.Row_ {
            label: I18n.tr("Estilo de los avisos")
            hint: I18n.tr("Gotas: cada aviso cae del notch como una tarjeta y se apilan debajo. Notch: el propio notch se estira para mostrarlo.")
            SettingsControls.Choice_ {
                options: [I18n.tr("Gotas"), I18n.tr("Notch")]
                current: root.drops ? I18n.tr("Gotas") : I18n.tr("Notch")
                onPicked: function (v) { root.set("notifStyle", v === I18n.tr("Notch") ? "notch" : "drops"); }
            }
        }
        SettingsControls.Row_ {
            label: I18n.tr("Probar")
            hint: I18n.tr("Envía tres avisos de ejemplo con los ajustes de ahora.")
            SettingsControls.Btn_ {
                text: I18n.tr("Mostrar un ejemplo")
                primary: true
                onClicked: root.example()
            }
        }
        SettingsControls.Row_ {
            label: I18n.tr("Volver a lo predeterminado")
            hint: I18n.tr("Devuelve las opciones de esta pestaña a como venían. Como el resto de Apariencia, se guarda con «Aplicar».")
            SettingsControls.Btn_ {
                text: I18n.tr("Restablecer")
                onClicked: root.restore()
            }
        }
    }

    // ─────────────────── size ───────────────────
    SettingsControls.Card_ {
        id: cSize
        visible: visibleRows > 0 && root.here
        title: I18n.tr("Tamaño")

        SettingsControls.Row_ {
            shown: root.drops
            label: I18n.tr("Altura")
            hint: I18n.tr("La altura de una tarjeta con detalle; las de una sola línea son algo más bajas. El icono y el texto crecen con ella.")
            SettingsControls.Slider_ {
                value: root.v.dropHeight; from: 40; to: 80; suffix: " px"
                onMoved: function (v) { root.set("dropHeight", Math.round(v)); }
            }
        }
        SettingsControls.Row_ {
            shown: root.drops
            label: I18n.tr("Ancho máximo")
            hint: I18n.tr("Hasta dónde se estira una tarjeta con un texto largo; lo que no cabe se corta con «…».")
            SettingsControls.Slider_ {
                value: root.v.dropWidth; from: 300; to: 640; suffix: " px"
                onMoved: function (v) { root.set("dropWidth", Math.round(v)); }
            }
        }
        SettingsControls.Row_ {
            shown: root.drops
            label: I18n.tr("Distancia al notch")
            hint: I18n.tr("El hueco entre el notch y la primera tarjeta.")
            SettingsControls.Slider_ {
                value: root.v.dropGap; from: 0; to: 160; suffix: " px"
                onMoved: function (v) { root.set("dropGap", Math.round(v)); }
            }
        }
    }

    // ─────────────────── colour ───────────────────
    SettingsControls.Card_ {
        id: cColor
        visible: visibleRows > 0 && root.here
        title: I18n.tr("Color")

        SettingsControls.Row_ {
            shown: root.drops
            label: I18n.tr("Fondo")
            hint: I18n.tr("Notch: el mismo color que el notch, como si la gota saliera de él. Negro: siempre negro. Tema: el fondo de la paleta del wallpaper.")
            SettingsControls.Choice_ {
                options: [I18n.tr("Notch"), I18n.tr("Negro"), I18n.tr("Tema")]
                current: root.v.dropColor === "black" ? I18n.tr("Negro")
                    : root.v.dropColor === "theme" ? I18n.tr("Tema") : I18n.tr("Notch")
                onPicked: function (v) {
                    root.set("dropColor", v === I18n.tr("Negro") ? "black" : v === I18n.tr("Tema") ? "theme" : "notch");
                }
            }
        }
        SettingsControls.Row_ {
            shown: root.drops
            label: I18n.tr("Opacidad")
            hint: I18n.tr("Por debajo de 100 % se ve lo que hay detrás de la tarjeta.")
            SettingsControls.Slider_ {
                value: root.v.dropOpacity; from: 30; to: 100; suffix: " %"
                onMoved: function (v) { root.set("dropOpacity", Math.round(v)); }
            }
        }
        SettingsControls.Row_ {
            shown: root.drops
            label: I18n.tr("Colores por tipo")
            hint: I18n.tr("Verde si salió bien, ámbar para avisar, rojo si falló. Apagado: todo con el color de acento del tema.")
            SettingsControls.Switch_ {
                checked: root.v.dropKindColors
                onToggled: function (v) { root.set("dropKindColors", v); }
            }
        }
    }

    // ─────────────────── time ───────────────────
    SettingsControls.Card_ {
        id: cTime
        visible: visibleRows > 0 && root.here
        title: I18n.tr("Tiempo")

        SettingsControls.Row_ {
            label: I18n.tr("Duración")
            hint: I18n.tr("Cuánto se queda un aviso si la aplicación no pide un tiempo propio. Los críticos y las preguntas tienen el suyo.")
            SettingsControls.Slider_ {
                value: root.v.notifSeconds; from: 2; to: 15; decimals: 1; suffix: " s"
                onMoved: function (v) { root.set("notifSeconds", Math.round(v * 10) / 10); }
            }
        }
        SettingsControls.Row_ {
            shown: root.drops
            label: I18n.tr("Pausar con el ratón")
            hint: I18n.tr("Mover el ratón sobre una tarjeta detiene su tiempo hasta que sales de ella.")
            SettingsControls.Switch_ {
                checked: root.v.dropHoverPause
                onToggled: function (v) { root.set("dropHoverPause", v); }
            }
        }
        SettingsControls.Row_ {
            shown: root.drops
            label: I18n.tr("Anillo de tiempo")
            hint: I18n.tr("El círculo a la derecha que se vacía con el tiempo que le queda a la tarjeta.")
            SettingsControls.Switch_ {
                checked: root.v.dropRing
                onToggled: function (v) { root.set("dropRing", v); }
            }
        }
    }

    // ─────────────────── stack ───────────────────
    SettingsControls.Card_ {
        id: cStack
        visible: visibleRows > 0 && root.here
        title: I18n.tr("Pila")

        SettingsControls.Row_ {
            shown: root.drops
            label: I18n.tr("Tarjetas a la vez")
            hint: I18n.tr("Las que caben debajo del notch; las demás esperan en una gota que las cuenta.")
            SettingsControls.Slider_ {
                value: root.v.dropMax; from: 1; to: 5
                onMoved: function (v) { root.set("dropMax", Math.round(v)); }
            }
        }
        SettingsControls.Row_ {
            shown: root.drops
            label: I18n.tr("Mostrar el detalle")
            hint: I18n.tr("La segunda línea, más pequeña, con el texto del aviso. Apagado: solo el título.")
            SettingsControls.Switch_ {
                checked: root.v.dropBody
                onToggled: function (v) { root.set("dropBody", v); }
            }
        }
        SettingsControls.Row_ {
            shown: root.drops
            label: I18n.tr("Animación")
            hint: I18n.tr("Elástica: la gota cae y rebota un poco. Suave: cae sin rebote. Ninguna: aparece en su sitio.")
            SettingsControls.Choice_ {
                options: [I18n.tr("Elástica"), I18n.tr("Suave"), I18n.tr("Ninguna")]
                current: root.v.dropMotion === "smooth" ? I18n.tr("Suave")
                    : root.v.dropMotion === "none" ? I18n.tr("Ninguna") : I18n.tr("Elástica")
                onPicked: function (v) {
                    root.set("dropMotion", v === I18n.tr("Suave") ? "smooth" : v === I18n.tr("Ninguna") ? "none" : "bouncy");
                }
            }
        }
    }
}
