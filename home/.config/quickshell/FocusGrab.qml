// FocusGrab.qml — "click outside = close".
//
// niri has no focus-grab protocol. The usual answer in niri shells (Noctalia,
// DankMaterialShell) is a click catcher: a transparent full-screen layer
// surface placed UNDER the panel and above the windows. A press anywhere on it
// fires `cleared`. It lives on the Top layer; the surfaces it protects must be
// on Overlay (see TopShell / WallpaperPicker / MediaControls), otherwise the
// catcher would eat their clicks too. The click is swallowed: it does not reach
// the window underneath.
import Quickshell
import Quickshell.Wayland
import QtQuick

Scope {
    id: grab
    property list<QtObject> windows
    property bool active: false
    // false for real windows (Settings): a Top-layer catcher would cover them.
    // Under niri such a window then simply stays open until Esc / close.
    property bool useCatcher: true
    signal cleared()

    LazyLoader {
        active: grab.active && grab.useCatcher
        PanelWindow {
            screen: (grab.windows.length > 0 && grab.windows[0].screen) ? grab.windows[0].screen : null
            anchors { top: true; bottom: true; left: true; right: true }
            exclusionMode: ExclusionMode.Ignore
            color: "transparent"
            WlrLayershell.layer: WlrLayer.Top
            WlrLayershell.namespace: "quickshell:grab"
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.AllButtons
                onPressed: grab.cleared()
            }
        }
    }
}
