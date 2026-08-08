extends Node

const TOGGLE_KEY := KEY_F1
const REFRESH_INTERVAL := 0.25

const AUTHOR_URL := "https://steamcommunity.com/id/Kotemorte86"

const UI_LAYER := 128

var _layer: CanvasLayer
var _root: Control
var _tabs: TabContainer
var _status: Label
var _refreshers: Array[Callable] = []
var _accum := 0.0
var _pause_while_open := false

var _ts_touched := false

var _button_accum := 0.0
var _scene_id := 0
var _menu_buttons: Node = null

const TECH_TREE_PATH := "res://tech_tree/tech_tree.tscn"

var mod_dir: String = ""

var _guard_node: Node = null

func _gm() -> Node: return get_node_or_null("/root/GameManager")
func _ss() -> Node: return get_node_or_null("/root/SaveSystem")
func _st() -> Node: return get_node_or_null("/root/SceneTransition")

func _get(o: Object, prop: String, dflt: Variant = null) -> Variant:
	if o == null:
		return dflt
	var v: Variant = o.get(prop)
	return dflt if v == null else v

func _say(msg: String) -> void:
	if _status:
		_status.text = "  " + msg
	print("[MAP STUDIO] ", msg)

func _battle() -> Node:
	var scene := get_tree().current_scene
	if scene == null:
		return null
	var stack: Array[Node] = [scene]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		var scr := n.get_script()
		if scr != null and str(scr.resource_path).ends_with("battle/battle.gd"):
			return n
		for c in n.get_children():
			stack.append(c)
	return null

func _lbl(parent: Node, text: String, size := 13, col := Color(0.85, 0.87, 0.9)) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	parent.add_child(l)
	return l

func _btn(parent: Node, text: String, cb: Callable, tip := "") -> Button:
	var b := Button.new()
	b.text = text
	b.tooltip_text = tip
	b.add_theme_font_size_override("font_size", 13)
	b.pressed.connect(cb)
	parent.add_child(b)
	return b

func _row(parent: Node) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 4)
	parent.add_child(h)
	return h

func _spin(parent: Node, minv: float, maxv: float, val: float, step := 1.0) -> SpinBox:
	var s := SpinBox.new()
	s.min_value = minv
	s.max_value = maxv
	s.step = step
	s.value = val
	s.custom_minimum_size.x = 130
	s.select_all_on_focus = true
	parent.add_child(s)
	return s

func _check(parent: Node, text: String, val: bool, cb: Callable) -> CheckBox:
	var c := CheckBox.new()
	c.text = text
	c.button_pressed = val
	c.add_theme_font_size_override("font_size", 13)
	c.toggled.connect(cb)
	parent.add_child(c)
	return c

func _sep(parent: Node) -> void:
	parent.add_child(HSeparator.new())

func _clear(n: Node) -> void:
	for c in n.get_children():
		n.remove_child(c)
		c.queue_free()

func _scroll_tab(title: String) -> VBoxContainer:
	var sc := ScrollContainer.new()
	sc.name = title
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_theme_constant_override("separation", 6)
	sc.add_child(v)
	_tabs.add_child(sc)
	return v

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

	_ach_guard()

	_load_locale()
	_build_ui()

func _rebuild_ui() -> void:
	_browser = null
	_browser_grid = null
	_browser_status = null
	_browser_empty = null
	_refreshers.clear()
	if _layer != null and is_instance_valid(_layer):
		_layer.queue_free()
	_build_ui()

func _build_ui() -> void:
	_layer = CanvasLayer.new()
	_layer.layer = UI_LAYER
	add_child(_layer)

	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_layer.add_child(_root)

	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_TOP_LEFT)
	panel.position = Vector2(16, 16)
	panel.custom_minimum_size = Vector2(1010, 700)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.07, 0.08, 0.10, 0.96)
	sb.border_color = Color(0.35, 0.75, 0.45)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(6)
	sb.set_content_margin_all(10)
	panel.add_theme_stylebox_override("panel", sb)
	_root.add_child(panel)

	var outer := VBoxContainer.new()
	outer.add_theme_constant_override("separation", 6)
	panel.add_child(outer)

	var head := _row(outer)
	_lbl(head, "MAP STUDIO", 18, Color(0.45, 0.9, 0.55))
	_lbl(head, _t("   F1 закрыть · F2 рисовать прямо по бою · F5 перезагрузить мод"),
		12, Color(0.5, 0.55, 0.6))

	_tabs = TabContainer.new()
	_tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_tabs.custom_minimum_size.y = 620
	outer.add_child(_tabs)

	_status = Label.new()
	_status.add_theme_font_size_override("font_size", 12)
	_status.add_theme_color_override("font_color", Color(0.6, 0.85, 1.0))
	_status.text = _t("  готово")
	outer.add_child(_status)

	_build_editor()
	_build_about()

	_root.visible = false
	_say(_t("Map Studio загружена"))

func _process(delta: float) -> void:
	_enforce_custom_speed()
	_auto_unregister(delta)
	_watch_locale(delta)

	var sc := get_tree().current_scene
	var sid: int = sc.get_instance_id() if sc != null else 0
	if sid != _scene_id:
		_scene_id = sid
		_button_accum = 999.0
	_button_accum += delta
	if _button_accum >= 0.25:
		_button_accum = 0.0
		_ensure_game_button()
		_ensure_menu_button()
		_cleanup_level_list()

	if _ts_touched and not _is_own_battle():
		Engine.time_scale = 1.0
		_ts_touched = false

	if not _root.visible:
		return
	_accum += delta
	if _accum < REFRESH_INTERVAL:
		return
	_accum = 0.0
	for r in _refreshers:
		r.call()

func _input(event: InputEvent) -> void:
	if not (event is InputEventKey):
		return
	var k := event as InputEventKey
	if not k.pressed or k.echo:
		return

	if k.keycode == TOGGLE_KEY:
		if _live_on:
			_live_exit()
		else:
			_browser_close()
			_toggle()
		get_viewport().set_input_as_handled()
		return

	if _browser_visible() and k.keycode == KEY_ESCAPE:
		_browser_close()
		get_viewport().set_input_as_handled()
		return

	if k.keycode == KEY_F2:
		_live_toggle()
		get_viewport().set_input_as_handled()
		return

	if _live_on and k.keycode == KEY_ESCAPE:
		_live_exit()
		get_viewport().set_input_as_handled()
		return

	if _live_on and k.keycode == KEY_TAB and _live_bar != null:
		_live_bar.visible = not _live_bar.visible
		get_viewport().set_input_as_handled()
		return

	if (_root.visible or _browser_visible()) and k.keycode in [KEY_ESCAPE, KEY_D]:
		get_viewport().set_input_as_handled()

func _browser_visible() -> bool:
	return _browser != null and is_instance_valid(_browser) and _browser.visible

func _ensure_game_button() -> void:
	var sc := get_tree().current_scene
	if sc == null:
		return
	var host := _find_node_by_name(sc, "ControlsVBox")
	if host == null:
		return

	var b: Button = host.get_node_or_null("MapStudioButton")
	if b == null:
		b = Button.new()
		b.name = &"MapStudioButton"
		b.pressed.connect(func() -> void: _browser_open())
		host.add_child(b)
		host.move_child(b, 0)

	b.text = _t("Свои карты")
	b.tooltip_text = _t("Карты игроков: играть, менять, создавать (клавиша F1)")

func _cleanup_level_list() -> void:
	var sc := get_tree().current_scene
	if sc == null or sc.scene_file_path != TECH_TREE_PATH:
		return
	var cont := _find_node_by_name(sc, "LevelContainer")
	if cont == null:
		return
	for c in cont.get_children():
		var v: Variant = c.get("level_id")
		if v != null and int(v) == CUSTOM_LEVEL_KEY:
			cont.remove_child(c)
			c.queue_free()

func _ensure_menu_button() -> void:
	var host := _menu_buttons_node()
	if host == null:
		return

	var b: Button = host.get_node_or_null("MapStudioMenuButton")
	if b == null:
		b = Button.new()
		b.name = &"MapStudioMenuButton"
		b.pressed.connect(func() -> void:
			if _gm() == null or (_get(_gm(), "levels", {}) as Dictionary).is_empty():
				_say(_t("сначала загрузите или начните игру"))
				return
			_hide_game_menu()
			_browser_open())
		host.add_child(b)
		var want: int = _menu_button_index(host)
		if want >= 0 and want < host.get_child_count():
			host.move_child(b, want)

	b.text = _t("Пользовательские карты")
	var levels: Dictionary = _get(_gm(), "levels", {})
	b.disabled = levels.is_empty()
	b.tooltip_text = _t("Редактор карт Map Studio (F1)") if not b.disabled \
		else _t("Доступно после загрузки игры")

func _menu_buttons_node() -> Node:
	if _menu_buttons != null and is_instance_valid(_menu_buttons):
		return _menu_buttons
	var stack: Array[Node] = [get_tree().root]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		if n.has_node("LoadGame") or n.has_node("NewGame"):
			_menu_buttons = n
			return n
		for c in n.get_children():
			stack.append(c)
	return null

func _hide_game_menu() -> void:
	var host := _menu_buttons_node()
	if host == null:
		return
	var n: Node = host
	while n != null:
		if n.has_method("hide_menu"):
			n.call("hide_menu")
			return
		n = n.get_parent()

func _menu_button_index(host: Node) -> int:
	var after := ["LoadGame", "NewGame", "Continue", "Resume"]
	var best := -1
	for c in host.get_children():
		if after.has(String(c.name)):
			best = maxi(best, c.get_index())
	return best + 1 if best >= 0 else -1

func _find_node_by_name(root: Node, wanted: String) -> Node:
	var stack: Array[Node] = [root]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		if String(n.name) == wanted:
			return n
		for c in n.get_children():
			stack.append(c)
	return null

func _toggle() -> void:
	_root.visible = not _root.visible
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if _root.visible:
		_accum = REFRESH_INTERVAL
		_ed_refresh_files()
		if _pause_while_open:
			get_tree().paused = true
	elif _pause_while_open:
		get_tree().paused = false

var _live_on := false
var _live_overlay: Control
var _live_bar: PanelContainer
var _live_img: Image
var _live_brush: Color = MAP_WALL
var _live_size := 2
var _live_info: Label
var _live_hover := Vector2i(-1, -1)
var _live_paused_by_us := false
var _live_name: LineEdit
var _live_source := ""
var _live_source_key := -1
var _live_place_mode := false
var _live_place_busy := false
var _live_spawners: Array = []
var _live_sp_list: VBoxContainer

func _live_can_edit() -> bool:
	return _battle() != null

func _live_toggle() -> void:
	if _live_on:
		_live_exit()
		return
	var b := _battle()
	if b == null:
		_say(_t("рисовать по бою можно только в бою")); return
	if not _is_own_battle():
		_say(_t("F2 работает только на своей карте. Чтобы взять уровень игры за основу, откройте F1 → Редактор → «Взять карту уровня игры»"))
		return
	var data: Object = (b.get("level") as Object).get("data")
	var mt: Object = data.get("map_texture") if data else null
	if mt == null:
		_say(_t("у уровня нет карты")); return
	_live_img = (mt as Texture2D).get_image().duplicate()
	if _live_img.get_format() != Image.FORMAT_RGBA8:
		_live_img.convert(Image.FORMAT_RGBA8)

	_live_source = _t("своя карта «%s»") % String((b.get("level") as Object).get("name"))
	_live_source_key = CUSTOM_LEVEL_KEY

	_live_spawners = _spawners_from_data(
		(b.get("level") as Object).get("data")).duplicate(true)

	_live_build_ui()
	_live_refresh_spawn_list()
	if _live_name and _live_name.text.strip_edges().is_empty():
		_live_name.text = _t("моя_карта")
	_live_on = true
	_live_overlay.visible = true
	_root.visible = false
	if not get_tree().paused:
		get_tree().paused = true
		_live_paused_by_us = true
	_say(_t("рисование по бою: ЛКМ — кисть, ПКМ — стереть, F2 — выход"))

func _live_exit() -> void:
	_live_on = false
	if _live_overlay:
		_live_overlay.visible = false
	if _live_paused_by_us:
		get_tree().paused = false
		_live_paused_by_us = false
	_say(_t("рисование по бою выключено"))

