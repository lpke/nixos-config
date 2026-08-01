const service = "dev.luke.XremapModeController";
const path = "/dev/luke/XremapModeController";
const iface = "dev.luke.XremapModeController";

function stringProperty(window, property) {
    if (!window || !(property in window) || window[property] === null) {
        return "";
    }
    return String(window[property]);
}

function notifyActiveWindow(window) {
    callDBus(
        service,
        path,
        iface,
        "SetActiveWindow",
        stringProperty(window, "caption"),
        stringProperty(window, "resourceClass"),
        stringProperty(window, "resourceName")
    );
}

if (workspace.windowList) {
    workspace.windowActivated.connect(notifyActiveWindow);
} else {
    workspace.clientActivated.connect(notifyActiveWindow);
}

notifyActiveWindow(workspace.activeWindow);
