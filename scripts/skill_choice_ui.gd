extends Control

# ============================================================
# skill_choice_ui.gd  [DIREVISI]
# Popup pilih skill (3 pilihan) di level 5 & 10
# Muncul SETELAH popup upgrade stat selesai
# ============================================================

signal skill_chosen(skill_id: String)

@onready var btn_a:     Button = $PanelContainer/VBoxContainer/HBoxContainer/BtnA
@onready var btn_b:     Button = $PanelContainer/VBoxContainer/HBoxContainer/BtnB
@onready var btn_c:     Button = $PanelContainer/VBoxContainer/HBoxContainer/BtnC
@onready var lbl_title: Label  = $PanelContainer/VBoxContainer/LblTitle
@onready var lbl_slot:  Label  = $PanelContainer/VBoxContainer/LblSlot

var skill_system: Node = null
var choices: Array = []

func _ready() -> void:
	visible = false
	btn_a.pressed.connect(func(): _confirm(0))
	btn_b.pressed.connect(func(): _confirm(1))
	btn_c.pressed.connect(func(): _confirm(2))

func show_choices(choice_ids: Array, skill_sys: Node) -> void:
	skill_system = skill_sys
	choices = choice_ids

	var slot_num: int = skill_sys.get_learned_skills().size() + 1
	lbl_title.text = "Pilih Skill Baru!"
	lbl_slot.text  = "Skill Slot %d dari 2" % slot_num

	var btns: Array = [btn_a, btn_b, btn_c]
	for i in range(3):
		if i < choice_ids.size():
			var data: Dictionary = skill_sys.get_skill_data(choice_ids[i])
			btns[i].visible = true
			btns[i].text = "%s\n%s\n(CD: %.0fs)" % [
				data.get("name", "???"),
				data.get("description", ""),
				data.get("cooldown", 0.0),
			]
		else:
			btns[i].visible = false

	visible = true
	get_tree().paused = true

func _confirm(index: int) -> void:
	if index >= choices.size():
		return
	var chosen: String = choices[index]
	if skill_system:
		skill_system.player_chose_skill(chosen)
	emit_signal("skill_chosen", chosen)
	visible = false
	get_tree().paused = false
