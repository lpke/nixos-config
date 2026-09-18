import QtQuick
import QtQuick.Window
import Qt.labs.folderlistmodel
import org.kde.layershell as LayerShell

Window {
    id: blackout

    readonly property string outputName: Application.arguments[Application.arguments.length - 2]
    readonly property string stateDirectory: Application.arguments[Application.arguments.length - 1]
    readonly property bool dismissing: state.status === FolderListModel.Ready && state.count === 0

    color: "transparent"
    title: "Display blackout"
    flags: Qt.FramelessWindowHint
    screen: findOutput()

    LayerShell.Window.layer: LayerShell.Window.LayerOverlay
    LayerShell.Window.anchors: LayerShell.Window.AnchorTop | LayerShell.Window.AnchorBottom
        | LayerShell.Window.AnchorLeft | LayerShell.Window.AnchorRight
    LayerShell.Window.exclusionZone: -1
    LayerShell.Window.keyboardInteractivity: LayerShell.Window.KeyboardInteractivityNone
    LayerShell.Window.scope: "display-blackout"

    FolderListModel {
        id: state
        folder: "file://" + blackout.stateDirectory
        nameFilters: ["visible"]
        showDirs: false
    }

    // FolderListModel watches for changes without a polling timer.
    onDismissingChanged: {
        if (dismissing) {
            if (cover.opacity === 0)
                Qt.quit();
            else
                cover.opacity = 0;
        }
    }

    Rectangle {
        id: cover
        anchors.fill: parent
        color: "black"
        opacity: 0

        Behavior on opacity {
            NumberAnimation { duration: 250; easing.type: Easing.InOutQuad }
        }
        onOpacityChanged: {
            if (blackout.dismissing && opacity === 0)
                Qt.quit();
        }
    }

    function findOutput() {
        for (const output of Application.screens) {
            if (output.name === outputName)
                return output;
        }
        return null;
    }

    Component.onCompleted: {
        const output = findOutput();
        if (!output) {
            console.error("Display unavailable:", outputName);
            Qt.exit(1);
            return;
        }
        width = output.width;
        height = output.height;
        // Qt uses the initial position to choose the native Wayland output.
        x = output.virtualX;
        y = output.virtualY;
        visible = true;
        if (!dismissing)
            cover.opacity = 1;
    }

    Connections {
        target: Application
        function onScreensChanged() {
            // Never move the blackout onto another monitor after unplugging.
            if (!blackout.findOutput())
                Qt.quit();
        }
    }

    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.BlankCursor
        // Consume clicks so they cannot activate hidden windows.
        acceptedButtons: Qt.AllButtons
    }
}
