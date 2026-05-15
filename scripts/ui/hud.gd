extends CanvasLayer

# ============================================================
# hud.gd  [DIREVISI]
# - Hanya 2 slot skill (karena max 2 skill aktif)
# - Update HP, EXP, Level, cooldown slot
# ============================================================

@onready var hp_bar:      ProgressBar     = $MarginContainer/VBoxContainer/HpBar
@onready var exp_bar:     ProgressBar     = $MarginContainer/VBoxContainer/HBoxLevelExp/ExpBar
@onready var lbl_level:   Label           = $MarginContainer/VBoxContainer/HBoxLevelExp/LblLevel
@onready var skill_slots: HBoxContainer   = $SkillSlots

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
	var ls = class_system.get_node("../LevelSystem")
	if ls:
		exp_bar.value = ls.get_exp_progress() * 100.0
		lbl_level.text = "LV " + str(ls.get_level())

func _update_skills() -> void:
	if skill_system == null:
		return
	var learned: Array = skill_system.get_learned_skills()
	var slots = skill_slots.get_children()
	for i in range(slots.size()):
		if i >= learned.size():
			slots[i].visible = false
			continue
		slots[i].visible = true
		var skill_id: String = learned[i]
		var ratio: float = skill_system.get_cooldown_ratio(skill_id)
		var cd_bar = slots[i].get_node_or_null("Cooldown")
		if cd_bar:
			cd_bar.value = ratio * 100.0
		# Tampilkan nama skill singkat
		var lbl = slots[i].get_node_or_null("LblKey")
		if lbl:
			lbl.text = "Q" if i == 0 else "E"

func show_level_up_text(level: int) -> void:
	print("[HUD] LEVEL UP! Level ", level)
	# Tambahkan animasi tween di sini jika mau
