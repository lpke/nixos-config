# KWin script recovery

Inactive native effect used on demand by `krohnkite recover`. It destroys and
recreates KWin's scripting engine, clearing JavaScript callbacks left behind by
older scripts without closing applications or restarting the compositor.

The current tiler is loaded explicitly before normal script discovery. The
compositor inherited immutable Nix data paths at login; recovery also puts the
current system data path first for later enables. Other enabled KWin scripts
restart too. This uses KWin's internal exported factory and must be rechecked
when updating KWin. An unavailable factory is rejected before changing state.
