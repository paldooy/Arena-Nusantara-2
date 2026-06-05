extends Control

# ============================================================
# hero_select.gd — Pilih hero sebelum game dimulai
# ============================================================

@onready var btn_berserker:   Button         = $Cards/CardB/VBox/BtnSelect
@onready var btn_necromancer: Button         = $Cards/CardN/VBox/BtnSelect
@onready var btn_back:        Button         = $BtnBack
@onready var lbl_hero_name:   Label          = $Preview/PadContainer/PVBox/LblName
@onready var lbl_hero_desc:   Label          = $Preview/PadContainer/PVBox/LblDesc
@onready var card_b:          PanelContainer = $Cards/CardB
@onready var card_n:          PanelContainer = $Cards/CardN

const INFO := {
	"b": {
		"name": "⚔  Ksatria Berserker",
		"desc": "Pejuang melee yang mengandalkan kecepatan dan serangan brutal.\n\n• Serangan arc setengah lingkaran ke arah hadap\n• Whirlwind Slash — putar serang semua musuh di sekitar\n• Blood Aura — ATK meningkat + dapatkan Lifesteal\n• Ground Smash — hantam tanah, AOE besar + stun\n\nCocok untuk pemain agresif yang suka terjun langsung.",
	},
	"n": {
		"name": "💀  Dukun Necromancer",
		"desc": "Penyihir gelap yang mengendalikan arwah dan undead.\n\n• Tembak projectile ke musuh yang diklik\n• Soul Mark — musuh yang ditandai jadi summon saat mati\n• Dark Empowerment — perkuat semua summon\n• Dark Circle — ledakan AOE di posisi kursor\n\nCocok untuk pemain yang suka bermain dari belakang.",
	},
}

func _ready() -> void:
	btn_berserker.pressed.connect(func():  _select(GameManager.CharacterClass.BERSERKER))
	btn_necromancer.pressed.connect(func(): _select(GameManager.CharacterClass.NECROMANCER))
	btn_back.pressed.connect(func(): _fade_to(GameManager.go_to_main_menu))

	btn_berserker.mouse_entered.connect(func():  _hover("b"))
	btn_necromancer.mouse_entered.connect(func(): _hover("n"))
	card_b.mouse_entered.connect(func():  _hover("b"))
	card_n.mouse_entered.connect(func(): _hover("n"))

	# Default preview
	_hover("b")

	modulate.a = 0.0
	create_tween().tween_property(self, "modulate:a", 1.0, 0.6)

func _hover(key: String) -> void:
	lbl_hero_name.text = INFO[key]["name"]
	lbl_hero_desc.text = INFO[key]["desc"]
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(card_b, "scale", Vector2(1.05, 1.05) if key == "b" else Vector2(1.0, 1.0), 0.12)
	tw.tween_property(card_n, "scale", Vector2(1.05, 1.05) if key == "n" else Vector2(1.0, 1.0), 0.12)

func _select(cls: GameManager.CharacterClass) -> void:
	_fade_to(func(): GameManager.start_game(cls))

func _fade_to(callback: Callable) -> void:
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 0.0, 0.3)
	await tw.finished
	callback.call()
