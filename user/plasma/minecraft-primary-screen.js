"use strict";

workspace.windowAdded.connect(function (window) {
    if (!/^minecraft(?:\s|$)/i.test(String(window.resourceClass))) {
        return;
    }

    // screenOrder follows KDE's display priorities. screens is connector order.
    const primary = workspace.screenOrder[0];
    if (primary && window.output !== primary) {
        workspace.sendClientToScreen(window, primary);
    }
});
