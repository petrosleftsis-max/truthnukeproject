A Godot 4.x demo project for a tactical 2D RPG.

## Features
* Setup combatant and skill definitions in databases using Autoloads
* Combatant movement on a 2D grid
* Support for different movement costs for tiles
* Support for flying units
* Support for blocking certain unit classes from entering specific tiles
* Simple melee enemy AI

## Exporting

`export_presets.cfg` is gitignored (it can hold signing credentials), so the
export settings don't travel with the repo. On a fresh clone, recreate the
Windows Desktop preset and set **Application → Icon** to
`res://imagese/icon/icon.ico` — that's the icon the exported `.exe` uses.
`config/icon` in the project settings is a separate thing: it only covers the
project manager, the editor, and the window while the game is running.

`imagese/icon/icon.ico` is generated from `icon.png` and holds 16/24/32/48/64/
128/256px, so Windows has a real image at every size it asks for instead of
downscaling one. Rebuild it if the art changes.

Exporting also needs the export templates for your exact Godot version:
Editor → Manage Export Templates.

## Additional Credits
Graphical assets created by DENZI under the CC-BY-SA 3.0 license:
https://opengameart.org/content/denzis-32x32-orthogonal-tilesets