func _live_build_ui() -> void:
	if _live_overlay != null:
		return
	_live_overlay = Control.new()
	_live_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_live_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_live_overlay.draw.connect(_live_draw)
	_live_overlay.gui_input.connect(_live_input)
	_layer.add_child(_live_overlay)

	_live_bar = PanelContainer.new()
	_live_bar.position = Vector2(16, 16)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.07, 0.08, 0.10, 0.95)
	sb.border_color = Color(0.35, 0.75, 0.45)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(6)
	sb.set_content_margin_all(8)
	_live_bar.add_theme_stylebox_override("panel", sb)
	_live_overlay.add_child(_live_bar)

	var sc := ScrollContainer.new()
	sc.custom_minimum_size = Vector2(980, 300)
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_live_bar.add_child(sc)

	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(v)
	_lbl(v, _t("РИСОВАНИЕ ПО БОЮ"), 16, Color(0.45, 0.9, 0.55))
	_live_info = Label.new()
	_live_info.add_theme_font_size_override("font_size", 12)
	_live_info.add_theme_color_override("font_color", Color(0.75, 0.78, 0.82))
	v.add_child(_live_info)

	var r := _row(v)
	_lbl(r, _t("Кисть:"))
	_btn(r, _t("Стена"), func() -> void: _live_brush = MAP_WALL)
	_btn(r, _t("Проход"), func() -> void: _live_brush = MAP_OPEN)
	_btn(r, _t("База"), func() -> void: _live_brush = MAP_BASE)
	_lbl(r, _t(" размер:"))
	for s in [1, 2, 3, 5, 8]:
		_btn(r, str(s), func() -> void: _live_size = s)

	var rs := _row(v)
	_lbl(rs, _t("Имя файла:"))
	_live_name = LineEdit.new()
	_live_name.custom_minimum_size.x = 180
	_live_name.text = _t("моя_карта")
	rs.add_child(_live_name)
	_btn(rs, _t("СОХРАНИТЬ (без перезапуска)"), _live_save,
		_t("Пишет карту и точки спавна в user://levels, бой продолжается"))

	var rmode := _row(v)
	_lbl(rmode, _t("Режим:"))
	var bmode: Button = null
	bmode = _btn(rmode, _t("Рисовать стены"), func() -> void:
		_live_place_mode = not _live_place_mode
		bmode.text = _t("Ставить точки спавна") if _live_place_mode else _t("Рисовать стены")
		_live_overlay.queue_redraw()
		_say(_t("режим: %s") % (_t("расстановка точек") if _live_place_mode else _t("рисование"))))
	_lbl(rmode, _t("  в режиме точек: ЛКМ — поставить, ПКМ — убрать ближайшую"),
		12, Color(0.6, 0.62, 0.66))

	var r2 := _row(v)
	_btn(r2, _t("ПРИМЕНИТЬ"), _live_apply,
		_t("Пересобирает бой без затемнения и возвращает камеру на место"))
	_btn(r2, _t("Сбросить правки"), func() -> void:
		var b := _battle()
		if b == null:
			return
		var d: Object = (b.get("level") as Object).get("data")
		_live_img = ((d.get("map_texture")) as Texture2D).get_image().duplicate()
		if _live_img.get_format() != Image.FORMAT_RGBA8:
			_live_img.convert(Image.FORMAT_RGBA8)
		_live_overlay.queue_redraw()
		_say(_t("правки сброшены")))
	_btn(r2, _t("В редактор карт"), func() -> void:
		_live_to_editor()
		_live_exit()
		_root.visible = true)
	_btn(r2, _t("Выход (F2)"), func() -> void: _live_exit())

	_sep(v)
	var rtoggle := _row(v)
	var game_box := VBoxContainer.new()
	game_box.visible = false
	var map_box := VBoxContainer.new()
	map_box.visible = false
	_btn(rtoggle, _t("Проверка боя ▼"), func() -> void:
		game_box.visible = not game_box.visible
		map_box.visible = false)
	_btn(rtoggle, _t("Карта и уровень ▼"), func() -> void:
		map_box.visible = not map_box.visible
		game_box.visible = false)
	_lbl(rtoggle, _t("  Tab — спрятать панель целиком"), 12, Color(0.6, 0.62, 0.66))
	v.add_child(game_box)
	v.add_child(map_box)

	_lbl(game_box, _t("ПРОВЕРКА СВОЕЙ КАРТЫ"), 14, Color(0.45, 0.9, 0.55))
	var lbat := _lbl(game_box, "", 12)
	_refreshers.append(func() -> void:
		if not _live_on:
			return
		var bb := _battle()
		if bb == null:
			lbat.text = _t("  не в бою")
			return
		if not _is_own_battle():
			lbat.text = _t("  идёт уровень игры — управление боем недоступно")
			return
		lbat.text = _t("  фаза %s   HP базы %.0f   живых %s   убито %s   всего врагов %s") % [
			bb.get("phase"), float(_get(bb, "health", 0.0)),
			bb.get("total_enemies_alive"), bb.get("total_enemies_killed"),
			bb.get("total_enemies_to_spawn")])

	var lspeed := _lbl(game_box, "", 13, Color(1.0, 0.85, 0.35))
	var set_ts := func(s: float) -> void:
		if not _is_own_battle():
			_say(_t("скорость меняется только на своей карте"))
			return
		Engine.time_scale = clampf(s, 0.0, 15.0)
		_ts_touched = not is_equal_approx(Engine.time_scale, 1.0)
		lspeed.text = _t("  скорость: %.2fx") % Engine.time_scale
	var rs1 := _row(game_box)
	for s in [0.0, 0.25, 0.5, 1.0, 2.0, 3.0, 5.0, 8.0, 12.0, 15.0]:
		_btn(rs1, ("%.2f" % s).trim_suffix("0").trim_suffix("0").trim_suffix(".") + "x",
			func() -> void: set_ts.call(s))
	lspeed.text = _t("  скорость: %.2fx") % Engine.time_scale
	_lbl(game_box, _t("  0x — полная заморозка, удобно рассматривать карту. Вне своей карты скорость всегда обычная."),
		12, Color(0.6, 0.62, 0.66))

	var rb := _row(game_box)
	_btn(rb, _t("Пауза боя"), func() -> void:
		if not _is_own_battle():
			_say(_t("только на своей карте")); return
		var bb := _battle()
		if bb and bb.has_method("toggle_pause"): bb.call("toggle_pause"))
	_btn(rb, _t("Начать бой"), func() -> void:
		if not _is_own_battle():
			_say(_t("только на своей карте")); return
		var bb := _battle()
		if bb == null: _say(_t("не в бою")); return
		if int(bb.get("phase")) == 0:
			bb.set("phase", 1)
		if bool(bb.get("is_paused")) and bb.has_method("toggle_pause"):
			bb.call("toggle_pause")
		_say(_t("бой запущен")))

	var rsize := _row(map_box)
	_lbl(rsize, _t("Новая пустая карта, клеток:"))
	var nw := _spin(rsize, 8, 256, 64, 1)
	var nh := _spin(rsize, 8, 256, 44, 1)
	_btn(rsize, _t("Создать"), func() -> void:
		_ed_new(int(nw.value), int(nh.value))
		_live_img = _ed_img.duplicate()
		_live_overlay.queue_redraw()
		_say(_t("создана пустая карта %dx%d — жми ПРИМЕНИТЬ") % [
			int(nw.value), int(nh.value)]))
	_lbl(map_box, _t("  1 клетка = 8 единиц мира. Размер меняется только пересозданием карты."), 12, Color(0.6, 0.62, 0.66))

	var rload := _row(map_box)
	_lbl(rload, _t("Взять карту уровня игры:"))
	var lvp := OptionButton.new()
	lvp.custom_minimum_size.x = 140
	rload.add_child(lvp)
	for k in range(1, 13):
		lvp.add_item(_t("Уровень %d") % k)
	_btn(rload, _t("Загрузить"), func() -> void:
		_ed_load_game_level(lvp.selected + 1)
		if _ed_img != null:
			_live_img = _ed_img.duplicate()
			_live_overlay.queue_redraw()
			_say(_t("карта уровня %d загружена — правь и жми ПРИМЕНИТЬ") % (lvp.selected + 1)))
	_btn(rload, _t("Взять из «Редактора» (F1)"), func() -> void:
		if _ed_img == null:
			_say(_t("в редакторе пусто")); return
		_live_img = _ed_img.duplicate()
		_live_overlay.queue_redraw()
		_say(_t("карта из F1 подставлена — жми ПРИМЕНИТЬ")))
	_lbl(map_box, _t("  Генератор карт живёт в F1, во вкладке «Редактор». Сгенерируй там и нажми кнопку выше."), 12, Color(0.6, 0.62, 0.66))

	_sep(map_box)
	_lbl(map_box, _t("ПАРАМЕТРЫ УРОВНЯ"), 14, Color(0.45, 0.9, 0.55))
	var rp := _row(map_box)
	_lbl(rp, _t("Скорость орков как на уровне:"))
	var lk := _spin(rp, 1, 12, _ed_level_key, 1)
	lk.custom_minimum_size.x = 70
	var sp_lbl := _lbl(rp, "", 12, Color(1.0, 0.85, 0.35))
	var upd_sp := func() -> void:
		sp_lbl.text = "  = %.0f" % (SPEED_BASE + SPEED_PER_LEVEL * _ed_level_key)
	lk.value_changed.connect(func(x: float) -> void:
		_ed_level_key = int(x)
		upd_sp.call())
	upd_sp.call()
	_lbl(rp, _t("  Сила орков:"))
	var hb := _spin(rp, 0.1, 100.0, _ed_health_buff, 0.1)
	hb.custom_minimum_size.x = 80
	hb.value_changed.connect(func(x: float) -> void: _ed_health_buff = x)
	_lbl(map_box, _t("  Скорость задаётся номером уровня (45 + 5 × номер) — это ограничение игры, мы держим её вручную. Сила — множитель здоровья орков. Применяются при нажатии ПРИМЕНИТЬ."),
		12, Color(0.6, 0.62, 0.66))

	_sep(map_box)
	_lbl(map_box, _t("ТОЧКИ СПАВНА"), 14, Color(0.45, 0.9, 0.55))
	_lbl(map_box, _t("  Правятся прямо на карте: включи «Ставить точки» и щёлкай по сцене. Правая кнопка убирает ближайшую."), 12, Color(0.6, 0.62, 0.66))
	var rsp := _row(map_box)
	_btn(rsp, _t("Обновить список"), func() -> void: _live_refresh_spawn_list())
	_btn(rsp, _t("Разделить орков поровну"), func() -> void:
		if _live_spawners.is_empty():
			_say(_t("точек нет")); return
		var total := 0
		for d in _live_spawners:
			total += int(d["amount"])
		var each: int = total / _live_spawners.size()
		for d in _live_spawners:
			d["amount"] = each
		_live_refresh_spawn_list()
		_say(_t("по %d орков на точку") % each))
	_live_sp_list = VBoxContainer.new()
	_live_sp_list.add_theme_constant_override("separation", 2)
	map_box.add_child(_live_sp_list)

func _live_draw() -> void:
	if _live_img == null or _live_overlay == null:
		return
	var ct := get_viewport().get_canvas_transform()
	var upp: float = float(WorldGen.WORLD_UNITS_PER_PIXEL)
	var cell: float = upp * ct.get_scale().x
	if cell < 1.0:
		return
	var view := _live_overlay.size
	var inv := ct.affine_inverse()
	var tl: Vector2 = inv * Vector2.ZERO
	var br: Vector2 = inv * view
	var x0: int = clampi(int(floor(tl.x / upp)) - 1, 0, _live_img.get_width() - 1)
	var y0: int = clampi(int(floor(tl.y / upp)) - 1, 0, _live_img.get_height() - 1)
	var x1: int = clampi(int(ceil(br.x / upp)) + 1, 0, _live_img.get_width())
	var y1: int = clampi(int(ceil(br.y / upp)) + 1, 0, _live_img.get_height())

	for y in range(y0, y1):
		for x in range(x0, x1):
			var c := _live_img.get_pixel(x, y)
			var col := Color(0, 0, 0, 0)
			if c == MAP_WALL:
				col = Color(0.25, 0.45, 1.0, 0.35)
			elif c == MAP_BASE:
				col = Color(1.0, 0.2, 0.2, 0.45)
			elif c == MAP_EDGE:
				col = Color(1.0, 0.2, 1.0, 0.45)
			if col.a <= 0.0:
				continue
			var p: Vector2 = ct * (Vector2(x, y) * upp)
			_live_overlay.draw_rect(Rect2(p, Vector2(cell, cell)), col, true)

	if cell >= 6.0:
		var grid := Color(1, 1, 1, 0.08)
		for x in range(x0, x1 + 1):
			var a: Vector2 = ct * Vector2(x * upp, y0 * upp)
			var bb: Vector2 = ct * Vector2(x * upp, y1 * upp)
			_live_overlay.draw_line(a, bb, grid, 1.0)
		for y in range(y0, y1 + 1):
			var a2: Vector2 = ct * Vector2(x0 * upp, y * upp)
			var b2: Vector2 = ct * Vector2(x1 * upp, y * upp)
			_live_overlay.draw_line(a2, b2, grid, 1.0)

	var fnt := ThemeDB.fallback_font
	for i in _live_spawners.size():
		var d: Dictionary = _live_spawners[i]
		var wp: Vector2 = Vector2(float(d["x"]) + 0.5, float(d["y"]) + 0.5) * upp
		var sp: Vector2 = ct * wp
		_live_overlay.draw_circle(sp, maxf(6.0, cell * 0.6), Color(0.2, 1.0, 0.3, 0.85))
		_live_overlay.draw_circle(sp, maxf(6.0, cell * 0.6), Color(0, 0.35, 0, 1), false, 2.0)
		var vel := Vector2(float(d["vx"]), float(d["vy"]))
		if vel.length() > 0.01:
			var dir := vel.normalized() * maxf(20.0, cell * 2.2)
			_live_overlay.draw_line(sp, sp + dir, Color(0.2, 1.0, 0.3, 0.95), 3.0)
		_live_overlay.draw_string(fnt, sp + Vector2(8, -8), str(i + 1),
			HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(0.8, 1.0, 0.85))

	if _live_hover.x >= 0:
		if _live_place_mode:
			var cp: Vector2 = ct * (Vector2(_live_hover.x + 0.5, _live_hover.y + 0.5) * upp)
			_live_overlay.draw_circle(cp, maxf(8.0, cell * 0.7),
				Color(1, 1, 0.3, 0.9), false, 2.0)
		else:
			var half: int = _live_size / 2
			var hp: Vector2 = ct * (Vector2(_live_hover.x - half, _live_hover.y - half) * upp)
			_live_overlay.draw_rect(
				Rect2(hp, Vector2(cell, cell) * _live_size),
				Color(1, 1, 0.3, 0.9), false, 2.0)

func _live_input(event: InputEvent) -> void:
	if not _live_on or _live_img == null:
		return
	var pos := Vector2.ZERO
	var left := false
	var right := false
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		pos = mb.position
		left = mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT
		right = mb.pressed and mb.button_index == MOUSE_BUTTON_RIGHT
	elif event is InputEventMouseMotion:
		var mm := event as InputEventMouseMotion
		pos = mm.position
		left = (mm.button_mask & MOUSE_BUTTON_MASK_LEFT) != 0
		right = (mm.button_mask & MOUSE_BUTTON_MASK_RIGHT) != 0
	else:
		return

	var inv := get_viewport().get_canvas_transform().affine_inverse()
	var world: Vector2 = inv * pos
	var upp: float = float(WorldGen.WORLD_UNITS_PER_PIXEL)
	var px := int(floor(world.x / upp))
	var py := int(floor(world.y / upp))
	_live_hover = Vector2i(px, py)
	if _live_info:
		_live_info.text = _t("правим: %s   |   клетка (%d, %d)   карта %dx%d   кисть %d") % [
			_live_source, px, py, _live_img.get_width(), _live_img.get_height(),
			_live_size]
	_live_overlay.queue_redraw()

	if not (left or right):
		return

	if _live_place_mode:
		if right:
			_live_remove_spawn_near(px, py)
		elif left and not _live_place_busy:
			_live_place_busy = true
			_live_add_spawn(px, py)
		return
	_live_place_busy = false

	var col: Color = MAP_OPEN if right else _live_brush
	var half: int = _live_size / 2
	for oy in range(-half, _live_size - half):
		for ox in range(-half, _live_size - half):
			var x := px + ox
			var y := py + oy
			if x < 0 or y < 0 or x >= _live_img.get_width() or y >= _live_img.get_height():
				continue
			_live_img.set_pixel(x, y, col)

