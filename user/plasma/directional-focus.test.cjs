const assert = require("node:assert/strict");
const fs = require("node:fs");
const vm = require("node:vm");
const { test } = require("node:test");

function setup() {
    const shortcuts = new Map();
    const native = [];
    const calls = [];
    const pending = [];
    const workspace = {};
    for (const direction of ["Left", "Down", "Up", "Right"]) {
        workspace[`slotSwitchWindow${direction}`] = () => native.push(direction);
    }
    vm.runInNewContext(fs.readFileSync(`${__dirname}/directional-focus.js`, "utf8"), {
        workspace,
        registerShortcut: (name, text, key, callback) => {
            assert.ok(!shortcuts.has(name));
            shortcuts.set(name, { key, callback });
        },
        callDBus: (...args) => {
            calls.push(args.slice(0, typeof args.at(-1) === "function" ? -1 : undefined));
            if (args[3] === "isScriptLoaded") pending.push(args.at(-1));
        },
    });
    return { shortcuts, native, calls, pending };
}

for (const [direction, key] of [["Left", "H"], ["Down", "J"], ["Up", "K"], ["Right", "L"]]) {
    test(`${key} uses Krohnkite while loaded, native KWin after unload, and Krohnkite after reload`, () => {
        const { shortcuts, native, calls, pending } = setup();
        const shortcut = shortcuts.get(`DirectionalFocus${direction}`);
        assert.equal(shortcut.key, `Meta+${key}`);
        shortcut.callback();
        assert.deepEqual(calls.pop(), ["org.kde.KWin", "/Scripting",
            "org.kde.kwin.Scripting", "isScriptLoaded", "krohnkite"]);
        assert.deepEqual(native, []);
        pending.shift()(true);
        assert.deepEqual(calls.pop(), ["org.kde.kglobalaccel", "/component/kwin",
            "org.kde.kglobalaccel.Component", "invokeShortcut", `KrohnkiteFocus${direction}`]);

        shortcut.callback();
        pending.shift()(false);
        assert.deepEqual(native, [direction]);
        assert.equal(calls.at(-1)[3], "isScriptLoaded");

        shortcut.callback();
        pending.shift()(true);
        assert.deepEqual(calls.at(-1).slice(3), ["invokeShortcut", `KrohnkiteFocus${direction}`]);
        assert.deepEqual(native, [direction]);
        assert.equal(shortcuts.size, 4);
    });
}
