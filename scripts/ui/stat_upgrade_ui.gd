extends CanvasLayer

# ============================================================
# stat_upgrade_ui.gd  [FIX — deskripsi upgrade lebih detail]
# ============================================================

signal upgrade_confirmed(upgrade_id: String)

@onready var bg_overlay: ColorRect      = $BgOverlay
@onready var panel:      PanelContainer = $PanelContainer
@onready var lbl_title:  Label          = $PanelContainer/VBoxContainer/LblTitle
@onready var btn_a:      Button         = $PanelContainer/VBoxContainer/HBoxContainer/BtnA
@onready var btn_b:      Button         = $PanelContainer/VBoxContainer/HBoxContainer/BtnB
@onready var btn_c:      Button         = $PanelContainer/VBoxContainer/HBoxContainer/BtnC

var stat_upgrade_system: Node  = null
var current_choices:     Array = []

# Label tier — index 0 tidak dipakai
const TIER_SYMBOL: Array = ["", "I", "II", "III", "★"]

func _ready() -> void:
	_set_ui_visible(false)
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

	lbl_title.text = "✦ Pilih Upgrade Stat ✦"

	var btns: Array = [btn_a, btn_b, btn_c]
	for i in range(3):
		if i < choice_ids.size():
			var data: Dictionary = upgrade_sys.get_upgrade_data(choice_ids[i])
			btns[i].visible = true
			btns[i].text    = _build_upgrade_text(data)
		else:
			btns[i].visible = false

	_set_ui_visible(true)
	call_deferred("_do_pause")

func _build_upgrade_text(data: Dictionary) -> String:
	var tier:   int    = data.get("tier", 1)
	var name:   String = data.get("name", "???")
	var desc:   String = data.get("desc", data.get("description", ""))
	var stat:   String = data.get("stat", "")
	var value          = data.get("value", 0)
	var sym:    String = TIER_SYMBOL[clamp(tier, 0, 4)]

	# Baris 1: nama + simbol tier
	var text: String = "[Tier %s]  %s\n" % [sym, name]

	# Baris 2: deskripsi singkat dari "desc"
	if desc != "":
		text += desc + "\n"

	# Baris 3: detail stat yang berubah (format ramah)
	text += _stat_detail(stat, value)

	return text

func _stat_detail(stat: String, value) -> String:
	match stat:
		"defense":
			return "→ Defense +%d (kurangi damage masuk %d flat)" % [value, value]
		"attack_pct":
			return "→ Damage +%.0f%%" % [(value * 100.0)]
		"lifesteal":
			return "→ Lifesteal +%.0f%% dari damage" % [(value * 100.0)]
		"crit_chance":
			return "→ Crit Chance +%.0f%%" % [(value * 100.0)]
		"crit_mult":
			return "→ Crit Damage +%.0f%% (multiplier ×%.2f)" % [(value * 100.0), value]
		"move_speed":
			return "→ Move Speed +%.0f" % [value]
		"hp_pct":
			return "→ Max HP +%.0f%% dari HP saat ini" % [(value * 100.0)]
		"hp":
			return "→ Max HP +%d (flat)" % [int(value)]
		"cd_reduction":
			return "→ Cooldown skill -%d%%" % [int(value * 100.0)]
		"attack_range":
			return "→ Jangkauan serangan +%.0f px" % [value]
		"attack_speed":
			return "→ Attack Speed +%.2f (interval lebih cepat)" % [value]
		"splash_radius":
			return "→ Radius ledakan +%.0f px" % [value]
		"summon_hp_pct":
			return "→ HP summon +%.0f%%" % [(value * 100.0)]
		"summon_limit":
			return "→ Batas summon +%d" % [int(value)]
		_:
			return "→ %s +%s" % [stat, str(value)]

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
