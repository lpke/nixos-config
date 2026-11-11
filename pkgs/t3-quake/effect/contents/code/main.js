// A render-only slide: the real window stays on its target output throughout.
// Fractional clipping keeps it off the monitor above, including stacked outputs.
function changed(window, oldOpacity) {
    if (!/com\.t3tools\.T3Code|t3code/i.test(window.windowClass)) return;
    if (oldOpacity === 0.9921875) {
        if (window.quakeAnimation) cancel(window.quakeAnimation);
        if (window.quakeConcealment) cancel(window.quakeConcealment);
        window.quakeConcealment = set({window: window, duration: 1,
            type: Effect.Opacity, from: 0, to: 0});
        return;
    }
    var opening = oldOpacity === 0.99609375;
    var closing = oldOpacity === 0.998046875;
    if (!opening && !closing && oldOpacity !== 0.984375) return;
    if (window.quakeConcealment) {
        cancel(window.quakeConcealment);
        window.quakeConcealment = null;
    }
    if (!opening && !closing) return;
    if (window.quakeAnimation) cancel(window.quakeAnimation);
    var animation = {
        window: window,
        duration: 180,
        curve: QEasingCurve.OutCubic,
        animations: [
            {type: Effect.Translation, from: {value1: 0, value2: opening ? -window.height : 0},
                to: {value1: 0, value2: opening ? 0 : -window.height}},
            {type: Effect.Clip, from: {value1: 1, value2: opening ? 0 : 1},
                to: {value1: 1, value2: opening ? 1 : 0},
                sourceAnchor: Effect.Top, targetAnchor: Effect.Top}
        ]
    };
    // A completed closing slide must stay clipped until hidden sizing starts.
    // animate() drops its transform at completion and flashes the full window.
    window.quakeAnimation = closing ? set(animation) : animate(animation);
}
function watch(window) {
    if (/t3-quake-placeholder/.test(window.windowClass)) {
        window.setData(Effect.WindowAddedGrabRole, effect);
        window.setData(Effect.WindowClosedGrabRole, effect);
    }
    window.windowOpacityChanged.connect(changed);
}
effects.windowAdded.connect(watch);
effects.stackingOrder.forEach(watch);

effects.windowClosed.connect(function(window) {
    if (window.quakeAnimation) cancel(window.quakeAnimation);
    if (window.quakeConcealment) cancel(window.quakeConcealment);
});
