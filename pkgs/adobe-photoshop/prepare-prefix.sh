# Called by the launcher with its dedicated WINEPREFIX and log already set.
assets='@assets@'
revision='@revision@'
previous_assets=$(cat "$data/runtime-assets" 2>/dev/null || true)

replace_file() {
  local source=$1 target=$2
  # Preserve mappings held by existing Adobe background processes.
  install -m 644 "$source" "$target.adobe-new"
  mv -f "$target.adobe-new" "$target"
}

if [[ "$previous_assets" != "$assets:$revision" || "$command_name" == repair ]]; then
  echo 'Preparing Adobe fonts and runtimes...'
  if [[ ! -f "$WINEPREFIX/system.reg" ]]; then
    wineboot --init >> "$log" 2>&1
  fi
  backup="$data/backups/runtime-$(date +%Y%m%d-%H%M%S)"
  install -d -m 700 "$backup"
  for key in 'HKCU\Software\Wine' 'HKCU\Control Panel\Desktop' 'HKCU\Control Panel\Colors' \
    'HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\User Shell Folders' \
    'HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Shell Folders'; do
    wine reg export "$key" "$(winepath -w "$backup/${key##*\\}.reg")" /y >> "$log" 2>&1
  done
  for directory in system32 syswow64; do
    install -d "$backup/$directory"
    for source in "$assets/$directory/"*.dll; do
      target="$WINEPREFIX/drive_c/windows/$directory/${source##*/}"
      if [[ -f "$target" ]]; then cp -a "$target" "$backup/$directory/"; fi
      replace_file "$source" "$target"
    done
  done
  for source in "$assets/fonts/"*.ttf; do
    target="$WINEPREFIX/drive_c/windows/Fonts/${source##*/}"
    # Leave fonts supplied by the user intact.
    if [[ ! -f "$target" ]]; then replace_file "$source" "$target"; fi
    name=$(fc-scan --format '%{fullname[0]}' "$target")
    wine reg add 'HKLM\Software\Microsoft\Windows NT\CurrentVersion\Fonts' \
      /v "$name (TrueType)" /d "${source##*/}" /f >> "$log" 2>&1
  done
  replace_file "$assets/fonts/LICENSE.txt" "$WINEPREFIX/drive_c/windows/Fonts/Selawik-LICENSE.txt"
  for source in "$assets/system32/"*.dll; do
    dll=${source##*/}
    [[ "$dll" == d3d12_vkd3d.dll ]] && continue
    wine reg add 'HKCU\Software\Wine\DllOverrides' /v "${dll%.dll}" \
      /d native,builtin /f >> "$log" 2>&1
  done
  # WebView2 uses DirectComposition, which needs Wine's D3D implementation.
  for dll in dxgi d3d11; do
    wine reg add 'HKCU\Software\Wine\AppDefaults\msedgewebview2.exe\DllOverrides' \
      /v "$dll" /d builtin /f >> "$log" 2>&1
  done
  {
    wine reg add 'HKCU\Software\Wine\AppDefaults\Photoshop.exe' /v Version /d win10 /f
    wine reg add 'HKCU\Software\Wine\X11 Driver' /v Managed /d Y /f
    # Adobe draws its own captions. A second X11 frame clips dialogs and can
    # trigger startup resizes before Photoshop has drawn its panels.
    wine reg add 'HKCU\Software\Wine\X11 Driver' /v Decorated /d N /f
    for color in ActiveTitle GradientActiveTitle InactiveTitle GradientInactiveTitle; do
      wine reg add 'HKCU\Control Panel\Colors' /v "$color" /d '79 79 79' /f
    done
    for color in TitleText InactiveTitleText; do
      wine reg add 'HKCU\Control Panel\Colors' /v "$color" /d '240 240 240' /f
    done
    # The original prefix had MenuHeight=6750318, producing enormous blank menus.
    # A negative value is in twips and scales correctly with the configured DPI.
    wine reg add 'HKCU\Control Panel\Desktop\WindowMetrics' /v MenuHeight /d '-285' /f
    wine regsvr32 /s windows.ui.dll
  } >> "$log" 2>&1
  printf '%s\n' "$assets:$revision" > "$data/runtime-assets"
fi

# Adobe ships Microsoft's shader compiler with Creative Cloud. Reuse that
# official local copy instead of downloading DLLs from a third-party mirror.
compiler="$WINEPREFIX/drive_c/Program Files/Common Files/Adobe/Adobe Desktop Common/CEF/d3dcompiler_47.dll"
if [[ -f "$compiler" ]] && ! cmp -s "$compiler" "$WINEPREFIX/drive_c/windows/system32/d3dcompiler_47.dll"; then
  compiler_backup="$data/backups/compiler-$(date +%Y%m%d-%H%M%S)"
  install -d -m 700 "$compiler_backup"
  if [[ -f "$WINEPREFIX/drive_c/windows/system32/d3dcompiler_47.dll" ]]; then
    cp -a "$WINEPREFIX/drive_c/windows/system32/d3dcompiler_47.dll" "$compiler_backup/"
  fi
  replace_file "$compiler" "$WINEPREFIX/drive_c/windows/system32/d3dcompiler_47.dll"
  wine reg add 'HKCU\Software\Wine\DllOverrides' /v d3dcompiler_47 /d native,builtin /f >> "$log" 2>&1
fi

scale=$(cat "$data/scale" 2>/dev/null || echo 150)
if [[ "$command_name" == scale ]]; then scale=$1; fi
if [[ ! "$scale" =~ ^[0-9]{3}$ ]] || (( 10#$scale < 100 || 10#$scale > 300 )); then
  echo 'Scale must be a percentage from 100 to 300.' >&2
  exit 2
fi
scale=$((10#$scale))
dpi=$((scale * 96 / 100))
wine reg add 'HKCU\Control Panel\Desktop' /v LogPixels /t REG_DWORD /d "$dpi" /f >> "$log" 2>&1
wine reg add 'HKLM\System\CurrentControlSet\Hardware Profiles\Current\Software\Fonts' \
  /v LogPixels /t REG_DWORD /d "$dpi" /f >> "$log" 2>&1
printf '%s\n' "$scale" > "$data/scale"

# Keep home accessible without moving any existing files out of the prefix.
# Wine's shell-folder paths become the initial locations for new file dialogs.
if [[ ! -e "$WINEPREFIX/dosdevices/h:" && ! -L "$WINEPREFIX/dosdevices/h:" ]]; then
  ln -s "$HOME" "$WINEPREFIX/dosdevices/h:"
fi
home_path=$(winepath -w "$HOME")
for key in 'User Shell Folders' 'Shell Folders'; do
  wine reg add "HKCU\\Software\\Microsoft\\Windows\\CurrentVersion\\Explorer\\$key" \
    /v Personal /t REG_SZ /d "$home_path" /f >> "$log" 2>&1
done
picker=$(cat "$data/file-picker" 2>/dev/null || echo kde)
if [[ "$command_name" == file-picker ]]; then picker=$1; fi
case "$picker" in
  kde) portal=always ;;
  wine) portal=never ;;
  *) echo 'File picker must be kde or wine.' >&2; exit 2 ;;
esac
wine reg add 'HKCU\Software\Wine\AppDefaults\Photoshop.exe\X11 Driver' \
  /v FileDialogPortal /d "$portal" /f >> "$log" 2>&1
printf '%s\n' "$picker" > "$data/file-picker"
