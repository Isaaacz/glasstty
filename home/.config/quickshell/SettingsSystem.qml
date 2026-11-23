// SettingsSystem.qml — the system switches that until now only existed in
// the notch's control centre (Super+D).
//
// WHY REPEAT THEM HERE: the control centre is for a quick touch and off you go
// — it is designed for a gesture. Settings is for when you want to READ what
// each thing does before touching it (that is what the footer strip is for)
// and for what does not fit in four buttons: the battery state, which network
// you are on, how many notifications you have. None of these settings is saved
// in the rice's JSON: they are system state and ShellState reads them.
import Quickshell
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Flickable {
    id: root

    property string note: I18n.tr("Los perfiles de energía se recuerdan para batería y cargador.")
    readonly property int matchCount: cScreen.visibleRows + cPower.visibleRows + cProfiles.visibleRows
        + cNet.visibleRows + cNotif.visibleRows + cTerm.visibleRows

    contentHeight: col.implicitHeight + 34
    clip: true
    boundsBehavior: Flickable.StopAtBounds
    ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded; width: 5 }
    onVisibleChanged: if (visible) { contentY = 0; Energy.refresh(); }

    ColumnLayout {
        id: col
        width: root.width - 48
        x: 24
        y: 16
        spacing: 10

        // ─────────────────── screen ───────────────────
        SettingsControls.Card_ {
            id: cScreen
            title: I18n.tr("Pantalla")

            SettingsControls.Row_ {
                shown: ShellState.bright >= 0
                label: I18n.tr("Brillo")
                hint: I18n.tr("El mismo brillo que las teclas de función, y con el mismo OSD en el notch.")
                SettingsControls.Slider_ {
                    value: Math.max(ShellState.brightMin, ShellState.bright); from: ShellState.brightMin; to: 100; suffix: " %"
                    onMoved: function (v) { ShellState.setBrightness(v); }
                }
            }

            SettingsControls.Row_ {
                label: I18n.tr("Luz nocturna")
                hint: I18n.tr("Baja la temperatura de color a 4000 K con hyprsunset. Súper+Shift+N hace lo mismo.")
                SettingsControls.Switch_ {
                    checked: ShellState.nightLight
                    onToggled: ShellState.toggleNightLight()
                }
            }

        }

        SettingsControls.Card_ {
            id: cProfiles
            title: I18n.tr("Perfiles de energía")
            SettingsControls.Row_ {
                label: I18n.tr("Perfil activo")
                hint: I18n.tr("Ahorro desactiva el turbo y el desenfoque de movimiento, y puede reducir el brillo. Equilibrado conserva el turbo y prioriza eficiencia. Rendimiento prioriza la respuesta.")
                SettingsControls.Val_ {
                    text: Energy.busy ? I18n.tr("Aplicando…") : Energy.label(Energy.active)
                    color: Energy.active === "power-saver" ? Colors.accentInk : Colors.label2
                }
            }
            SettingsControls.Row_ {
                shown: Energy.available
                label: I18n.tr("Con batería")
                hint: I18n.tr("Se aplica al desenchufar y al iniciar la sesión con batería. Puedes cambiarlo cuando necesites más velocidad.")
                SettingsControls.Choice_ {
                    options: Energy.labels
                    current: Energy.label(Config.energyOnBattery)
                    onPicked: function(v) { Energy.choose(true, v); }
                }
            }
            SettingsControls.Row_ {
                shown: Energy.available
                label: I18n.tr("Con cargador")
                hint: I18n.tr("Se aplica al enchufar y al iniciar la sesión con corriente. La elección se guarda automáticamente.")
                SettingsControls.Choice_ {
                    options: Energy.labels
                    current: Energy.label(Config.energyOnAC)
                    onPicked: function(v) { Energy.choose(false, v); }
                }
            }
            SettingsControls.Row_ {
                shown: ShellState.bright >= 0 && Energy.available
                label: I18n.tr("Reducir brillo en Ahorro")
                hint: I18n.tr("Al entrar en Ahorro baja el brillo si supera el límite. Al salir recupera el anterior, salvo que lo hayas cambiado manualmente.")
                SettingsControls.Switch_ {
                    checked: Config.dimOnSaver
                    onToggled: function(v) { Config.dimOnSaver = v; Config.save(); }
                }
            }
            SettingsControls.Row_ {
                shown: ShellState.bright >= 0 && Energy.available && Config.dimOnSaver
                label: I18n.tr("Brillo en Ahorro")
                hint: I18n.tr("Es un límite al entrar en el perfil, no un bloqueo: las teclas de brillo siguen funcionando. Si ya estaba más bajo, no lo sube.")
                SettingsControls.Slider_ {
                    value: Config.saverBrightness; from: 10; to: 80; suffix: " %"
                    onMoved: function(v) { Config.saverBrightness = Math.round(v); Config.save(); }
                }
            }
            SettingsControls.Row_ {
                shown: !Energy.available || Energy.error.length > 0
                label: Energy.error.length > 0 ? Energy.error : I18n.tr("Servicio de perfiles no disponible")
                hint: I18n.tr("Los perfiles necesitan el servicio TLP de energía activo.")
                SettingsControls.Btn_ {
                    text: I18n.tr("Reintentar")
                    onClicked: { Energy.refresh(); Energy.apply(); }
                }
            }
            SettingsControls.Row_ {
                shown: ShellState.batt >= 0
                label: I18n.tr("Permitir reposo con batería")
                hint: I18n.tr("Quita Cafeína al desenchufar: deja atenuar, bloquear, apagar la pantalla y suspender según tus tiempos de inactividad. Al enchufar restaura Cafeína. Puedes encenderla manualmente en el notch.")
                SettingsControls.Switch_ {
                    checked: Config.batteryAllowIdle
                    onToggled: function(v) { Config.batteryAllowIdle = v; Config.save(); }
                }
            }
        }

        // ─────────────────── power ───────────────────
        SettingsControls.Card_ {
            id: cPower
            title: I18n.tr("Energía")

            // On a tower there is no /sys/class/power_supply/BAT*, so `batt`
            // is -1 and this row said "sin batería" (no battery) forever.
            // Reporting something that cannot exist on that machine is not
            // honesty, it is a gap with text in it: the three rows below were
            // already hidden for the same reason and this one was left alone
            // presiding over them. The ENERGY card does not end up empty
            // because Caffeine and the rest are still there.
            SettingsControls.Row_ {
                shown: ShellState.batt >= 0
                label: I18n.tr("Batería")
                hint: I18n.tr("Carga actual según el kernel, la misma que enseña el notch.")
                SettingsControls.Val_ {
                    text: I18n.tr("{0} % · {1}", ShellState.batt,
                                  ShellState.ac ? I18n.tr("con cargador") : I18n.tr("con batería"))
                    color: ShellState.batt < 15 && !ShellState.ac ? Colors.crit : Colors.label2
                }
            }

            SettingsControls.Row_ {
                shown: ShellState.battHealth >= 0 || ShellState.battCycles >= 0
                label: I18n.tr("Salud")
                hint: I18n.tr("Capacidad máxima actual frente a la capacidad de fábrica, según UPower. Los ciclos vienen directamente del contador de la batería.")
                SettingsControls.Val_ {
                    text: {
                        const salud = ShellState.battHealth >= 0
                                    ? ShellState.battHealth.toFixed(0) + " %" : I18n.tr("sin dato");
                        return ShellState.battCycles >= 0
                             ? I18n.tr("{0} · {1} ciclos", salud, ShellState.battCycles) : salud;
                    }
                    color: ShellState.battHealth >= 0 && ShellState.battHealth < 60 ? Colors.crit
                        : ShellState.battHealth >= 0 && ShellState.battHealth < 80 ? Colors.warn : Colors.label2
                }
            }

            SettingsControls.Row_ {
                shown: ShellState.battFullWh > 0
                label: I18n.tr("Capacidad")
                hint: I18n.tr("Energía que admite cargada al máximo frente al diseño original. Se muestra en vatios-hora, no es el porcentaje de carga de ahora.")
                SettingsControls.Val_ {
                    text: ShellState.battDesignWh > 0
                        ? I18n.tr("{0} de {1}", ShellState.fmtWh(ShellState.battFullWh),
                                  ShellState.fmtWh(ShellState.battDesignWh))
                        : ShellState.fmtWh(ShellState.battFullWh)
                }
            }

            SettingsControls.Row_ {
                shown: ShellState.batt >= 0
                label: I18n.tr("Autonomía")
                hint: I18n.tr("Estimación de UPower según el consumo reciente. Puede tardar unos minutos en estabilizarse después de enchufar, desenchufar o despertar el equipo.")
                SettingsControls.Val_ {
                    text: ShellState.battEstimateText
                        + (ShellState.battRateW > 0.05 ? " · " + ShellState.battRateW.toFixed(1) + " W" : "")
                }
            }

            SettingsControls.Row_ {
                label: I18n.tr("Cafeína")
                hint: I18n.tr("Impide apagar la pantalla y suspender por inactividad. El ajuste Permitir reposo con batería la desactiva al desenchufar; puedes volver a activarla manualmente.")
                SettingsControls.Switch_ {
                    checked: ShellState.caffeine
                    onToggled: function (v) { ShellState.caffeine = v; }
                }
            }

        }

        // ─────────────────── network ───────────────────
        SettingsControls.Card_ {
            id: cNet
            title: I18n.tr("Red")

            SettingsControls.Row_ {
                shown: ShellState.hasWifi
                label: I18n.tr("Wi-Fi")
                hint: I18n.tr("Enciende o apaga la radio wifi (NetworkManager).")
                SettingsControls.Switch_ {
                    checked: ShellState.wifiOn
                    onToggled: function (v) { ShellState.setWifi(v); }
                }
            }

            SettingsControls.Action_ {
                label: I18n.tr("Redes disponibles")
                hint: I18n.tr("Abre el selector de redes en el notch. Ajustes se cierra para no taparlo.")
                icon: Icons.wifi
                value: ShellState.wiredDev ? I18n.tr("cable")
                     : ShellState.wifiNet ? ShellState.wifiNet.name
                     : (ShellState.wifiOn || !ShellState.hasWifi) ? I18n.tr("sin conexión") : I18n.tr("apagado")
                onTriggered: {
                    ShellState.settingsOpen = false;
                    ShellState.togglePanel("network");
                }
            }

            SettingsControls.Action_ {
                label: I18n.tr("Perfiles de red")
                hint: I18n.tr("Gestiona perfiles WPA-Enterprise sin enseñar contraseñas en comandos: identidad, método EAP y certificados se guardan mediante NetworkManager.")
                icon: Icons.wifiLock
                value: I18n.tr("EAP y certificados")
                onTriggered: ShellState.openNetworkProfiles()
            }
        }

        // ─────────────────── notifications ───────────────────
        SettingsControls.Card_ {
            id: cNotif
            title: I18n.tr("Notificaciones")

            SettingsControls.Row_ {
                label: I18n.tr("No molestar")
                hint: I18n.tr("Las notificaciones siguen llegando y quedan en el centro de control, pero el notch no las anuncia.")
                SettingsControls.Switch_ {
                    checked: ShellState.dnd
                    onToggled: function (v) { ShellState.dnd = v; }
                }
            }

            SettingsControls.Action_ {
                label: I18n.tr("Vaciar la bandeja")
                hint: I18n.tr("Descarta todas las notificaciones guardadas.")
                icon: Icons.bell
                value: ShellState.notifCount === 0 ? I18n.tr("vacía")
                     : I18n.tr("{0} sin leer", ShellState.notifCount)
                onTriggered: ShellState.clearNotifs()
            }
        }

        // ─────────────────── terminal ───────────────────
        SettingsControls.Card_ {
            id: cTerm
            title: I18n.tr("Terminal")

            SettingsControls.Row_ {
                label: I18n.tr("Entorno de Python")
                hint: I18n.tr("Abre el prompt con (nombre) en verde cuando hay un entorno activo, sea un venv o uno de conda, para no acabar instalando en el que no era. Se aplica en las terminales que abras a partir de ahora.")
                SettingsControls.Switch_ {
                    checked: ShellState.promptEnv
                    onToggled: ShellState.togglePromptEnv()
                }
            }
        }

        SettingsControls.Note_ {
            Layout.topMargin: 10
            visible: ShellState.settingsQuery.length > 0
                     && !cScreen.visible && !cPower.visible && !cNet.visible
                     && !cNotif.visible && !cTerm.visible
            text: I18n.tr("Ningún ajuste de Sistema coincide con «{0}».", ShellState.settingsQuery)
        }
    }
}
