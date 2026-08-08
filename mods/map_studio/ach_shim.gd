extends Node

const SURVIVE_1: StringName = &"ACH_SURVIVE_1"
const SURVIVE_3: StringName = &"ACH_SURVIVE_3"
const SURVIVE_6: StringName = &"ACH_SURVIVE_6"
const ONE_TOWER: StringName = &"ACH_SURVIVE_ONE_TOWER"
const NO_TOWERS: StringName = &"ACH_SURVIVE_NO_TOWERS"
const ONE_TOWER_TYPE: StringName = &"ACH_SURVIVE_ONE_TOWER_TYPE"
const ELEMENTAL: StringName = &"ACH_SURVIVE_ELEMENTAL"
const THREE_TOWER_TYPE: StringName = &"ACH_SURVIVE_THREE_TOWER_TYPE"
const FOUR_TOWER_TYPE: StringName = &"ACH_SURVIVE_FOUR_TOWER_TYPE"
const BUY_ALL: StringName = &"ACH_BUY_ALL"
const NUKE: StringName = &"ACH_NUKE"

var _real: Node = null
var _guard: Node = null

func set_achieved(ach: StringName) -> void:
	if _guard != null and is_instance_valid(_guard) and _guard.should_block():
		_guard.note_blocked(ach)
		return
	if _real != null and is_instance_valid(_real):
		_real.set_achieved(ach)

func reset_stats_and_achievements() -> void:
	if _real != null and is_instance_valid(_real):
		_real.reset_stats_and_achievements()