func _spawners_from_data(data: Object) -> Array:
	var out: Array = []
	if data == null:
		return out
	var upp: int = WorldGen.WORLD_UNITS_PER_PIXEL
	for sp in (data.get("spawners") as Array):
		var p: Vector2 = sp.get("position")
		var vel: Vector2 = sp.get("initial_velocity")
		var ws: Variant = sp.get("waves")
		var amount := 300
		var dur := 20.0
		if ws is Array and not (ws as Array).is_empty():
			amount = int(((ws as Array)[0] as Object).get("amount"))
			dur = float(((ws as Array)[0] as Object).get("duration"))
		out.append({"x": int(round(p.x / upp)), "y": int(round(p.y / upp)),
			"vx": int(vel.x), "vy": int(vel.y), "amount": amount, "duration": dur})
	return out

func _live_add_spawn(px: int, py: int) -> void:
	if _live_img == null:
		return
	var w := _live_img.get_width()
	var h := _live_img.get_height()
	var vel := Vector2i(50, 0)
	var dl := px
	var dr := w - 1 - px
	var dt := py
	var db := h - 1 - py
	var m: int = mini(mini(dl, dr), mini(dt, db))
	if m == dl: vel = Vector2i(50, 0)
	elif m == dr: vel = Vector2i(-50, 0)
	elif m == dt: vel = Vector2i(0, 50)
	else: vel = Vector2i(0, -50)
	_live_spawners.append({"x": px, "y": py, "vx": vel.x, "vy": vel.y,
		"amount": 300, "duration": 20.0})
	_live_refresh_spawn_list()
	_live_overlay.queue_redraw()
	_say(_t("точка спавна в (%d, %d), скорость %s") % [px, py, vel])

func _live_remove_spawn_near(px: int, py: int) -> void:
	if _live_spawners.is_empty():
		return
	var best := -1
	var bd := 1e9
	for i in _live_spawners.size():
		var d: float = Vector2(int(_live_spawners[i]["x"]) - px,
			int(_live_spawners[i]["y"]) - py).length()
		if d < bd:
			bd = d
			best = i
	if best >= 0 and bd < 12.0:
		_live_spawners.remove_at(best)
		_live_refresh_spawn_list()
		_live_overlay.queue_redraw()
		_say(_t("точка убрана, осталось %d") % _live_spawners.size())

func _live_refresh_spawn_list() -> void:
	if _live_sp_list == null:
		return
	_clear(_live_sp_list)
	if _live_spawners.is_empty():
		_lbl(_live_sp_list, _t("Точек нет — орков не будет. Включи «Ставить точки» и щёлкни по карте."), 12, Color(1, 0.75, 0.4))
		return
	var total := 0
	for d in _live_spawners:
		total += int(d["amount"])
	_lbl(_live_sp_list, _t("Всего точек %d, орков суммарно %d") % [
		_live_spawners.size(), total], 12, Color(1.0, 0.85, 0.35))
	for i in _live_spawners.size():
		var d: Dictionary = _live_spawners[i]
		var h := _row(_live_sp_list)
		_lbl(h, "%d:" % (i + 1))
		_lbl(h, _t("клетка"))
		var sx := _spin(h, -64, 512, float(d["x"]), 1)
		sx.custom_minimum_size.x = 75
		sx.value_changed.connect(func(x: float) -> void:
			d["x"] = int(x); _live_overlay.queue_redraw())
		var sy := _spin(h, -64, 512, float(d["y"]), 1)
		sy.custom_minimum_size.x = 75
		sy.value_changed.connect(func(x: float) -> void:
			d["y"] = int(x); _live_overlay.queue_redraw())
		_lbl(h, _t("скор."))
		var svx := _spin(h, -500, 500, float(d["vx"]), 1)
		svx.custom_minimum_size.x = 75
		svx.value_changed.connect(func(x: float) -> void: d["vx"] = int(x))
		var svy := _spin(h, -500, 500, float(d["vy"]), 1)
		svy.custom_minimum_size.x = 75
		svy.value_changed.connect(func(x: float) -> void: d["vy"] = int(x))
		_lbl(h, _t("орков"))
		var sa := _spin(h, 1, 999999, float(d["amount"]), 1)
		sa.custom_minimum_size.x = 95
		sa.value_changed.connect(func(x: float) -> void: d["amount"] = int(x))
		_lbl(h, _t("за,с"))
		var sd := _spin(h, 0.5, 3600, float(d["duration"]), 0.5)
		sd.custom_minimum_size.x = 80
		sd.value_changed.connect(func(x: float) -> void: d["duration"] = x)
		_btn(h, _t("Убрать"), func() -> void:
			_live_spawners.remove_at(i)
			_live_refresh_spawn_list()
			_live_overlay.queue_redraw())

func _live_save() -> void:
	var b := _battle()
	if b == null or _live_img == null:
		_say(_t("не в бою")); return
	var nm := _live_name.text.strip_edges() if _live_name else ""
	if nm.is_empty():
		_say(_t("укажи имя файла")); return

	var data: Object = (b.get("level") as Object).get("data")
	var sps: Array = _live_spawners.duplicate(true) if not _live_spawners.is_empty() \
		else _spawners_from_data(data)

	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(EDITOR_DIR))
	var payload := {
		"name": nm,
		"width": _live_img.get_width(),
		"height": _live_img.get_height(),
		"png_base64": Marshalls.raw_to_base64(_live_img.save_png_to_buffer()),
		"style_level": _ed_style_level,
		"level_key": _ed_level_key,
		"health_buff": float(data.get("enemy_health_buff")),
		"marks": int(data.get("marks_upon_survival")),
		"spawners": sps,
	}
	var file := _safe_file_name(nm) + ".json"
	var f := FileAccess.open(EDITOR_DIR + file, FileAccess.WRITE)
	if f == null:
		_say(_t("не смог записать файл")); return
	f.store_string(JSON.stringify(payload, "  "))
	f.close()
	_ed_refresh_files()
	if _live_info:
		_live_info.text = _t("сохранено «%s» -> %s (бой не прерван)") % [nm, file]
	_say(_t("сохранено «%s» -> %s, бой продолжается") % [nm, file])

func _live_to_editor() -> void:
	var b := _battle()
	if b == null or _live_img == null:
		return
	var data: Object = (b.get("level") as Object).get("data")
	_ed_img = _live_img.duplicate()
	_ed_spawners = _spawners_from_data(data)
	_ed_health_buff = float(data.get("enemy_health_buff"))
	if _ed_name_edit:
		_ed_name_edit.text = _live_name.text if _live_name else _t("моя_карта")
	_ed_refresh_spawners()
	_ed_fit_zoom()
	_say(_t("правки перенесены в «Редактор» (%s)") % _live_source)

func _live_apply() -> void:
	var b := _battle()
	if b == null or _live_img == null:
		_say(_t("не в бою")); return
	var data: Object = (b.get("level") as Object).get("data")

	_ed_img = _live_img.duplicate()
	_ed_spawners = _live_spawners.duplicate(true) if not _live_spawners.is_empty() \
		else _spawners_from_data(data)
	_ed_health_buff = float(data.get("enemy_health_buff"))
	if _ed_name_edit:
		_ed_name_edit.text = _live_name.text if _live_name else _t("моя_карта")

	var was_editing := true
	_live_exit()
	_say(_t("применяю правки…"))
	await _ed_play_fast()

	if was_editing:
		_live_toggle()
		_say(_t("правки применены (обзор камеры сброшен к виду по умолчанию)"))

func _ed_play_fast() -> void:
	var gm := _gm()
	var st := _st()
	if gm == null or st == null:
		return
	var levels: Dictionary = _get(gm, "levels", {})
	var cmap: Dictionary = gm.get_script().get_script_constant_map()
	var LevelCls: Variant = cmap.get("Level")
	if LevelCls == null:
		_say(_t("класс Level не найден")); return
	var nd: Object = _ed_build_level_data()
	levels[CUSTOM_LEVEL_KEY] = (LevelCls as GDScript).new(
		_ed_name_edit.text if _ed_name_edit else _t("моя карта"), nd)
	_ed_custom_registered = true
	gm.set("selected_level", CUSTOM_LEVEL_KEY)
	var gs := get_node_or_null("/root/GPUSim")
	if gs != null and gs.has_method("reset"):
		gs.call("reset")
	st.call("change_scene", Constants.BATTLE_SCENE_PATH, true)
	var w := 0
	while w < 600 and _battle() == null:
		await get_tree().process_frame
		w += 1
	for i in 5:
		await get_tree().process_frame

const MAP_WALL := Color(0, 0, 1, 1)
const MAP_OPEN := Color(0, 0, 0, 0)
const MAP_BASE := Color(1, 0, 0, 1)
const MAP_EDGE := Color(1, 0, 1, 1)
const EDITOR_DIR := "user://levels/"

const MIN_WALL := 3
const MIN_BLOCK := 5

const SPEED_BASE := 45.0
const SPEED_PER_LEVEL := 5.0
const CUSTOM_LEVEL_KEY := 9001

var _ed_img: Image
var _ed_tex: ImageTexture
var _ed_rect: TextureRect
var _ed_brush: Color = MAP_WALL
var _ed_spawners: Array = []
var _ed_sp_list: VBoxContainer
var _ed_status: Label
var _ed_name_edit: LineEdit
var _ed_style_level: int = 1
var _ed_files: OptionButton
var _ed_file_names: Array[String] = []
var _ed_health_buff := 1.0
var _ed_marks := 100
var _ed_level_key := 1
var _ed_custom_registered := false
var _ed_battle_seen := false
var _ed_no_battle_time := 0.0
var _ed_prev_level := 1
var _ed_zoom := 16
var _ed_brush_size := 1
var _ed_coords: Label
var _ed_preview: Image

