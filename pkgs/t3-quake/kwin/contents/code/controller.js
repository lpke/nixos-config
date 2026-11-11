// One T3 window, with all restoration state owned by the compositor.
function rect(value) {
    return {x: value.x, y: value.y, width: value.width, height: value.height};
}
function alive(window) { return window && !window.deleted; }
function isT3(window) {
    return window.normalWindow && /^(t3code|com\.t3tools\.t3code)$/i.test(String(window.resourceClass));
}
function Controller(workspace, kwin, changed) {
    this.workspace = workspace;
    this.kwin = kwin;
    this.changed = changed;
    this.window = null;
    this.placeholder = null;
    this.mode = "normal";
    this.saved = null;
    this.request = null;
    this.deadline = 0;
    this.previous = null;
    this.wantReturnFocus = false;
    this.target = null;
    this.sequence = 0;
    this.lastCommand = 0;
    this.instance = null;
    this.tilerLoaded = true;
    this.reopen = false;
}
Controller.prototype.add = function(window) {
    if (!this.window && alive(window) && isT3(window)) this.window = window;
    if (this.window && String(window.resourceClass) === "t3-quake-placeholder" &&
        window.caption === "T3 quake · " + String(this.window.internalId)) {
        this.placeholder = window;
    }
};
Controller.prototype.remove = function(window) {
    if (window === this.window) {
        this.recover();
        this.window = null;
        this.instance = null;
        this.lastCommand = 0;
        this.request = {quit: true};
        this.changed();
    } else if (window === this.placeholder) {
        this.placeholder = null;
        if (this.mode !== "normal") this.returnHome(false);
    }
};
Controller.prototype.message = function() {
    var result = {id: String(this.window.internalId), mode: this.mode, request: this.request};
    this.request = null;
    return result;
};
Controller.prototype.command = function(command) {
    if (command && command.id && (!this.window || command.id !== String(this.window.internalId))) return;
    if (command && command.error) throw new Error(command.error);
    if (command && command.instance) {
        if (this.instance && this.instance !== command.instance)
            throw new Error("The window controller restarted unexpectedly.");
        this.instance = command.instance;
    }
    if (command && command.sequence > this.lastCommand) {
        this.lastCommand = command.sequence;
        if (command.action === "toggle") {
            if (this.mode === "closing" || this.mode === "return-sizing") this.reopen = !this.reopen;
            else if (this.mode === "normal") this.reopen = !this.reopen;
            else this.returnHome(false);
        } else if (command.action === "restore") {
            this.reopen = false;
            this.returnHome(false);
        }
    }
    // Let the old placeholder leave the compositor before borrowing its slot again.
    if (this.mode === "normal" && this.reopen && !this.workspace.stackingOrder.some(function(w) {
        return alive(w) && String(w.resourceClass) === "t3-quake-placeholder";
    })) {
        this.reopen = false;
        this.summon();
    }
};
Controller.prototype.summon = function() {
    var w = this.window;
    if (!alive(w) || this.mode !== "normal") return;
    this.previous = this.workspace.activeWindow === w ? null : this.workspace.activeWindow;
    this.saved = {geometry: rect(w.frameGeometry), desktops: w.desktops.slice(), activities: w.activities.slice(),
        above: w.keepAbove, below: w.keepBelow, border: w.noBorder, taskbar: w.skipTaskbar,
        pager: w.skipPager, switcher: w.skipSwitcher, opacity: w.opacity, fullscreen: w.fullScreen,
        maximize: w.maximizeMode, minimized: w.minimized, output: w.output};
    var output = this.workspace.activeWindow ? this.workspace.activeWindow.output : this.workspace.activeScreen;
    this.targetOutput = output;
    var area = this.workspace.clientArea(this.kwin.MaximizeArea, output, this.workspace.currentDesktop);
    this.target = {x: Math.round(area.x + area.width * .2), y: area.y,
        width: Math.round(area.width * .6), height: Math.round(area.height * .6)};
    this.mode = "placeholder";
    this.deadline = Date.now() + 2500;
    this.request = {placeholder: {id: String(w.internalId), geometry: this.saved.geometry}};
    this.changed();
};
Controller.prototype.tick = function(now) {
    var w = this.window;
    if (!alive(w) || !this.saved) return;
    if (this.mode === "placeholder") {
        if (now > this.deadline) throw new Error("The tile placeholder did not appear.");
        if (!alive(this.placeholder)) return;
        if (this.tilerLoaded && this.placeholder.opacity !== 0.99951171875 && !this.placeholderReady)
            return;
        // Allow Krohnkite's window-added handler to replace its tile first.
        if (!this.placeholderReady) {
            this.placeholderReady = now + 32;
            this.placeholder.opacity = 1;
            return;
        }
        if (now < this.placeholderReady) return;
        w.opacity = 0;
        w.fullScreen = false;
        w.setMaximize(false, false);
        w.desktops = [this.workspace.currentDesktop];
        w.activities = [this.workspace.currentActivity];
        w.keepBelow = false;
        w.keepAbove = true;
        w.noBorder = true;
        w.skipTaskbar = true;
        w.skipPager = true;
        w.skipSwitcher = true;
        w.minimized = false;
        this.workspace.sendClientToScreen(w, this.targetOutput);
        w.frameGeometry = this.target;
        this.mode = "sizing";
        this.deadline = now + 2500;
        this.readyAt = 0;
    } else if (this.mode === "sizing" || this.mode === "return-sizing") {
        var goal = this.mode === "sizing" ? this.target : this.home;
        var size = w.frameGeometry;
        if (Math.abs(size.x - goal.x) < 2 && Math.abs(size.y - goal.y) < 2 &&
            Math.abs(size.width - goal.width) < 2 && Math.abs(size.height - goal.height) < 2) {
            if (!this.readyAt) this.readyAt = now + 32;
            if (now < this.readyAt) return;
            if (this.mode === "sizing") {
                this.mode = "opening";
                this.started = now;
                w.opacity = 0.99609375;
                w.opacity = this.saved.opacity;
                this.workspace.activeWindow = w;
            } else this.finishReturn();
        } else if (now > this.deadline) throw new Error("T3 did not confirm its new window size.");
    } else if (this.mode === "opening") {
        var fraction = Math.min(1, (now - this.started) / 180);
        if (fraction === 1) this.mode = "quake";
    } else if (this.mode === "closing" && now - this.started >= 180) {
        this.beginReturn();
    }
};
Controller.prototype.focus = function(window) {
    if (this.mode === "normal") return;
    // Wayland may activate the helper before its window-added signal arrives.
    if ((this.mode === "placeholder" || this.mode === "sizing") && window &&
        String(window.resourceClass) === "t3-quake-placeholder" &&
        window.caption === "T3 quake · " + String(this.window.internalId)) return;
    var unrelated = window && window !== this.window && window !== this.placeholder &&
        window.transientFor !== this.window;
    if (unrelated) this.wantReturnFocus = false;
    if (this.mode === "return-sizing") return;
    if (window === this.placeholder) this.returnHome(true);
    else if (unrelated) this.returnHome(false);
};
Controller.prototype.contextChanged = function() {
    this.wantReturnFocus = false;
    this.returnHome(false);
};
Controller.prototype.returnHome = function(focus) {
    if (!this.saved) return;
    if (this.mode === "return-sizing" || this.mode === "closing") {
        this.wantReturnFocus = this.wantReturnFocus || focus;
        return;
    }
    this.wantReturnFocus = focus;
    if (!focus && (this.mode === "quake" || this.mode === "opening")) {
        this.mode = "closing";
        this.started = Date.now();
        this.window.opacity = 0.998046875;
        this.window.opacity = this.saved.opacity;
        this.restorePreviousFocus();
    } else this.beginReturn();
};
Controller.prototype.restorePreviousFocus = function() {
    var previous = this.previous;
    if (this.workspace.activeWindow === this.window && alive(previous) &&
        (previous.onAllDesktops || previous.desktops.indexOf(this.workspace.currentDesktop) >= 0) &&
        (!previous.activities.length || previous.activities.indexOf(this.workspace.currentActivity) >= 0))
        this.workspace.activeWindow = previous;
};
Controller.prototype.beginReturn = function() {
    var w = this.window;
    w.opacity = 0;
    this.home = alive(this.placeholder) ? rect(this.placeholder.frameGeometry) : this.saved.geometry;
    w.keepAbove = this.saved.above;
    w.keepBelow = this.saved.below;
    w.noBorder = this.saved.border;
    w.desktops = alive(this.placeholder) ? this.placeholder.desktops : this.saved.desktops;
    w.activities = alive(this.placeholder) ? this.placeholder.activities : this.saved.activities;
    var output = alive(this.placeholder) ? this.placeholder.output : this.saved.output;
    if (this.workspace.screens.indexOf(output) < 0) output = this.workspace.activeScreen;
    this.workspace.sendClientToScreen(w, output);
    w.frameGeometry = this.home;
    // Maximized/fullscreen geometry can only be confirmed after restoring its mode.
    w.setMaximize(Boolean(this.saved.maximize & 1), Boolean(this.saved.maximize & 2));
    w.fullScreen = this.saved.fullscreen;
    this.mode = "return-sizing";
    this.deadline = Date.now() + 2500;
    this.readyAt = 0;
    // Explicit focus on a same-desktop application never changes desktop/activity.
    if (!this.wantReturnFocus) this.restorePreviousFocus();
};
Controller.prototype.finishReturn = function() {
    var w = this.window, saved = this.saved, focus = this.wantReturnFocus;
    this.mode = "normal";
    this.saved = null;
    w.skipTaskbar = saved.taskbar;
    w.skipPager = saved.pager;
    w.skipSwitcher = saved.switcher;
    if (alive(this.placeholder)) {
        this.placeholder.opacity = 0;
        this.placeholder.closeWindow();
    }
    this.placeholder = null;
    this.placeholderReady = 0;
    w.minimized = saved.minimized;
    w.opacity = saved.opacity;
    if (focus) this.workspace.activeWindow = w;
};
Controller.prototype.recover = function() {
    if (this.saved && alive(this.window)) {
        this.wantReturnFocus = false;
        this.beginReturn();
        this.finishReturn();
    } else if (alive(this.placeholder)) this.placeholder.closeWindow();
    this.mode = "normal";
    this.saved = null;
    this.placeholder = null;
    this.request = null;
    this.placeholderReady = 0;
    this.reopen = false;
};
