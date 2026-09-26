Put the game the app should boot here as `game.nds` (a symlink works too):

    ln -s /path/to/your/game.nds ROM/game.nds

The file is copied into the app bundle at build time and is ignored by git.
