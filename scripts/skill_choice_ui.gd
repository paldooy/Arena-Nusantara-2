extends Control

# ============================================================
# skill_choice_ui.gd
# Popup pilih skill di level 5 & 10 — pause game lalu lanjut
# ============================================================

signal skill_chosen(skill_id: String)

@onready var btn_skill_a: Button = $PanelContainer/VBoxContainer/HBoxContainer/BtnSkillA
@onready var btn_skill_b: Button = $PanelContainer/VBoxContainer/HBoxContainer/BtnSkillB
@onready var lbl_title:   Label  = $PanelContainer/VBoxContainer/LblTitle

var skill_system: Node = null
var choices: Array     = []

func _ready() -> void:
	visible = false
	btn_skill_a.pressed.connect(_on_choice_a)
	btn_skill_b.pressed.connect(_on_choice_b)

func show_choices(choice_ids: Array, skill_sys: Node) -> void:
	skill_system = skill_sys
	choices      = choice_ids

	var data_a: Dictionary = skill_sys.get_skill_data(choice_ids[0])
	var data_b: Dictionary = skill_sys.get_skill_data(choice_ids[1])

	btn_skill_a.text = data_a.get("name", "???") + "\n" + data_a.get("description", "")
	btn_skill_b.text = data_b.get("name", "???") + "\n" + data_b.get("description", "")

	visible = true
	get_tree().paused = true

func _on_choice_a() -> void:
	_confirm(choices[0])

func _on_choice_b() -> void:
	_confirm(choices[1])

func _confirm(skill_id: String) -> void:
	if skill_system:
		skill_system.player_chose_skill(skill_id)
	emit_signal("skill_chosen", skill_id)
	visible = false
	get_tree().paused = false
