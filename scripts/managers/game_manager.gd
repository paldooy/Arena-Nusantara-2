extends Node

# ============================================================
# game_manager.gd  — AUTOLOAD (singleton)
# Global state: class yang dipilih, state game, restart
# Daftarkan di Project > Project Settings > Autoload
# Node name: GameManager
# ============================================================

signal on_game_started(char_class_name: String)
signal on_game_over(win: bool)

enum GameState { MENU, PLAYING, WIN, LOSE }
enum CharacterClass { BERSERKER, NECROMANCER }

var game_state: GameState = GameState.MENU
var selected_class: CharacterClass = CharacterClass.BERSERKER

# Path scene
const SCENE_MAIN_MENU = "res://scenes/MainMenu.tscn"
const SCENE_GAME_WORLD = "res://scenes/GameWorld.tscn"

func start_game(cls: CharacterClass) -> void:
	selected_class = cls
	game_state = GameState.PLAYING
	get_tree().paused = false
	emit_signal("on_game_started", CharacterClass.keys()[cls])
	get_tree().change_scene_to_file(SCENE_GAME_WORLD)

func end_game(win: bool) -> void:
	if win:
		game_state = GameState.WIN
	else:
		game_state = GameState.LOSE
	get_tree().paused = true
	emit_signal("on_game_over", win)

func restart() -> void:
	game_state = GameState.MENU
	get_tree().paused = false
	get_tree().change_scene_to_file(SCENE_MAIN_MENU)

func is_playing() -> bool:
	return game_state == GameState.PLAYING