func _build_editor() -> void:
	var v := _scroll_tab(_t("Редактор"))
	_lbl(v, _t("Карта — картинка, 1 пиксель = 8 единиц мира. Рисуй мышью."),
		12, Color(0.6, 0.62, 0.66))
	_lbl(v, _t("В бою можно рисовать прямо по сцене: клавиша F2. Там видно настоящие стены, башни и орков, а «Применить» пересобирает бой."),
		12, Color(0.45, 0.9, 0.55))

	var r1 := _row(v)
	_lbl(r1, _t("Размер, пикс:"))
	var sw := _spin(r1, 8, 256, 32, 1)
	var sh := _spin(r1, 8, 256, 32, 1)
	_btn(r1, _t("Новая карта"), func() -> void:
		_ed_new(int(sw.value), int(sh.value)))
	_btn(r1, _t("Залить стеной"), func() -> void:
		if _ed_img: _ed_img.fill(MAP_WALL); _ed_update_tex())
	_btn(r1, _t("Очистить"), func() -> void:
		if _ed_img: _ed_img.fill(MAP_OPEN); _ed_border(); _ed_update_tex())

	_build_gen_panel(v)
	_lbl(v, _t("ВАЖНО: стена тоньше %d клеток игрой игнорируется, отдельный блок ")
		% MIN_WALL + _t("должен быть не меньше %dx%d. Замерено на движке.")
		% [MIN_BLOCK, MIN_BLOCK], 12, Color(1, 0.75, 0.4))

	var rl := _row(v)
	_lbl(rl, _t("Взять карту уровня игры:"))
	var lvpick := OptionButton.new()
	lvpick.custom_minimum_size.x = 150
	rl.add_child(lvpick)
	for k in range(1, 13):
		lvpick.add_item(_t("Уровень %d") % k)
	_btn(rl, _t("Загрузить для правки"), func() -> void:
		_ed_load_game_level(lvpick.selected + 1))
	_lbl(rl, _t("— можно править готовые карты"), 12, Color(0.6, 0.62, 0.66))

	var r2 := _row(v)
	_lbl(r2, _t("Кисть:"))
	_btn(r2, _t("Стена"), func() -> void: _ed_brush = MAP_WALL; _ed_say(_t("кисть: стена")))
	_btn(r2, _t("Проход"), func() -> void: _ed_brush = MAP_OPEN; _ed_say(_t("кисть: проход")))
	_btn(r2, _t("База"), func() -> void: _ed_brush = MAP_BASE; _ed_say(_t("кисть: база")))
	_btn(r2, _t("Кромка"), func() -> void: _ed_brush = MAP_EDGE; _ed_say(_t("кисть: кромка")))
	_lbl(r2, _t("  размер:"))
	for bs in [1, 2, 3, 5, 8]:
		_btn(r2, str(bs), func() -> void:
			_ed_brush_size = bs
			_ed_say(_t("размер кисти: %d") % bs))
	_lbl(r2, _t("  масштаб:"))
	_btn(r2, "−", func() -> void: _ed_set_zoom(_ed_zoom - 4))
	_btn(r2, "+", func() -> void: _ed_set_zoom(_ed_zoom + 4))
	_btn(r2, _t("Вписать"), func() -> void: _ed_fit_zoom())
	_lbl(v, _t("Левая кнопка мыши — рисовать выбранной кистью, правая — стирать в проход."),
		12, Color(0.6, 0.62, 0.66))

	var r3 := _row(v)
	_lbl(r3, _t("Оформление с уровня:"))
	var style := OptionButton.new()
	style.custom_minimum_size.x = 150
	r3.add_child(style)
	for k in range(1, 13):
		style.add_item(_t("Уровень %d") % k)
	style.item_selected.connect(func(i: int) -> void: _ed_style_level = i + 1)
	_lbl(r3, _t("Сила орков:"))
	var hb := _spin(r3, 0.1, 100.0, 1.0, 0.1)
	hb.value_changed.connect(func(x: float) -> void: _ed_health_buff = x)
	_lbl(r3, _t("  Свои карты наград не приносят"), 12, Color(0.6, 0.62, 0.66))

	var r3b := _row(v)
	_lbl(r3b, _t("Скорость орков как на уровне:"))
	var lk := _spin(r3b, 1, 12, 1, 1)
	var speed_lbl := _lbl(r3b, "", 13, Color(1.0, 0.85, 0.35))
	var upd_speed := func() -> void:
		speed_lbl.text = _t("  скорость: %.0f") % [
			SPEED_BASE + SPEED_PER_LEVEL * _ed_level_key]
	lk.value_changed.connect(func(x: float) -> void:
		_ed_level_key = int(x)
		upd_speed.call())
	upd_speed.call()
	_lbl(v, _t("Своя карта живёт в отдельном слоте и штатные уровни НЕ занимает. Скорость орков в игре задаётся номером уровня (45 + 5 × номер), поэтому мы держим её вручную."), 12, Color(0.6, 0.62, 0.66))

	_sep(v)
	var canvas_scroll := ScrollContainer.new()
	canvas_scroll.custom_minimum_size = Vector2(960, 620)
	canvas_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	canvas_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	v.add_child(canvas_scroll)

	_ed_rect = TextureRect.new()
	_ed_rect.stretch_mode = TextureRect.STRETCH_KEEP
	_ed_rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_ed_rect.mouse_filter = Control.MOUSE_FILTER_STOP
	_ed_rect.gui_input.connect(_ed_on_input)
	canvas_scroll.add_child(_ed_rect)

	_ed_coords = Label.new()
	_ed_coords.add_theme_font_size_override("font_size", 12)
	_ed_coords.add_theme_color_override("font_color", Color(0.75, 0.78, 0.82))
	v.add_child(_ed_coords)

	_ed_status = Label.new()
	_ed_status.add_theme_font_size_override("font_size", 12)
	_ed_status.add_theme_color_override("font_color", Color(0.6, 0.85, 1.0))
	v.add_child(_ed_status)
	_sep(v)

	_lbl(v, _t("Точки спавна (координаты в пикселях карты, можно за краем)"),
		14, Color(0.45, 0.9, 0.55))
	var r4 := _row(v)
	_btn(r4, _t("Добавить точку"), func() -> void:
		_ed_spawners.append({"x": -2, "y": 8, "vx": 50, "vy": 0,
			"amount": 300, "duration": 20.0})
		_ed_refresh_spawners())
	_btn(r4, _t("Убрать последнюю"), func() -> void:
		if not _ed_spawners.is_empty():
			_ed_spawners.pop_back()
			_ed_refresh_spawners())
	_ed_sp_list = VBoxContainer.new()
	_ed_sp_list.add_theme_constant_override("separation", 2)
	v.add_child(_ed_sp_list)

	_sep(v)
	_lbl(v, _t("СОХРАНЁННЫЕ КАРТЫ"), 14, Color(0.45, 0.9, 0.55))
	var r5 := _row(v)
	_lbl(r5, _t("Название карты:"))
	_ed_name_edit = LineEdit.new()
	_ed_name_edit.text = _t("Моя карта")
	_ed_name_edit.custom_minimum_size.x = 220
	_ed_name_edit.placeholder_text = _t("как будет называться уровень")
	r5.add_child(_ed_name_edit)
	_btn(r5, _t("Сохранить"), func() -> void: _ed_save(true),
		_t("Перезаписывает карту с таким же названием"))
	_btn(r5, _t("Сохранить как новую"), func() -> void: _ed_save(false),
		_t("Всегда создаёт отдельный файл"))

	var r5b := _row(v)
	_lbl(r5b, _t("Открыть:"))
	_ed_files = OptionButton.new()
	_ed_files.custom_minimum_size.x = 300
	r5b.add_child(_ed_files)
	_btn(r5b, _t("Загрузить"), func() -> void: _ed_load_selected())
	_btn(r5b, _t("Удалить"), func() -> void: _ed_delete_selected())
	_btn(r5b, _t("Обновить список"), func() -> void: _ed_refresh_files())

	var r5c := _row(v)
	_lbl(r5c, _t("Обмен картами:"))
	_btn(r5c, _t("Поделиться"), func() -> void: _ed_share_selected(),
		_t("Копирует выбранную карту в папку обмена мода"))
	_btn(r5c, _t("Сделать своей"), func() -> void: _ed_import_selected(),
		_t("Копирует чужую карту в личные, чтобы можно было править"))
	_btn(r5c, _t("Открыть папку обмена"), func() -> void:
		var share_dir := _ed_shared_dir()
		if share_dir == "":
			_ed_say(_t("папка обмена недоступна")); return
		DirAccess.make_dir_recursive_absolute(share_dir)
		OS.shell_open(share_dir))
	_lbl(v, _t("  Имя файла делается из названия автоматически. Свои карты — в %s, ")
		% EDITOR_DIR
		+ _t("чужие достаточно положить .json в папку обмена внутри мода: они появятся в списке с пометкой «общая»."),
		12, Color(0.6, 0.62, 0.66))

	var r6 := _row(v)
	_btn(r6, _t("ПРОВЕРИТЬ КАРТУ"), _ed_validate,
		_t("Строит мир из картинки и сообщает, годится ли она"))
	_btn(r6, _t("ИГРАТЬ"), _ed_play, _t("Регистрирует уровень и запускает бой"))
	_btn(r6, _t("Открыть папку"), func() -> void:
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(EDITOR_DIR))
		OS.shell_open(ProjectSettings.globalize_path(EDITOR_DIR)))
	_btn(r6, _t("Убрать свой уровень"), func() -> void:
		_ed_unregister()
		_ed_say(_t("свой уровень убран из списка")))
	_sep(v)
	_lbl(v, _t("Своя карта живёт в отдельном слоте и уровни игры не подменяет — кампания остаётся нетронутой."), 12, Color(0.6, 0.62, 0.66))

	_ed_new(32, 32)
	_ed_spawners.append({"x": -2, "y": 8, "vx": 50, "vy": 0,
		"amount": 300, "duration": 20.0})
	_ed_refresh_spawners()
	_ed_refresh_files()

var _gen_style := 0
var _gen_wind := 0.45
var _gen_corridor := 3
var _gen_open := 0.15
var _gen_seed := 12345
var _gen_spawns := 1
var _gen_bases := 1
var _gen_spawn_side := 0
var _gen_base_side := 1
var _gen_last_report := ""

const GEN_STYLES := ["Воронка (как 1.1)", "Столбы-ромбы (как 2.2)",
		"Острова (как 4.1)", "Лабиринт", "Комнаты"]
const GEN_SIDES := ["Слева", "Справа", "Сверху", "Снизу", "Со всех сторон"]
const GEN_BASE_PLACES := ["Полосой на краю", "Блоком в центре"]

var _gen_base_center := false
var _gen_base_size := 3

func _build_gen_panel(v: Node) -> void:
	_lbl(v, _t("ГЕНЕРАТОР КАРТ"), 14, Color(0.45, 0.9, 0.55))

	var r1 := _row(v)
	_lbl(r1, _t("Стиль:"))
	var gstyle := OptionButton.new()
	gstyle.custom_minimum_size.x = 165
	r1.add_child(gstyle)
	for t in GEN_STYLES:
		gstyle.add_item(_t(t))
	gstyle.selected = _gen_style
	var style_hint := _lbl(v, "", 12, Color(0.6, 0.62, 0.66))
	var upd_hint := func() -> void:
		var hints := [
			_t("Воронка — как уровень 1.1: широкий вход, длинное узкое горло, арена у базы. Горло и есть место под башни."),
			_t("Столбы-ромбы — как уровень 2.2: открытые полосы с ромбовидными препятствиями, они расщепляют поток орков."),
			_t("Острова — как уровень 4.1: крупные рваные массивы суши, между ними широкие проходы. Больше свободы в расстановке."),
			_t("Лабиринт — плотная сеть ходов, много развилок и тупиков."),
			_t("Комнаты — залы, соединённые проходами. Просторно под башни."),
		]
		style_hint.text = "  " + hints[clampi(_gen_style, 0, hints.size() - 1)]
	gstyle.item_selected.connect(func(i: int) -> void:
		_gen_style = i
		upd_hint.call())
	upd_hint.call()

	var r2 := _row(v)
	_lbl(r2, _t("Входов орков:"))
	var gsp := _spin(r2, 1, 8, _gen_spawns, 1)
	gsp.custom_minimum_size.x = 70
	gsp.value_changed.connect(func(x: float) -> void: _gen_spawns = int(x))
	_lbl(r2, _t("с края:"))
	var gss := OptionButton.new()
	gss.custom_minimum_size.x = 140
	r2.add_child(gss)
	for s in GEN_SIDES:
		gss.add_item(_t(s))
	gss.selected = _gen_spawn_side
	gss.item_selected.connect(func(i: int) -> void: _gen_spawn_side = i)

	var r3 := _row(v)
	_lbl(r3, _t("Баз:"))
	var gb := _spin(r3, 1, 4, _gen_bases, 1)
	gb.custom_minimum_size.x = 70
	gb.value_changed.connect(func(x: float) -> void: _gen_bases = int(x))
	_lbl(r3, _t("с края:"))
	var gbs := OptionButton.new()
	gbs.custom_minimum_size.x = 140
	r3.add_child(gbs)
	for s in GEN_SIDES:
		gbs.add_item(_t(s))
	gbs.selected = _gen_base_side
	gbs.item_selected.connect(func(i: int) -> void: _gen_base_side = i)

	var r3b := _row(v)
	_lbl(r3b, _t("База:"))
	var gbp := OptionButton.new()
	gbp.custom_minimum_size.x = 160
	r3b.add_child(gbp)
	for s in GEN_BASE_PLACES:
		gbp.add_item(_t(s))
	gbp.selected = 1 if _gen_base_center else 0
	gbp.item_selected.connect(func(i: int) -> void: _gen_base_center = (i == 1))
	_lbl(r3b, _t("размер:"))
	var gbz := _spin(r3b, 1, 12, _gen_base_size, 1)
	gbz.custom_minimum_size.x = 70
	gbz.value_changed.connect(func(x: float) -> void: _gen_base_size = int(x))
	_lbl(v, _t("  Базы — то, что орки идут ломать, входы — откуда они лезут. «Блоком в центре» повторяет уровень 6.1: оборона со всех сторон."),
		12, Color(0.6, 0.62, 0.66))

	var r4 := _row(v)
	_lbl(r4, _t("Извилистость %"))
	var gw2 := _spin(r4, 0, 90, int(_gen_wind * 100), 5)
	gw2.custom_minimum_size.x = 80
	gw2.value_changed.connect(func(x: float) -> void: _gen_wind = x / 100.0)
	_lbl(r4, _t("Ширина прохода"))
	var gc := _spin(r4, 1, 12, _gen_corridor, 1)
	gc.custom_minimum_size.x = 70
	gc.value_changed.connect(func(x: float) -> void: _gen_corridor = int(x))
	_lbl(r4, _t("Простор %"))
	var go := _spin(r4, 0, 100, int(_gen_open * 100), 5)
	go.custom_minimum_size.x = 80
	go.value_changed.connect(func(x: float) -> void: _gen_open = x / 100.0)
	_lbl(v, _t("  Извилистость — насколько путь петляет. Простор — сколько лишних клеток открыть под башни."), 12, Color(0.6, 0.62, 0.66))

	var r5 := _row(v)
	_lbl(r5, _t("Зерно:"))
	var gs := _spin(r5, 0, 999999, _gen_seed, 1)
	gs.custom_minimum_size.x = 120
	gs.value_changed.connect(func(x: float) -> void: _gen_seed = int(x))
	_btn(r5, _t("Случайное зерно"), func() -> void:
		gs.value = randi() % 1000000
		_gen_seed = int(gs.value)
		_gen_generate())
	_btn(r5, _t("СГЕНЕРИРОВАТЬ"), func() -> void: _gen_generate())
	_lbl(v, _t("  Одно зерно всегда даёт одну и ту же карту — удобно повторять удачный результат."), 12, Color(0.6, 0.62, 0.66))
	_lbl(v, _t("Стены тоньше %d клеток игра не видит вовсе — генератор это ")
		% MIN_WALL + _t("соблюдает сам."), 12, Color(1, 0.75, 0.4))

func _gen_edge_cell(side: int, i: int, total: int, gw: int, gh: int,
		rng: RandomNumberGenerator) -> Dictionary:
	var s := side
	if s == 4:
		s = rng.randi() % 4
	var t: float = (float(i) + 0.5) / float(maxi(1, total))
	match s:
		0: return {"cell": Vector2i(0, clampi(int(t * gh), 0, gh - 1)), "side": 0}
		1: return {"cell": Vector2i(gw - 1, clampi(int(t * gh), 0, gh - 1)), "side": 1}
		2: return {"cell": Vector2i(clampi(int(t * gw), 0, gw - 1), 0), "side": 2}
		_: return {"cell": Vector2i(clampi(int(t * gw), 0, gw - 1), gh - 1), "side": 3}

func _gen_walk(a: Vector2i, b: Vector2i, gw: int, gh: int,
		rng: RandomNumberGenerator) -> Array:
	var out: Array = [a]
	var cur := a
	var guard := 0
	while cur != b and guard < gw * gh * 6:
		guard += 1
		var opts: Array[Vector2i] = []
		if cur.x != b.x:
			opts.append(Vector2i(signi(b.x - cur.x), 0))
		if cur.y != b.y:
			opts.append(Vector2i(0, signi(b.y - cur.y)))
		if rng.randf() < _gen_wind:
			var side := Vector2i(0, 1) if rng.randf() < 0.5 else Vector2i(0, -1)
			if cur.x == b.x:
				side = Vector2i(1, 0) if rng.randf() < 0.5 else Vector2i(-1, 0)
			opts.append(side)
		if opts.is_empty():
			break
		var d: Vector2i = opts[rng.randi() % opts.size()]
		var nxt := Vector2i(clampi(cur.x + d.x, 0, gw - 1), clampi(cur.y + d.y, 0, gh - 1))
		if nxt == cur:
			break
		cur = nxt
		out.append(cur)
	return out

