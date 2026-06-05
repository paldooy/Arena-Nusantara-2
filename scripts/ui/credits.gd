extends Control

# ============================================================
# credits.gd
# ============================================================

@onready var btn_back: Button = $BtnBack

func _ready() -> void:
	btn_back.pressed.connect(func(): _fade_to(GameManager.go_to_main_menu))
	modulate.a = 0.0
	create_tween().tween_property(self, "modulate:a", 1.0, 0.6)

func _fade_to(callback: Callable) -> void:
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 0.0, 0.3)
	await tw.finished
	callback.call()
