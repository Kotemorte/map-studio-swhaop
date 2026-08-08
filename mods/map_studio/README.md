# Map Studio

A map editor and generator for *Sir, We Have an Orc Problem*. Draw your own
maps, test them in battle and share them with other players.

*По-русски - в [README.ru.md](README.ru.md).*

## Installing

Copy `override.cfg` and the `mods` folder next to `swhaop.exe`. On Steam that
is usually:

```
C:\Program Files (x86)\Steam\steamapps\common\Sir, We Have an Orc Problem
```

Start the game. To remove the mod, delete `override.cfg` - the game goes back
to normal immediately.

The mod does not modify a single game file and unpacks nothing.

## Getting started

The mod hooks into the game's interface in two places:

- **Game menu**, next to *Load Game* and *Options* - an entry called
  **Custom maps**. It stays disabled until a game is loaded: the editor needs
  a save slot.
- **Tech tree**, bottom left corner - a **Your maps** button.

The **F1** key opens the editor directly.

Your maps never show up in the campaign level list - they are launched from
the mod only.

## Keys

| Key | What it does |
|---|---|
| **F1** | open and close the editor |
| **F2** | draw over the battle - **on your own map only** |
| **F5** | reload the mod |
| **Tab** | in F2 mode, hide the panel to see the whole map |
| **Esc** | leave F2 mode |

## Your Steam achievements stay safe

**Completing a custom map never counts towards Steam.** This is not a setting:
it cannot be switched off, because the mod has no button, mode or flag that
would let a custom map unlock an achievement.

The game grants all 11 achievements through a single call, and the mod
intercepts it: on a player-made map the achievement is silently skipped, on the
game's own levels everything works exactly as before. The original game code is
not rewritten - when blocking is not needed, the call goes straight to it.

For the same reason custom maps grant no upgrade marks: otherwise the
*Fully Loaded* achievement could be farmed on a map drawn for that purpose.

## What the mod does not do

It deals with maps and nothing else. There is no:

- granting currency or unlocking upgrades;
- unlocking towers or lifting their limits;
- marking levels as completed;
- unlocking achievements;
- modifying the game's levels - your map lives in a separate slot, the
  campaign stays untouched, and drawing over a battle (F2) is unavailable on
  the game's levels entirely. A game level can be used as a starting point via
  *Take a game level's map* in the editor, which never alters the original;
- console or object inspector.

Speeding up and pausing a battle work **on your own map only** - they are
testing tools. Leave your map and the game runs at its normal pace again.

## Making a map

1. **F1 → Editor tab.** Set a size and press *Create*, or generate a map from
   parameters.
2. Draw with the brushes: wall, floor, base, edge. Orc spawn points are placed
   directly on the map.
3. **CHECK MAP** builds the world exactly as the game does and tells you
   whether the map will work.
4. **PLAY** starts a battle on your map.
5. **F2** during the battle lets you fix the map while seeing it in action.
   *Apply* restarts the battle with your changes.

### Walls thinner than three cells do not work

The engine ignores a wall whose width and height are both under three cells -
orcs walk straight through it. That is a property of the game, not of the mod.
*CHECK MAP* finds such places in advance.

### Generator styles

They follow the patterns the game's own levels are built on:

- **Funnel (like 1.1)** - wide entrance, narrow throat, arena by the base;
- **Diamond pillars (like 2.2)** - open lanes with rhombi splitting the flow;
- **Islands (like 4.1)** - large ragged masses with wide passages;
- **Maze**, **Rooms**.

## Sharing maps

Your maps are saved to the game's save folder:
`%APPDATA%\Sir, We Have an Orc Problem\levels\` - plain `.json` files.

The shared folder is `mods/map_studio/maps/`. Drop someone else's `.json`
there and the map appears in the list marked **shared**: you can play it right
away or copy it into your own to edit. The *Share*, *Make it mine* and
*Open shared folder* buttons are on the Editor tab.

## Language

The mod follows the language the game is set to. Russian and English are
included; any other language falls back to English.

Adding your own translation takes one file - see
[locale/README.md](locale/README.md).

## What the mod is made of

| File | Purpose |
|---|---|
| `mod.gd` | entry point |
| `ach_guard.gd` | achievement and reward protection |
| `ach_shim.gd` | achievement call interception |
| `map_studio.gd` | editor, generator, map sharing |
| `locale/` | translations |
| `maps/` | shared folder |

Everything is plain text script: you can read it and check that the mod does
exactly what is described here.