func _gen_generate() -> void:
	var w: int = _ed_img.get_width() if _ed_img else 64
	var h: int = _ed_img.get_height() if _ed_img else 44
	var rng := RandomNumberGenerator.new()
	rng.seed = _gen_seed

	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	img.fill(MAP_WALL)

	var step: int = _gen_corridor + MIN_WALL
	var gw: int = maxi(3, (w - MIN_WALL * 2) / step)
	var gh: int = maxi(3, (h - MIN_WALL * 2) / step)

	var bases: Array = []
	if _gen_base_center:
		bases.append({"cell": Vector2i(gw / 2, gh / 2), "side": -1})
	else:
		for i in _gen_bases:
			bases.append(_gen_edge_cell(_gen_base_side, i, _gen_bases, gw, gh, rng))
	var spawns: Array = []
	for i in _gen_spawns:
		spawns.append(_gen_edge_cell(_gen_spawn_side, i, _gen_spawns, gw, gh, rng))

	var cells := {}
	var paths: Array = []
	for sp in spawns:
		var from: Vector2i = sp["cell"]
		var best: Vector2i = bases[0]["cell"]
		var bd := 1e9
		for bs in bases:
			var dd: float = Vector2(from - (bs["cell"] as Vector2i)).length()
			if dd < bd:
				bd = dd
				best = bs["cell"]
		var p := _gen_walk(from, best, gw, gh, rng)
		paths.append(p)
		for c in p:
			cells[c] = true
	for bs in bases:
		cells[bs["cell"]] = true

	match _gen_style:
		0:
			_gen_style_funnel(cells, paths, gw, gh)
		1:
			_gen_open_around(cells, gw, gh, 2)
		2:
			_gen_open_around(cells, gw, gh, 3)
		3:
			_gen_style_maze(cells, gw, gh, rng)
		_:
			_gen_style_rooms(cells, paths, gw, gh, rng)

	if _gen_open > 0.0 and _gen_style != 0:
		var extra: int = int(gw * gh * _gen_open)
		var keys: Array = cells.keys()
		for i in extra:
			if keys.is_empty():
				break
			var c: Vector2i = keys[rng.randi() % keys.size()]
			var d: Vector2i = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1),
				Vector2i(0, -1)][rng.randi() % 4]
			var n := Vector2i(clampi(c.x + d.x, 0, gw - 1), clampi(c.y + d.y, 0, gh - 1))
			cells[n] = true

	for c in cells:
		_gen_carve_cell(img, c, step)
	for c in cells:
		for d in [Vector2i(1, 0), Vector2i(0, 1)]:
			if cells.has((c as Vector2i) + d):
				_gen_link_cells(img, c, (c as Vector2i) + d, step)

	_gen_frame(img)
	var base_pixels: Array = []
	for bs in bases:
		if int(bs["side"]) < 0:
			base_pixels.append_array(_gen_center_base(img, bs, step))
		else:
			base_pixels.append_array(_gen_cut_base(img, bs, step))
	var entries: Array = []
	for sp in spawns:
		entries.append(_gen_cut_entry(img, sp, step))

	match _gen_style:
		1: _gen_pillars(img, rng, step)
		2: _gen_islands(img, rng, step)
		_: pass

	_gen_cleanup_thin(img)

	var fixed := 0
	for i in entries.size():
		if not _gen_reaches_base(img, entries[i]["pixel"]):
			_gen_force_link(img, entries[i], bases, step)
			fixed += 1
	_gen_cleanup_thin(img)

	_ed_img = img
	_ed_spawners.clear()
	for en in entries:
		var p: Vector2i = en["pixel"]
		var side: int = en["side"]
		var pos := Vector2i(p.x, p.y)
		var vel := Vector2i(50, 0)
		match side:
			0: pos.x = -2; vel = Vector2i(50, 0)
			1: pos.x = w + 1; vel = Vector2i(-50, 0)
			2: pos.y = -2; vel = Vector2i(0, 50)
			_: pos.y = h + 1; vel = Vector2i(0, -50)
		_ed_spawners.append({"x": pos.x, "y": pos.y, "vx": vel.x, "vy": vel.y,
			"amount": int(400 / maxi(1, entries.size())), "duration": 20.0})
	_ed_refresh_spawners()
	_ed_fit_zoom()

	var open_cnt := 0
	for y in h:
		for x in w:
			if img.get_pixel(x, y) == MAP_OPEN:
				open_cnt += 1
	_gen_last_report = (_t("%s %dx%d, зерно %d: входов %d, баз %d, проходимых клеток %d")
		% [_t(GEN_STYLES[_gen_style]), w, h, _gen_seed, entries.size(), bases.size(), open_cnt])
	if fixed > 0:
		_gen_last_report += _t(", досоединено входов: %d") % fixed
	_ed_say(_gen_last_report)

func _gen_open_around(cells: Dictionary, gw: int, gh: int, r: int) -> void:
	var seed_cells: Array = cells.keys()
	for c in seed_cells:
		var cc: Vector2i = c
		for oy in range(-r, r + 1):
			for ox in range(-r, r + 1):
				if absi(ox) + absi(oy) > r:
					continue
				var n := Vector2i(clampi(cc.x + ox, 0, gw - 1), clampi(cc.y + oy, 0, gh - 1))
				cells[n] = true

func _gen_style_funnel(cells: Dictionary, paths: Array, gw: int, gh: int) -> void:
	for p in paths:
		var pth: Array = p
		var n := pth.size()
		if n < 3:
			continue
		for i in n:
			var t: float = float(i) / float(n - 1)
			var r := 0
			if t < 0.28:
				r = 2
			elif t > 0.70:
				r = 3
			if r == 0:
				continue
			var c: Vector2i = pth[i]
			for oy in range(-r, r + 1):
				for ox in range(-r, r + 1):
					if absi(ox) + absi(oy) > r:
						continue
					cells[Vector2i(clampi(c.x + ox, 0, gw - 1),
						clampi(c.y + oy, 0, gh - 1))] = true

func _gen_pillars(img: Image, rng: RandomNumberGenerator, step: int) -> void:
	var w := img.get_width()
	var h := img.get_height()
	var spacing: int = maxi(8, step * 2)
	var y := spacing
	while y < h - spacing:
		var x: int = spacing + (spacing / 2 if (y / spacing) % 2 == 1 else 0)
		while x < w - spacing:
			var r: int = rng.randi_range(2, maxi(2, _gen_corridor))
			if _gen_area_is_open(img, x, y, r + _gen_corridor):
				_gen_diamond(img, x, y, r)
			x += spacing
		y += spacing

func _gen_area_is_open(img: Image, cx: int, cy: int, r: int) -> bool:
	var w := img.get_width()
	var h := img.get_height()
	for oy in range(-r, r + 1):
		for ox in range(-r, r + 1):
			var x := cx + ox
			var y := cy + oy
			if x < 0 or y < 0 or x >= w or y >= h:
				return false
			if img.get_pixel(x, y) != MAP_OPEN:
				return false
	return true

func _gen_diamond(img: Image, cx: int, cy: int, r: int) -> void:
	var w := img.get_width()
	var h := img.get_height()
	for oy in range(-r, r + 1):
		for ox in range(-r, r + 1):
			if absi(ox) + absi(oy) > r:
				continue
			var x := cx + ox
			var y := cy + oy
			if x > 0 and y > 0 and x < w - 1 and y < h - 1:
				img.set_pixel(x, y, MAP_WALL)

func _gen_islands(img: Image, rng: RandomNumberGenerator, step: int) -> void:
	var w := img.get_width()
	var h := img.get_height()
	var count: int = clampi(int(w * h / 900.0), 2, 14)
	for i in count:
		var cx: int = rng.randi_range(step, maxi(step + 1, w - step))
		var cy: int = rng.randi_range(step, maxi(step + 1, h - step))
		var rx: int = rng.randi_range(step, step * 3)
		var ry: int = rng.randi_range(step, step * 3)
		if not _gen_area_is_open(img, cx, cy, maxi(rx, ry) + _gen_corridor):
			continue
		for oy in range(-ry, ry + 1):
			for ox in range(-rx, rx + 1):
				var fx: float = float(ox) / maxf(1.0, float(rx))
				var fy: float = float(oy) / maxf(1.0, float(ry))
				var d: float = fx * fx + fy * fy
				if d > 1.0:
					continue
				if d > 0.62 and rng.randf() < 0.45:
					continue
				var x := cx + ox
				var y := cy + oy
				if x > 0 and y > 0 and x < w - 1 and y < h - 1:
					img.set_pixel(x, y, MAP_WALL)

func _gen_style_maze(cells: Dictionary, gw: int, gh: int,
		rng: RandomNumberGenerator) -> void:
	var visited := {}
	var stack: Array[Vector2i] = [Vector2i(0, 0)]
	visited[Vector2i(0, 0)] = true
	cells[Vector2i(0, 0)] = true
	while not stack.is_empty():
		var cur: Vector2i = stack[-1]
		var opts: Array[Vector2i] = []
		for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var n: Vector2i = cur + d
			if n.x >= 0 and n.y >= 0 and n.x < gw and n.y < gh and not visited.has(n):
				opts.append(n)
		if opts.is_empty():
			stack.pop_back()
			continue
		var nxt: Vector2i = opts[rng.randi() % opts.size()]
		visited[nxt] = true
		cells[nxt] = true
		stack.append(nxt)

func _gen_style_rooms(cells: Dictionary, paths: Array, gw: int, gh: int,
		rng: RandomNumberGenerator) -> void:
	var rooms: int = clampi(int(gw * gh / 14.0), 2, 12)
	for i in rooms:
		var rw: int = rng.randi_range(2, 4)
		var rh: int = rng.randi_range(2, 3)
		var rx: int = rng.randi_range(0, maxi(0, gw - rw))
		var ry: int = rng.randi_range(0, maxi(0, gh - rh))
		for y in range(ry, mini(ry + rh, gh)):
			for x in range(rx, mini(rx + rw, gw)):
				cells[Vector2i(x, y)] = true
		if paths.is_empty():
			continue
		var pth: Array = paths[rng.randi() % paths.size()]
		var near: Vector2i = pth[0]
		var best := 1e9
		for c in pth:
			var dd: float = Vector2((c as Vector2i) - Vector2i(rx, ry)).length()
			if dd < best:
				best = dd
				near = c
		var cc := Vector2i(rx, ry)
		while cc.x != near.x:
			cc.x += signi(near.x - cc.x)
			cells[cc] = true
		while cc.y != near.y:
			cc.y += signi(near.y - cc.y)
			cells[cc] = true

func _gen_carve_cell(img: Image, c: Vector2i, step: int) -> void:
	var x0: int = MIN_WALL + c.x * step
	var y0: int = MIN_WALL + c.y * step
	for y in range(y0, y0 + _gen_corridor):
		for x in range(x0, x0 + _gen_corridor):
			if x > 0 and y > 0 and x < img.get_width() - 1 and y < img.get_height() - 1:
				img.set_pixel(x, y, MAP_OPEN)

func _gen_link_cells(img: Image, a: Vector2i, b: Vector2i, step: int) -> void:
	var ax: int = MIN_WALL + a.x * step
	var ay: int = MIN_WALL + a.y * step
	var bx: int = MIN_WALL + b.x * step
	var by: int = MIN_WALL + b.y * step
	for y in range(mini(ay, by), maxi(ay, by) + _gen_corridor):
		for x in range(mini(ax, bx), maxi(ax, bx) + _gen_corridor):
			if x > 0 and y > 0 and x < img.get_width() - 1 and y < img.get_height() - 1:
				img.set_pixel(x, y, MAP_OPEN)

func _gen_frame(img: Image) -> void:
	var w := img.get_width()
	var h := img.get_height()
	for k in MIN_WALL:
		for x in w:
			if k < h:
				img.set_pixel(x, k, MAP_WALL)
				img.set_pixel(x, h - 1 - k, MAP_WALL)
		for y in h:
			if k < w:
				img.set_pixel(k, y, MAP_WALL)
				img.set_pixel(w - 1 - k, y, MAP_WALL)

func _gen_cell_center(c: Vector2i, step: int) -> Vector2i:
	return Vector2i(MIN_WALL + c.x * step + _gen_corridor / 2,
		MIN_WALL + c.y * step + _gen_corridor / 2)

func _gen_connector(img: Image, c: Vector2i, side: int, step: int) -> void:
	var w := img.get_width()
	var h := img.get_height()
	var x0: int = MIN_WALL + c.x * step
	var y0: int = MIN_WALL + c.y * step
	var x1: int = x0 + _gen_corridor - 1
	var y1: int = y0 + _gen_corridor - 1
	match side:
		0:
			for y in range(y0, y1 + 1):
				for x in range(1, x0 + 1):
					if y > 0 and y < h - 1 and x < w - 1:
						img.set_pixel(x, y, MAP_OPEN)
		1:
			for y in range(y0, y1 + 1):
				for x in range(x1, w - 1):
					if y > 0 and y < h - 1 and x > 0:
						img.set_pixel(x, y, MAP_OPEN)
		2:
			for x in range(x0, x1 + 1):
				for y in range(1, y0 + 1):
					if x > 0 and x < w - 1 and y < h - 1:
						img.set_pixel(x, y, MAP_OPEN)
		_:
			for x in range(x0, x1 + 1):
				for y in range(y1, h - 1):
					if x > 0 and x < w - 1 and y > 0:
						img.set_pixel(x, y, MAP_OPEN)

func _gen_cut_base(img: Image, bs: Dictionary, step: int) -> Array:
	var w := img.get_width()
	var h := img.get_height()
	var c: Vector2i = bs["cell"]
	var side: int = bs["side"]
	var ctr := _gen_cell_center(c, step)
	var out: Array = []
	var half: int = maxi(1, _gen_corridor / 2)
	_gen_connector(img, c, side, step)
	match side:
		0:
			for y in range(ctr.y - half, ctr.y + half + 1):
				if y <= 0 or y >= h - 1: continue
				img.set_pixel(0, y, MAP_BASE)
				out.append(Vector2i(0, y))
				for x in range(1, MIN_WALL + 1):
					img.set_pixel(x, y, MAP_OPEN)
		1:
			for y in range(ctr.y - half, ctr.y + half + 1):
				if y <= 0 or y >= h - 1: continue
				img.set_pixel(w - 1, y, MAP_BASE)
				out.append(Vector2i(w - 1, y))
				for x in range(w - 1 - MIN_WALL, w - 1):
					img.set_pixel(x, y, MAP_OPEN)
		2:
			for x in range(ctr.x - half, ctr.x + half + 1):
				if x <= 0 or x >= w - 1: continue
				img.set_pixel(x, 0, MAP_BASE)
				out.append(Vector2i(x, 0))
				for y in range(1, MIN_WALL + 1):
					img.set_pixel(x, y, MAP_OPEN)
		_:
			for x in range(ctr.x - half, ctr.x + half + 1):
				if x <= 0 or x >= w - 1: continue
				img.set_pixel(x, h - 1, MAP_BASE)
				out.append(Vector2i(x, h - 1))
				for y in range(h - 1 - MIN_WALL, h - 1):
					img.set_pixel(x, y, MAP_OPEN)
	return out

func _gen_center_base(img: Image, bs: Dictionary, step: int) -> Array:
	var w := img.get_width()
	var h := img.get_height()
	var ctr := _gen_cell_center(bs["cell"], step)
	var half: int = maxi(2, _gen_base_size * _gen_corridor / 2)
	var out: Array = []
	for y in range(ctr.y - half - _gen_corridor, ctr.y + half + _gen_corridor + 1):
		for x in range(ctr.x - half - _gen_corridor, ctr.x + half + _gen_corridor + 1):
			if x > 0 and y > 0 and x < w - 1 and y < h - 1:
				img.set_pixel(x, y, MAP_OPEN)
	for y in range(ctr.y - half, ctr.y + half + 1):
		for x in range(ctr.x - half, ctr.x + half + 1):
			if x > 0 and y > 0 and x < w - 1 and y < h - 1:
				img.set_pixel(x, y, MAP_BASE)
				out.append(Vector2i(x, y))
	return out

