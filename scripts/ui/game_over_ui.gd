extends CanvasLayer

# ============================================================
# game_over_ui.gd — Menampilkan screen Game Over / Kamu Menang
# ============================================================

@onready var bg_overlay: ColorRect      = $BgOverlay
@onready var panel:      PanelContainer = $PanelContainer
@onready var lbl_title:  Label          = $PanelContainer/VBox/LblTitle
@onready var lbl_desc:   Label          = $PanelContainer/VBox/LblDesc
@onready var btn_retry:  Button         = $PanelContainer/VBox/HBoxButtons/BtnRetry
@onready var btn_menu:   Button         = $PanelContainer/VBox/HBoxButtons/BtnMenu

func _ready() -> void:
	visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS
	btn_retry.pressed.connect(_on_retry_pressed)
	btn_menu.pressed.connect(_on_menu_pressed)

func show_game_over(is_win: bool) -> void:
	visible = true
	
	# Set styling and text based on win/lose state
	if is_win:
		lbl_title.text = "✦ KAMU MENANG! ✦"
		lbl_title.add_theme_color_override("font_color", Color(0.95, 0.82, 0.2)) # Glorious Gold
		lbl_desc.text = "Selamat! Kamu berhasil mengalahkan Leak\ndan menyelamatkan kedamaian Nusantara!"
	else:
		lbl_title.text = "💀 GAME OVER 💀"
		lbl_title.add_theme_color_override("font_color", Color(0.9, 0.2, 0.2)) # Crimson Red
		lbl_desc.text = "Karaktermu gugur di medan tempur.\nJangan menyerah, mari coba lagi!"

	# Animation fade-in
	bg_overlay.modulate.a = 0.0
	panel.modulate.a = 0.0
	panel.pivot_offset = panel.size / 2.0
	panel.scale = Vector2(0.8, 0.8)
	
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(bg_overlay, "modulate:a", 1.0, 0.4)
	tw.tween_property(panel, "modulate:a", 1.0, 0.4)
	tw.tween_property(panel, "scale", Vector2(1.0, 1.0), 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _on_retry_pressed() -> void:
	get_tree().paused = false
	GameManager.go_to_hero_select()

func _on_menu_pressed() -> void:
	get_tree().paused = false
	GameManager.go_to_main_menu()
