# Photoshop on lpnix

Verified on 2026-10-11: Photoshop 27.11.0 opens, edits layers and text, saves and
reopens PSD files, and exports PNG files. Creative Cloud opens and loads its
Home and Apps pages. Luke completed Adobe sign-in and purchased the subscription.
Photoshop reports a subscription license, GPU acceleration and OpenCL enabled
on the NVIDIA RTX 3090. Tests used private KDE sessions at 5120×2160 and 4096×1728.

## Launch and adjust

Use **Adobe Photoshop** or **Adobe Creative Cloud** in KDE's application menu.
Their icons come from the installed Adobe executables. The Photoshop desktop
entry and `adobe-photoshop run` use the same launcher.
Desktop entries resolve the installed command through Plasma's `PATH`, so a
cached entry cannot pin an older launcher after a Nix profile update.

```sh
adobe-photoshop run                 # Photoshop; optional file paths follow
adobe-creative-cloud                # Creative Cloud desktop app
adobe-photoshop cloud               # Same Creative Cloud command
adobe-photoshop scale 150           # UI size, 100–300 percent; default 150
adobe-photoshop file-picker kde     # Native KDE picker; use wine to switch back
adobe-photoshop stop                # Close all Adobe apps/services; save work first
adobe-photoshop repair              # Restore compatibility fonts and runtimes
adobe-photoshop status
adobe-photoshop --help              # -h also works
adobe-creative-cloud --help
```

After changing scale, save your work, run `adobe-photoshop stop`, then relaunch.
Closing visible windows alone leaves Wine background services alive with the
previous DPI. The affected running window reported 96 DPI even though the
registry said 144; a fresh session correctly reports 192 at 200%. `setup` remains available
for downloading and running Adobe's official Creative Cloud installer. Browser
sign-in uses `xdg-open`, so it follows the desktop's default browser, currently
Helium. The launcher does not change browser associations.
Wine errors are retained in the run log by default. An explicit `WINEDEBUG`
environment variable overrides the default `-all,err+all` channel selection.

## Repairs after installation

| Symptom | Cause and repair |
| --- | --- |
| Photoshop showed an empty, unresponsive shell | The prefix had no Windows fonts. Photoshop's DirectWrite UI requires the Segoe UI family. The package uses Microsoft's open Selawik font with the family names rewritten by AdobeWine's upstream tool, then registers the fonts. |
| AdobeNotificationHelper repeatedly crashed | Wine's builtin 32-bit `msvcp140.dll` lacks `GetNextAsyncId`. Adobe's redistributable installer skipped replacement because Wine reported a newer version. Extract Microsoft's matching x86 and x64 Visual C++ 14.51.36247 runtime DLL sets and select native DLLs. |
| File menus were enormous and blank | The prefix contained `MenuHeight=6750318`. Set it to `-285` twips, which respects DPI scaling. |
| Canvas rendering failed | Install DXVK 3.1.1 and vkd3d-proton 3.0.1. Reuse Microsoft's `d3dcompiler_47.dll` from Adobe's installed CEF directory. Include AdobeWine's D3D12 compute shim. |
| Creative Cloud pages stalled | Launch with the upstream `--disable-gpu-vsync` workaround. |
| Small text on the main monitor | Set Wine's DPI through the scale command. The default is 150%, or 144 DPI, as requested after the 200% tests. A complete Adobe session restart is required. |
| Creative Cloud resisted resizing | It advertised identical minimum and maximum sizes. A targeted KWin rule permits resizing and Krohnkite tiling. |
| Photoshop stopped tiling after restart or resizing | Wine marked its screen-sized startup window as fullscreen. A KWin rule keeps its normal window outside fullscreen, including after resizing. Photoshop's own screen modes remain available, but compositor fullscreen is intentionally blocked for tiling stability. |
| Resizing could leave a blank or frozen window | Remove the duplicate window-manager decoration, prevent Wine from switching the window into compositor fullscreen, and keep the optional offscreen repaint under one nonblocking surface-lock acquisition. The original guard released this lock before presenting and releasing surface references, allowing a later blocking acquisition to deadlock against the GPU thread. |
| KDE save format did not match the filename | The upstream portal patch ignored the returned `current_filter`. Pass it back into Wine and notify Adobe before accepting the save. Verified by switching PNG to PSD and reopening the resulting layered PSD. |
| Save for Web returned to its preview without exporting | The forced KDE portal bypassed the legacy Save Optimized As dialog's Windows hook and custom template. Such dialogs now automatically use Wine's complete dialog so Adobe receives its callbacks and custom export options. Standard dialogs retain KDE integration. |
| Document-tab tooltips stayed on screen after leaving a tab | Photoshop deletes the active tracking tool before deactivating its tooltip. Wine hid only ordinary tooltips during deletion, then discarded the tracking index, leaving the popup visible. Hide the active tracking tooltip before deleting its tool, in both common-controls versions. |

