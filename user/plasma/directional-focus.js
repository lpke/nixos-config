// Keep the shortcut owner alive when Krohnkite is disabled or unloaded.
function focusDirection(direction) {
    callDBus("org.kde.KWin", "/Scripting", "org.kde.kwin.Scripting",
        "isScriptLoaded", "krohnkite", function (loaded) {
            if (loaded) {
                callDBus("org.kde.kglobalaccel", "/component/kwin",
                    "org.kde.kglobalaccel.Component", "invokeShortcut",
                    "KrohnkiteFocus" + direction);
            } else {
                workspace["slotSwitchWindow" + direction]();
            }
        });
}

[
    ["Left", "H"],
    ["Down", "J"],
    ["Up", "K"],
    ["Right", "L"],
].forEach(function (binding) {
    const direction = binding[0];
    registerShortcut("DirectionalFocus" + direction, "Directional focus: " + direction,
        "Meta+" + binding[1], function () { focusDirection(direction); });
});
