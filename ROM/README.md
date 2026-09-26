Put the game the app should boot here as `game.nds`, or as `game.zip` containing a single `.nds`. Symlinks work:

    ln -s /path/to/your/game.nds ROM/game.nds

The game is copied into the app bundle at build time. Everything in this folder except this README is ignored by git: never commit ROMs.
