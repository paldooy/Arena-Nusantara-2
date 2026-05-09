extends Node2D

# ============================================================
# spawner.gd
# Spawn musuh di pinggir arena berdasarkan level player
# Pasang script ini ke node EnemySpawner di GameWorld.tscn
# ============================================================

@export var arena_size: Vector2 = Vector2(800, 600)

# Preload scene musuh — buat scene kosong dulu jika belum ada
const SCENE_SLIME       = preload("res://scenes/characters/Slime.tscn")
const SCENE_GOBLIN      = preload("res://scenes/characters/Goblin.tscn")
const SCENE_SKELETON    = preload("res://scenes/characters/Skeleton.tscn")
const SCENE_DARK_KNIGHT = preload("res://scenes/characters/DarkKnight.tscn")
const SCENE_BOSS        = preload("res://scenes/characters/Boss.tscn")

var enemy_balance:      Node  = null
var level_system:       Node  = null
var current_player_level: int = 1

var spawn_timer:    float = 0.0
var spawn_interval: float = 3.5
var is_boss_spawned: bool = false
var active_enemies: Array = []

func setup(eb: Node, ls: Node) -> void:
	enemy_balance = eb
	level_system  = ls

func update_level(new_level: int) -> void:
	current_player_level = new_level
	if new_level < 15:
		spawn_interval = enemy_balance.get_spawn_interval(new_level)

func _process(delta: float) -> void:
	if not GameManager.is_playing():
		return
	if is_boss_spawned or current_player_level >= 15:
		return

	spawn_timer += delta
	if spawn_timer >= spawn_interval:
		spawn_timer = 0.0
		_spawn_enemy()

func _spawn_enemy() -> void:
	var enemy_type = enemy_balance.pick_random_enemy(current_player_level)
	var stats: Dictionary = enemy_balance.generate_enemy_stats(enemy_type, current_player_level)
	var scene = _get_scene_for_type(enemy_type)
	if scene == null:
		return

	var instance = scene.instantiate()
	instance.position = _random_spawn_pos()
	# Tambah ke YSort (parent dari spawner adalah GameWorld, YSort ada di sana)
	var y_sort = get_parent().get_node_or_null("YSort")
	if y_sort:
		y_sort.add_child(instance)
	else:
		get_parent().add_child(instance)

	if instance.has_method("setup"):
		instance.setup(stats, enemy_type)

	if not instance.on_died.is_connected(_on_enemy_died):
		instance.on_died.connect(_on_enemy_died)
	active_enemies.append(instance)
	_update_player_enemy_list()

func spawn_boss() -> void:
	if is_boss_spawned:
		return
	is_boss_spawned = true

	var stats: Dictionary = enemy_balance.generate_enemy_stats(
		enemy_balance.EnemyType.BOSS, 15
	)
	var instance = SCENE_BOSS.instantiate()
	instance.position = Vector2(arena_size.x * 0.5, 80.0)

	var y_sort = get_parent().get_node_or_null("YSort")
	if y_sort:
		y_sort.add_child(instance)
	else:
		get_parent().add_child(instance)

	if instance.has_method("setup"):
		instance.setup(stats, enemy_balance.EnemyType.BOSS)

	if not instance.on_died.is_connected(_on_boss_died):
		instance.on_died.connect(_on_boss_died)
	active_enemies.append(instance)
	_update_player_enemy_list()

func _on_enemy_died(enemy_node: Node, enemy_type_val: int) -> void:
	active_enemies.erase(enemy_node)

	# Jika musuh ditandai Soul Mark → emit sinyal ke game_world untuk spawn summon
	if enemy_node.get("is_marked"):
		get_parent().emit_signal("request_summon_from_death", enemy_node.global_position)

	# Beri EXP
	enemy_balance.notify_enemy_killed(enemy_type_val, current_player_level)
	_update_player_enemy_list()

func _on_boss_died(_enemy_node: Node, _enemy_type_val: int) -> void:
	GameManager.end_game(true)

func _update_player_enemy_list() -> void:
	active_enemies = active_enemies.filter(func(e): return is_instance_valid(e))
	var players = get_tree().get_nodes_in_group("player")
	for p in players:
		p.enemies_in_scene = active_enemies

func _random_spawn_pos() -> Vector2:
	var side: int = randi() % 4
	match side:
		0: return Vector2(randf_range(0, arena_size.x), -20.0)
		1: return Vector2(randf_range(0, arena_size.x), arena_size.y + 20.0)
		2: return Vector2(-20.0, randf_range(0, arena_size.y))
		3: return Vector2(arena_size.x + 20.0, randf_range(0, arena_size.y))
	return Vector2(arena_size.x * 0.5, -20.0)

func _get_scene_for_type(enemy_type) -> PackedScene:
	match int(enemy_type):
		0: return SCENE_SLIME
		1: return SCENE_GOBLIN
		2: return SCENE_SKELETON
		3: return SCENE_DARK_KNIGHT
		_: return null
