# Translating Map Studio / Перевод Map Studio

**English below.**

---

## Как добавить свой язык

Мод сам определяет язык, на котором идёт игра, и подхватывает нужный файл.

1. Скопируйте `ru.json` и назовите копию кодом своего языка: `de.json`,
   `fr.json`, `pl.json`, `pt_BR.json` и так далее.
2. Переведите **значения**. Ключи - русский текст - трогать нельзя: по ним
   мод находит строку.
3. Сохраните файл в кодировке UTF-8 и перезапустите игру (или нажмите F5).

```json
{
  "Играть": "Spielen",
  "Создать карту": "Karte erstellen"
}
```

### Правила

- **Ключи оставлять как есть.** Изменённый ключ просто не найдётся, и строка
  останется русской.
- **Подстановки сохранять.** `%d`, `%s`, `%.0f`, `%.2f` - на их место
  подставляются числа и названия. Их количество и порядок должны совпадать с
  оригиналом, иначе строка сломается.
- **`\n` - перенос строки.** Оставляйте там, где он есть.
- Ведущие пробелы в начале строк - это отступы в интерфейсе, сохраняйте их.
- Переводить всё необязательно: пропущенные строки останутся русскими.

### Какой файл будет выбран

Порядок поиска для языка `pt_BR`:

1. `pt_BR.json` - точное совпадение;
2. `pt.json` - по языку без региона;
3. `en.json` - запасной вариант.

Русский - исходный язык строк в коде, для него файл не нужен: `ru.json` лежит
здесь только как образец со списком всех строк.

Языки, которые понимает сама игра: `de`, `es`, `fr`, `it`, `ja`, `ko`, `nl`,
`pl`, `pt_BR`, `ru`, `zh_CN`, `zh_TW`, плюс английский.

---

## Adding your own language

The mod detects the language the game is running in and loads the matching
file.

1. Copy `ru.json` and name the copy after your language code: `de.json`,
   `fr.json`, `pl.json`, `pt_BR.json` and so on. If you prefer working from
   English, copy `en.json` instead - the keys are identical.
2. Translate the **values**. Never change the keys (they are the Russian
   original): the mod looks strings up by them.
3. Save as UTF-8 and restart the game (or press F5).

### Rules

- **Keep the keys unchanged.** A modified key simply will not be found and the
  string stays Russian.
- **Keep the placeholders.** `%d`, `%s`, `%.0f`, `%.2f` are replaced with
  numbers and names at runtime. Their count and order must match the original,
  otherwise the string breaks.
- **`\n` is a line break.** Keep it where it appears.
- Leading spaces are interface indentation - keep them too.
- You do not have to translate everything: missing strings fall back to
  Russian.

### Which file gets picked

Lookup order for `pt_BR`:

1. `pt_BR.json` - exact match;
2. `pt.json` - language without region;
3. `en.json` - fallback.

Russian is the language the strings are written in, so it needs no file:
`ru.json` sits here only as a template listing every string.
