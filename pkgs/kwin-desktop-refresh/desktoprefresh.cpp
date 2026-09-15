// SPDX-License-Identifier: GPL-2.0-or-later
#include "desktoprefresh.h"
#include "policy.h"

#include "core/backendoutput.h"
#include "core/output.h"
#include "core/renderloop.h"
#include "effect/effecthandler.h"
#include "effect/effectwindow.h"

#include <KConfigGroup>

namespace KWin
{

DesktopRefreshEffect::DesktopRefreshEffect()
{
    connect(effects, &EffectsHandler::windowActivated, this, &DesktopRefreshEffect::updateState);
    connect(effects, &EffectsHandler::screenLockingChanged, this, &DesktopRefreshEffect::updateState);
    connect(effects, &EffectsHandler::screenAdded, this, [this](LogicalOutput *output) {
        watchOutput(output);
        updateState();
    });
    connect(effects, &EffectsHandler::screenRemoved, this, &DesktopRefreshEffect::updateState);
    for (auto *output : effects->screens()) {
        watchOutput(output);
    }

    // Catch changes to a focused window's title/class or output even when the
    // effect is paused. This timer checks policy only; frame pacing is KWin's job.
    m_stateCheck.setInterval(250);
    connect(&m_stateCheck, &QTimer::timeout, this, &DesktopRefreshEffect::updateState);
    m_stateCheck.start();
    reconfigure(ReconfigureAll);
}

void DesktopRefreshEffect::watchOutput(LogicalOutput *output)
{
    connect(output, &LogicalOutput::changed, this, &DesktopRefreshEffect::updateState);
    connect(output, &LogicalOutput::geometryChanged, this, &DesktopRefreshEffect::updateState);
    auto *backend = output->backendOutput();
    connect(backend, &BackendOutput::dpmsModeChanged, this, &DesktopRefreshEffect::updateState);
    connect(backend, &BackendOutput::enabledChanged, this, &DesktopRefreshEffect::updateState);
    connect(backend, &BackendOutput::vrrPolicyChanged, this, &DesktopRefreshEffect::updateState);
}

void DesktopRefreshEffect::reconfigure(ReconfigureFlags)
{
    const KConfigGroup config(effects->config(), QStringLiteral("Effect-desktoprefresh"));
    m_output = config.readEntry("Output", QStringLiteral("AW3926QW"));
    m_excludedClasses = config.readEntry("ExcludedClasses", QStringList{
        QStringLiteral("wowclassic.exe"), QStringLiteral("wow.exe")});
    m_excludedTitles = config.readEntry("ExcludedTitles", QStringList{QStringLiteral("World of Warcraft")});
    updateState();
}

void DesktopRefreshEffect::updateState()
{
    LogicalOutput *target = nullptr;
    for (auto *output : effects->screens()) {
        if (!m_output.isEmpty()
            && (output->name().compare(m_output, Qt::CaseInsensitive) == 0
                || output->model().compare(m_output, Qt::CaseInsensitive) == 0)) {
            target = output;
            break;
        }
    }

    const bool targetChanged = m_target != target;
    m_target = target;
    bool ready = false;
    bool excludedOnOutput = false;
    if (target) {
        const auto *backend = target->backendOutput();
        ready = backend->isEnabled() && backend->dpmsMode() == BackendOutput::DpmsMode::On
            && backend->vrrPolicy() == VrrPolicy::Always;
        const auto *window = effects->activeWindow();
        excludedOnOutput = window && window->screen() == target
            && DesktopRefresh::excluded(window->windowClass(), window->caption(),
                                        m_excludedClasses, m_excludedTitles);
    }

    const bool refreshing = DesktopRefresh::shouldRefresh(ready, effects->isScreenLocked(), excludedOnOutput);
    const bool start = refreshing && (!m_refreshing || targetChanged);
    m_refreshing = refreshing;
    if (start) {
        requestFrame();
    }
}

void DesktopRefreshEffect::requestFrame()
{
    if (m_refreshing && m_target) {
        const auto rect = m_target->geometry();
        // Damage one logical pixel without changing its content. KWin repaints
        // and presents the output; the rest of the desktop need not be redrawn.
        effects->addRepaint(rect.x(), rect.y(), 1, 1);
        // Effect damage goes through OutputLayer, which KWin can delay by 33 ms
        // when an animated window controls VRR. Keep the damage, then request
        // an output-wide frame without an item/layer so it bypasses that delay.
        // The render loop still enforces pending-frame and display timing limits.
        m_target->backendOutput()->renderLoop()->scheduleRepaint();
        ++m_requestedFrames;
    }
}

void DesktopRefreshEffect::paintScreen(const RenderTarget &target, const RenderViewport &viewport,
                                     int mask, const Region &region, LogicalOutput *screen)
{
    effects->paintScreen(target, viewport, mask, region, screen);
    m_paintedTarget = m_paintedTarget || (screen == m_target);
}

void DesktopRefreshEffect::postPaintScreen()
{
    effects->postPaintScreen();
    if (m_paintedTarget) {
        m_paintedTarget = false;
        requestFrame();
    }
}

bool DesktopRefreshEffect::isActive() const
{
    return m_refreshing && m_target;
}

bool DesktopRefreshEffect::blocksDirectScanout() const
{
    // Otherwise an opaque fullscreen app could bypass the repaint loop.
    return isActive();
}

QString DesktopRefreshEffect::debug(const QString &) const
{
    return QStringLiteral("version=1.0.1; output=%1; refreshing=%2; requestedFrames=%3; excludedClasses=%4; excludedTitles=%5")
        .arg(m_target ? m_target->name() : QStringLiteral("not found"))
        .arg(isActive()).arg(m_requestedFrames)
        .arg(m_excludedClasses.join(QLatin1Char(',')), m_excludedTitles.join(QLatin1Char(',')));
}

KWIN_EFFECT_FACTORY_SUPPORTED(DesktopRefreshEffect, "metadata.json",
                              return effects->isOpenGLCompositing();)

}

#include "desktoprefresh.moc"
