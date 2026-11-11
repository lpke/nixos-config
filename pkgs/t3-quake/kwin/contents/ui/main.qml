import QtQuick
import org.kde.kwin 3.0
import "../code/controller.js" as Code

Item {
    id: root
    property var controller: null
    property bool pending: false
    property bool failed: false
    property double sentAt: 0
    property bool attached: false
    property bool ticking: false

    function sync() {
        attached = controller && controller.window !== null;
        ticking = controller && controller.mode !== "normal" && controller.mode !== "quake";
    }

    function exchange() {
        if (!controller || !controller.window || failed || pending) return;
        pending = true;
        sentAt = Date.now();
        bridge.arguments = [JSON.stringify(controller.message())];
        bridge.call();
    }
    function fail(reason) {
        if (failed) return;
        failed = true;
        controller.recover();
        sync();
        console.warn("T3 quake:", reason);
        stopFailedController.call();
        notification.call();
    }
    DBusCall {
        id: stopFailedController
        service: "org.freedesktop.systemd1"
        path: "/org/freedesktop/systemd1"
        dbusInterface: "org.freedesktop.systemd1.Manager"
        method: "StopUnit"
        arguments: ["t3-quake.service", "replace"]
    }
    DBusCall {
        id: stopController
        service: "io.github.lpke.T3Quake"
        path: "/T3Quake"
        dbusInterface: "io.github.lpke.T3Quake"
        method: "Stop"
    }
    DBusCall {
        id: bridge
        service: "io.github.lpke.T3Quake"
        path: "/T3Quake"
        dbusInterface: "io.github.lpke.T3Quake"
        method: "Exchange"
        onFinished: function(returnValue) {
            root.pending = false;
            if (root.failed || !root.attached) return;
            try { controller.command(JSON.parse(returnValue[0])); root.sync(); }
            catch (error) { root.fail(String(error)); }
        }
        onFailed: {
            root.pending = false;
            if (root.attached) root.fail("The window controller stopped responding.");
        }
    }
    DBusCall {
        id: tilerCheck
        service: "org.kde.KWin"
        path: "/Scripting"
        dbusInterface: "org.kde.kwin.Scripting"
        method: "isScriptLoaded"
        arguments: ["krohnkite"]
        onFinished: function(returnValue) { root.controller.tilerLoaded = returnValue[0]; }
    }
    DBusCall {
        id: notification
        service: "org.freedesktop.systemd1"
        path: "/org/freedesktop/systemd1"
        dbusInterface: "org.freedesktop.systemd1.Manager"
        method: "StartUnit"
        arguments: ["t3-quake-error.service", "replace"]
        onFailed: console.warn("T3 quake: Could not display the error notification. Run t3-quake restart.")
    }
    Timer {
        interval: 100; repeat: true; running: root.attached
        onTriggered: {
            if (root.pending && Date.now() - root.sentAt > 2500)
                root.fail("The window controller timed out.");
            root.exchange();
        }
    }
    Timer {
        interval: 16; repeat: true; running: root.ticking
        onTriggered: {
            try { root.controller.tick(Date.now()); root.sync(); }
            catch (error) { root.fail(String(error)); }
        }
    }
    Connections {
        target: Workspace
        function onWindowAdded(window) { root.controller.add(window); root.sync(); root.exchange(); }
        function onWindowRemoved(window) {
            var wasT3 = window === root.controller.window;
            root.controller.remove(window); root.sync();
            if (wasT3) {
                root.failed = false;
                root.pending = false;
                stopController.call();
            }
            else root.exchange();
        }
        function onWindowActivated(window) { root.controller.focus(window); root.sync(); }
        function onCurrentDesktopChanged() { root.controller.contextChanged(); root.sync(); }
        function onCurrentActivityChanged() { root.controller.contextChanged(); root.sync(); }
        function onScreensChanged() { root.controller.contextChanged(); root.sync(); }
    }
    Component.onCompleted: {
        controller = new Code.Controller(Workspace, KWin, function() { root.exchange(); });
        Workspace.stackingOrder.forEach(function(window) { controller.add(window); });
        sync();
        tilerCheck.call();
        exchange();
    }
    Component.onDestruction: { if (controller) controller.recover(); }
}