func _gen_cut_entry(img: Image, sp: Dictionary, step: int) -> Dictionary:
	var w := img.get_width()
	var h := img.get_height()
	var c: Vector2i = sp["cell"]
	var side: int = sp["side"]
	var ctr := _gen_cell_center(c, step)
	var half: int = maxi(1, _gen_corridor / 2)
	var inner := ctr
	_gen_connector(img, c, side, step)
	match side:
		0:
			for y in range(ctr.y - half, ctr.y + half + 1):
				if y <= 0 or y >= h - 1: continue
				for x in range(1, MIN_WALL + 1):
					img.set_pixel(x, y, MAP_OPEN)
			inner = Vector2i(MIN_WALL, ctr.y)
		1:
			for y in range(ctr.y - half, ctr.y + half + 1):
				if y <= 0 or y >= h - 1: continue
				for x in range(w - 1 - MIN_WALL, w - 1):
					img.set_pixel(x, y, MAP_OPEN)
			inner = Vector2i(w - 1 - MIN_WALL, ctr.y)
		2:
			for x in range(ctr.x - half, ctr.x + half + 1):
				if x <= 0 or x >= w - 1: continue
				for y in range(1, MIN_WALL + 1):
					img.set_pixel(x, y, MAP_OPEN)
			inner = Vector2i(ctr.x, MIN_WALL)
		_:
			for x in range(ctr.x - half, ctr.x + half + 1):
				if x <= 0 or x >= w - 1: continue
				for y in range(h - 1 - MIN_WALL, h - 1):
					img.set_pixel(x, y, MAP_OPEN)
			inner = Vector2i(ctr.x, h - 1 - MIN_WALL)
	return {"cell": c, "side": side, "pixel": inner}

func _gen_reaches_base(img: Image, from: Vector2i) -> bool:
	var w := img.get_width()
	var h := img.get_height()
	if from.x < 0 or from.y < 0 or from.x >= w or from.y >= h:
		return false
	if img.get_pixel(from.x, from.y) != MAP_OPEN:
		return false
	var seen := {from: true}
	var queue: Array[Vector2i] = [from]
	while not queue.is_empty():
		var c: Vector2i = queue.pop_front()
		for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var n: Vector2i = c + d
			if n.x < 0 or n.y < 0 or n.x >= w or n.y >= h or seen.has(n):
				continue
			var px := img.get_pixel(n.x, n.y)
			if px == MAP_BASE:
				return true
			if px != MAP_OPEN:
				continue
			seen[n] = true
			queue.append(n)
	return false

func _gen_force_link(img: Image, entry: Dictionary, bases: Array, step: int) -> void:
	var from: Vector2i = entry["cell"]
	var best: Vector2i = bases[0]["cell"]
	var bd := 1e9
	for bs in bases:
		var dd: float = Vector2(from - (bs["cell"] as Vector2i)).length()
		if dd < bd:
			bd = dd
			best = bs["cell"]
	var cur := from
	var guard := 0
	while cur != best and guard < 4096:
		guard += 1
		var nxt := cur
		if cur.x != best.x:
			nxt.x += signi(best.x - cur.x)
		elif cur.y != best.y:
			nxt.y += signi(best.y - cur.y)
		_gen_carve_cell(img, cur, step)
		_gen_carve_cell(img, nxt, step)
		_gen_link_cells(img, cur, nxt, step)
		cur = nxt
	_gen_carve_cell(img, best, step)

func _gen_cleanup_thin(img: Image) -> void:
	var w := img.get_width()
	var h := img.get_height()
	var doomed: Array[Vector2i] = []
	for y in range(1, h - 1):
		for x in range(1, w - 1):
			if img.get_pixel(x, y) != MAP_WALL:
				continue
			var hor := 1
			var k := 1
			while x - k >= 0 and _is_solid(img.get_pixel(x - k, y)):
				hor += 1; k += 1
			k = 1
			while x + k < w and _is_solid(img.get_pixel(x + k, y)):
				hor += 1; k += 1
			var ver := 1
			k = 1
			while y - k >= 0 and _is_solid(img.get_pixel(x, y - k)):
				ver += 1; k += 1
			k = 1
			while y + k < h and _is_solid(img.get_pixel(x, y + k)):
				ver += 1; k += 1
			if mini(hor, ver) < MIN_WALL:
				doomed.append(Vector2i(x, y))
	for p in doomed:
		img.set_pixel(p.x, p.y, MAP_OPEN)
	if not doomed.is_empty():
		_gen_cleanup_thin_once(img)

func _gen_cleanup_thin_once(img: Image) -> void:
	var w := img.get_width()
	var h := img.get_height()
	var doomed: Array[Vector2i] = []
	for y in range(1, h - 1):
		for x in range(1, w - 1):
			if img.get_pixel(x, y) != MAP_WALL:
				continue
			var hor := 1
			var k := 1
			while x - k >= 0 and _is_solid(img.get_pixel(x - k, y)):
				hor += 1; k += 1
			k = 1
			while x + k < w and _is_solid(img.get_pixel(x + k, y)):
				hor += 1; k += 1
			var ver := 1
			k = 1
			while y - k >= 0 and _is_solid(img.get_pixel(x, y - k)):
				ver += 1; k += 1
			k = 1
			while y + k < h and _is_solid(img.get_pixel(x, y + k)):
				ver += 1; k += 1
			if mini(hor, ver) < MIN_WALL:
				doomed.append(Vector2i(x, y))
	for p in doomed:
		img.set_pixel(p.x, p.y, MAP_OPEN)

func _ed_say(msg: String) -> void:
	if _ed_status:
		_ed_status.text = "  " + msg
	_say(msg)

func _ed_new(w: int, h: int) -> void:
	_ed_img = Image.create(w, h, false, Image.FORMAT_RGBA8)
	_ed_img.fill(MAP_OPEN)
	_ed_border()
	var y0: int = int(h * 0.4)
	var y1: int = int(h * 0.6)
	for y in range(y0, y1):
		_ed_img.set_pixel(w - 1, y, MAP_BASE)
	if y0 - 1 > 0:
		_ed_img.set_pixel(w - 1, y0 - 1, MAP_EDGE)
	if y1 < h:
		_ed_img.set_pixel(w - 1, y1, MAP_EDGE)
	_ed_fit_zoom()
	_ed_say(_t("новая карта %dx%d (мир %dx%d), база справа") % [
		w, h, w * WorldGen.WORLD_UNITS_PER_PIXEL, h * WorldGen.WORLD_UNITS_PER_PIXEL])

func _ed_set_zoom(z: int) -> void:
	_ed_zoom = clampi(z, 2, 48)
	_ed_update_tex()

func _ed_fit_zoom() -> void:
	if _ed_img == null:
		return
	var z: int = int(min(940.0 / _ed_img.get_width(), 600.0 / _ed_img.get_height()))
	_ed_zoom = clampi(z, 2, 48)
	_ed_update_tex()

func _ed_border() -> void:
	if _ed_img == null:
		return
	var w := _ed_img.get_width()
	var h := _ed_img.get_height()
	for k in MIN_WALL:
		for x in w:
			if k < h:
				_ed_img.set_pixel(x, k, MAP_WALL)
				_ed_img.set_pixel(x, h - 1 - k, MAP_WALL)
		for y in h:
			if k < w:
				_ed_img.set_pixel(k, y, MAP_WALL)
				_ed_img.set_pixel(w - 1 - k, y, MAP_WALL)

func _ed_update_tex() -> void:
	if _ed_img == null:
		return
	_ed_preview = _ed_img.duplicate()
	var w := _ed_preview.get_width()
	var h := _ed_preview.get_height()
	for d in _ed_spawners:
		var px: int = clampi(int(d["x"]), 0, w - 1)
		var py: int = clampi(int(d["y"]), 0, h - 1)
		_ed_preview.set_pixel(px, py, Color(0, 1, 0, 1))
		for o in [-1, 1]:
			if px + o >= 0 and px + o < w:
				_ed_preview.set_pixel(px + o, py, Color(0, 0.6, 0, 1))
			if py + o >= 0 and py + o < h:
				_ed_preview.set_pixel(px, py + o, Color(0, 0.6, 0, 1))

	_ed_tex = ImageTexture.create_from_image(_ed_preview)
	if _ed_rect:
		_ed_rect.texture = _ed_tex
		_ed_rect.custom_minimum_size = Vector2(w, h) * _ed_zoom
		_ed_rect.size = _ed_rect.custom_minimum_size
	if _ed_coords:
		_ed_coords.text = _t("  карта %dx%d пикс = мир %dx%d ед.   масштаб x%d   точек спавна %d") % [
			w, h, w * WorldGen.WORLD_UNITS_PER_PIXEL,
			h * WorldGen.WORLD_UNITS_PER_PIXEL, _ed_zoom, _ed_spawners.size()]

func _ed_on_input(event: InputEvent) -> void:
	if _ed_img == null or _ed_rect == null:
		return
	var pos := Vector2.ZERO
	var left := false
	var right := false
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		pos = mb.position
		left = mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT
		right = mb.pressed and mb.button_index == MOUSE_BUTTON_RIGHT
	elif event is InputEventMouseMotion:
		var mm := event as InputEventMouseMotion
		pos = mm.position
		left = (mm.button_mask & MOUSE_BUTTON_MASK_LEFT) != 0
		right = (mm.button_mask & MOUSE_BUTTON_MASK_RIGHT) != 0
	else:
		return

	var px := int(pos.x) / _ed_zoom
	var py := int(pos.y) / _ed_zoom
	var w := _ed_img.get_width()
	var h := _ed_img.get_height()
	if px < 0 or py < 0 or px >= w or py >= h:
		return

	if _ed_coords:
		var c := _ed_img.get_pixel(px, py)
		var what := _t("проход")
		if c == MAP_WALL: what = _t("стена")
		elif c == MAP_BASE: what = _t("база")
		elif c == MAP_EDGE: what = _t("кромка")
		_ed_coords.text = _t("  пиксель (%d, %d) = %s   мир (%d, %d)   карта %dx%d   масштаб x%d") % [
			px, py, what, px * WorldGen.WORLD_UNITS_PER_PIXEL,
			py * WorldGen.WORLD_UNITS_PER_PIXEL, w, h, _ed_zoom]

	if not (left or right):
		return
	var col: Color = MAP_OPEN if right else _ed_brush
	var half: int = _ed_brush_size / 2
	var changed := false
	for oy in range(-half, _ed_brush_size - half):
		for ox in range(-half, _ed_brush_size - half):
			var x := px + ox
			var y := py + oy
			if x < 0 or y < 0 or x >= w or y >= h:
				continue
			if _ed_img.get_pixel(x, y) != col:
				_ed_img.set_pixel(x, y, col)
				changed = true
	if changed:
		_ed_update_tex()

func _ed_refresh_spawners() -> void:
	if _ed_sp_list == null:
		return
	_clear(_ed_sp_list)
	if _ed_spawners.is_empty():
		_lbl(_ed_sp_list, _t("Точек нет — орков не будет."), 12, Color(1, 0.75, 0.4))
		return
	for i in _ed_spawners.size():
		var d: Dictionary = _ed_spawners[i]
		var h := _row(_ed_sp_list)
		_lbl(h, _t("Точка %d:") % (i + 1))
		_lbl(h, "X")
		var sx := _spin(h, -64, 512, float(d["x"]), 1)
		sx.custom_minimum_size.x = 80
		sx.value_changed.connect(func(x: float) -> void: d["x"] = int(x))
		_lbl(h, "Y")
		var sy := _spin(h, -64, 512, float(d["y"]), 1)
		sy.custom_minimum_size.x = 80
		sy.value_changed.connect(func(x: float) -> void: d["y"] = int(x))
		_lbl(h, _t("скор.X"))
		var svx := _spin(h, -500, 500, float(d["vx"]), 1)
		svx.custom_minimum_size.x = 80
		svx.value_changed.connect(func(x: float) -> void: d["vx"] = int(x))
		_lbl(h, "Y")
		var svy := _spin(h, -500, 500, float(d["vy"]), 1)
		svy.custom_minimum_size.x = 80
		svy.value_changed.connect(func(x: float) -> void: d["vy"] = int(x))
		_lbl(h, _t("орков"))
		var sa := _spin(h, 1, 999999, float(d["amount"]), 1)
		sa.custom_minimum_size.x = 100
		sa.value_changed.connect(func(x: float) -> void: d["amount"] = int(x))
		_lbl(h, _t("за,с"))
		var sd := _spin(h, 0.5, 3600, float(d["duration"]), 0.5)
		sd.custom_minimum_size.x = 90
		sd.value_changed.connect(func(x: float) -> void: d["duration"] = x)

func _ed_build_level_data() -> Object:
	var levels: Dictionary = _get(_gm(), "levels", {})
	var src: Object = (levels[_ed_style_level] as Object).get("data") if levels.has(_ed_style_level) else null
	var nd: Object = LevelData.new()
	nd.set("map_texture", ImageTexture.create_from_image(_ed_img))
	nd.set("world_size", Vector2(_ed_img.get_width(), _ed_img.get_height())
		* WorldGen.WORLD_UNITS_PER_PIXEL)
	if src != null:
		nd.set("sprite_sheet_texture", src.get("sprite_sheet_texture"))
		nd.set("wall_tiles_count", src.get("wall_tiles_count"))
		nd.set("ground_tiles_count", src.get("ground_tiles_count"))
	nd.set("enemy_health_buff", _ed_health_buff)
	nd.set("marks_upon_survival", 0)
	nd.set("marks_upon_all_killed", 0)
	nd.set("level_bonus_marks", 0)

	var arr: Variant = nd.get("spawners")
	if arr is Array:
		for d in _ed_spawners:
			var sp: Object = EnemySpawnerData.new()
			sp.set("position", Vector2(float(d["x"]), float(d["y"]))
				* WorldGen.WORLD_UNITS_PER_PIXEL)
			sp.set("initial_velocity", Vector2(float(d["vx"]), float(d["vy"])))
			var rect := RectangleShape2D.new()
			rect.size = Vector2(16, 48)
			sp.set("shape", rect)
			var w: Object = EnemySpawnWave.new()
			w.set("amount", int(d["amount"]))
			w.set("duration", float(d["duration"]))
			var ws: Variant = sp.get("waves")
			if ws is Array:
				(ws as Array).append(w)
			(arr as Array).append(sp)
	return nd

