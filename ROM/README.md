Put each game the store sells here as `<id>.nds`, or as `<id>.zip` containing a single `.nds`, where `<id>` matches a `DisplayGame` in `App/Views/GameSelectionView.swift`. Symlinks work:

    just rom kart /path/to/Mario\ Kart\ DS.zip

The games are copied into the app bundle at build time. Everything in this folder except this README is ignored by git: never commit ROMs.
