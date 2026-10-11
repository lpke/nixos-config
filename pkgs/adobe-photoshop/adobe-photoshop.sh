data="$HOME/.local/share/adobe-photoshop"
umask 077
export WINEPREFIX="$data/prefix"
export WINEARCH=win64
export WINEDEBUG=-all
export WINEDLLOVERRIDES='winemenubuilder.exe=d'
export WINE_HEAP_QUARANTINE='Creative Cloud.exe;Creative Cloud Helper.exe;Creative Cloud UI Helper.exe;Adobe Desktop Service.exe;node.exe;CCXProcess.exe;CoreSync.exe;CRLogTransport.exe;HDHelper.exe;AdobeIPCBroker.exe;AdobeUpdateService.exe'

usage() {
  cat <<'EOF'
adobe-photoshop setup     Download and open Adobe's Creative Cloud installer.
adobe-photoshop cloud     Open Creative Cloud to sign in or install Photoshop.
adobe-photoshop run       Open installed Photoshop. Optional file paths follow.
adobe-creative-cloud      Open Creative Cloud (same as adobe-photoshop cloud).
adobe-photoshop repair    Reinstall compatibility fonts and runtimes.
adobe-photoshop scale N   Set UI size to N percent (100–300; default 150).
adobe-photoshop file-picker kde|wine  Choose file dialogs (default kde).
adobe-photoshop stop      Close ALL Adobe apps and background services. Save first.
adobe-photoshop status    Show runtime, prefix and installed application paths.
adobe-photoshop --help    Show this help (-h also works).

Adobe sign-in opens your default browser. An Adobe account and Photoshop
entitlement are required.
After scaling changes, save your work, run adobe-photoshop stop, then relaunch.
EOF
}

cloud_exe=""
for base in 'Program Files' 'Program Files (x86)'; do
  candidate="$WINEPREFIX/drive_c/$base/Adobe/Adobe Creative Cloud/ACC/Creative Cloud.exe"
  if [[ -f "$candidate" ]]; then
    cloud_exe="$candidate"
    break
  fi
done

photoshop_exe=""
shopt -s nullglob
photoshop_candidates=("$WINEPREFIX"/drive_c/Program\ Files/Adobe/Adobe\ Photoshop*/Photoshop.exe)
if (( ${#photoshop_candidates[@]} )); then
  photoshop_exe=$(printf '%s\n' "${photoshop_candidates[@]}" | sort -V | tail -1)
fi

command_name="${1:-help}"
if (( $# )); then shift; fi
case "$command_name" in
  help|-h|--help) usage; exit 0 ;;
  status)
    wine --version
    printf 'Prefix: %s\nCreative Cloud: %s\nPhotoshop: %s\n' \
      "$WINEPREFIX" "${cloud_exe:-not installed}" "${photoshop_exe:-not installed}"
    printf 'Configured UI scale: %s%% (requires a fresh Adobe session)\n' "$(cat "$data/scale" 2>/dev/null || echo 150)"
    printf 'File picker: %s\n' "$(cat "$data/file-picker" 2>/dev/null || echo kde)"
    exit 0
    ;;
  stop)
    if [[ ! -f "$WINEPREFIX/system.reg" ]]; then exit 0; fi
    echo 'Closing Adobe applications and background services in the dedicated Adobe prefix.'
    wineserver -k
    wineserver -w
    exit 0
    ;;
  file-picker)
    if (( $# != 1 )) || [[ "$1" != kde && "$1" != wine ]]; then
      echo 'Usage: adobe-photoshop file-picker kde|wine' >&2
      exit 2
    fi
    ;;
  scale)
    if (( $# != 1 )) || [[ ! "$1" =~ ^[0-9]{3}$ ]] || (( 10#$1 < 100 || 10#$1 > 300 )); then
      echo 'Usage: adobe-photoshop scale N (percentage from 100 to 300)' >&2
      exit 2
    fi
    ;;
  setup|cloud|run|repair) ;;
  *) usage >&2; exit 2 ;;
esac

install -d -m 700 "$data" "$data/downloads" "$data/logs"
case "$command_name" in
  setup)
    archive="$data/downloads/ACCCx6_10_0_252_41.zip"
    installer="$data/downloads/creative-cloud/Set-up.exe"
    if [[ ! -f "$archive" ]]; then
      curl --fail --location --proto '=https' --proto-redir '=https' --retry 2 \
        'https://ccmdls.adobe.com/AdobeProducts/StandaloneBuilds/ACCC/ESD/6.10.0/252.41/win64/ACCCx6_10_0_252_41.zip' \
        --output "$archive.part"
      mv "$archive.part" "$archive"
    fi
    printf '4e5f5b72db712a30a212aafa2c5cb47c555248c5b30f20b529103519c7d4fa4c  %s\n' \
      "$archive" | sha256sum --check --status
    unzip -oq "$archive" -d "$data/downloads/creative-cloud"
    exe="$installer"
    ;;
  cloud)
    if [[ -z "$cloud_exe" ]]; then
      echo "Creative Cloud is not installed. Run: adobe-photoshop setup" >&2
      exit 1
    fi
    exe="$cloud_exe"
    ;;
  run)
    if [[ -z "$photoshop_exe" ]]; then
      echo "Photoshop is not installed. Install it through Adobe Creative Cloud first." >&2
      exit 1
    fi
    exe="$photoshop_exe"
    ;;
esac

log="$data/logs/$command_name-$(date +%Y%m%d-%H%M%S).log"
echo "Log: $log"
# Serialize prefix preparation, but release the lock before opening the app.
exec 9> "$data/prepare.lock"
flock 9
@prepare@
@icons@
# Select XWayland without changing the user's global Wine configuration.
wine reg add 'HKCU\Software\Wine\Drivers' /v Graphics /t REG_SZ /d x11 /f >> "$log" 2>&1
# Use the desktop's default browser without changing its associations.
wine reg add 'HKCU\Software\Wine\WineBrowser' /v Browsers /t REG_SZ /d '@browser@' /f >> "$log" 2>&1
flock -u 9
exec 9>&-
case "$command_name" in
  repair) echo 'Adobe runtimes repaired. Restart Adobe applications to use the changes.'; exit 0 ;;
  scale) echo "Adobe UI scale: $scale%. Save your work, run adobe-photoshop stop, then relaunch."; exit 0 ;;
  file-picker) echo "Photoshop file picker: $picker"; exit 0 ;;
esac
args=()
if [[ "$command_name" == cloud ]]; then args+=(--disable-gpu-vsync); fi
for arg in "$@"; do
  if [[ -e "$arg" ]]; then args+=("$(winepath -w "$arg")"); else args+=("$arg"); fi
done
if [[ "$command_name" == setup ]]; then
  wine '@showInstaller@' >> "$log" 2>&1 &
fi
cd "$HOME"
exec wine "$exe" "${args[@]}" >> "$log" 2>&1
