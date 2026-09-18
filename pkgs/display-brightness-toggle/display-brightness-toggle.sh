# Serialize presses so each toggle reads the previous toggle's result.
exec 9>"${XDG_RUNTIME_DIR:?}/display-brightness-toggle.lock"
flock 9
state_dir="$XDG_RUNTIME_DIR/display-blackout"

config=$(kscreen-doctor --json)
if ! output=$(jq -er '
  [.outputs[] | select(.connected and .enabled and .priority == 1)]
  | if length != 1 then error("Expected one enabled primary display") else .[0] end
  | .name
' <<< "$config"); then
  echo "display-brightness-toggle: cannot find primary display" >&2
  exit 1
fi

# A layer-shell overlay stays black while the other monitor is in use. KWin's
# brightness/dimming controls retain a luminance floor, even at zero.
if systemctl --user is-active --quiet display-blackout.service; then
  # Restore brightness behind the opaque cover, then let it fade away.
  kscreen-doctor "output.$output.brightness.100"
  rm -f "$state_dir/visible"
  # Normally QML exits after its 250 ms fade. Bound cleanup if it is unresponsive.
  for ((attempt = 0; attempt < 30; attempt++)); do
    if ! systemctl --user is-active --quiet display-blackout.service; then
      break
    fi
    sleep 0.1
  done
  systemctl --user stop display-blackout.service 2>/dev/null || true
else
  mkdir -p "$state_dir"
  touch "$state_dir/visible"
  systemd-run --user --quiet --collect --service-type=exec \
    --unit=display-blackout --property=PartOf=graphical-session.target \
    --setenv=QT_QPA_PLATFORM=wayland --setenv=QT_FORCE_STDERR_LOGGING=1 \
    "@qml@" -I "@layerShellImports@" "@blackoutQml@" -- "$output" "$state_dir"
  kscreen-doctor "output.$output.brightness.0"
fi
