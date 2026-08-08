# Map Studio

A map editor and generator for **Sir, We Have an Orc Problem**. Draw your own
maps, test them in battle and share them with other players.

*По-русски - [ниже](#map-studio-по-русски).*

![Drawing over a live battle](https://i.imgur.com/SlvRSbG.png)
*Drawing over a live battle - you see the real orcs*

## Install

1. Download **[the latest release](../../releases/latest)**.
2. Unpack the archive next to `swhaop.exe`, usually:
   `C:\Program Files (x86)\Steam\steamapps\common\Sir, We Have an Orc Problem`
3. Start the game.

To remove the mod, delete `override.cfg` - the game is back to normal
immediately. No administrator rights, no patched game files.

> Steam's *Verify integrity of game files* may delete the mod. If that
> happens, just unpack the archive again - the game itself is never touched.

## Getting started

The mod hooks into the game in two places:

- **Game menu** - a **Custom maps** entry, next to *Load Game* and *Options*
- **Tech tree** - a **Your maps** button in the bottom left corner

The **F1** key opens the editor directly.

![The mod adds one entry to the game menu](https://i.imgur.com/ClUaHI7.png)

## What it does

![Your maps and maps shared by other players](https://i.imgur.com/BWrntsT.png)

- Draw maps with a brush: walls, floor, base, orc spawn points
- Generate maps from parameters - five styles based on the patterns the
  game's own levels use: funnel (like 1.1), diamond pillars (like 2.2),
  islands (like 4.1), maze, rooms
- Draw over a live battle (**F2**) and restart it with your changes
- Check a map before playing: the mod builds the world exactly as the game
  does and warns about walls the engine would ignore
- Share maps as small `.json` files

A ready-made map is included: **Surrounded** - a 128×128 maze with orcs
pouring in from five entrances at once, 12 728 of them.

![A battle on Surrounded](https://i.imgur.com/DKLAjH6.png)

## Your Steam achievements stay safe

**Completing a custom map never counts towards Steam.** This is not a setting:
it cannot be switched off, because the mod has no button, mode or flag that
would let a custom map unlock an achievement.

The game grants all 11 achievements through a single call, and the mod
intercepts it: on a player-made map the achievement is silently skipped, on the
game's own levels everything works exactly as before. The original game code is
not rewritten - it lives on a separate node, and when blocking is not needed
the call goes straight to it.

For the same reason custom maps grant no upgrade marks: otherwise *Fully
Loaded* could be farmed on a map drawn for that purpose.

![Achievement protection cannot be switched off](https://i.imgur.com/ZvOdtFS.png)

## What the mod does not do

It deals with maps and nothing else. There is no granting of currency, no
unlocking of upgrades or towers, no marking levels as completed, no unlocking
of achievements, no console or object inspector.

The campaign is never modified: your map lives in a separate slot, game levels
stay untouched, and drawing over a battle is unavailable on them. A game level
can be used as a starting point via *Take a game level's map* in the editor,
which never alters the original.

Speeding up and pausing a battle work **on your own map only** - they are
testing tools.

## Making a map

1. **F1 → Editor tab.** Set a size and press *Create*, or generate a map from
   parameters.
2. Draw with the brushes. Orc spawn points are placed directly on the map.
3. **CHECK MAP** builds the world exactly as the game does and tells you
   whether the map will work.
4. **PLAY** starts a battle on your map.
5. **F2** during the battle lets you fix the map while seeing it in action.

### Walls thinner than three cells do not work

The engine ignores a wall whose width and height are both under three cells -
orcs walk straight through it. That is a property of the game, not of the mod.
*CHECK MAP* finds such places in advance.

## Sharing maps

Your maps are saved to `%APPDATA%\Sir, We Have an Orc Problem\levels\` as plain
`.json` files. Drop someone else's `.json` into `mods/map_studio/maps/` and it
appears in the list marked **shared** - play it right away or copy it into your
own to edit.

## Languages

English and Russian are included; any other language falls back to English.
Adding your own translation takes one file - see
[`mods/map_studio/locale/README.md`](mods/map_studio/locale/README.md).

## How it works

The game is made in Godot and has no mod system. This one is external:

- `override.cfg` is read by Godot next to the executable **before the game
  starts**, and registers an autoload;
- `mods/mod_loader.gd` finds every subfolder of `mods` and runs `mod.gd` from
  each;
- everything is plain text GDScript, compiled at runtime. You can read it and
  check that the mod does exactly what is described here.

Press **F5** in game to reload all mods without restarting.

## License

MIT - see [LICENSE](LICENSE).

Made by [KotiMorte](https://steamcommunity.com/id/Kotemorte86).

---

# Map Studio (по-русски)

Редактор и генератор карт для **Sir, We Have an Orc Problem**. Рисуйте свои
карты, проверяйте их в бою и обменивайтесь ими с другими игроками.

## Установка

1. Скачайте **[последний релиз](../../releases/latest)**.
2. Распакуйте архив в папку с игрой, рядом с `swhaop.exe`:
   `C:\Program Files (x86)\Steam\steamapps\common\Sir, We Have an Orc Problem`
3. Запустите игру.

Чтобы удалить мод, удалите `override.cfg` - игра сразу станет обычной. Ни прав
администратора, ни правки файлов игры.

> Проверка целостности файлов в Steam может удалить мод. Тогда просто
> распакуйте архив заново - сама игра при этом не страдает.

## С чего начать

Мод встраивается в игру в двух местах:

- **Меню игры** - пункт **Пользовательские карты**, рядом с «Загрузить игру»
- **Дерево технологий** - кнопка **Свои карты** в левом нижнем углу

Клавиша **F1** открывает редактор напрямую.

## Что умеет

- Рисование карты кистью: стены, проход, база, точки выхода орков
- Генератор карт по параметрам - пять стилей, повторяющих приёмы уровней самой
  игры: воронка (как 1.1), столбы-ромбы (как 2.2), острова (как 4.1),
  лабиринт, комнаты
- Рисование прямо поверх боя (**F2**) с перезапуском боя по кнопке
- Проверка карты до игры: мод строит мир так же, как это делает игра, и
  предупреждает о стенах, которые движок проигнорирует
- Обмен картами - это небольшие файлы `.json`

В комплекте карта **Surrounded** - лабиринт 128×128, орки лезут одновременно с
пяти входов, всего 12 728 штук.

## Достижения Steam не пострадают

**Прохождение самодельных карт в Steam не засчитывается.** Это не настройка -
отключить нельзя, в моде просто нет такой возможности. На уровнях игры
достижения работают как раньше.

По той же причине свои карты не приносят марок прокачки: иначе «Полную
загрузку» можно было бы получить на карте, нарисованной под фарм.

Кампанию мод не трогает: своя карта живёт в отдельном слоте, уровни игры не
изменяются, рисование поверх боя на них недоступно.

## Стены тоньше трёх клеток не работают

Движок игнорирует стену, у которой и ширина, и высота меньше трёх клеток -
орки проходят сквозь неё. Это особенность самой игры, а не мода. Кнопка
**ПРОВЕРИТЬ КАРТУ** находит такие места заранее.

## Свой язык

Русский и английский в комплекте, для остальных языков используется
английский. Свой перевод добавляется одним файлом - инструкция в
[`mods/map_studio/locale/README.md`](mods/map_studio/locale/README.md).

## Лицензия

MIT - см. [LICENSE](LICENSE).

Автор - [KotiMorte](https://steamcommunity.com/id/Kotemorte86).
