#include "../policy.h"

#include <iostream>

int main()
{
    using namespace DesktopRefresh;
    int failures = 0;
    const auto check = [&failures](bool value, const char *name) {
        if (!value) {
            std::cerr << "FAIL: " << name << '\n';
            ++failures;
        }
    };
    const QStringList classes{QStringLiteral("wowclassic.exe"), QStringLiteral("steam_app_123*")};
    const QStringList titles{QStringLiteral("World of Warcraft")};
    check(excluded("wowclassic.exe WoWClassic.exe", "game", classes, titles), "Wine class, case insensitive");
    check(excluded("steam_app_3407247691 steam_app_3407247691", "World of Warcraft", classes, titles), "actual Steam WoW title");
    check(!excluded("steam_app_3407247691 steam_app_3407247691", "Battle.net", classes, titles), "launcher shares WoW class");
    check(excluded("steam_app_1234", "game", classes, titles), "explicit wildcard");
    check(!excluded("browser", "World of Warcraft - Wiki", classes, titles), "title must match entirely");
    check(!excluded("mywowclassic.exe", "game", classes, titles), "class must match entirely");
    check(!excluded("", "", {}, {}), "empty exclusions match nothing");
    check(shouldRefresh(true, false, false), "desktop or game on another output");
    check(!shouldRefresh(true, false, true), "focused excluded game on target");
    check(!shouldRefresh(true, true, false), "screen locked");
    check(!shouldRefresh(false, false, false), "missing, sleeping, disabled or non-Always output");
    return failures ? 1 : 0;
}
