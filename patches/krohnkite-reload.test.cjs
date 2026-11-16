const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');
const { test } = require('node:test');

function setup() {
    const settings = {};
    const signals = new Map();
    const timers = [];
    function signal(name) {
        if (!signals.has(name)) signals.set(name, {
            callbacks: new Set(),
            connect(callback) { this.callbacks.add(callback); },
            disconnect(callback) { this.callbacks.delete(callback); },
        });
        return signals.get(name);
    }
    const workspace = new Proxy({ stackingOrder: [], screens: [] }, {
        get(target, key) { return key in target ? target[key] : signal(key); },
    });
    const context = vm.createContext({ print() {}, popupDialog: { show() {} }, Qt: {
        createQmlObject() {
            const timer = { triggered: signal(`timer-${timers.length}`),
                start() {}, stop() { this.stopped = true; }, destroy() { this.destroyed = true; } };
            timers.push(timer);
            return timer;
        },
    } });
    vm.runInContext(fs.readFileSync(process.env.KROHNKITE_SCRIPT, 'utf8'), context);
    const classes = vm.runInContext('({KWinDriver, WindowClass, WindowState, Rect, DefaultGapsCfg})', context);
    const driver = new classes.KWinDriver({ workspace, timerRoot: {},
        kwin: { readConfig: (key, fallback) => settings[key] ?? fallback },
        shortcuts: new Proxy({}, { get: (_, name) => () => ({activated: signal(name)}) }),
    });
    driver.main();
    return { driver, workspace, settings, signals, timers, ...classes };
}

test('settings reload preserves engine, tile order, layout object and manual floating state', () => {
    const { driver, settings, WindowClass, WindowState, Rect, DefaultGapsCfg } = setup();
    const engine = driver.engine;
    const adapter = { id: 'manual', geometry: new Rect(10,20,500,400), minSize: {}, maxSize: {} };
    const manual = new WindowClass(adapter);
    manual.setState(WindowState.Floating);
    const tiles = engine.windows.list;
    tiles.push(manual);
    const surface = { id: 'desktop', ignore: false, output: { name: 'screen' },
        desktop: { id: 'one', name: 'One' }, activity: '' };
    const layout = engine.layouts.getCurrentLayout(surface);
    layout.masterRatio = 0.37;
    const oldGaps = DefaultGapsCfg.instance;
    settings.screenGapLeft = 25;
    settings.floatingClass = '1Password';
    settings.tileLayoutOrder = 12;
    assert.equal(driver.reloadConfig(), true);
    assert.equal(driver.engine, engine);
    assert.equal(engine.windows.list, tiles);
    assert.equal(tiles[0], manual);
    assert.equal(manual.state, WindowState.Floating);
    assert.equal(engine.layouts.getCurrentLayout(surface), layout);
    assert.equal(layout.masterRatio, 0.37);
    assert.notEqual(DefaultGapsCfg.instance, oldGaps);
    assert.equal(DefaultGapsCfg.instance.left, 25);
    assert.equal(driver.reloadConfig(), false);
});

test('surface and dock migrations are refused before altering runtime', () => {
    const { driver, settings, DefaultGapsCfg } = setup();
    const before = DefaultGapsCfg.instance;
    for (const key of ['layoutPerDesktop', 'layoutPerActivity', 'dockHGap']) {
        settings[key] = key.startsWith('layout') ? false : 42;
        assert.throws(() => driver.reloadConfig(), /requires an explicit Krohnkite restart/);
        assert.equal(DefaultGapsCfg.instance, before);
        delete settings[key];
    }
    assert.equal(driver.reloadConfig(), false);
});

test('reload refuses an active move or resize', () => {
    const { driver, workspace, settings } = setup();
    workspace.stackingOrder = [{move: true}];
    settings.screenGapLeft = 25;
    assert.throws(() => driver.reloadConfig(), /Finish moving or resizing/);
});

test('shutdown disconnects native and shortcut handlers and retires captured callbacks', () => {
    const { driver, signals } = setup();
    const oldShortcut = [...signals.get('getToggleFloat').callbacks][0];
    let calls = 0;
    driver.control.onShortcut = () => calls++;
    assert.ok(driver.connections.length > 20);
    driver.dispose();
    for (const signal of signals.values()) assert.equal(signal.callbacks.size, 0);
    oldShortcut();
    assert.equal(calls, 0);
    assert.throws(() => driver.reloadConfig(), /busy/);
    driver.dispose();
});

test('shutdown cancels deferred tiling work before a replacement can start', () => {
    const { driver, timers } = setup();
    let calls = 0;
    driver.setTimeout(() => calls++, 100);
    assert.equal(timers.length, 1);
    const lateCallback = [...timers[0].triggered.callbacks][0];
    driver.dispose();
    assert.equal(timers[0].stopped, true);
    assert.equal(timers[0].destroyed, true);
    lateCallback();
    assert.equal(calls, 0);
});
