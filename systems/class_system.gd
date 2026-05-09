extends Node

# ============================================================
# class_system.gd
# Koordinator utama: menghubungkan level, stat, dan skill
# ============================================================

signal on_player_ready(char_class_name: String)
signal on_stats_updated(stats: Dictionary)

enum CharacterClass { BERSERKER, NECROMANCER }

@onready var level_system  = $"../LevelSystem"
@onready var stat_system   = $"../StatSystem"
@onready var skill_system  = $"../SkillSystem"

var selected_class: CharacterClass
var current_hp: int = 0
var max_hp: int = 0

func init_class(cls: CharacterClass) -> void:
	selected_class = cls

	stat_system.init(cls)
	skill_system.init(cls)
	level_system.level = 1
	level_system.current_exp = 0
	level_system.exp_to_next = level_system.EXP_TABLE[0]

	max_hp     = stat_system.get_max_hp()
	current_hp = max_hp

	# Sambungkan sinyal level_system ke class_system
	if not level_system.on_level_up.is_connected(_on_level_up):
		level_system.on_level_up.connect(_on_level_up)
	if not level_system.on_skill_unlock.is_connected(_on_skill_unlock):
		level_system.on_skill_unlock.connect(_on_skill_unlock)

	emit_signal("on_player_ready", CharacterClass.keys()[cls])
	emit_signal("on_stats_updated", stat_system.stats)
	print("[ClassSystem] Class dipilih: ", CharacterClass.keys()[cls])

func _on_level_up(new_level: int) -> void:
	stat_system.apply_level_up(new_level)
	# Update max HP dan heal sebagian saat level up (reward kecil)
	var old_max = max_hp
	max_hp = stat_system.get_max_hp()
	current_hp += (max_hp - old_max)          # tambah HP sebesar kenaikan max HP
	current_hp = min(current_hp, max_hp)       # jangan melebihi max
	emit_signal("on_stats_updated", stat_system.stats)

func _on_skill_unlock(level: int) -> void:
	skill_system.on_level_reached(level)

# ─── COMBAT ───────────────────────────────────────────────
func take_damage(raw_damage: int) -> int:
	var defense: int = int(stat_system.get_stat("defense"))
	var final_dmg: int = max(1, raw_damage - defense)
	current_hp -= final_dmg
	current_hp = max(current_hp, 0)
	return final_dmg

func heal(amount: int) -> void:
	current_hp = min(current_hp + amount, max_hp)

func is_alive() -> bool:
	return current_hp > 0

func get_attack_damage() -> int:
	var base: int = stat_system.get_damage()
	if stat_system.get_crit_roll():
		return int(base * stat_system.get_stat("crit_mult"))
	return base

func get_hp_ratio() -> float:
	if max_hp == 0:
		return 0.0
	return float(current_hp) / float(max_hp)
