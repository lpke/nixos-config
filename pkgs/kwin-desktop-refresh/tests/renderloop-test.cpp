#include "core/renderloop.h"
#include "core/renderloop_p.h"

#include <QCoreApplication>
#include <iostream>

int main(int argc, char **argv)
{
    QCoreApplication app(argc, argv);
    KWin::RenderLoop loop(nullptr);
    auto *state = KWin::RenderLoopPrivate::get(&loop);
    loop.setRefreshRate(165000);
    loop.setPresentationMode(KWin::PresentationMode::AdaptiveSync);

    // Model the state during postPaintScreen: a frame is still in flight and
    // OutputLayer damage has been deferred by KWin's active-window VRR policy.
    // Use the real KWin scheduler, without a physical output or compositor.
    loop.prepareNewFrame();
    state->delayedVrrTimer.start(std::chrono::milliseconds(33), Qt::PreciseTimer, &loop);
    if (!state->delayedVrrTimer.isActive()) {
        std::cerr << "Failed to establish the delayed VRR request\n";
        return 1;
    }

    loop.scheduleRepaint();
    if (state->delayedVrrTimer.isActive() || !state->pendingReschedule) {
        std::cerr << "Output-wide repaint did not replace the delayed request\n";
        return 1;
    }
    if (state->pendingFrameCount != 1 || state->compositeTimer.isActive()) {
        std::cerr << "Repaint bypassed the in-flight frame limit\n";
        return 1;
    }

    // Multiple requests during one frame must coalesce, not enqueue frames.
    loop.scheduleRepaint();
    if (state->pendingFrameCount != 1 || !state->pendingReschedule) {
        std::cerr << "Repeated repaint requests did not coalesce\n";
        return 1;
    }
    return 0;
}
