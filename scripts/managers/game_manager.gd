extends Node

# ============================================================
# game_manager.gd  [AUTOLOAD]
# ============================================================

enum GameState { MENU, HERO_SELECT, PLAYING, WIN, LOSE }
enum CharacterClass { BERSERKER, NECROMANCER }

var game_state: GameState = GameState.MENU
var selected_class: CharacterClass

signal on_game_started(char_class: int)
signal on_game_over(is_win: bool)

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func go_to_main_menu() -> void:
	game_state = GameState.MENU
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/MainMenu.tscn")

func go_to_hero_select() -> void:
	game_state = GameState.HERO_SELECT
	get_tree().change_scene_to_file("res://scenes/HeroSelect.tscn")

func go_to_credits() -> void:
	get_tree().change_scene_to_file("res://scenes/Credits.tscn")

func start_game(cls: CharacterClass) -> void:
	selected_class = cls
	game_state = GameState.PLAYING
	get_tree().paused = false
	emit_signal("on_game_started", cls)
	get_tree().change_scene_to_file("res://scenes/GameWorld.tscn")

func end_game(win: bool) -> void:
	game_state = GameState.WIN if win else GameState.LOSE
	get_tree().paused = true
	emit_signal("on_game_over", win)

func is_playing() -> bool:
	return game_state == GameState.PLAYING
