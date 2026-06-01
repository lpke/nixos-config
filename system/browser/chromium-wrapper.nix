{ lib }:

{
  wrapChromiumBrowser = pkgs: { name, package, binary, desktopFiles ? [], flags ? [] }:
    if flags == [] then package else
    pkgs.symlinkJoin {
      inherit name;
      paths = [ package ];
      nativeBuildInputs = [ pkgs.makeWrapper ];

      postBuild = ''
        wrapProgram "$out/bin/${binary}" \
${lib.concatMapStringsSep " \\\n" (flag: "          --add-flags ${lib.escapeShellArg flag}") flags}

        for desktopFile in ${lib.escapeShellArgs desktopFiles}; do
          desktopPath="$out/share/applications/$desktopFile"
          if [ -e "$desktopPath" ]; then
            cp --remove-destination "$(readlink -f "$desktopPath")" "$desktopPath"
            chmod u+w "$desktopPath"
            if grep -qF ${lib.escapeShellArg "${package}/bin/${binary}"} "$desktopPath"; then
              substituteInPlace "$desktopPath" \
                --replace-fail ${lib.escapeShellArg "${package}/bin/${binary}"} "$out/bin/${binary}"
            fi
            if grep -Eq ${lib.escapeShellArg "^Exec=${binary}($| )"} "$desktopPath"; then
              substituteInPlace "$desktopPath" \
                --replace-fail ${lib.escapeShellArg "Exec=${binary}"} "Exec=$out/bin/${binary}"
            fi
          fi
        done
      '';

      meta = package.meta or {};
    };
}