The preparation step also registers `windows.ui.dll`, sets Photoshop's Windows
version to Windows 10, keeps WebView2's D3D11/DXGI implementation builtin for
DirectComposition, and enables Wine's managed X11 windows without a second window-manager caption.
The duplicate caption clipped the blue Wine title bar beneath the KDE title.
Wine's remaining dialog captions use neutral gray colors. Changes
apply only to the dedicated Adobe prefix. Existing DLLs and relevant registry
keys are backed up before replacement. DLL files are replaced atomically so
existing background processes retain their loaded copies.

The document-tab tooltip fix rebuilds Wine's `comctl32.dll` and
`comctl32_v6.dll`. It preserves tooltips and needs no background helper or
Photoshop preference change. These are builtin Wine modules, so the updated
launcher supplies them without replacing the prefix's DLL files. Newly started
Photoshop processes use the fix; already running processes retain their loaded
modules.

## Verification and limits

- The final package passed Nix's shell checks and repeated prefix repair.
- The full `nixosConfigurations.lpnix.config.system.build.toplevel` build passed.
- A Photoshop script created a 640×480 RGB document with a background, blue
  rectangle and editable text. It saved a PSD, closed and reopened it, checked
  all three layers and the text layer type, then exported PNG. Independent
  image inspection confirmed dimensions and expected pixel colors.
- Restarted Photoshop and repeated the document test with the final package.
- Photoshop's own system information reports `useGPU=1`, `useOpenCL=1`, a
  24 GB RTX 3090, successful GPU detection and display scale 1.5 in the initial run. The latest Windows API probe confirms system and Photoshop window DPI both equal 192 at 200%.
- Clicked Photoshop menus and dialogs, checked canvas repaint, resized both
  applications and tested the installed Krohnkite configuration in private KDE.
- The repaired AdobeNotificationHelper ran without its previous exception.
- Both launchers support `--help` and `-h`; the system `help` text lists them.
- KDE's application cache was refreshed after installing the desktop entries.
- The native KDE picker opened from Photoshop without a test-only portal override.
  It starts at Home for Wine-internal paths and retains useful host-directory history.
  A separate Windows common-dialog probe also confirmed the C-drive-root fallback.
- Saved and reopened a three-layer PSD through KDE, including editable text.
  Independently checked PSD file signatures and a 640×480 PNG export.
- The October 11 repaint module passed 60 resize cycles between half-screen,
  floating, wide and screen-sized windows. Photoshop then answered COM queries
  and exported the document correctly.
  After another fresh launch, 12 further cycles with the native Plasma panel
  active also passed, followed by another successful export.
- On 2026-10-16, reproduced Save for Web returning success from KDE without
  creating a file. Its legacy dialog requested both a hook and a custom template
  with flags `0x008888a4`. The patched build, with KDE still enabled, exported
  JPEG and PNG images at 320×240 with the expected blue rectangle and white
  border. Cancelling overwrite preserved the existing file; confirming overwrite
  replaced it. Standard Save As and Open still used KDE, and a saved PSD reopened
  at 320×240 with both layers intact. These tests ran in a copied prefix with
  private KWin, XWayland and D-Bus, without host windows or audio. The updated
  package and full CUDA system configuration both built successfully.
