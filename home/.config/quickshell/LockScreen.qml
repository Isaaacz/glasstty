// LockScreen.qml — the lock screen, dressed as the login screen.
//
// The login screen is SDDM with the thyx theme (github.com/rccyx/thyx, MIT;
// see sddm-thyx.sh). SDDM cannot lock a running session, so this draws the
// same thing here: it reads thyx's own theme.conf (colours, font, background
// image or video, blur), so changing the thyx preset changes both screens.
//
// Security: ext-session-lock (WlSessionLock). If this process dies while
// locked, niri keeps the session locked; scripts/lock.sh falls back to
// swaylock if the shell does not confirm a secure lock within 2 s.
// The password goes through PAM, service "swaylock" (/etc/pam.d/swaylock).
pragma ComponentBehavior: Bound

import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Services.Pam
import Quickshell.Widgets
import QtQuick
import QtQuick.Effects
import QtQuick.Layouts
import QtMultimedia

Scope {
    id: root


    // ─── state shared by every screen ───
    property string password: ""
    property bool busy: false
    property string errorText: ""
    property int failures: 0
    readonly property bool locked: lock.locked
    readonly property bool secure: lock.secure

    // NO RELOADS WHILE LOCKED. A shell reload (a QML file changing) destroys
    // the lock object: niri keeps the session locked (safe), but the reloaded
    // shell cannot lock it again and dies, leaving a locked screen with no
    // password field. So file watching is switched off for as long as the
    // screen is locked and back on after unlocking.
    function lockNow() {
        if (lock.locked) return;
        root.password = ""; root.errorText = ""; root.busy = false;
        ShellState.closePanel();
        Quickshell.watchFiles = false;
        lock.locked = true;
    }
    function unlockNow() {
        lock.locked = false;
        Quickshell.watchFiles = true;
    }
    function submit() {
        if (root.busy || root.password.length === 0) return;
        root.busy = true;
        root.errorText = "";
        if (!pam.start()) { root.busy = false; root.errorText = I18n.tr("No se pudo iniciar la autenticación"); }
    }

    PamContext {
        id: pam
        // The same PAM service swaylock uses (auth include login): known to
        // work on this system, and swaylock is the fallback locker anyway.
        configDirectory: "/etc/pam.d"
        config: "swaylock"
        user: LockTheme.user
        onPamMessage: {
            if (pam.responseRequired) pam.respond(root.password);
            else if (pam.messageIsError) root.errorText = pam.message;
        }
        onCompleted: function (result) {
            root.busy = false;
            if (result === PamResult.Success) {
                root.password = "";
                root.failures = 0;
                root.unlockNow();
            } else {
                root.password = "";
                root.failures++;
                root.errorText = result === PamResult.MaxTries ? I18n.tr("Demasiados intentos. Espera un poco.") : I18n.tr("Contraseña incorrecta");
            }
        }
        onError: function (err) {
            root.busy = false;
            root.password = "";
            root.errorText = I18n.tr("Error de autenticación");
        }
    }

    IpcHandler {
        target: "lock"
        function lock(): void { root.lockNow(); }
        // "unlocked" | "locking" | "secure": scripts/lock.sh waits for "secure".
        function status(): string { return !lock.locked ? "unlocked" : (lock.secure ? "secure" : "locking"); }
        // Which thyx theme.conf is in use and how many keys were read.
        function theme(): string { return LockTheme.themeDir + " keys=" + Object.keys(LockTheme.cfg).length + " bg=" + LockTheme.bgPath; }
    }

    WlSessionLock {
        id: lock
        locked: false

        WlSessionLockSurface {
            id: surf
            color: LockTheme.c("StartupBackgroundColor", "#000000")

            LockFace {
                anchors.fill: parent
                lock: root
            }
        }
    }
}
