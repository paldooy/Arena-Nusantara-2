extends CanvasLayer

# ============================================================
# hud.gd
# Update HP bar, EXP bar, label level, cooldown skill slots
# ============================================================

@onready var hp_bar:      ProgressBar   = $MarginContainer/VBoxContainer/HpBar
@onready var exp_bar:     ProgressBar   = $MarginContainer/VBoxContainer/HBoxLevelExp/ExpBar
@onready var lbl_level:   Label         = $MarginContainer/VBoxContainer/HBoxLevelExp/LblLevel
@onready var skill_slots: HBoxContainer = $SkillSlots

# Diisi oleh game_world.gd
var class_system: Node = null
var skill_system: Node = null

func _process(_delta: float) -> void:
	_update_hp()
	_update_exp()
	_update_skills()

func _update_hp() -> void:
	if class_system == null:
		return
	hp_bar.value = class_system.get_hp_ratio() * 100.0

func _update_exp() -> void:
	if class_system == null:
		return
	var ls: Node = class_system.get_node_or_null("../LevelSystem")
	if ls == null:
		return
	exp_bar.value  = ls.get_exp_progress() * 100.0
	lbl_level.text = "LV " + str(ls.get_level())

func _update_skills() -> void:
	if skill_system == null:
		return
	var learned: Array = skill_system.get_learned_skills()
	# Filter passive dari slot UI
	var active_skills: Array = learned.filter(
		func(id): return not skill_system.get_skill_data(id).get("passive", false)
	)

	var slots = skill_slots.get_children()
	for i in range(slots.size()):
		if i >= active_skills.size():
			slots[i].visible = false
			continue
		slots[i].visible = true
		var skill_id: String = active_skills[i]
		var ratio: float     = skill_system.get_cooldown_ratio(skill_id)
		var cd_bar = slots[i].get_node_or_null("Cooldown")
		if cd_bar:
			cd_bar.value = ratio * 100.0

func show_level_up_text(level: int) -> void:
	print("[HUD] LEVEL UP! → ", level)
	# TODO: tambahkan Label animasi "LEVEL UP!" di sini jika diinginkan
