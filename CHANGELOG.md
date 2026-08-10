# Changelog

## v1.1 - 2026-08-11

Battle testing: run the wave fast, stop it, keep the base alive, and stop
placing the same towers again after every visit. Maps made in v1.0 load as they
are.

- **Battle speed up to 256x**, done by taking extra simulation steps instead of
  scaling engine time. Time scaling was not a speed up at all: the engine takes
  proportionally fewer, longer physics steps, so the same amount of game time
  passes per real second while a single step grows to a fifth of a second -
  long enough for an orc to pass straight through a one cell wall. Measured: 8x
  gives exactly 8.0 times more orcs per second, and the whole Surrounded wave of
  6212 orcs is released in one second at 32x. Buttons plus a field for a custom
  value; anything above 256x is clamped with a message. Works only on your own
  map and only on a running battle: picking a speed never starts one.
- **"Stop" freezes the battle, not the game.** Physics stepping is disabled on
  the simulation and the spawners only, so menus, panels and the mouse keep
  working.
- **Immortal base** checkbox: the base keeps the health it had when you switched
  it on, so you can watch how far a wave gets without losing the battle. Health
  is restored after every simulation step rather than once per frame - at high
  speeds damage kills the base within a single drawn frame.
- **Tower layout is kept per map** and survives switching maps and restarting
  the game. The game stores towers inside the level object, which the mod
  rebuilds on every launch, so the list was born empty every time. The layout
  now lives in `map_studio_towers.json` next to the saves, one entry per map.
  Only missing towers are added back, so a layout never doubles.
- **Shared panel shelf**: mod panels stack in one column in the top left corner
  and collapse one by one. Mods that support the same shelf share the column
  instead of overlapping.
- **Plays well with neighbouring mods**: whoever takes over the battle marks it
  on the scene tree root and the others stand down for that time, so extra
  simulation steps never add up. Nothing is required from the neighbour.
- Fixed: opening the mod window during the building phase started the battle -
  measured at three thousand orcs in eight seconds. Hiding the game menu means
  "back to battle" for the game, so the phase and the pause are now restored and
  held for several frames.
- Fixed: panels did not react to clicks during the building phase, which is a
  pause of the whole scene tree.

Known limit: laser beams flicker at speed. This is only the drawing - the tower
fires just as often and deals its damage. A beam flash lasts about 0.4 seconds
of game time, which covers 25 drawn frames at 1x, about three at 4x and one at
16x.

## v1.0 - 2026-08-09

First public release.

- Map editor: brushes (wall, floor, base, edge), orc spawn points placed
  directly on the map, zoom, map validation against the real engine rules
- Map generator with five styles based on the game's own level design:
  funnel (1.1), diamond pillars (2.2), islands (4.1), maze, rooms
- Drawing over a live battle (F2) with a fast battle restart
- Map browser with thumbnails, opened from the game menu and the tech tree
- Sharing maps as `.json` through the mod's shared folder
- **Steam achievement protection**: custom maps never count towards Steam and
  grant no upgrade marks; cannot be switched off
- English and Russian, other languages fall back to English; adding a
  translation takes one file
- Bundled map: **Surrounded**
