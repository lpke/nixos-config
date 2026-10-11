#define UNICODE
#define _UNICODE
#include <windows.h>
#include <stdio.h>
#include <wchar.h>

/* Wine can leave the installer at y=32767, outside every monitor. */
static BOOL CALLBACK show_installer(HWND window, LPARAM result) {
    wchar_t class_name[128], path[1024];
    DWORD process_id, length = 1024;
    GetClassNameW(window, class_name, 128);
    if (wcscmp(class_name, L"AdobeInstallerWindowClass")) return TRUE;

    GetWindowThreadProcessId(window, &process_id);
    HANDLE process = OpenProcess(PROCESS_QUERY_LIMITED_INFORMATION, FALSE, process_id);
    if (!process) return TRUE;
    BOOL found = QueryFullProcessImageNameW(process, 0, path, &length);
    CloseHandle(process);
    if (!found) return TRUE;
    const wchar_t *name = wcsrchr(path, L'\\');
    if (!name || _wcsicmp(name + 1, L"Set-up.exe")) return TRUE;

    RECT rect;
    GetWindowRect(window, &rect);
    BOOL offscreen = MonitorFromRect(&rect, MONITOR_DEFAULTTONULL) == NULL;
    /* Leave a window the user can already see or has minimized alone. */
    if (!IsIconic(window) && (!IsWindowVisible(window) || offscreen)) {
        MONITORINFO monitor = { .cbSize = sizeof(MONITORINFO) };
        if (!GetMonitorInfoW(MonitorFromWindow(window, MONITOR_DEFAULTTOPRIMARY), &monitor))
            return TRUE;
        RECT work = monitor.rcWork;
        int width = min(rect.right - rect.left, work.right - work.left);
        int height = min(rect.bottom - rect.top, work.bottom - work.top);
        int x = work.left + (work.right - work.left - width) / 2;
        int y = work.top + (work.bottom - work.top - height) / 2;
        if (!SetWindowPos(window, NULL, x, y, width, height,
                SWP_NOZORDER | SWP_NOACTIVATE | SWP_SHOWWINDOW | SWP_ASYNCWINDOWPOS))
            return TRUE;
        puts("Restored the off-screen Adobe installer window.");
    }
    *(BOOL *)result = TRUE;
    return FALSE;
}

int main(void) {
    /* Allow normal startup to show the window before applying the workaround. */
    Sleep(5000);
    for (unsigned int attempt = 0; attempt < 55; ++attempt) {
        BOOL found = FALSE;
        EnumWindows(show_installer, (LPARAM)&found);
        if (found) return 0;
        Sleep(1000);
    }
    fputs("Adobe installer window did not appear within 60 seconds.\n", stderr);
    return 1;
}
