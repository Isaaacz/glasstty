// SettingsNotifs.qml — Settings › Pop-ups: how notifications show up.
//
// The style (drops falling out of the notch, or the notch stretching) and,
// for the drops (NotifDrops.qml), their size, colour, time and stacking.
// Every change applies live; "Show an example" sends three cards to see it.
import Quickshell
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Flickable {
    id: root

    property string note: I18n.tr("Los cambios se ven en el acto: usa «Mostrar un ejemplo» para probarlos.")
    readonly property int matchCount: cStyle.visibleRows + cSize.visibleRows + cColor.visibleRows
        + cTime.visibleRows + cStack.visibleRows

    readonly property bool drops: Config.notifStyle !== "notch"

    contentHeight: col.implicitHeight + 34
    clip: true
    boundsBehavior: Flickable.StopAtBounds
    ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded; width: 5 }
    onVisibleChanged: if (visible) contentY = 0

    function set(key, v) { Config[key] = v; Config.save(); }

    // Three cards of different kinds, through the same `notch` command scripts use.
    function example() {
        const q = function (s) { return "'" + String(s).replace(/'/g, "'\\''") + "'"; };
        Quickshell.execDetached(["sh", "-c",
            "notch ok " + q(I18n.tr("Compilación lista")) + " " + q(I18n.tr("sin errores en 12 s")) + "; " +
            "sleep 0.35; notch info " + q(I18n.tr("Copia de seguridad")) + " " + q(I18n.tr("128 archivos subidos")) + "; " +
            "sleep 0.35; notch warn " + q(I18n.tr("Disco casi lleno")) + " " + q(I18n.tr("92 % usado en /"))]);
    }

    ColumnLayout {
        id: col
        width: root.width - 48
        x: 24
        y: 16
        spacing: 10

        // ─────────────────── style ───────────────────
        SettingsControls.Card_ {
            id: cStyle
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
                label: I18n.tr("No molestar")
                hint: I18n.tr("Las notificaciones siguen llegando y quedan en el centro de control, pero el notch no las anuncia.")
                SettingsControls.Switch_ {
                    checked: ShellState.dnd
                    onToggled: function (v) { ShellState.dnd = v; }
                }
            }
        }

        // ─────────────────── size ───────────────────
        SettingsControls.Card_ {
            id: cSize
            title: I18n.tr("Tamaño")

            SettingsControls.Row_ {
                shown: root.drops
                label: I18n.tr("Altura")
                hint: I18n.tr("La altura de una tarjeta con detalle; las de una sola línea son algo más bajas. El icono y el texto crecen con ella.")
                SettingsControls.Slider_ {
                    value: Config.dropHeight; from: 40; to: 80; suffix: " px"
                    onMoved: function (v) { root.set("dropHeight", Math.round(v)); }
                }
            }
            SettingsControls.Row_ {
                shown: root.drops
                label: I18n.tr("Ancho máximo")
                hint: I18n.tr("Hasta dónde se estira una tarjeta con un texto largo; lo que no cabe se corta con «…».")
                SettingsControls.Slider_ {
                    value: Config.dropWidth; from: 300; to: 640; suffix: " px"
                    onMoved: function (v) { root.set("dropWidth", Math.round(v)); }
                }
            }
            SettingsControls.Row_ {
                shown: root.drops
                label: I18n.tr("Distancia al notch")
                hint: I18n.tr("El hueco entre el notch y la primera tarjeta.")
                SettingsControls.Slider_ {
                    value: Config.dropGap; from: 0; to: 40; suffix: " px"
                    onMoved: function (v) { root.set("dropGap", Math.round(v)); }
                }
            }
        }

        // ─────────────────── colour ───────────────────
        SettingsControls.Card_ {
            id: cColor
            title: I18n.tr("Color")

            SettingsControls.Row_ {
                shown: root.drops
                label: I18n.tr("Fondo")
                hint: I18n.tr("Notch: el mismo color que el notch, como si la gota saliera de él. Negro: siempre negro. Tema: el fondo de la paleta del wallpaper.")
                SettingsControls.Choice_ {
                    options: [I18n.tr("Notch"), I18n.tr("Negro"), I18n.tr("Tema")]
                    current: Config.dropColor === "black" ? I18n.tr("Negro")
                        : Config.dropColor === "theme" ? I18n.tr("Tema") : I18n.tr("Notch")
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
                    value: Config.dropOpacity; from: 30; to: 100; suffix: " %"
                    onMoved: function (v) { root.set("dropOpacity", Math.round(v)); }
                }
            }
            SettingsControls.Row_ {
                shown: root.drops
                label: I18n.tr("Colores por tipo")
                hint: I18n.tr("Verde si salió bien, ámbar para avisar, rojo si falló. Apagado: todo con el color de acento del tema.")
                SettingsControls.Switch_ {
                    checked: Config.dropKindColors
                    onToggled: function (v) { root.set("dropKindColors", v); }
                }
            }
        }

        // ─────────────────── time ───────────────────
        SettingsControls.Card_ {
            id: cTime
            title: I18n.tr("Tiempo")

            SettingsControls.Row_ {
                label: I18n.tr("Duración")
                hint: I18n.tr("Cuánto se queda un aviso si la aplicación no pide un tiempo propio. Los críticos y las preguntas tienen el suyo.")
                SettingsControls.Slider_ {
                    value: Config.notifSeconds; from: 2; to: 15; decimals: 1; suffix: " s"
                    onMoved: function (v) { root.set("notifSeconds", Math.round(v * 10) / 10); }
                }
            }
            SettingsControls.Row_ {
                shown: root.drops
                label: I18n.tr("Pausar con el ratón")
                hint: I18n.tr("Mover el ratón sobre una tarjeta detiene su tiempo hasta que sales de ella.")
                SettingsControls.Switch_ {
                    checked: Config.dropHoverPause
                    onToggled: function (v) { root.set("dropHoverPause", v); }
                }
            }
            SettingsControls.Row_ {
                shown: root.drops
                label: I18n.tr("Anillo de tiempo")
                hint: I18n.tr("El círculo a la derecha que se vacía con el tiempo que le queda a la tarjeta.")
                SettingsControls.Switch_ {
                    checked: Config.dropRing
                    onToggled: function (v) { root.set("dropRing", v); }
                }
            }
        }

        // ─────────────────── stack ───────────────────
        SettingsControls.Card_ {
            id: cStack
            title: I18n.tr("Pila")

            SettingsControls.Row_ {
                shown: root.drops
                label: I18n.tr("Tarjetas a la vez")
                hint: I18n.tr("Las que caben debajo del notch; las demás esperan en una gota que las cuenta.")
                SettingsControls.Slider_ {
                    value: Config.dropMax; from: 1; to: 5
                    onMoved: function (v) { root.set("dropMax", Math.round(v)); }
                }
            }
            SettingsControls.Row_ {
                shown: root.drops
                label: I18n.tr("Mostrar el detalle")
                hint: I18n.tr("La segunda línea, más pequeña, con el texto del aviso. Apagado: solo el título.")
                SettingsControls.Switch_ {
                    checked: Config.dropBody
                    onToggled: function (v) { root.set("dropBody", v); }
                }
            }
            SettingsControls.Row_ {
                shown: root.drops
                label: I18n.tr("Animación")
                hint: I18n.tr("Elástica: la gota cae y rebota un poco. Suave: cae sin rebote. Ninguna: aparece en su sitio.")
                SettingsControls.Choice_ {
                    options: [I18n.tr("Elástica"), I18n.tr("Suave"), I18n.tr("Ninguna")]
                    current: Config.dropMotion === "smooth" ? I18n.tr("Suave")
                        : Config.dropMotion === "none" ? I18n.tr("Ninguna") : I18n.tr("Elástica")
                    onPicked: function (v) {
                        root.set("dropMotion", v === I18n.tr("Suave") ? "smooth" : v === I18n.tr("Ninguna") ? "none" : "bouncy");
                    }
                }
            }
        }
    }
}
