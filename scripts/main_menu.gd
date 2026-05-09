extends Control

# ============================================================
# main_menu.gd
# ============================================================

@onready var btn_berserker:   Button = $VBoxContainer/BtnBerserker
@onready var btn_necromancer: Button = $VBoxContainer/BtnNecromancer

func _ready() -> void:
	btn_berserker.pressed.connect(_on_berserker)
	btn_necromancer.pressed.connect(_on_necromancer)

func _on_berserker() -> void:
	GameManager.start_game(GameManager.CharacterClass.BERSERKER)

func _on_necromancer() -> void:
	GameManager.start_game(GameManager.CharacterClass.NECROMANCER)
