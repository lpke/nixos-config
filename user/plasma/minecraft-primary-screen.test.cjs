const assert = require("node:assert/strict");
const fs = require("node:fs");
const vm = require("node:vm");
const { test } = require("node:test");

function signal() {
    const callbacks = [];
    return {
        connect: (callback) => callbacks.push(callback),
        emit: (...args) => callbacks.forEach((callback) => callback(...args)),
    };
}

test("Minecraft starts on the current primary display and can then be moved freely", () => {
    const samsung = { name: "DP-1" };
    const third = { name: "DP-2" };
    const alienware = { name: "HDMI-A-1" };
    const windows = [];
    const moves = [];
    function window(resourceClass) {
        const result = {
            resourceClass, output: samsung,
            windowClassChanged: signal(), outputChanged: signal(),
            fullScreenChanged: signal(),
        };
        windows.push(result);
        return result;
    }
    const existing = window("Minecraft Minecraft Beta 1.7.3");
    const launcher = window("org.prismlauncher.PrismLauncher");
    const workspace = {
        screens: [samsung, third, alienware],
        screenOrder: [alienware, samsung, third],
        windowAdded: signal(), screenOrderChanged: signal(),
        windowList: () => windows,
        sendClientToScreen: (window, output) => {
            moves.push(window);
            window.output = output;
            window.outputChanged.emit();
        },
    };
    vm.runInNewContext(fs.readFileSync(`${__dirname}/minecraft-primary-screen.js`, "utf8"), { workspace });
    assert.equal(existing.output, samsung);
    workspace.windowAdded.emit(launcher);
    assert.equal(launcher.output, samsung);

    // The old rule's index 2 no longer exists after unplugging the third display.
    workspace.screens = [samsung, alienware];
    workspace.screenOrder = [alienware, samsung];
    workspace.screenOrderChanged.emit();
    const beta = window("Minecraft Beta 1.7.3");
    workspace.windowAdded.emit(beta);
    assert.equal(beta.output, alienware);

    const modern = window("minecraft");
    workspace.windowAdded.emit(modern);
    assert.equal(modern.output, alienware);
    modern.output = samsung;
    modern.outputChanged.emit();
    modern.fullScreenChanged.emit();
    modern.windowClassChanged.emit();
    assert.equal(modern.output, samsung);

    workspace.screenOrder = [];
    workspace.screenOrderChanged.emit();
    workspace.screenOrder = [samsung, alienware];
    workspace.screenOrderChanged.emit();
    assert.equal(beta.output, alienware);
    const nextLaunch = window("Minecraft Beta 1.7.3");
    nextLaunch.output = alienware;
    workspace.windowAdded.emit(nextLaunch);
    assert.equal(nextLaunch.output, samsung);
    assert.ok(!moves.includes(launcher));
    assert.equal(moves.length, 3);
});
