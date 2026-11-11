const assert = require('node:assert/strict');
const { test } = require('node:test');
const fs = require('node:fs');
const vm = require('node:vm');
const path = require('node:path');

function setup() {
    let now = 1000;
    const context = vm.createContext({Date: {now: () => now}});
    vm.runInContext(fs.readFileSync(path.join(__dirname, '../kwin/contents/code/controller.js'), 'utf8'), context);
    const desk = {id: 'home'}, away = {id: 'away'};
    function window(id, klass = 'peer') {
        return {internalId: id, resourceClass: klass, normalWindow: true, deleted: false,
            frameGeometry: {x: 800, y: 0, width: 800, height: 900},
            desktops: [desk], activities: [], opacity: 1, keepAbove: false, keepBelow: false,
            noBorder: false, skipTaskbar: false, skipPager: false, skipSwitcher: false,
            fullScreen: false, maximizeMode: 0, minimized: false, output: {},
            setMaximize(h, v) { this.maximizeMode = (h ? 1 : 0) | (v ? 2 : 0); },
            closeWindow() { this.deleted = true; }};
    }
    const t3 = window('t3', 'com.t3tools.T3Code'), peer = window('peer');
    const workspace = {activeWindow: peer, currentDesktop: desk, currentActivity: '',
        stackingOrder: [t3, peer],
        screens: [t3.output, peer.output], activeScreen: peer.output,
        sendClientToScreen: (w, output) => { w.output = output; },
        clientArea: () => ({x: 1600, y: 1000, width: 1600, height: 1000})};
    const c = new context.Controller(workspace, {MaximizeArea: 1}, () => {});
    c.add(t3);
    function tick(ms = 100) { now += ms; c.tick(now); }
    function prepare() {
        c.summon();
        const p = window('placeholder', 't3-quake-placeholder');
        p.caption = 'T3 quake · t3';
        p.opacity = 0.99951171875;
        p.output = t3.output;
        c.add(p);
        workspace.stackingOrder.push(p);
        tick(); tick();
        assert.equal(c.mode, 'sizing');
        return p;
    }
    function summon() {
        const p = prepare();
        for (let i = 0; i < 8; i++) tick();
        assert.equal(c.mode, 'quake');
        return p;
    }
    function settle() { for (let i = 0; i < 8; i++) tick(); }
    return {c, t3, peer, workspace, desk, away, tick, prepare, summon, settle};
}

test('borrows the same window, conceals sizing, and restores all original flags', () => {
    const {c, t3, workspace, peer, summon, settle} = setup();
    const before = JSON.stringify(t3);
    summon();
    assert.equal(workspace.activeWindow, t3);
    assert.equal(t3.noBorder, true);
    assert.equal(t3.skipTaskbar, true);
    c.returnHome(false);
    assert.equal(workspace.activeWindow, peer, 'keyboard focus returns before the close animation');
    settle();
    assert.equal(c.mode, 'normal');
    assert.equal(workspace.activeWindow, peer);
    assert.equal(JSON.stringify(t3), before);
});

test('placeholder focus returns T3 to the placeholder\'s new position', () => {
    const {c, t3, workspace, summon, settle} = setup();
    const p = summon();
    p.frameGeometry = {x: 0, y: 200, width: 400, height: 600};
    c.focus(p); settle();
    assert.equal(JSON.stringify(t3.frameGeometry), JSON.stringify(p.frameGeometry));
    assert.equal(workspace.activeWindow, t3);
    assert.equal(p.deleted, true);
});

test('dismiss from another desktop restores home without changing the current desktop', () => {
    const {c, t3, peer, workspace, away, summon, settle} = setup();
    workspace.currentDesktop = away;
    peer.desktops = [away];
    summon();
    c.returnHome(false); settle();
    assert.equal(workspace.currentDesktop, away);
    assert.equal(t3.desktops[0].id, 'home');
    assert.equal(workspace.activeWindow, peer);
});

test('lost focus dismisses, but a T3 transient does not', () => {
    const {c, t3, peer, summon, settle} = setup();
    summon();
    c.focus({transientFor: t3});
    assert.equal(c.mode, 'quake');
    c.focus(peer); settle();
    assert.equal(c.mode, 'normal');
});

test('failed placeholder setup leaves the original window recoverable', () => {
    const {c, t3, tick} = setup();
    c.summon();
    assert.equal(t3.opacity, 1);
    assert.throws(() => tick(3000), /placeholder/);
    c.recover();
    assert.equal(t3.opacity, 1);
    assert.equal(c.mode, 'normal');
});

test('controller failure while borrowed recovers immediately', () => {
    const {c, t3, summon} = setup();
    const p = summon();
    c.recover();
    assert.equal(c.mode, 'normal');
    assert.equal(t3.opacity, 1);
    assert.equal(t3.keepAbove, false);
    assert.equal(p.deleted, true);
});

test('T3 closes without trying to resize its deleted window', () => {
    const {c, t3, summon} = setup();
    const p = summon();
    t3.deleted = true;
    c.remove(t3);
    assert.equal(c.window, null);
    assert.equal(c.saved, null);
    assert.equal(p.deleted, true);
});

test('duplicate command delivery cannot toggle the window twice', () => {
    const {c} = setup();
    c.command({sequence: 1, action: 'toggle'});
    c.command({sequence: 1, action: 'toggle'});
    assert.equal(c.mode, 'placeholder');
});

