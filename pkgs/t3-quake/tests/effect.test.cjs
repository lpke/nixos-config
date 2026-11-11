const assert = require('node:assert/strict');
const { test } = require('node:test');
const fs = require('node:fs');
const vm = require('node:vm');
const path = require('node:path');

function setup() {
    function signal() {
        return {connect(fn) { this.handler = fn; }, emit(...args) { this.handler?.(...args); }};
    }
    const Effect = {WindowAddedGrabRole: 1, WindowClosedGrabRole: 2};
    const effects = {windowAdded: signal(), windowClosed: signal(), stackingOrder: []};
    const pointer = Symbol('quake native effect pointer');
    const owners = new Map([[Effect.WindowAddedGrabRole, Symbol('KDE opening effect')]]);
    let opening = true;
    const window = {windowClass: 'python3.13 t3-quake-placeholder',
        // A JS object written with setData isn't the native void* used by isGrabbed.
        setData(role, value) { owners.set(role, value); }, windowOpacityChanged: signal()};
    const effect = {
        grab(w, role, force) {
            assert.equal(w, window);
            if (owners.has(role) && !force) return false;
            owners.set(role, pointer);
            // Models KDE Scale's windowDataChanged handler checking isGrabbed().
            if (role === Effect.WindowAddedGrabRole) opening = false;
            return true;
        }
    };
    const context = vm.createContext({effects, effect, Effect});
    vm.runInContext(fs.readFileSync(path.join(__dirname, '../effect/contents/code/main.js'), 'utf8'), context);
    return {effects, window, owners, pointer, Effect, opening: () => opening};
}

test('native placeholder grabs cancel KDE opening animation and reserve closing animation', () => {
    const {effects, window, owners, pointer, Effect, opening} = setup();
    effects.windowAdded.emit(window);
    assert.equal(opening(), false, 'cancel the opening effect that can paint it on the old desktop');
    assert.equal(owners.get(Effect.WindowAddedGrabRole), pointer);
    assert.equal(owners.get(Effect.WindowClosedGrabRole), pointer);
});

test('other windows retain their standard KDE animations', () => {
    const {effects, window, opening} = setup();
    window.windowClass = 'peer peer';
    effects.windowAdded.emit(window);
    assert.equal(opening(), true);
});
