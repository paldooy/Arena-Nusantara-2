extends Node

# ============================================================
# game_manager.gd  [AUTOLOAD]
# ============================================================

enum GameState { MENU, HERO_SELECT, PLAYING, WIN, LOSE }
enum CharacterClass { BERSERKER, NECROMANCER }

var game_state: GameState = GameState.MENU
var selected_class: CharacterClass

# Definisikan tipe data di dalam sinyal untuk auto-complete yang lebih baik
signal on_game_started(char_class: CharacterClass)
signal on_game_over(is_win: bool)

func _ready() -> void:
	# Memastikan GameManager tetap berjalan meski game sedang di-pause
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
	
	# Ganti scene terlebih dahulu
	var error = get_tree().change_scene_to_file("res://scenes/GameWorld.tscn")
	
	# Tunggu sampai scene baru benar-benar selesai dimuat sebelum memancarkan sinyal
	if error == OK:
		await get_tree().node_added
		on_game_started.emit(cls)


func end_game(win: bool) -> void:
	game_state = GameState.WIN if win else GameState.LOSE
	get_tree().paused = true
	
	# Menggunakan sintaks .emit() khas Godot 4
	on_game_over.emit(win)


func is_playing() -> bool:
	return game_state == GameState.PLAYING
