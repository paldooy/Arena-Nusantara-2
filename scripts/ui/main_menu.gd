extends Control

# ============================================================
# main_menu.gd — Menu utama: Play & Credit
# ============================================================

@onready var btn_play:   Button = $Center/VBox/BtnPlay
@onready var btn_credit: Button = $Center/VBox/BtnCredit
@onready var lbl_title:  Label  = $TitleArea/LblTitle

var _t: float = 0.0

func _ready() -> void:
	btn_play.pressed.connect(_on_play)
	btn_credit.pressed.connect(func(): _fade_to(GameManager.go_to_credits))
	modulate.a = 0.0
	create_tween().tween_property(self, "modulate:a", 1.0, 0.8)

func _process(delta: float) -> void:
	_t += delta
	if lbl_title:
		lbl_title.position.y = sin(_t * 1.1) * 5.0

func _on_play() -> void:
	_fade_to(GameManager.go_to_hero_select)

func _fade_to(callback: Callable) -> void:
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 0.0, 0.35)
	await tw.finished
	callback.call()
