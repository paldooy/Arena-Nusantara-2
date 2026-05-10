extends Control

# ============================================================
# skill_choice_ui.gd  [FIX — sama dengan stat_upgrade_ui]
# Level 5  → 3 tombol (semua skill class)
# Level 10 → 2 tombol (2 skill yang belum dipilih)
# ============================================================

signal skill_chosen(skill_id: String)

@onready var lbl_title: Label  = $PanelContainer/VBoxContainer/LblTitle
@onready var lbl_slot:  Label  = $PanelContainer/VBoxContainer/LblSlot
@onready var btn_a:     Button = $PanelContainer/VBoxContainer/HBoxContainer/BtnA
@onready var btn_b:     Button = $PanelContainer/VBoxContainer/HBoxContainer/BtnB
@onready var btn_c:     Button = $PanelContainer/VBoxContainer/HBoxContainer/BtnC

var skill_system: Node  = null
var choices:      Array = []

func _ready() -> void:
	visible = false
	# Force semua child ke ALWAYS agar tombol aktif saat paused
	_set_process_mode_recursive(self, Node.PROCESS_MODE_ALWAYS)
	btn_a.pressed.connect(func(): _confirm(0))
	btn_b.pressed.connect(func(): _confirm(1))
	btn_c.pressed.connect(func(): _confirm(2))

func _set_process_mode_recursive(node: Node, mode: int) -> void:
	node.process_mode = mode
	for child in node.get_children():
		_set_process_mode_recursive(child, mode)

func show_choices(choice_ids: Array, skill_sys: Node) -> void:
	skill_system = skill_sys
	choices      = choice_ids

	var slot_num: int = skill_sys.get_learned_skills().size() + 1
	lbl_title.text = "Pilih Skill!"
	lbl_slot.text  = "Slot %d dari 2 aktif" % slot_num

	var btns: Array = [btn_a, btn_b, btn_c]
	for i in range(3):
		if i < choices.size():
			var data: Dictionary = skill_sys.get_skill_data(choices[i])
			btns[i].visible = true
			btns[i].text = "[%s]\n%s\n(CD: %.0fs)" % [
				data.get("name", "???"),
				data.get("description", ""),
				data.get("cooldown", 0.0),
			]
		else:
			btns[i].visible = false

	visible = true
	call_deferred("_do_pause")

func _do_pause() -> void:
	get_tree().paused = true

func _confirm(index: int) -> void:
	if index >= choices.size(): return
	if skill_system:
		skill_system.player_chose_skill(choices[index])
	emit_signal("skill_chosen", choices[index])
	visible = false
	get_tree().paused = false
