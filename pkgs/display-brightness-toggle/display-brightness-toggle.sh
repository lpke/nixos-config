# Serialize presses so each toggle reads the previous toggle's result.
exec 9>"${XDG_RUNTIME_DIR:?}/display-brightness-toggle.lock"
flock 9

config=$(kscreen-doctor --json)
if ! setting=$(jq -er '
  [.outputs[] | select(.connected and .enabled and .priority == 1)]
  | if length != 1 then error("Expected one enabled primary display") else .[0] end
  | if (.brightness | type) != "number" then error("Display brightness unavailable") else . end
  | "output.\(.name).brightness.\(if .brightness == 0 then 100 else 0 end)"
' <<< "$config"); then
  echo "display-brightness-toggle: cannot read primary display brightness" >&2
  exit 1
fi

kscreen-doctor "$setting"