test('a new T3 session accepts its new helper and ignores replies for the old window', () => {
    const {c, t3} = setup();
    c.command({sequence: 9, action: null, instance: 'old', id: 't3'});
    t3.deleted = true;
    c.remove(t3);
    const next = {...t3, deleted: false, internalId: 'next'};
    c.add(t3);
    assert.equal(c.window, null, 'retained deleted windows cannot become the new target');
    c.add(next);
    c.command({sequence: 9, action: 'toggle', instance: 'old', id: 't3'});
    assert.equal(c.mode, 'normal');
    c.command({sequence: 1, action: null, instance: 'new', id: 'next'});
    assert.equal(c.instance, 'new');
    assert.equal(c.lastCommand, 1);
});

test('a toggle during closing reopens after the old placeholder is removed', () => {
    const {c, summon, settle} = setup();
    summon();
    c.command({sequence: 1, action: 'toggle'});
    c.command({sequence: 2, action: 'toggle'});
    settle();
    assert.equal(c.mode, 'normal');
    c.command({sequence: 2, action: null});
    assert.equal(c.mode, 'placeholder');
});

test('recovery preserves maximized/fullscreen and original opacity', () => {
    const {c, t3, summon, settle} = setup();
    t3.maximizeMode = 3; t3.fullScreen = true; t3.opacity = .8;
    summon();
    c.returnHome(false); settle();
    assert.equal(t3.maximizeMode, 3);
    assert.equal(t3.fullScreen, true);
    assert.equal(t3.opacity, .8);
});

test('a newer focus choice cancels a pending summon', () => {
    for (const mode of ['placeholder', 'sizing']) {
        const {c, peer, workspace, prepare, settle} = setup();
        if (mode === 'sizing') prepare(); else c.summon();
        const next = {...peer, internalId: 'new-focus'};
        workspace.activeWindow = next;
        c.focus(next); settle();
        assert.equal(c.mode, 'normal');
        assert.equal(workspace.activeWindow, next);
    }
});

test('a placeholder activation before window-added does not cancel summon', () => {
    const {c, workspace, prepare, settle} = setup();
    c.summon();
    const early = {resourceClass: 't3-quake-placeholder', caption: 'T3 quake · t3'};
    workspace.activeWindow = early;
    c.focus(early);
    assert.equal(c.mode, 'placeholder');
    c.recover();
    prepare(); settle();
    assert.equal(c.mode, 'quake');
});

test('a context change cancels pending summon and recall activation', () => {
    for (const mode of ['placeholder', 'sizing', 'return-sizing']) {
        const {c, peer, workspace, away, prepare, summon, settle} = setup();
        if (mode === 'return-sizing') c.focus(summon());
        else if (mode === 'sizing') prepare();
        else c.summon();
        workspace.currentDesktop = away;
        peer.desktops = [away];
        workspace.activeWindow = peer;
        c.contextChanged(); settle();
        assert.equal(c.mode, 'normal');
        assert.equal(workspace.activeWindow, peer);
        assert.equal(workspace.currentDesktop, away);
    }
});

test('a newer focus choice cancels pending placeholder recall activation', () => {
    const {c, peer, workspace, summon, settle} = setup();
    c.focus(summon());
    assert.equal(c.mode, 'return-sizing');
    workspace.activeWindow = peer;
    c.focus(peer); settle();
    assert.equal(c.mode, 'normal');
    assert.equal(workspace.activeWindow, peer);
});


test('geometry and buffers settle before revealing a resized client', () => {
    const {c, t3, prepare, tick} = setup();
    prepare();
    assert.equal(t3.opacity, 0);
    tick(16);
    assert.equal(t3.keepAbove, false, 'concealment precedes native placement');
    tick(16);
    assert.equal(t3.keepAbove, true);
    t3.bufferGeometry = {...t3.frameGeometry};
    tick(16);
    tick(32);
    t3.bufferGeometry.width -= 1;
    tick(16);
    tick(32);
    assert.equal(t3.opacity, 0, 'a newer buffer restarts the settle interval');
    tick(32);
    assert.equal(c.mode, 'opening');
});

test('a placeholder on the wrong output is corrected before T3 leaves home', () => {
    const {c, t3, prepare, tick} = setup();
    c.summon();
    const p = {...t3, internalId: 'placeholder', resourceClass: 't3-quake-placeholder',
        caption: 'T3 quake · t3', opacity: 0.99951171875, output: {}};
    c.add(p);
    tick();
    assert.equal(p.output, t3.output);
    assert.equal(c.mode, 'placeholder');
    assert.equal(t3.opacity, 1);
});


test('a late output change preserves an already consumed tiler acknowledgment', () => {
    const {c, t3, workspace, tick, settle} = setup();
    c.summon();
    const p = {...t3, internalId: 'placeholder', resourceClass: 't3-quake-placeholder',
        caption: 'T3 quake · t3', opacity: 0.99951171875};
    c.add(p); workspace.stackingOrder.push(p);
    tick(16);
    assert.equal(p.opacity, 1, 'the tiler acknowledgment has been consumed');
    p.output = {};
    tick(16);
    assert.equal(p.output, t3.output);
    tick(16);
    assert.equal(c.mode, 'placeholder', 'the corrected output must settle');
    settle();
    assert.equal(c.mode, 'quake');
});
