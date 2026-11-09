import QtQuick
import QtQuick.Window
import org.kde.layershell as LayerShell

Window {
    id: overlay
    property bool covered: false
    property bool labeling: false
    property string monitorName: ""
    property real coverOpacity: 0
    property real labelOpacity: 0
    signal labelFinished()
    signal surfaceIdle()

    title: "Monitor control overlay"
    color: "transparent"
    flags: Qt.FramelessWindowHint | Qt.WindowDoesNotAcceptFocus
           | (covered || coverOpacity > 0 ? 0 : Qt.WindowTransparentForInput)
    visible: covered || coverOpacity > 0 || labeling

    LayerShell.Window.layer: LayerShell.Window.LayerOverlay
    LayerShell.Window.anchors: LayerShell.Window.AnchorTop | LayerShell.Window.AnchorBottom
        | LayerShell.Window.AnchorLeft | LayerShell.Window.AnchorRight
    LayerShell.Window.exclusionZone: -1
    LayerShell.Window.keyboardInteractivity: LayerShell.Window.KeyboardInteractivityNone
    LayerShell.Window.activateOnShow: false
    LayerShell.Window.scope: "monitor-control"
    LayerShell.Window.screen: targetScreen

    function showLabel() {
        fade.stop();
        labeling = true;
        labelOpacity = 1;
        hold.restart();
    }

    onCoveredChanged: {
        coverFade.stop();
        coverFade.from = coverOpacity;
        coverFade.to = covered ? 1 : 0;
        // Match Mac's 250 ms smoothstep, shortening interrupted reversals by
        // the remaining opacity distance rather than restarting a full fade.
        coverFade.duration = Math.round(250 * Math.abs(coverFade.to - coverOpacity));
        coverFade.start();
    }

    Rectangle { anchors.fill: parent; color: "black"; opacity: overlay.coverOpacity }

    NumberAnimation {
        id: coverFade
        objectName: "coverFade"
        target: overlay
        property: "coverOpacity"
        easing.type: Easing.BezierSpline
        easing.bezierCurve: [1 / 3, 0, 2 / 3, 1, 1, 1]
        onFinished: if (!overlay.covered && !overlay.labeling) overlay.surfaceIdle()
    }

    // The label shares its output-bound surface with the cover, so it is always
    // above that cover, including when a hotkey is pressed during the label.
    Rectangle {
        anchors.centerIn: parent
        width: Math.min(parent.width - 48, labelText.implicitWidth + 88)
        height: labelText.implicitHeight + 64
        color: "black"
        border.color: "white"
        border.width: 5
        opacity: overlay.labelOpacity
        visible: overlay.labeling
        Text {
            id: labelText
            anchors.centerIn: parent
            width: parent.width - 64
            text: overlay.monitorName
            textFormat: Text.PlainText
            color: "white"
            font.pixelSize: 44
            font.weight: Font.DemiBold
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.Wrap
        }
    }

    Timer { id: hold; interval: 5000; onTriggered: fade.start() }
    NumberAnimation {
        id: fade
        target: overlay
        property: "labelOpacity"
        to: 0
        duration: 250
        easing.type: Easing.BezierSpline
        easing.bezierCurve: [1 / 3, 0, 2 / 3, 1, 1, 1]
        onFinished: {
            overlay.labeling = false;
            overlay.labelFinished();
            if (!overlay.covered && overlay.coverOpacity === 0) overlay.surfaceIdle();
        }
    }
    MouseArea {
        anchors.fill: parent
        enabled: overlay.covered
        acceptedButtons: Qt.AllButtons
        hoverEnabled: true
        cursorShape: Qt.BlankCursor
    }
}
