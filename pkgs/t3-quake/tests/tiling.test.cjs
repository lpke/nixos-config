const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');
const { test } = require('node:test');

if (!process.env.KROHNKITE_SCRIPT) throw new Error('Set KROHNKITE_SCRIPT to the built, patched script');
function setup() {
    const context = vm.createContext({print() {}});
    vm.runInContext(fs.readFileSync(process.env.KROHNKITE_SCRIPT, 'utf8'), context);
    const {KWinDriver, WindowState, WindowClass} = vm.runInContext('({KWinDriver, WindowState, WindowClass})', context);
    const driver = new KWinDriver({kwin: {}, workspace: {
        sendClientToScreen: (client, output) => { client.output = output; }
    }, shortcuts: {}, timerRoot: {}});
    driver.engine.arrange = () => {};
    const origin = {id: 't3-id', internalState: WindowState.Tiled, geometry: {width: 640},
        floatGeometry: {width: 800}, weightMap: {home: 1.2},
        window: {window: {resourceClass: 'com.t3tools.T3Code', desktops: ['home'], activities: [],
            frameGeometry: {width: 640}, deleted: false}}};
    const placeholder = {id: 'placeholder', window: {window: {
        resourceClass: 't3-quake-placeholder', caption: 'T3 quake · t3-id'}}};
    for (const window of [origin, placeholder]) {
        window.copyLayoutStateFrom = WindowClass.prototype.copyLayoutStateFrom;
        window.setState = WindowClass.prototype.setState;
    }
    const peer = {id: 'peer'};
    driver.engine.windows.list = [peer, origin];
    return {driver, origin, placeholder, peer, WindowState, context};
}

test('substitution preserves tile order and acknowledges only a genuine T3 target', () => {
    const {driver, origin, placeholder, peer, WindowState} = setup();
    assert.equal(driver.borrowT3Tile(placeholder), true);
    assert.equal(driver.engine.windows.list[0], peer);
    assert.equal(driver.engine.windows.list[1], placeholder);
    assert.equal(origin.internalState, WindowState.Unmanaged);
    assert.equal(placeholder.window.window.opacity, 0.99951171875);
    placeholder.weightMap.home = 2;
    driver.engine.windows.swap(placeholder, peer);
    assert.equal(driver.returnT3Tile(placeholder), true);
    assert.equal(driver.engine.windows.list[0], origin);
    assert.equal(driver.engine.windows.list[1], peer);
    assert.equal(origin.weightMap.home, 2);
    assert.equal(origin.internalState, WindowState.Tiled);
});

test('floating windows retain floating state', () => {
    const {driver, origin, placeholder, WindowState} = setup();
    origin.internalState = WindowState.Floating;
    driver.borrowT3Tile(placeholder);
    assert.equal(placeholder.internalState, WindowState.Floating);
    driver.returnT3Tile(placeholder);
    assert.equal(origin.internalState, WindowState.Floating);
});

test('closing T3 while borrowed cannot resurrect a deleted window', () => {
    const {driver, origin, placeholder, peer} = setup();
    driver.borrowT3Tile(placeholder);
    origin.window.window.deleted = true;
    driver.returnT3Tile(placeholder);
    assert.equal(driver.engine.windows.length, 1);
    assert.equal(driver.engine.windows.at(0), peer);
});

test('a placeholder never replaces an unrelated window', () => {
    const {driver, origin, placeholder} = setup();
    origin.window.window.resourceClass = 'other-app';
    assert.equal(driver.borrowT3Tile(placeholder), false);
    assert.equal(driver.engine.windows.at(1), origin);
});

test('the actual Columns arrangement preserves column membership and geometry', () => {
    const {driver, context, WindowState} = setup();
    const {WindowClass, Rect, ColumnsLayout, ColumnLayout, TilingEngine} = vm.runInContext(
        'CONFIG = {columnsLayoutInitialAngle: 0, columnsBalanced: false,' +
        'dockSurfacesConfig: [], dockWindowClassConfig: [], dockOrder: [0,0,0,0]};' +
        '({WindowClass, Rect, ColumnsLayout, ColumnLayout, TilingEngine})', context);
    const surface = {id: 'home', workingArea: new Rect(0, 0, 1600, 1000),
        getParams: () => ['output', '', 'home']};
    function window(id, resourceClass) {
        const backend = {id, geometry: surface.workingArea, surface, minSize: {width: 1, height: 1},
            maxSize: {width: 10000, height: 10000}, visible: () => true,
            window: {resourceClass, desktops: ['home'], activities: [], deleted: false}};
        backend.commit = geometry => {
            if (geometry) backend.window.frameGeometry = backend.geometry = geometry;
        };
        const result = new WindowClass(backend);
        result.setState(WindowState.Tiled);
        return result;
    }
    const origin = window('t3-id', 'com.t3tools.T3Code'), peer = window('peer', 'peer');
    const placeholder = window('placeholder', 't3-quake-placeholder');
    placeholder.window.window.caption = 'T3 quake · t3-id';
    const columns = new ColumnsLayout();
    columns.parts = [new ColumnLayout(), new ColumnLayout()];
    columns.parts[0].windowIds.add(peer.id);
    columns.parts[1].windowIds.add(origin.id);
    columns.columnsConfiguration = [1, 1];
    Object.defineProperty(driver, 'screens', {value: [surface]});
    driver.engine.windows.list = [peer, origin];
    driver.engine.layouts.getCurrentLayout = () => columns;
    driver.engine.getGaps = () => ({left: 0, right: 0, top: 0, bottom: 0, between: 8});
    driver.engine.arrange = TilingEngine.prototype.arrange;
    driver.engine.arrange(driver);
    const before = JSON.stringify([peer.geometry, origin.geometry]);
    assert.equal(columns.columns.length, 2);
    driver.borrowT3Tile(placeholder);
    assert.equal(columns.columns.length, 2);
    assert.equal(JSON.stringify([peer.geometry, placeholder.geometry]), before);
    driver.returnT3Tile(placeholder);
    assert.equal(columns.columns.length, 2);
    assert.equal(JSON.stringify([peer.geometry, origin.geometry]), before);
});


test('fractional T3 client sizes do not trigger an endless native configure loop', () => {
    const {context} = setup();
    const {KWinWindow, Rect} = vm.runInContext('CONFIG = {}; KWINCONFIG = {}; Qt = {rect: (x,y,width,height) => ({x,y,width,height})}; ({KWinWindow, Rect})', context);
    let writes = 0;
    const native = {resourceClass: 'com.t3tools.T3Code', deleted: false,
        frameGeometry: {x: 0, y: 25, width: 1638.4, height: 1702.4},
        resizeable: true, minSize: {width: 1, height: 1}, maxSize: {width: 10000, height: 10000}};
    const actual = native.frameGeometry;
    Object.defineProperty(native, 'frameGeometry', {get: () => actual, set() {writes++;}});
    const wrapper = Object.create(KWinWindow.prototype);
    wrapper.window = native;
    wrapper.commit(new Rect(0, 25, 1638, 1702));
    assert.equal(writes, 0);
    wrapper.commit(new Rect(100, 25, 1200, 900));
    assert.equal(writes, 1, 'real moves and resizes still reach the client');
});
