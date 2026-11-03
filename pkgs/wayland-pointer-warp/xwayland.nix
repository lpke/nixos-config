{ pkgs }: xwayland:
assert xwayland.version == "24.1.12";
xwayland.overrideAttrs (old: {
  patches = (old.patches or []) ++ [ ./xwayland-direct-warp.patch ];
})
