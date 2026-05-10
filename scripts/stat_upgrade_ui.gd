extends CanvasLayer

# ============================================================
# stat_upgrade_ui.gd  [FIX FINAL]
#
# Root node HARUS CanvasLayer (bukan Control) karena parent-nya
# adalah Node2D (GameWorld). Control di bawah Node2D tidak
# akan render sebagai UI overlay layar penuh.
#
# Visibility dikontrol via show()/hide() pada child nodes,
# bukan lewat CanvasLayer.visible karena itu tidak reliable.
# ============================================================

signal upgrade_confirmed(upgrade_id: String)

@onready var bg_overlay:   ColorRect      = $BgOverlay
@onready var panel:        PanelContainer = $PanelContainer
@onready var lbl_title:    Label          = $PanelContainer/VBoxContainer/LblTitle
@onready var btn_a:        Button         = $PanelContainer/VBoxContainer/HBoxContainer/BtnA
@onready var btn_b:        Button         = $PanelContainer/VBoxContainer/HBoxContainer/BtnB
@onready var btn_c:        Button         = $PanelContainer/VBoxContainer/HBoxContainer/BtnC

var stat_upgrade_system: Node  = null
var current_choices:     Array = []

func _ready() -> void:
	# Sembunyikan saat awal
	_set_ui_visible(false)

	# Semua node di subtree ini harus ALWAYS agar jalan saat pause
	_set_process_mode_recursive(self, Node.PROCESS_MODE_ALWAYS)

	btn_a.pressed.connect(func(): _confirm(0))
	btn_b.pressed.connect(func(): _confirm(1))
	btn_c.pressed.connect(func(): _confirm(2))

func _set_process_mode_recursive(node: Node, mode: int) -> void:
	node.process_mode = mode
	for child in node.get_children():
		_set_process_mode_recursive(child, mode)

func _set_ui_visible(show_ui: bool) -> void:
	bg_overlay.visible = show_ui
	panel.visible      = show_ui

func show_upgrades(choice_ids: Array, upgrade_sys: Node) -> void:
	stat_upgrade_system = upgrade_sys
	current_choices     = choice_ids

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

	_set_ui_visible(true)
	# Pause di frame berikutnya agar UI sempat render
	call_deferred("_do_pause")

func _do_pause() -> void:
	get_tree().paused = true

func _confirm(index: int) -> void:
	if index >= current_choices.size():
		return
	var chosen_id: String = current_choices[index]
	if stat_upgrade_system:
		stat_upgrade_system.apply_upgrade(chosen_id)
	emit_signal("upgrade_confirmed", chosen_id)
	_set_ui_visible(false)
	get_tree().paused = false
