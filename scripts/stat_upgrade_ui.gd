extends Control

# ============================================================
# stat_upgrade_ui.gd  [BARU]
# Popup muncul tiap level up — pilih 1 dari 3 upgrade stat
# Muncul SETELAH upgrade stat (sebelum pilih skill jika level 5/10)
# ============================================================

signal upgrade_confirmed(upgrade_id: String)

@onready var lbl_title:   Label           = $PanelContainer/VBoxContainer/LblTitle
@onready var btn_a:       Button          = $PanelContainer/VBoxContainer/HBoxContainer/BtnA
@onready var btn_b:       Button          = $PanelContainer/VBoxContainer/HBoxContainer/BtnB
@onready var btn_c:       Button          = $PanelContainer/VBoxContainer/HBoxContainer/BtnC

var stat_upgrade_system: Node = null
var current_choices: Array = []

func _ready() -> void:
	visible = false
	btn_a.pressed.connect(func(): _confirm(0))
	btn_b.pressed.connect(func(): _confirm(1))
	btn_c.pressed.connect(func(): _confirm(2))

func show_upgrades(choice_ids: Array, upgrade_sys: Node) -> void:
	stat_upgrade_system = upgrade_sys
	current_choices = choice_ids

	lbl_title.text = "Pilih Upgrade Stat!"

	var btns: Array = [btn_a, btn_b, btn_c]
	for i in range(3):
		if i < choice_ids.size():
			var data: Dictionary = upgrade_sys.get_upgrade_data(choice_ids[i])
			btns[i].visible = true
			btns[i].text = "[Tier %d] %s\n%s" % [
				data.get("tier", 1),
				data.get("name", "???"),
				data.get("description", "")
			]
		else:
			btns[i].visible = false

	visible = true
	get_tree().paused = true

func _confirm(index: int) -> void:
	if index >= current_choices.size():
		return
	var chosen_id: String = current_choices[index]
	if stat_upgrade_system:
		stat_upgrade_system.apply_upgrade(chosen_id)
	emit_signal("upgrade_confirmed", chosen_id)
	visible = false
	get_tree().paused = false
