install_icon() {
  local name=$1 executable=$2 resource=$3
  local directory="${XDG_DATA_HOME:-$HOME/.local/share}/icons/hicolor/256x256/apps"
  [[ -n "$executable" && ! -f "$directory/$name.png" ]] || return 0
  local temporary
  temporary=$(mktemp -d "$data/.icon-XXXXXX")
  if wrestool -x -t14 -n"$resource" "$executable" > "$temporary/app.ico" 2>> "$log" &&
     icotool -x -i1 -o "$temporary/app.png" "$temporary/app.ico" >> "$log" 2>&1; then
    install -d "$directory"
    install -m 644 "$temporary/app.png" "$directory/$name.png"
  fi
  rm -r "$temporary"
}

# Use the icons shipped with the user's officially installed Adobe binaries.
install_icon adobe-photoshop "$photoshop_exe" 1000
install_icon adobe-creative-cloud "$cloud_exe" 101