func _ed_validate() -> void:
	if _ed_img == null:
		_ed_say(_t("нет карты")); return
	var base := 0
	var open := 0
	for y in _ed_img.get_height():
		for x in _ed_img.get_width():
			var c := _ed_img.get_pixel(x, y)
			if c == MAP_BASE:
				base += 1
			elif c == MAP_OPEN:
				open += 1
	_ed_say(_t("считаю мир…"))
	var tex := ImageTexture.create_from_image(_ed_img)
	var wd: Object = await WorldGen.create_world_data(tex)
	var okk: bool = wd != null and bool(wd.get("successful"))
	var polys: Variant = wd.get("wall_polygons") if wd != null else null
	var thin := _count_thin_walls(_ed_img)
	var msg := _t("мир построен: %s, полигонов стен %d; база %d пикс, проход %d пикс") % [
		_t("да") if okk else _t("НЕТ"), (polys as Array).size() if polys is Array else -1,
		base, open]
	if base == 0:
		msg += _t("   ⚠ базы нет — оркам некуда идти")
	if _ed_spawners.is_empty():
		msg += _t("   ⚠ нет точек спавна")
	if thin > 0:
		msg += _t("   ⚠ слишком тонких стен: %d клеток (нужно от %d) — игра их не увидит") % [
			thin, MIN_WALL]
	if base > 0 and not _ed_spawners.is_empty() and thin == 0 and okk:
		msg += _t("   всё в порядке")
	_ed_say(msg)

func _is_solid(c: Color) -> bool:
	return c == MAP_WALL or c == MAP_BASE or c == MAP_EDGE

func _count_thin_walls(img: Image) -> int:
	if img == null:
		return 0
	var w := img.get_width()
	var h := img.get_height()
	var n := 0
	for y in range(1, h - 1):
		for x in range(1, w - 1):
			if img.get_pixel(x, y) != MAP_WALL:
				continue
			var hor := 1
			var k := 1
			while x - k >= 0 and _is_solid(img.get_pixel(x - k, y)):
				hor += 1; k += 1
			k = 1
			while x + k < w and _is_solid(img.get_pixel(x + k, y)):
				hor += 1; k += 1
			var ver := 1
			k = 1
			while y - k >= 0 and _is_solid(img.get_pixel(x, y - k)):
				ver += 1; k += 1
			k = 1
			while y + k < h and _is_solid(img.get_pixel(x, y + k)):
				ver += 1; k += 1
			if mini(hor, ver) < MIN_WALL:
				n += 1
	return n

func _ed_load_game_level(key: int) -> void:
	var levels: Dictionary = _get(_gm(), "levels", {})
	if not levels.has(key):
		_ed_say(_t("уровень %d не загружен — выбери слот сохранения") % key); return
	var data: Object = (levels[key] as Object).get("data")
	if data == null:
		_ed_say(_t("у уровня нет данных")); return
	var mt: Object = data.get("map_texture")
	if mt == null:
		_ed_say(_t("у уровня нет карты")); return
	_ed_img = (mt as Texture2D).get_image().duplicate()
	if _ed_img.get_format() != Image.FORMAT_RGBA8:
		_ed_img.convert(Image.FORMAT_RGBA8)

	_ed_spawners.clear()
	var upp: int = WorldGen.WORLD_UNITS_PER_PIXEL
	for sp in (data.get("spawners") as Array):
		var p: Vector2 = sp.get("position")
		var vel: Vector2 = sp.get("initial_velocity")
		var ws: Variant = sp.get("waves")
		var amount := 300
		var dur := 20.0
		if ws is Array and not (ws as Array).is_empty():
			amount = int(((ws as Array)[0] as Object).get("amount"))
			dur = float(((ws as Array)[0] as Object).get("duration"))
		_ed_spawners.append({"x": int(round(p.x / upp)), "y": int(round(p.y / upp)),
			"vx": int(vel.x), "vy": int(vel.y), "amount": amount, "duration": dur})

	_ed_style_level = key
	_ed_level_key = key
	_ed_health_buff = float(data.get("enemy_health_buff"))
	_ed_marks = int(data.get("marks_upon_survival"))
	if _ed_name_edit:
		_ed_name_edit.text = _t("уровень_%d_правка") % key
	_ed_refresh_spawners()
	_ed_fit_zoom()
	_ed_say(_t("загружен уровень %d: карта %dx%d, точек %d — правь и жми ИГРАТЬ") % [
		key, _ed_img.get_width(), _ed_img.get_height(), _ed_spawners.size()])

func _ed_play() -> void:
	var gm := _gm()
	if gm == null:
		_ed_say(_t("GameManager недоступен")); return
	var levels: Dictionary = _get(gm, "levels", {})
	if levels.is_empty():
		_ed_say(_t("сначала выбери слот сохранения")); return
	var cmap: Dictionary = gm.get_script().get_script_constant_map()
	var LevelCls: Variant = cmap.get("Level")
	if LevelCls == null:
		_ed_say(_t("внутренний класс Level не найден")); return

	var nd: Object = _ed_build_level_data()
	var inst: Object = (LevelCls as GDScript).new(_ed_name_edit.text, nd)
	levels[CUSTOM_LEVEL_KEY] = inst
	var prev: int = int(_get(gm, "selected_level", 1))
	if prev != CUSTOM_LEVEL_KEY:
		_ed_prev_level = prev
	_ed_custom_registered = true
	gm.set("selected_level", CUSTOM_LEVEL_KEY)
	_ed_say(_t("запускаю «%s», скорость орков %.0f (как на уровне %d)") % [
		_ed_name_edit.text, SPEED_BASE + SPEED_PER_LEVEL * _ed_level_key, _ed_level_key])
	if gm.has_method("load_level"):
		gm.call("load_level", CUSTOM_LEVEL_KEY)
	_root.visible = false

func _ed_unregister() -> void:
	var levels: Dictionary = _get(_gm(), "levels", {})
	if levels.has(CUSTOM_LEVEL_KEY):
		levels.erase(CUSTOM_LEVEL_KEY)
	_ed_custom_registered = false

func _is_own_battle() -> bool:
	return int(_get(_gm(), "selected_level", -1)) == CUSTOM_LEVEL_KEY

func _auto_unregister(delta: float) -> void:
	if not _ed_custom_registered:
		return
	if _battle() != null:
		_ed_battle_seen = true
		_ed_no_battle_time = 0.0
		return
	if not _ed_battle_seen:
		return
	_ed_no_battle_time += delta
	if _ed_no_battle_time > 1.5:
		_ed_unregister()
		_ed_battle_seen = false
		_ed_no_battle_time = 0.0
		var gm := _gm()
		if gm != null and int(_get(gm, "selected_level", -1)) == CUSTOM_LEVEL_KEY:
			gm.set("selected_level", _ed_prev_level)
		_say(_t("своя карта убрана из списка уровней игры"))

func _enforce_custom_speed() -> void:
	if not _ed_custom_registered:
		return
	var gm := _gm()
	if gm == null or int(_get(gm, "selected_level", -1)) != CUSTOM_LEVEL_KEY:
		return
	var gs := get_node_or_null("/root/GPUSim")
	if gs == null:
		return
	var want: float = SPEED_BASE + SPEED_PER_LEVEL * _ed_level_key
	if not is_equal_approx(float(_get(gs, "flow_speed", 0.0)), want):
		gs.set("flow_speed", want)

func _safe_file_name(nm: String) -> String:
	var out := ""
	for ch in nm.strip_edges():
		if ch == " ":
			out += "_"
		elif ch in "\\/:*?\"<>|.":
			continue
		else:
			out += ch
	if out.is_empty():
		out = _t("карта")
	return out

func _ed_shared_dir() -> String:
	if mod_dir.is_empty():
		return ""
	return mod_dir.path_join("maps")

func _ed_map_dirs() -> Array:
	var dirs: Array = [EDITOR_DIR]
	var sh := _ed_shared_dir()
	if sh != "":
		dirs.append(sh + "/")
	return dirs

func _ed_list_maps() -> Array:
	var out: Array = []
	var dirs := _ed_map_dirs()
	for i in dirs.size():
		var base := String(dirs[i])
		var shared := i > 0
		var dir := DirAccess.open(base)
		if dir == null:
			continue
		for fn in dir.get_files():
			if not fn.ends_with(".json"):
				continue
			var f := FileAccess.open(base + fn, FileAccess.READ)
			if f == null:
				continue
			var parsed: Variant = JSON.parse_string(f.get_as_text())
			f.close()
			if not (parsed is Dictionary):
				continue
			var d: Dictionary = parsed
			out.append({
				"path": base + fn,
				"file": fn,
				"name": String(d.get("name", fn.trim_suffix(".json"))),
				"w": int(d.get("width", 0)),
				"h": int(d.get("height", 0)),
				"spawns": (d.get("spawners", []) as Array).size(),
				"shared": shared,
			})
	out.sort_custom(func(a, b) -> bool:
		return String(a["name"]).naturalnocasecmp_to(String(b["name"])) < 0)
	return out

func _ed_save(overwrite: bool = true) -> void:
	if _ed_img == null:
		_ed_say(_t("нет карты")); return
	var nm := _ed_name_edit.text.strip_edges()
	if nm.is_empty():
		_ed_say(_t("укажи название карты")); return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(EDITOR_DIR))

	var base := _safe_file_name(nm)
	var file := base + ".json"
	if not overwrite:
		var i := 2
		while FileAccess.file_exists(EDITOR_DIR + file):
			file = "%s_%d.json" % [base, i]
			i += 1

	var data := {
		"name": nm,
		"width": _ed_img.get_width(),
		"height": _ed_img.get_height(),
		"png_base64": Marshalls.raw_to_base64(_ed_img.save_png_to_buffer()),
		"style_level": _ed_style_level,
		"level_key": _ed_level_key,
		"health_buff": _ed_health_buff,
		"marks": _ed_marks,
		"spawners": _ed_spawners,
	}
	var f := FileAccess.open(EDITOR_DIR + file, FileAccess.WRITE)
	if f == null:
		_ed_say(_t("не смог записать файл")); return
	f.store_string(JSON.stringify(data, "  "))
	f.close()
	_ed_refresh_files()
	_ed_select_file(EDITOR_DIR + file)
	_ed_say(_t("сохранено «%s» -> %s") % [nm, file])

func _ed_refresh_files() -> void:
	if _ed_files == null:
		return
	var prev := _ed_selected_file()
	_ed_files.clear()
	_ed_file_names.clear()
	for m in _ed_list_maps():
		var mark: String = _t("[общая] ") if bool(m["shared"]) else ""
		_ed_files.add_item(_t("%s%s  (%dx%d, точек %d)") % [
			mark, m["name"], m["w"], m["h"], m["spawns"]])
		_ed_file_names.append(String(m["path"]))
	if prev != "":
		_ed_select_file(prev)

func _ed_selected_file() -> String:
	if _ed_files == null or _ed_files.selected < 0:
		return ""
	if _ed_files.selected >= _ed_file_names.size():
		return ""
	return String(_ed_file_names[_ed_files.selected])

func _ed_select_file(path: String) -> void:
	var i := _ed_file_names.find(path)
	if i >= 0 and _ed_files != null:
		_ed_files.selected = i

func _ed_load_selected() -> void:
	var file := _ed_selected_file()
	if file == "":
		_ed_say(_t("нет сохранённых карт")); return
	_ed_load_path(file)

func _ed_load_path(file: String) -> bool:
	var f := FileAccess.open(file, FileAccess.READ)
	if f == null:
		_ed_say(_t("не открыл файл %s") % file.get_file()); return false
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	f.close()
	if not (parsed is Dictionary):
		_ed_say(_t("файл повреждён: %s") % file.get_file()); return false
	var d: Dictionary = parsed
	var img := Image.new()
	if img.load_png_from_buffer(Marshalls.base64_to_raw(
			String(d.get("png_base64", "")))) != OK:
		_ed_say(_t("картинка не читается")); return false
	_ed_img = img
	_ed_tex = null
	_ed_style_level = int(d.get("style_level", 1))
	_ed_level_key = clampi(int(d.get("level_key", _ed_style_level)), 1, 12)
	_ed_health_buff = float(d.get("health_buff", 1.0))
	_ed_spawners = (d.get("spawners", []) as Array).duplicate(true)
	if _ed_name_edit != null:
		_ed_name_edit.text = String(d.get("name", file.get_file().trim_suffix(".json")))
	_ed_refresh_spawners()
	_ed_fit_zoom()
	_ed_say(_t("загружено «%s»: %dx%d, точек %d") % [
		String(d.get("name", _t("карта"))), _ed_img.get_width(), _ed_img.get_height(),
		_ed_spawners.size()])
	return true

func _ed_delete_selected() -> void:
	var file := _ed_selected_file()
	if file == "":
		_ed_say(_t("нечего удалять")); return
	var err := DirAccess.remove_absolute(ProjectSettings.globalize_path(file))
	if err != OK:
		_ed_say(_t("не удалось удалить %s") % file.get_file()); return
	_ed_refresh_files()
	_ed_say(_t("удалено: %s") % file.get_file())

func _ed_share_selected() -> void:
	var src := _ed_selected_file()
	if src == "":
		_ed_say(_t("выбери карту")); return
	var sh := _ed_shared_dir()
	if sh == "":
		_ed_say(_t("папка обмена недоступна: мод запущен без своей папки")); return
	DirAccess.make_dir_recursive_absolute(sh)
	var dst := sh.path_join(src.get_file())
	if src == dst:
		_ed_say(_t("эта карта уже в папке обмена")); return

	var fin := FileAccess.open(src, FileAccess.READ)
	if fin == null:
		_ed_say(_t("не читается исходный файл")); return
	var text := fin.get_as_text()
	fin.close()
	var fout := FileAccess.open(dst, FileAccess.WRITE)
	if fout == null:
		_ed_say(_t("не пишется в папку обмена")); return
	fout.store_string(text)
	fout.close()
	_ed_refresh_files()
	_ed_say(_t("карта скопирована в папку обмена: %s") % dst.get_file())