- On 2026-10-31, reproduced stuck document-tab tooltips and traced Photoshop
  deleting a tracking tool before deactivation. A standalone Windows API test
  failed five checks in each unpatched common-controls version. Both patched
  versions passed all 14 checks, including deletion, reappearance, deleting an
  unrelated tool and normal tracking deactivation. Photoshop passed 12
  alternating tab-hover/leave cycles and repeated hovering of the same tab.
  The toolbar's rich tooltip still appeared and disappeared normally.
  The tests used a copied prefix with private Xvfb/Openbox and process/runtime
  namespaces. The package built and the CUDA NixOS configuration evaluated.
  The package is installed in the user profile; the system generation was not
  switched and no host Adobe processes were terminated.

The later October 31 freeze investigation found that the original repaint guard
was incomplete. The UI could retain Wine's user lock, drop the surface lock,
then block taking the surface lock again in `client_surface_present` or
`client_surface_release`. A GPU submission thread could hold that surface lock
while waiting for the user lock. The replacement follows upstream
[patch 0083](https://github.com/le-birnes/AdobeWine/blob/main/patches/0083-win32u-do-not-wait-for-surfaces-lock-when-re-presenting-offscreen-surfaces.patch),
adapted to the pinned 0.2.2 source. It keeps the successful nonblocking acquisition
through all surface copies; the held lock protects their lifetimes without extra
reference releases.

A D3D11 child-window fixture with concurrent GDI repaint and resizing reproduced
the deadlock under a test-only 5 ms delay after a repaint unlocked the mutex.
Native stacks and mutex owners confirmed the cycle between the UI and
`dxvk-submit` threads. The repaired build passed the same targeted test with 321
resizes and 682 GPU presents in 12 seconds. No timing hook is installed in the
normal runtime. Photoshop then passed 30 measured window-size changes, answered
COM requests, saved and reopened a two-layer PSD, and exported a 640x480 PNG
with the expected blue center and white border. The test-only Openbox session
needed fullscreen removed before these measurements; the host's existing KWin
rule already prevents fullscreen for the normal Photoshop window.
The killed Photoshop process from the earlier user-reported
freeze had no retained hang stack, so that specific incident cannot be assigned
to this defect with certainty. No GPU reset or out-of-memory kill was recorded
in the inspected kernel journal.

Open and Save use KDE's native file dialog, the same file-browser components as
Dolphin. Adobe's custom export settings remain Adobe dialogs; their standard
file-location chooser can use the portal. Dialogs with Windows hooks or custom
templates, including Save for Web's Save Optimized As, use Wine's dialog
automatically because the portal cannot deliver Windows
[hook notifications](https://learn.microsoft.com/en-us/windows/win32/dlgbox/cdn-fileok)
or host application dialog templates. `adobe-photoshop file-picker wine`
restores Wine dialogs for workflows that need Adobe-specific controls the portal
does not support. Remote KIO locations were not tested.

Firefly operations, printing, every filter,
Camera Raw workflows and Lightroom have not been acceptance-tested. This is a
working Wine installation, outside Adobe's supported Windows/macOS desktop
[platforms](https://helpx.adobe.com/photoshop/system-requirements.html).

The October 11/16 GUI tests ran in a copied prefix with private display, process, home and
audio namespaces. Later tests used headless KWin/XWayland and the actual NVIDIA
GPU. A test-only XWayland wrapper disabled its input portal inside that namespace
to allow automation. The host's XWayland executable was not changed. Tests made
no visible windows or audio on the user's desktop.

Luke explicitly requested termination of the frozen Photoshop window; its
verified process received SIGTERM. Other pre-existing Adobe background processes
were left running. Test processes were stopped only inside their private
namespace. Normal app launches have no workspace restriction or forced muting.

## Findings and experiments

The first visual test required manually restoring the installer window, which
the original launcher did not do. A subsequent normal launch reproduced the
failure: Wine marked the window visible at Windows coordinate `y=32767`, outside
every monitor, while X11 left it unmapped at a negative coordinate. The setup
launcher now starts a small Windows helper that checks the installer after five
seconds and moves an off-screen window into the monitor's work area. It matches
both Adobe's installer window class and `Set-up.exe`, leaves visible and minimized
windows alone, and exits within one minute. It does not switch desktops, force
focus or terminate processes.

| Route | Finding on this machine |
| --- | --- |
| [PhialsBasement's Wine installer patches](https://github.com/PhialsBasement/wine-adobe-installers) and [January article](https://phiality.com/blog/photoshop-on-linux-wine) | The recent reports concern real MSHTML/MSXML compatibility work. Getting an installer running is a separate milestone from a usable Photoshop installation. |
| [AdobeOnLinux](https://github.com/qwertychouskie/AdobeOnLinux) | Its current recipe requires Wine Staging 11.10 or newer. Tested 11.18 with Adobe's current 6.10.0 installer and alternate 6.8.1 installer. The embedded browser remained blank, with an IE7-mode JavaScript syntax error. |
| Microsoft WebView2 | The bootstrapper stalled while downloading. Microsoft's standalone 155.0.4283.45 installer succeeded in a disposable prefix; its SHA-256 matched Microsoft's winget manifest. Windows-version overrides and software-rendering options still left Adobe's installer stalled. This prefix was removed. |
| [tristanmuzzu/adobe-for-linux](https://github.com/tristanmuzzu/adobe-for-linux) | Reviewed its Wine 11.16 patch set and reported Photoshop 27.10 editing/save/export results. Its prebuilt runtime targets Ubuntu 26.04 dependencies. No upstream setup script was executed. |
| [AdobeWine 0.2.2](https://github.com/le-birnes/AdobeWine/releases/tag/v0.2.2) | Wine 11.18 plus 61 compatibility patches. Both the original release runtime and the final Nix package displayed Adobe's account-authentication screen in a fresh dedicated prefix. This is the retained route. |

AdobeWine's own [acceptance results](https://github.com/le-birnes/AdobeWine/blob/9faf503a3dcd8420534f141626667141c49fc7ae/docs/ACCEPTANCE.md)
and [compatibility notes](https://github.com/le-birnes/AdobeWine/blob/9faf503a3dcd8420534f141626667141c49fc7ae/docs/COMPATIBILITY.md)
report broader application testing on other hardware. Those are upstream claims,
not results from lpnix. Its patch set addresses browser APIs, process handling,
fonts and application crashes beyond the earlier installer fixes.

The first Nix packaging attempt added too many ELF program headers to Wine's
loader. [Wine's preloader](https://github.com/wine-mirror/wine/blob/master/loader/preloader.c)
allows at most 16. The package removes the optional build-ID note from its two
small Wine loaders, leaving room for the Nix interpreter and embedded library
paths. A build check enforces the 16-header limit.

The original runtime wrapper exported `LD_LIBRARY_PATH`, which passed Wine's
newer glibc into native Linux programs. Browser launch then failed with
`undefined symbol: __pointer_chk_guard, version GLIBC_PRIVATE`. Library paths now
live in Wine's ELF files, without changing the environment inherited by native
programs. The launcher also configures Wine's `WineBrowser\\Browsers` registry
value to use `xdg-open` directly. The original dedicated Chrome wrapper was
removed at the user's request.

A source build was started and cancelled after it spent substantial time
compiling Wine's tests. `wine.sourceBuild` retains a pinned source recipe with
tests disabled, but that recipe has not completed a build. The installed runtime
uses the project's checksum-verified release binary with two modules rebuilt
from the matching pinned source: `comdlg32` for the file picker and `win32u.so`
for the repaint guard. Both targeted source builds completed successfully.

## Sources and integrity

Adobe's installer came from the link published on its
[official direct-download page](https://helpx.adobe.com/download-install/apps/download-install-apps/creative-cloud-apps/download-creative-cloud-desktop-app-using-direct-links.html).
`Set-up.exe` passed Authenticode verification with Adobe Inc as signer, including
its certificate chain and timestamp. Photoshop itself was installed by Creative
Cloud. Adobe executables and licensing mechanisms were not patched.

| Component | Official or upstream source |
| --- | --- |
| Creative Cloud installer | Adobe `ACCCx6_10_0_252_41.zip`, SHA-256 `4e5f5b72db712a30a212aafa2c5cb47c555248c5b30f20b529103519c7d4fa4c` |
| Wine runtime | [AdobeWine 0.2.2](https://github.com/le-birnes/AdobeWine/releases/tag/v0.2.2), release SHA-256 `2e9d36e2c07d7b5fd7b01b1141ef5e9ae9c2feb0b659eea8ea1d9782a49e3b9c` |
| Wine source and compatibility scripts | Revision `9faf503a3dcd8420534f141626667141c49fc7ae` |
| Runtime nixpkgs | Revision `6510408d147d8c5e6d76043e899e9251756f6a75` |
| Visual C++ runtime | [Microsoft's redistributable downloads](https://learn.microsoft.com/en-us/cpp/windows/latest-supported-vc-redist), x86 and x64 version 14.51.36247 |
| UI fonts | [Microsoft Selawik 1.01](https://github.com/microsoft/Selawik/releases/tag/1.01), OFL license retained alongside fonts |
| D3D11 translation | [DXVK 3.1.1](https://github.com/doitsujin/dxvk/releases/tag/v3.1.1) |
| D3D12 translation | [vkd3d-proton 3.0.1](https://github.com/HansKristian-Work/vkd3d-proton/releases/tag/v3.0.1) |
| Shader compiler | Microsoft's DLL bundled with the officially installed Creative Cloud |

`runtime-assets.nix` pins every additional download by URL and SHA-256. The
Microsoft redistributable hashes match their official download URL digests.
Their Authenticode chain could not be independently completed with the local
CA bundle; no claim of successful signature verification is made for them.
No third-party Photoshop repacks or activation bypasses were used.

## Change inventory and local state

| Repository location | Purpose |
| --- | --- |
| `pkgs/adobe-photoshop/wine.nix` | Pinned Wine runtime and Nix ELF/dependency fixes from the initial installation. |
| `pkgs/adobe-photoshop/runtime-assets.nix` | Pinned font, Visual C++, DXVK, vkd3d and D3D12 shim package. |
| `pkgs/adobe-photoshop/default.nix` | Packages the launchers, runtime preparation, icons and two KDE desktop entries. |
| `pkgs/adobe-photoshop/adobe-photoshop.sh` | Dedicated prefix, setup/cloud/run/repair/scale/file-picker/stop/status commands, browser integration, error logging and an explicit `WINEDEBUG` override. |
| `pkgs/adobe-photoshop/prepare-prefix.sh` | Idempotent compatibility repairs, backups and DPI configuration. |
| `pkgs/adobe-photoshop/install-icons.sh` | Extracts icons from the installed Adobe applications. |
| `pkgs/adobe-photoshop/file-dialogs.nix`, `portal-file-type.patch`, `portal-custom-dialogs.patch` | Rebuild Wine's dialog module with native picker format selection, home-directory defaults and complete Windows dialogs for hooks/templates. |
| `pkgs/adobe-photoshop/repaint.nix`, `resize-repaint.patch` | Rebuild Wine's window module with one nonblocking surface-lock acquisition covering the complete optional offscreen repaint. |
| `pkgs/adobe-photoshop/tooltips.nix`, `tracking-tooltip-delete.patch` | Rebuild both common-controls modules so deleting an active tracking tool hides its popup. |
| `pkgs/adobe-photoshop/show-installer.c` | Earlier installer window-placement repair. |
| `flake.nix`, `system/configuration.nix` | Earlier standalone package exposure and system package integration. |
| `system/help/help.txt` | Command usage in `help`. |
| `user/plasma/window-rules.nix` | Adobe window sizing rules for KWin/Krohnkite. |
| This README | Findings, verification, sources and complete change inventory. |

The updated Adobe package and built `help` package are installed in Luke's Nix
user profile. The full CUDA configuration was rebuilt but not activated. Its dry
activation would stop `accounts-daemon`, restart `polkit` and Home Manager, and
reload D-Bus. Profile installation avoids interrupting unrelated work. After a future normal `bnix` activation, the
standalone profile entries can be removed with
`nix profile remove adobe-photoshop help`, letting the system provide those
commands and future updates. No system service restarts are needed. The latest scaling, dialog and rendering
changes need a fresh Adobe session. Save work, run `adobe-photoshop stop`, then
`adobe-photoshop run`. Existing user applications were not terminated for this
update.

For the stale desktop-entry repair, launch records confirmed that KDE still
executed the old launcher. The cache mapped in `/proc/<plasmashell-pid>/maps`
contained that same obsolete path. Rebuilding with Plasma's locale and
`XDG_DATA_DIRS` replaced it with the current entry. On this NixOS installation,
the `kbuildsycoca6` wrapper prepends additional data directories, so the repair
used its `.kbuildsycoca6-wrapped` binary with Plasma's existing Qt environment.
The mapped caches used by the activity manager and desktop portal were refreshed
too. Verified that both desktop entries resolve through Plasma's `PATH` to the
current launchers. The next host desktop launch confirmed the updated launcher.
Plasma was not restarted. This follows KDE's
[cache invalidation behavior](https://api.kde.org/ksycoca.html).

Runtime changes outside the repository:

- `~/.local/share/adobe-photoshop/prefix/`: registered compatibility fonts,
  replaced runtime DLLs, repaired registry values and DPI settings.
- `~/.local/share/adobe-photoshop/backups/`: original runtime DLLs, exported
  registry keys, original shader compiler and pre-Adobe KWin rules.
- `~/.local/share/adobe-photoshop/scale`, `runtime-assets`, `prepare.lock`:
  persisted UI size, preparation revision and concurrency lock.
- `~/.local/share/adobe-photoshop/file-picker`: persisted picker preference.
- `~/.local/share/adobe-photoshop/prefix/dosdevices/h:`: home-directory drive mapping. Existing prefix documents are preserved.
- `~/.local/share/adobe-photoshop/launcher`: link to the current built package.
- `~/.local/share/adobe-photoshop/logs/`: launch/repair logs and a private
  `verification-20261011/`, `verification-polish-20261011/` and
  `verification-save-for-web-20261016/` directories with
  test documents, exports, results, screenshots and build evidence. No account data is committed to Git.
- `~/.local/share/adobe-photoshop/logs/verification-tooltips-20261031/`:
  standalone tooltip reproducer, before/after API results, Photoshop hover
  observations, tooltip-only traces and screenshots.
- `~/.local/share/adobe-photoshop/logs/verification-freeze-20261031/`:
  D3D11 stress fixture, test-only scheduling hook, before/after logs, captured
  thread stacks and mutex owners, measured Photoshop resizes and PSD/PNG checks.
- `~/.local/share/icons/hicolor/256x256/apps/adobe-{photoshop,creative-cloud}.png`:
  Adobe application icons.
- `~/.config/kwinrulesrc`: applied the generated Adobe rules immediately,
  preserving the existing Discord, Minecraft and RuneLite rules.
- Nix user profile and KDE application cache: installed/refreshed launchers.

The official installer remains in `~/.local/share/adobe-photoshop/downloads/`.
Chezmoi is unchanged. Private test prefixes, temporary tools and the
`~/.cache/adobe-repair/` and `~/.cache/adobe-polish/` work directories were removed after retaining verification
artifacts. Normal Nix store objects and profile generations remain managed by
Nix; no global garbage collection ran.
