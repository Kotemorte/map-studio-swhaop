extends Node

const GM_PATH := "/root/GameManager"
const ACH_PATH := "/root/Achievements"
const SAVE_PATH := "/root/SaveSystem"

var mod_dir: String = ""

var custom_keys: Array[int] = []
var custom_active: bool = false

var blocked_log: Array[String] = []

var installed: bool = false
var install_error: String = ""

var _ach: Node = null
var _orig_script: Script = null
var _real: Node = null

var _reward_snapshot: Dictionary = {}
var _resave_pending: bool = false
var _resave_delay: float = 0.0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	install()

func _exit_tree() -> void:
	uninstall()

func _process(delta: float) -> void:
	if _resave_delay > 0.0:
		_resave_delay = maxf(0.0, _resave_delay - delta)

	if not (is_custom_battle() and _battle_alive()):
		if _resave_pending:
			_resave()
		_reward_snapshot.clear()
		return

	var gm := get_node_or_null(GM_PATH)
	if gm == null:
		return
	var cur = gm.get("currency_amounts")
	if not (cur is Dictionary):
		return

	if _reward_snapshot.is_empty():
		_reward_snapshot = (cur as Dictionary).duplicate()
		return
	for k in _reward_snapshot:
		if cur.has(k) and cur[k] != _reward_snapshot[k]:
			cur[k] = _reward_snapshot[k]
			_resave_pending = true

	if _resave_pending and _resave_delay <= 0.0:
		_resave()

func _battle_alive() -> bool:
	return get_tree().get_first_node_in_group("battle") != null

func _resave() -> void:
	_resave_pending = false
	_resave_delay = 2.0
	var ss := get_node_or_null(SAVE_PATH)
	if ss != null and ss.has_method("save_save_data"):
		ss.call("save_save_data")

func install() -> bool:
	if installed:
		return true
	install_error = ""

	_ach = get_node_or_null(ACH_PATH)
	if _ach == null:
		install_error = "нет автозагрузки Achievements"
		printerr("[MAP STUDIO] ", install_error)
		return false

	_orig_script = _ach.get_script()
	if _orig_script == null:
		install_error = "у Achievements нет скрипта"
		printerr("[MAP STUDIO] ", install_error)
		return false

	var shim_path := mod_dir.path_join("ach_shim.gd")
	var src := FileAccess.get_file_as_string(shim_path)
	if src.is_empty():
		install_error = "не читается ach_shim.gd (%s)" % shim_path
		printerr("[MAP STUDIO] ", install_error)
		return false

	var shim := GDScript.new()
	shim.source_code = src
	shim.resource_path = "user://__ach_shim.gd"
	var err: int = shim.reload()
	if err != OK:
		install_error = "ach_shim.gd не компилируется (%s)" % error_string(err)
		printerr("[MAP STUDIO] ", install_error)
		return false

	_real = Node.new()
	_real.name = &"AchievementsReal"
	_real.set_script(_orig_script)
	add_child(_real)

	_ach.set_script(shim)
	_ach.set("_real", _real)
	_ach.set("_guard", self)

	installed = true
	print("[MAP STUDIO] достижения защищены: свои карты в Steam не идут")
	return true

func uninstall() -> void:
	if not installed:
		return
	if _ach != null and is_instance_valid(_ach) and _orig_script != null:
		_ach.set_script(_orig_script)
	if _real != null and is_instance_valid(_real):
		_real.queue_free()
	_real = null
	installed = false
	print("[MAP STUDIO] защита снята, достижения работают штатно")

func should_block() -> bool:
	return is_custom_battle()

func is_custom_battle() -> bool:
	if custom_active:
		return true
	var gm := get_node_or_null(GM_PATH)
	if gm == null:
		return false
	var lvl: int = int(gm.get("selected_level"))
	return custom_keys.has(lvl)

func note_blocked(ach: StringName) -> void:
	blocked_log.append(String(ach))
	if blocked_log.size() > 50:
		blocked_log.remove_at(0)
	print("[MAP STUDIO] achievement blocked (custom map): ", String(ach))

func register_custom_key(key: int) -> void:
	if not custom_keys.has(key):
		custom_keys.append(key)
