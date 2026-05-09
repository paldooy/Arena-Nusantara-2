extends Node

# ============================================================
# level_system.gd
# Mengatur EXP, level up, trigger skill unlock, dan spawn boss
# ============================================================

signal on_level_up(new_level: int)
signal on_exp_gained(current_exp: int, exp_needed: int)
signal on_skill_unlock(level: int)
signal on_boss_trigger()

const MAX_LEVEL: int = 15
const SKILL_UNLOCK_LEVELS: Array[int] = [5, 10]

var level: int = 1
var current_exp: int = 0
var exp_to_next: int = 0

const EXP_TABLE: Array[int] = [
	0,    # level 1  (tidak dipakai)
	120,  # level 1 → 2
	150,  # level 2 → 3
	180,  # level 3 → 4
	220,  # level 4 → 5
	260,  # level 5 → 6
	300,  # level 6 → 7
	340,  # level 7 → 8
	380,  # level 8 → 9
	420,  # level 9 → 10
	460,  # level 10 → 11
	500,  # level 11 → 12
	540,  # level 12 → 13
	580,  # level 13 → 14
	620,  # level 14 → 15
]

func _ready() -> void:
	level = 1
	current_exp = 0
	exp_to_next = EXP_TABLE[level - 1]

func add_exp(amount: int) -> void:
	if level >= MAX_LEVEL:
		return
	current_exp += amount
	emit_signal("on_exp_gained", current_exp, exp_to_next)
	while current_exp >= exp_to_next and level < MAX_LEVEL:
		current_exp -= exp_to_next
		_level_up()

func _level_up() -> void:
	level += 1
	print("[LevelSystem] Level Up! Sekarang level: ", level)
	emit_signal("on_level_up", level)
	if level in SKILL_UNLOCK_LEVELS:
		emit_signal("on_skill_unlock", level)
	if level < MAX_LEVEL:
		exp_to_next = EXP_TABLE[level - 1]
	else:
		exp_to_next = 0
		current_exp = 0
		print("[LevelSystem] Level MAX! Boss akan muncul!")
		emit_signal("on_boss_trigger")

func get_level() -> int:
	return level

func get_exp_progress() -> float:
	if exp_to_next == 0:
		return 1.0
	return float(current_exp) / float(exp_to_next)

func is_max_level() -> bool:
	return level >= MAX_LEVEL
