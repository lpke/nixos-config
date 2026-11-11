// A render-only slide: the real window stays on its target output throughout.
// Fractional clipping keeps it off the monitor above, including stacked outputs.
function changed(window, oldOpacity) {
    if (!/com\.t3tools\.T3Code|t3code/i.test(window.windowClass)) return;
    var opening = oldOpacity === 0.99609375;
    var closing = oldOpacity === 0.998046875;
    if (!opening && !closing) return;
    if (window.quakeAnimation) cancel(window.quakeAnimation);
    window.quakeAnimation = animate({
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
    });
}
function watch(window) {
    window.windowOpacityChanged.connect(changed);
}
effects.windowAdded.connect(watch);
effects.stackingOrder.forEach(watch);
