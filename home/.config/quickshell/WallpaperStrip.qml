// WallpaperStrip.qml — quick wallpaper picker inside the Control Centre.
//
// Replaces the original's pokémon team card in this fork.
// A horizontal strip of the same thumbnails the full picker uses
// (~/.cache/wallpaper-thumbs, kept by scripts/wall-thumbs.sh). Click one and
// set-wallpaper.sh runs as usual: WallpaperFx transition, pywal palette. The
// panel stays open, so you see the notch recolour itself. "Ver todos" opens
// the full picker (Super+W).
import Quickshell
import Quickshell.Io
import Quickshell.Widgets
import QtQuick
import QtQuick.Layouts
import Qt.labs.folderlistmodel

Rectangle {
    id: root

    readonly property string home: Quickshell.env("HOME")
    readonly property string thumbsDir: home + "/.cache/wallpaper-thumbs"
    // The XDG pictures folder (~/Imagens here); corrected by xdg-user-dir.
    property string picturesDir: home + "/Pictures"
    readonly property string wallsDir: picturesDir + "/wallpapers"
    // What is on screen now: pywal's last image (set-wallpaper.sh feeds it).
    property string current: ""

    Layout.fillWidth: true
    Layout.preferredHeight: 118
    radius: 13
    color: Colors.fill3
    border.width: 1
    border.color: Colors.hairline

    function originalOf(thumbName) { return root.wallsDir + "/" + String(thumbName).replace(/\.jpg$/, "") }

    // Opening the Control Centre centres the strip on the wallpaper in use.
    function showCurrent() {
        for (let i = 0; i < walls.count; i++)
            if (root.originalOf(walls.get(i, "fileName")) === root.current) {
                list.positionViewAtIndex(i, GridView.Contain);
                return;
            }
    }
    readonly property bool panelOpen: ShellState.panel === "control"
    onPanelOpenChanged: if (panelOpen) Qt.callLater(root.showCurrent)
    Component.onCompleted: Qt.callLater(root.showCurrent)

    Process {
        running: true
        command: ["xdg-user-dir", "PICTURES"]
        stdout: StdioCollector {
            onStreamFinished: {
                const d = this.text.trim();
                if (d !== "" && d !== root.home) root.picturesDir = d;
            }
        }
    }
    FileView {
        id: currentFile
        path: root.home + "/.cache/wal/wal"
        watchChanges: true
        onFileChanged: reload()
        onLoaded: { root.current = String(text()).trim(); Qt.callLater(root.showCurrent); }
    }

    FolderListModel {
        id: walls
        folder: "file://" + root.thumbsDir
        nameFilters: ["*.jpg"]
        showDirs: false
        sortField: FolderListModel.Name
    }

    ColumnLayout {
        anchors { fill: parent; leftMargin: 12; rightMargin: 10; topMargin: 9; bottomMargin: 9 }
        spacing: 7

        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            StyledText {
                text: I18n.tr("Wallpapers")
                color: Colors.label
                font.family: Appearance.fontUI
                font.pixelSize: Appearance.fsXXS
                font.weight: Font.DemiBold
            }
            StyledText {
                Layout.fillWidth: true
                elide: Text.ElideRight
                text: walls.count > 0 ? walls.count + "  ·  " + I18n.tr("clique para aplicar")
                                      : I18n.tr("Coloque imagens em") + " " + root.wallsDir.replace(root.home, "~")
                color: Colors.label3
                font.family: Appearance.fontUI
                font.pixelSize: 8
            }
            StyledText {
                text: I18n.tr("Ver todos") + "  ›"
                color: allMa.containsMouse ? Colors.accent : Colors.label3
                font.family: Appearance.fontUI
                font.pixelSize: Appearance.fsXXS
                MouseArea {
                    id: allMa
                    anchors.fill: parent
                    anchors.margins: -4
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: { ShellState.closePanel(); Compositor.global("wallpaper"); }
                }
            }
        }

        // A grid (the Control Centre's Wallpapers page): 4 per row, scrolls down.
        GridView {
            id: list
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            model: walls
            boundsBehavior: Flickable.StopAtBounds
            cellWidth: Math.floor(width / 4)
            cellHeight: Math.round(cellWidth * 9 / 16)

            delegate: Item {
                id: tile
                required property string fileName
                required property string filePath
                readonly property string original: root.originalOf(fileName)
                readonly property bool isCurrent: original === root.current
                width: list.cellWidth - 8
                height: list.cellHeight - 8

                ClippingRectangle {
                    anchors.fill: parent
                    radius: 8
                    color: Colors.fill3
                    Image {
                        anchors.fill: parent
                        source: "file://" + tile.filePath
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                        sourceSize.height: tile.height * 2
                        opacity: tileMa.containsMouse || tile.isCurrent ? 1 : 0.82
                        scale: tileMa.pressed ? 0.97 : 1
                        Behavior on opacity { NumberAnimation { duration: Appearance.mQuick } }
                        Behavior on scale { NumberAnimation { duration: Appearance.mQuick; easing.type: Easing.OutQuad } }
                    }
                }
                // Ring on the one showing now, softer ring on hover.
                Rectangle {
                    anchors.fill: parent
                    radius: 8
                    color: "transparent"
                    border.width: tile.isCurrent ? 2 : (tileMa.containsMouse ? 1 : 0)
                    border.color: tile.isCurrent ? Colors.accent
                        : Qt.rgba(Colors.accent.r, Colors.accent.g, Colors.accent.b, 0.6)
                }
                MouseArea {
                    id: tileMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: if (!tile.isCurrent)
                        Quickshell.execDetached([root.home + "/.config/glasstty/set-wallpaper.sh", tile.original])
                }
            }
        }
    }
}
