const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const vm = require("node:vm");
const { test } = require("node:test");

// Test the compiled package, including all patches, rather than copied methods.
const script = process.env.KROHNKITE_SCRIPT;
if (!script) throw new Error("Set KROHNKITE_SCRIPT to the built contents/code/script.js");

function setup() {
    const context = vm.createContext({
        LOG: null,
        print: (message) => { throw new Error(message); },
    });
    vm.runInContext(fs.readFileSync(script, "utf8"), context);
    const { KWinDriver, Rect } = vm.runInContext("({ KWinDriver, Rect })", context);
    const callbacks = {};
    const shortcuts = new Proxy({}, {
        get: (_, name) => () => ({
            activated: { connect: (callback) => { callbacks[name] = callback; } },
        }),
    });
    const native = [];
    const workspace = { activeWindow: null };
    for (const dir of ["Left", "Right", "Up", "Down"]) {
        workspace[`slotSwitchWindow${dir}`] = () => native.push(dir);
    }
    const api = { kwin: {}, workspace, shortcuts, timerRoot: {} };
    const driver = new KWinDriver(api);
    const surface = {};
    Object.defineProperty(driver, "currentSurface", { value: surface });
    const wrappers = new Map();
    driver.windowMap = { get: (client) => wrappers.get(client) ?? null };
    driver.bindShortcut();

    function tile(name, x, y, width = 800, height = 600) {
        const client = { name };
        const wrapper = {
            id: name,
            tiled: true,
            geometry: new Rect(x, y, width, height),
            actualGeometry: new Rect(x, y, width, height),
            timestamp: 0,
            visible: (target) => target === surface,
            window: { window: client },
        };
        wrappers.set(client, wrapper);
        driver.engine.windows.push(wrapper);
        return wrapper;
    }
    return { driver, callbacks, native, workspace, tile, api, KWinDriver };
}

test("H/J/K/L have one owner, with native actions unbound", () => {
    const root = path.resolve(__dirname, "..");
    const config = fs.readFileSync(`${root}/user/plasma/apps/krohnkite.nix`, "utf8");
    const native = fs.readFileSync(`${root}/user/plasma/shortcuts.nix`, "utf8");
    for (const [dir, key] of [["Left", "h"], ["Right", "l"], ["Down", "j"], ["Up", "k"]]) {
        assert.ok(config.includes(`kwin.KrohnkiteFocus${dir} = "Meta+${key}";`));
        assert.ok(native.includes(`kwin."Switch Window ${dir}" = [];`));
    }
});

for (const [direction, x, y] of [["Left", -800, 0], ["Right", 800, 0], ["Up", 0, -600], ["Down", 0, 600]]) {
    test(`${direction} focus selects the same tile as swap, even with unsettled client geometry`, () => {
        const { driver, callbacks, native, workspace, tile } = setup();
        const current = tile("Alacritty", 0, 0);
        const neighbor = tile("Helium", x, y);
        // Model a client configure still carrying the geometry from before a retile.
        current.actualGeometry = neighbor.geometry;
        neighbor.actualGeometry = current.geometry;
        workspace.activeWindow = current.window.window;
        let swapped;
        driver.engine.windows.swap = (source, target) => { swapped = [source, target]; };
        driver.engine.swapDirection(driver, direction.toLowerCase());
        callbacks[`getFocus${direction}`]();
        assert.deepEqual(swapped, [current, neighbor]);
        assert.equal(workspace.activeWindow, neighbor.window.window);
        assert.deepEqual(native, []);
    });
}

test("each edge delegates to the matching native direction, preserving wraparound", () => {
    const { callbacks, native, workspace, tile } = setup();
    workspace.activeWindow = tile("only tile", 0, 0).window.window;
    for (const dir of ["Left", "Right", "Up", "Down"]) callbacks[`getFocus${dir}`]();
    assert.deepEqual(native, ["Left", "Right", "Up", "Down"]);
});

test("floating and unmanaged windows retain native focus", () => {
    const { callbacks, native, workspace, tile } = setup();
    const floating = tile("floating", 0, 0);
    floating.tiled = false;
    tile("neighbor", 800, 0);
    workspace.activeWindow = floating.window.window;
    callbacks.getFocusRight();
    workspace.activeWindow = { name: "unmanaged" };
    callbacks.getFocusLeft();
    workspace.activeWindow = null;
    callbacks.getFocusUp();
    assert.deepEqual(native, ["Right", "Left", "Up"]);
});

test("minimized, off-desktop and off-screen tiles are excluded by the window store", () => {
    const { callbacks, native, workspace, tile } = setup();
    workspace.activeWindow = tile("current", 0, 0).window.window;
    const hidden = tile("not visible on this surface", 800, 0);
    hidden.visible = () => false;
    callbacks.getFocusRight();
    assert.deepEqual(native, ["Right"]);
});

test("stale focus callbacks neither focus tiles nor invoke native actions", () => {
    const { callbacks, native, workspace, tile, api, KWinDriver } = setup();
    const current = tile("current", 0, 0);
    tile("neighbor", 800, 0);
    workspace.activeWindow = current.window.window;
    new KWinDriver(api);
    callbacks.getFocusRight();
    callbacks.getFocusLeft();
    assert.equal(workspace.activeWindow, current.window.window);
    assert.deepEqual(native, []);
});
