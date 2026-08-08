extends Node

const RELOAD_KEY := KEY_F5
const ENTRY := "mod.gd"
const DISABLE_MARK := "disabled"

var mods_dir: String = ""

var _mods: Array[Node] = []
var _report: Array[String] = []

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	mods_dir = OS.get_executable_path().get_base_dir().path_join("mods")
	_load_all()

func get_report() -> Array:
	return _report.duplicate()

func _load_all() -> void:
	for m in _mods:
		if is_instance_valid(m):
			m.queue_free()
	_mods.clear()
	_report.clear()

	var d := DirAccess.open(mods_dir)
	if d == null:
		print("[МОДЫ] папка не найдена: ", mods_dir)
		return

	var names := d.get_directories()
	names.sort()
	for sub in names:
		var dir := mods_dir.path_join(sub)
		if FileAccess.file_exists(dir.path_join(DISABLE_MARK)):
			_report.append("%s — выключен (файл disabled)" % sub)
			continue
		var entry := dir.path_join(ENTRY)
		if not FileAccess.file_exists(entry):
			continue
		_load_one(sub, dir, entry)

	print("[МОДЫ] загружено: %d" % _mods.size())

func _load_one(mod_name: String, dir: String, entry: String) -> void:
	var src := FileAccess.get_file_as_string(entry)
	if src.is_empty():
		_report.append("%s — ОШИБКА: mod.gd пуст или нечитаем" % mod_name)
		printerr("[МОДЫ] %s: mod.gd пуст" % mod_name)
		return

	var scr := GDScript.new()
	scr.source_code = src
	scr.resource_path = "user://__mod_%s.gd" % mod_name
	var err: int = scr.reload()
	if err != OK:
		_report.append("%s — ОШИБКА компиляции (%s)" % [mod_name, error_string(err)])
		printerr("[МОДЫ] %s: ошибка компиляции — подробности выше" % mod_name)
		return
	if not scr.can_instantiate():
		_report.append("%s — ОШИБКА: скрипт не создаётся" % mod_name)
		return

	var inst: Node = scr.new()
	if inst == null:
		_report.append("%s — ОШИБКА: не удалось создать объект" % mod_name)
		return

	inst.name = StringName(mod_name)
	inst.set("mod_dir", dir)
	inst.set("mod_name", mod_name)
	add_child(inst)
	_mods.append(inst)
	_report.append("%s — загружен" % mod_name)
	print("[МОДЫ] %s загружен из %s" % [mod_name, dir])

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if (event as InputEventKey).keycode == RELOAD_KEY:
			print("[МОДЫ] перезагрузка")
			_load_all()
			get_viewport().set_input_as_handled()
