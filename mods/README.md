# Mods for *Sir, We Have an Orc Problem*

The game is made in Godot and has no mod system of its own. This one is
external: it touches no game file, unpacks nothing and rebuilds nothing.

## Installing

1. Copy `override.cfg` and the `mods` folder next to `swhaop.exe`.
2. Start the game.

No administrator rights needed.

## Removing

Delete `override.cfg` - the game is back to normal. The `mods` folder can
stay: without that file it is never read.

## What is in override.cfg

```
_custom_features="steam"

[autoload]

ModLoader="*mods/mod_loader.gd"
```

- `_custom_features="steam"` is required, otherwise the game will not connect
  to Steam and loses saves and achievements.
- `[autoload]` starts the mod loader together with the game.

Godot reads `override.cfg` next to the executable before the game starts, and
the path inside it is resolved relative to the game folder rather than the
working directory - so the mod survives both a Steam launch and moving the
folder to another drive.

**If you already have your own `override.cfg`**, do not replace it: add the
lines from the `[autoload]` block to it instead.

## How mods are arranged

One mod is one subfolder inside `mods` containing a `mod.gd` file:

```
mods/
  mod_loader.gd        the loader
  map_studio/
    mod.gd             the mod's entry point
    ...mod files
```

The loader finds every subfolder and runs `mod.gd` from each.

- **To disable a mod without deleting it**, put an empty file named `disabled`
  next to its `mod.gd`.
- **F5** reloads all mods without leaving the game.

What loaded and with which errors is written to the log:
`%APPDATA%\Sir, We Have an Orc Problem\logs\godot.log`.

## Installed mods

- **map_studio** - map editor and generator. Details in
  `map_studio/README.md`.

---

# Моды для «Sir, We Have an Orc Problem»

Игра сделана на Godot и своей системы модов не имеет. Эта - внешняя: она не
трогает ни один файл игры, ничего не распаковывает и не пересобирает.

## Установка

1. Скопируйте в папку с `swhaop.exe` файл `override.cfg` и папку `mods`.
2. Запустите игру.

Права администратора не нужны.

## Удаление

Удалите `override.cfg` - игра сразу станет обычной. Папку `mods` можно
оставить: без этого файла она не читается.

## Как устроены моды

Один мод - одна подпапка внутри `mods` с файлом `mod.gd`. Загрузчик сам
находит все подпапки и запускает из каждой `mod.gd`.

- **Выключить мод, не удаляя** - положите рядом с его `mod.gd` пустой файл
  с именем `disabled`.
- **F5** - перезагрузить все моды не выходя из игры.

`_custom_features="steam"` в `override.cfg` обязателен: без него игра не
свяжется со Steam и потеряет сохранения с достижениями.

## Установленные моды

- **map_studio** - редактор и генератор карт. Подробности -
  в `map_studio/README.ru.md`.
