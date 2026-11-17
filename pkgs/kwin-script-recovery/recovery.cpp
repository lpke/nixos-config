#include "effect/effect.h"
#include <QDBusConnection>
#include <dlfcn.h>
#include <QTimer>
#include <QFileInfo>

namespace KWin {
class ScriptRecoveryEffect : public Effect {
    Q_OBJECT
public:
    bool isActive() const override { return false; }
    QString debug(const QString &action) const override {
        if (action == "reset" && !pending) {
            pending = true;
            result = "pending";
            const QString mainScript = QFileInfo(QStringLiteral("/run/current-system/sw/share/kwin/scripts/krohnkite/contents/ui/main.qml")).canonicalFilePath();
            if (mainScript.isEmpty()) { pending = false; result = "installed Krohnkite not found"; return result; }
            QTimer::singleShot(0, const_cast<ScriptRecoveryEffect *>(this), [this, mainScript] {
                auto *old = QDBusConnection::sessionBus().objectRegisteredAt("/Scripting");
                // Scripting's header is not installed. Resolve its exported
                // factory for the pinned KWin ABI before changing live state.
                using Create = QObject *(*)(QObject *);
                const auto create = reinterpret_cast<Create>(dlsym(RTLD_DEFAULT, "_ZN4KWin9Scripting6createEP7QObject"));
                if (!create) { result = "unsupported KWin scripting ABI"; pending = false; return; }
                if (!old) { result = "no scripting engine"; pending = false; return; }
                QObject *owner = old->parent();
                delete old;
                // The existing compositor inherited immutable data paths at
                // login. Prefer the current system for future script enables.
                const QByteArray current = "/run/current-system/sw/share";
                const QByteArray previous = qgetenv("XDG_DATA_DIRS");
                qputenv("XDG_DATA_DIRS", current + ':' + previous);
                auto *fresh = create(owner);
                int identity = -1;
                QMetaObject::invokeMethod(fresh, "loadDeclarativeScript", Qt::DirectConnection,
                    Q_RETURN_ARG(int, identity), Q_ARG(QString, mainScript), Q_ARG(QString, QStringLiteral("krohnkite")));
                if (identity < 0) { result = "replacement script refused"; pending = false; return; }
                QMetaObject::invokeMethod(fresh, "start", Qt::DirectConnection);
                result = "restarted";
                pending = false;
            });
        }
        return result;
    }
private:
    mutable bool pending = false;
    mutable QString result = "ready-v2";
};
KWIN_EFFECT_FACTORY(ScriptRecoveryEffect, "metadata.json")
}
#include "recovery.moc"