func _ed_import_selected() -> void:
	var src := _ed_selected_file()
	if src == "":
		_ed_say(_t("выбери карту")); return
	if src.begins_with(EDITOR_DIR):
		_ed_say(_t("эта карта уже своя")); return
	DirAccess.make_dir_recursive_absolute(
		ProjectSettings.globalize_path(EDITOR_DIR))
	var base := src.get_file().trim_suffix(".json")
	var dst := EDITOR_DIR + base + ".json"
	var i := 2
	while FileAccess.file_exists(dst):
		dst = "%s%s_%d.json" % [EDITOR_DIR, base, i]
		i += 1

	var fin := FileAccess.open(src, FileAccess.READ)
	if fin == null:
		_ed_say(_t("не читается файл")); return
	var text := fin.get_as_text()
	fin.close()
	var fout := FileAccess.open(dst, FileAccess.WRITE)
	if fout == null:
		_ed_say(_t("не смог записать копию")); return
	fout.store_string(text)
	fout.close()
	_ed_refresh_files()
	_ed_select_file(dst)
	_ed_say(_t("карта скопирована в свои: %s") % dst.get_file())

func _guard_status(g: Node) -> String:
	if not bool(g.get("installed")):
		return _t("НЕ РАБОТАЕТ: %s") % String(g.get("install_error"))
	var where := _t("своя карта") if bool(g.call("is_custom_battle")) \
		else _t("уровень игры")
	return _t("защита включена, сейчас: %s, заблокировано за сессию: %d") % [
		where, (g.get("blocked_log") as Array).size()]

func _ach_guard() -> Node:
	if _guard_node != null and is_instance_valid(_guard_node):
		return _guard_node
	var p := get_parent()
	if p != null:
		_guard_node = p.get_node_or_null("AchGuard")
	if _guard_node != null:
		_guard_node.call("register_custom_key", CUSTOM_LEVEL_KEY)
	return _guard_node

func _build_about() -> void:
	var v := _scroll_tab(_t("О моде"))

	_lbl(v, "Map Studio", 18, Color(0.45, 0.9, 0.55))
	_lbl(v, _t("Редактор и генератор карт. Мод занимается только картами: он не выдаёт валюту, не открывает апгрейды и башни, не отмечает уровни пройденными и не изменяет уровни игры."),
		13, Color(0.8, 0.82, 0.86))
	_sep(v)

	_lbl(v, _t("Клавиши"), 15, Color(0.55, 0.9, 1.0))
	_lbl(v, _t("F1 — открыть и закрыть это окно\nF2 — рисовать прямо поверх боя\nF5 — перезагрузить мод\nTab — в режиме F2 спрятать панель, чтобы видеть карту целиком\nEsc — выйти из режима F2"), 13)
	_sep(v)

	_lbl(v, _t("Достижения Steam"), 15, Color(0.55, 0.9, 1.0))
	var g := _ach_guard()
	if g == null:
		_lbl(v, _t("Страж достижений не найден — мод загружен не полностью. Проверьте, что рядом с map_studio.gd лежат ach_guard.gd и ach_shim.gd."), 13, Color(1, 0.5, 0.5))
	else:
		_lbl(v, _t("Прохождение самодельных карт в Steam не засчитывается — это жёстко зашито и не отключается. На уровнях игры достижения работают как обычно."), 13, Color(0.8, 0.82, 0.86))
		var status := _lbl(v, "", 13, Color(1.0, 0.85, 0.35))
		var journal := _lbl(v, "", 12, Color(0.7, 0.7, 0.7))
		_refreshers.append(func() -> void:
			if not is_instance_valid(g):
				status.text = _t("  страж выгружен")
				return
			status.text = "  " + _guard_status(g)
			var log_arr: Array = g.get("blocked_log")
			if log_arr.is_empty():
				journal.text = _t("  за эту сессию ничего не блокировалось")
			else:
				var tail: Array = log_arr.slice(maxi(0, log_arr.size() - 5))
				journal.text = _t("  не засчитано: ") + ", ".join(tail))
	_sep(v)

	_lbl(v, _t("Где лежат карты"), 15, Color(0.55, 0.9, 1.0))
	_lbl(v, _t("Свои карты — в папке сохранений игры. Карты, которыми делятся другие игроки, — в папке обмена внутри мода: положите туда .json, и он появится в списке редактора с пометкой «общая»."),
		13, Color(0.8, 0.82, 0.86))
	var r := _row(v)
	_btn(r, _t("Открыть папку своих карт"), func() -> void:
		DirAccess.make_dir_recursive_absolute(
			ProjectSettings.globalize_path(EDITOR_DIR))
		OS.shell_open(ProjectSettings.globalize_path(EDITOR_DIR)))
	_btn(r, _t("Открыть папку обмена"), func() -> void:
		var share_dir := _ed_shared_dir()
		if share_dir == "":
			_say(_t("папка обмена недоступна")); return
		DirAccess.make_dir_recursive_absolute(share_dir)
		OS.shell_open(share_dir))
	var paths := _lbl(v, "", 12, Color(0.6, 0.62, 0.66))
	paths.text = _t("  свои: %s\n  обмен: %s") % [
		ProjectSettings.globalize_path(EDITOR_DIR),
		_ed_shared_dir() if _ed_shared_dir() != "" else "—"]
	_sep(v)

	_lbl(v, _t("Полезно помнить"), 15, Color(0.55, 0.9, 1.0))
	_lbl(v, _t("Стена тоньше трёх клеток движком за стену не считается — орки проходят сквозь неё. Кнопка «ПРОВЕРИТЬ КАРТУ» строит мир так же, как это делает игра, и показывает такие места заранее.\nИзменения карты применяются перезапуском боя: заменить мир на лету движок не позволяет."), 13, Color(0.8, 0.82, 0.86))

	_check(v, _t("ставить игру на паузу, пока открыто это окно"), _pause_while_open,
		func(on: bool) -> void: _pause_while_open = on)

	_sep(v)
	_lbl(v, _t("Автор мода"), 15, Color(0.55, 0.9, 1.0))
	var author := _row(v)
	_lbl(author, "KotiMorte", 14, Color(0.9, 0.92, 0.95))
	_btn(author, _t("Профиль в Steam"), func() -> void:
		OS.shell_open(AUTHOR_URL)
		_say(_t("открываю профиль автора в Steam")),
		AUTHOR_URL)

var _browser: Control = null
var _browser_grid: GridContainer = null
var _browser_status: Label = null
var _browser_empty: Label = null

func _browser_build() -> void:
	if _browser != null and is_instance_valid(_browser):
		return

	_browser = Control.new()
	_browser.set_anchors_preset(Control.PRESET_FULL_RECT)
	_browser.mouse_filter = Control.MOUSE_FILTER_STOP
	_layer.add_child(_browser)

	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0, 0, 0, 0.72)
	_browser.add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_browser.add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(1120, 720)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.07, 0.08, 0.10, 0.98)
	sb.border_color = Color(0.35, 0.75, 0.45)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(8)
	sb.set_content_margin_all(16)
	panel.add_theme_stylebox_override("panel", sb)
	center.add_child(panel)

	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	panel.add_child(v)

	var head := _row(v)
	_lbl(head, _t("Пользовательские карты"), 22, Color(0.45, 0.9, 0.55))
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(spacer)
	_btn(head, _t("Создать карту"), func() -> void:
		_ed_new(48, 32)
		if _ed_name_edit != null:
			_ed_name_edit.text = _t("Новая карта")
		_browser_close()
		_root.visible = true,
		_t("Пустая карта и переход в редактор"))
	_btn(head, _t("Папка обмена"), func() -> void:
		var share_dir := _ed_shared_dir()
		if share_dir == "":
			_browser_say(_t("папка обмена недоступна")); return
		DirAccess.make_dir_recursive_absolute(share_dir)
		OS.shell_open(share_dir),
		_t("Сюда кладут карты, скачанные у других игроков"))
	_btn(head, _t("Редактор (F1)"), func() -> void:
		_browser_close()
		_root.visible = true,
		_t("Полный редактор: кисти, генератор, точки выхода орков"))
	_btn(head, _t("Закрыть"), func() -> void: _browser_close())

	_lbl(v, _t("Свои карты и карты из папки обмена. Прохождение в Steam не засчитывается, награды за них не начисляются."),
		13, Color(0.62, 0.65, 0.7))
	_sep(v)

	var sc := ScrollContainer.new()
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	v.add_child(sc)

	_browser_grid = GridContainer.new()
	_browser_grid.columns = 4
	_browser_grid.add_theme_constant_override("h_separation", 12)
	_browser_grid.add_theme_constant_override("v_separation", 12)
	_browser_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(_browser_grid)

	_browser_empty = _lbl(v, "", 15, Color(1.0, 0.85, 0.35))
	_browser_status = _lbl(v, "", 13, Color(0.6, 0.85, 1.0))
	_browser.visible = false

func _browser_say(msg: String) -> void:
	if _browser_status != null:
		_browser_status.text = "  " + msg
	print("[MAP STUDIO] ", msg)

func _browser_open() -> void:
	_browser_build()
	_hide_game_menu()
	_root.visible = false
	_browser.visible = true
	_browser_refresh()

func _browser_close() -> void:
	if _browser != null and is_instance_valid(_browser):
		_browser.visible = false

func _browser_refresh() -> void:
	if _browser_grid == null:
		return
	_clear(_browser_grid)
	var maps := _ed_list_maps()
	for m in maps:
		_browser_grid.add_child(_browser_card(m))
	if maps.is_empty():
		_browser_empty.text = _t("  Карт пока нет. Нажмите «Создать карту» — ")\
			+ _t("или положите чужой .json в папку обмена.")
	else:
		_browser_empty.text = ""
	_browser_say(_t("карт: %d") % maps.size())

func _browser_card(m: Dictionary) -> Control:
	var card := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.12, 0.13, 0.16, 1.0)
	sb.border_color = Color(0.3, 0.55, 0.35) if not bool(m["shared"]) \
		else Color(0.5, 0.45, 0.25)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(6)
	sb.set_content_margin_all(8)
	card.add_theme_stylebox_override("panel", sb)

	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	card.add_child(v)

	var pic := TextureRect.new()
	pic.custom_minimum_size = Vector2(240, 160)
	pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	pic.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	pic.texture = _browser_preview(String(m["path"]))
	v.add_child(pic)

	var title := _lbl(v, String(m["name"]), 15, Color(0.9, 0.92, 0.95))
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title.custom_minimum_size.x = 240

	var mark: String = _t("карта другого игрока") if bool(m["shared"]) else _t("своя карта")
	_lbl(v, _t("%d×%d · точек выхода: %d\n%s") % [m["w"], m["h"], m["spawns"], mark],
		12, Color(0.6, 0.62, 0.66))

	var r := _row(v)
	_btn(r, _t("Играть"), func() -> void: _browser_play(String(m["path"])))
	_btn(r, _t("Изменить"), func() -> void: _browser_edit(String(m["path"])))
	var r2 := _row(v)
	if bool(m["shared"]):
		_btn(r2, _t("Сделать своей"), func() -> void:
			_ed_select_file(String(m["path"]))
			_ed_import_selected()
			_browser_refresh())
	else:
		_btn(r2, _t("Поделиться"), func() -> void:
			_ed_select_file(String(m["path"]))
			_ed_share_selected()
			_browser_refresh())
	_btn(r2, _t("Удалить"), func() -> void:
		_ed_select_file(String(m["path"]))
		_ed_delete_selected()
		_browser_refresh())
	return card

func _browser_preview(path: String) -> Texture2D:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return null
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	f.close()
	if not (parsed is Dictionary):
		return null
	var src := Image.new()
	if src.load_png_from_buffer(Marshalls.base64_to_raw(
			String((parsed as Dictionary).get("png_base64", "")))) != OK:
		return null

	var w := src.get_width()
	var h := src.get_height()
	var out := Image.create(w, h, false, Image.FORMAT_RGBA8)
	for y in h:
		for x in w:
			var c := src.get_pixel(x, y)
			var col := Color(0.10, 0.11, 0.13, 1.0)
			if c.a > 0.5:
				if c.r > 0.5 and c.b > 0.5:
					col = Color(0.85, 0.35, 0.85, 1.0)
				elif c.r > 0.5:
					col = Color(0.90, 0.25, 0.25, 1.0)
				elif c.b > 0.5:
					col = Color(0.62, 0.66, 0.72, 1.0)
			out.set_pixel(x, y, col)
	return ImageTexture.create_from_image(out)

func _browser_play(path: String) -> void:
	if not _ed_load_path(path):
		return
	_browser_close()
	_ed_play()

func _browser_edit(path: String) -> void:
	if not _ed_load_path(path):
		return
	_browser_close()
	_root.visible = true

const LOCALE_DIR := "locale"
const BASE_LOCALE := "ru"
const FALLBACK_LOCALE := "en"

var _loc: Dictionary = {}
var _loc_code: String = BASE_LOCALE
var _loc_watch := 0.0
var _loc_uptime := 0.0

func _t(s: String) -> String:
	if _loc.is_empty():
		return s
	var v: Variant = _loc.get(s)
	return String(v) if v != null and String(v) != "" else s

func _game_locale() -> String:
	var code := TranslationServer.get_locale()
	return code if code != "" else OS.get_locale()

func _load_locale() -> void:
	_loc.clear()
	var code := _game_locale()
	_loc_code = code
	if code.begins_with(BASE_LOCALE):
		return

	var dir := mod_dir.path_join(LOCALE_DIR)
	var lang := code.split("_")[0]
	for name in [code, lang, FALLBACK_LOCALE]:
		var path := dir.path_join("%s.json" % name)
		if not FileAccess.file_exists(path):
			continue
		var f := FileAccess.open(path, FileAccess.READ)
		if f == null:
			continue
		var parsed: Variant = JSON.parse_string(f.get_as_text())
		f.close()
		if parsed is Dictionary:
			_loc = parsed
			_loc_code = String(name)
			print(_t("[MAP STUDIO] язык: %s (файл %s.json, строк %d)")
					% [code, name, _loc.size()])
			return
	print(_t("[MAP STUDIO] язык %s: перевода нет, остаётся русский") % code)

func _watch_locale(delta: float) -> void:
	_loc_uptime += delta
	_loc_watch += delta
	if _loc_watch < 1.0:
		return
	_loc_watch = 0.0
	if _game_locale() == _loc_code:
		return
	if _live_on:
		return
	if _loc_uptime > 5.0:
		print(_t("[MAP STUDIO] язык сменился на %s — пересобираю интерфейс")
				% _game_locale())
	_load_locale()
	_rebuild_ui()
