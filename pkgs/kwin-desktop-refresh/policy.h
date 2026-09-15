#pragma once

#include <QRegularExpression>
#include <QStringList>

namespace DesktopRefresh
{

inline bool matches(const QString &value, const QStringList &patterns)
{
    for (const auto &pattern : patterns) {
        if (!pattern.isEmpty() && QRegularExpression(
                QRegularExpression::wildcardToRegularExpression(pattern),
                QRegularExpression::CaseInsensitiveOption).match(value).hasMatch()) {
            return true;
        }
    }
    return false;
}

inline bool excluded(const QString &windowClass, const QString &caption,
                     const QStringList &classes, const QStringList &titles)
{
    // X11 exposes both the instance and class, separated by a space.
    for (const auto &part : windowClass.split(QLatin1Char(' '), Qt::SkipEmptyParts)) {
        if (matches(part, classes)) {
            return true;
        }
    }
    return matches(caption, titles);
}

inline bool shouldRefresh(bool outputReady, bool locked, bool excludedOnOutput)
{
    return outputReady && !locked && !excludedOnOutput;
}

}
