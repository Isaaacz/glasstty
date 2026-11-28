// shell.qml — entrypoint. Instantiates the components of the Quickshell system.
// The dashboard/Sidebar was retired: its content lives in the notch's Control
// Centre (ControlPanel.qml). Super+N now toggles notch <-> island.
//
// The full-screen Overview was ALSO retired (6 Aug 2026): it is now one more
// face of the notch (OverviewPanel.qml), so it is no longer a separate window
// and is not instantiated here. Its shortcut, Super+Tab, has not changed.
import Quickshell
import QtQml

Scope {
    id: root
    TopShell {}     // bar + notch on a single surface (replaces waybar)
    StageWindow {} // alternate visual workspace organiser
    SettingsWindow {}   // Settings app (floating window, launched from the notch)
    MediaControls {}
    WallpaperPicker {}
    WallpaperFx {}      // wallpaper transitions, drawn here instead of by awww
    LockScreen {}       // lock screen with the thyx look (same theme as the SDDM login)
    IdleDim {}          // the screen fades to dark before the idle lock
    NotifDrops {}       // notifications as drops falling out of the notch
    BatteryWatch {}     // low-battery warnings at 20, 10 and 5 %
    GameOverlay {}      // performance over the game (Super+Shift+G) and the heat warning
    ExitScreen {}       // full-screen exit screen (Super+Shift+E, power key)
    Screenshot {}       // Print: GNOME-style capture screen

    // Restarts the shell if a hot reload ever leaves its IPC stuck on "Not
    // ready" (shortcuts, dim and lock all go through it). One copy at a time:
    // the script exits at once when another is running. See the script.
    Component.onCompleted: Quickshell.execDetached(["sh", Quickshell.shellPath("scripts/ipc-watchdog.sh")])
}
