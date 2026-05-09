extends Node2D

# ============================================================
# spawner.gd
# Spawn musuh di pinggir arena berdasarkan level player
# ============================================================

@export var arena_size: Vector2 = Vector2(800, 600)

# Preload scene musuh
const SCENE_SLIME       = preload("res://scenes/characters/Slime.tscn")
const SCENE_GOBLIN      = preload("res://scenes/characters/Goblin.tscn")
const SCENE_SKELETON    = preload("res://scenes/characters/Skeleton.tscn")
const SCENE_DARK_KNIGHT = preload("res://scenes/characters/DarkKnight.tscn")
const SCENE_BOSS        = preload("res://scenes/characters/Boss.tscn")

var enemy_balance: Node = null
var level_system: Node = null
var current_player_level: int = 1

var spawn_timer: float = 0.0
var spawn_interval: float = 3.5
var is_boss_spawned: bool = false
var active_enemies: Array = []

func _ready() -> void:
	pass

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
	if is_boss_spawned:
		return
	if current_player_level >= 15:
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
	get_parent().add_child(instance)

	if instance.has_method("setup"):
		instance.setup(stats, enemy_type)

	instance.on_died.connect(_on_enemy_died)
	active_enemies.append(instance)

	# Beritahu player soal musuh baru
	var players = get_tree().get_nodes_in_group("player")
	for p in players:
		if p.has_method("enemies_in_scene"):
			pass
		p.enemies_in_scene = active_enemies

func spawn_boss() -> void:
	if is_boss_spawned:
		return
	is_boss_spawned = true

	var stats: Dictionary = enemy_balance.generate_enemy_stats(
		enemy_balance.EnemyType.BOSS, 15
	)
	var instance = SCENE_BOSS.instantiate()
	# Spawn di tengah atas arena
	instance.position = Vector2(arena_size.x / 2.0, 80.0)
	get_parent().add_child(instance)

	if instance.has_method("setup"):
		instance.setup(stats, enemy_balance.EnemyType.BOSS)

	instance.on_died.connect(_on_boss_died)
	active_enemies.append(instance)

	var players = get_tree().get_nodes_in_group("player")
	for p in players:
		p.enemies_in_scene = active_enemies

func _on_enemy_died(enemy_node: Node, enemy_type: int) -> void:
	active_enemies.erase(enemy_node)

	# Jika musuh ditandai Necromancer, emit sinyal summon
	if enemy_node.is_marked:
		get_parent().emit_signal("request_summon_from_death", enemy_node.global_position)

	# Beri EXP ke level system
	enemy_balance.notify_enemy_killed(enemy_type, current_player_level)

	# Update referensi di player
	var players = get_tree().get_nodes_in_group("player")
	for p in players:
		p.enemies_in_scene = active_enemies

func _on_boss_died(_enemy_node: Node, _enemy_type: int) -> void:
	GameManager.end_game(true)

func _random_spawn_pos() -> Vector2:
	# Spawn di salah satu sisi arena
	var side: int = randi() % 4
	match side:
		0: return Vector2(randf_range(0, arena_size.x), -20)           # atas
		1: return Vector2(randf_range(0, arena_size.x), arena_size.y + 20) # bawah
		2: return Vector2(-20, randf_range(0, arena_size.y))            # kiri
		3: return Vector2(arena_size.x + 20, randf_range(0, arena_size.y)) # kanan
	return Vector2.ZERO

func _get_scene_for_type(enemy_type) -> PackedScene:
	match enemy_type:
		0: return SCENE_SLIME
		1: return SCENE_GOBLIN
		2: return SCENE_SKELETON
		3: return SCENE_DARK_KNIGHT
		_: return null
