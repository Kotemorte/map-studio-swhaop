extends Node

var mod_dir: String = ""
var mod_name: String = ""

const PARTS := [
	["ach_guard.gd", "AchGuard"],
	["map_studio.gd", "MapStudio"],
]

var guard: Node = null
var menu: Node = null

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for part in PARTS:
		var node := _load_part(String(part[0]), StringName(part[1]))
		if node == null:
			continue
		if part[1] == "AchGuard":
			guard = node
		elif part[1] == "MapStudio":
			menu = node

func _load_part(file_name: String, node_name: StringName) -> Node:
	var path := mod_dir.path_join(file_name)
	if not FileAccess.file_exists(path):
		printerr("[%s] нет файла %s" % [mod_name, path])
		return null

	var src := FileAccess.get_file_as_string(path)
	if src.is_empty():
		printerr("[%s] файл пуст: %s" % [mod_name, file_name])
		return null

	var scr := GDScript.new()
	scr.source_code = src
	scr.resource_path = "user://__%s_%s" % [mod_name, file_name]
	var err: int = scr.reload()
	if err != OK:
		printerr("[%s] %s не компилируется (%s) — подробности выше"
				% [mod_name, file_name, error_string(err)])
		return null
	if not scr.can_instantiate():
		printerr("[%s] %s не создаётся" % [mod_name, file_name])
		return null

	var inst: Node = scr.new()
	inst.name = node_name
	inst.set("mod_dir", mod_dir)
	add_child(inst)
	return inst
