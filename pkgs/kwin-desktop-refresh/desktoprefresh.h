#pragma once

#include "effect/effect.h"

#include <QPointer>
#include <QStringList>
#include <QTimer>

namespace KWin
{

class DesktopRefreshEffect : public Effect
{
    Q_OBJECT

public:
    DesktopRefreshEffect();
    void reconfigure(ReconfigureFlags flags) override;
    void paintScreen(const RenderTarget &target, const RenderViewport &viewport,
                     int mask, const Region &region, LogicalOutput *screen) override;
    void postPaintScreen() override;
    bool isActive() const override;
    bool blocksDirectScanout() const override;
    QString debug(const QString &parameter) const override;

private:
    void watchOutput(LogicalOutput *output);
    void updateState();
    void requestFrame();

    QString m_output;
    QStringList m_excludedClasses;
    QStringList m_excludedTitles;
    QPointer<LogicalOutput> m_target;
    bool m_refreshing = false;
    bool m_paintedTarget = false;
    quint64 m_requestedFrames = 0;
    QTimer m_stateCheck;
};

}
