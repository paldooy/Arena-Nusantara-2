extends Node2D

# ============================================================
# spawner.gd  [DIREVISI — Hantu Nusantara v2]
#
# CARA PASANG:
#   GameWorld.tscn → node "EnemySpawner" → script sudah terpasang
#   via ext_resource di GameWorld.tscn (tidak perlu attach manual).
#
# JIKA MUSUH TIDAK MUNCUL, cek:
#   1. Autoload "GameManager" terdaftar di Project Settings
#   2. Node tree GameWorld sesuai: YSort ada, Systems ada
#   3. Semua scene .tscn ada di path yang benar
#   4. game_world.gd memanggil setup() di _ready()
# ============================================================

@export var arena_size: Vector2 = Vector2(800, 600)

const SCENE_POCONG    = preload("res://scenes/characters/Pocong.tscn")
const SCENE_BANASPATI = preload("res://scenes/characters/Banaspati.tscn")
const SCENE_GENDERUWO = preload("res://scenes/characters/Genderuwo.tscn")
const SCENE_LEAK      = preload("res://scenes/characters/Leak.tscn")

var enemy_balance:        Node  = null
var level_system:         Node  = null
var current_player_level: int   = 1
var spawn_timer:          float = 0.0
var spawn_interval:       float = 3.2
var is_boss_spawned:      bool  = false
var active_enemies:       Array = []

func _ready() -> void:
	print("[Spawner] Siap. Arena: ", arena_size)

func setup(eb: Node, ls: Node) -> void:
	enemy_balance = eb
	level_system  = ls
	print("[Spawner] setup() OK — EB:", eb != null, " LS:", ls != null)

func update_level(new_level: int) -> void:
	current_player_level = new_level
	if new_level < 15:
		spawn_interval = enemy_balance.get_spawn_interval(new_level)
	print("[Spawner] Level: ", new_level, " | Interval spawn: ", spawn_interval, "s")

# ── LOOP ───────────────────────────────────────────────────
func _process(delta: float) -> void:
	if not GameManager.is_playing(): return
	if is_boss_spawned: return
	if current_player_level >= 15: return
	if enemy_balance == null:
		push_warning("[Spawner] enemy_balance null! setup() belum dipanggil.")
		return

	spawn_timer += delta
	if spawn_timer >= spawn_interval:
		spawn_timer = 0.0
		_spawn_enemy()

# ── SPAWN MUSUH BIASA ──────────────────────────────────────
func _spawn_enemy() -> void:
	var enemy_type: int    = enemy_balance.pick_random_enemy(current_player_level)
	var stats: Dictionary  = enemy_balance.generate_enemy_stats(enemy_type, current_player_level)
	var scene: PackedScene = _get_scene(enemy_type)
	if scene == null:
		push_warning("[Spawner] scene null untuk tipe " + str(enemy_type))
		return

	var instance = scene.instantiate()
	instance.position = _random_spawn_pos()

	# Tambahkan ke GameWorld (parent Spawner)
	get_parent().add_child(instance)

	# Tunggu 1 frame agar @onready sudah resolved
	await get_tree().process_frame
	if not is_instance_valid(instance): return

	instance.setup(stats, enemy_type)
	instance.on_died.connect(_on_enemy_died)
	active_enemies.append(instance)
	_sync_enemy_list()

	print("[Spawner] Spawn %s | HP:%d DMG:%d" % [
		instance.name, stats.get("hp", 0), stats.get("damage", 0)
	])

# ── SPAWN BOSS ─────────────────────────────────────────────
func spawn_boss() -> void:
	if is_boss_spawned: return
	is_boss_spawned = true
	print("[Spawner] BOSS — Leak muncul!")

	var stats: Dictionary = enemy_balance.generate_enemy_stats(
		enemy_balance.EnemyType.LEAK, 15
	)
	var instance = SCENE_LEAK.instantiate()
	instance.position = Vector2(arena_size.x / 2.0, 80.0)
	get_parent().add_child(instance)

	await get_tree().process_frame
	if not is_instance_valid(instance): return

	instance.setup(stats, enemy_balance.EnemyType.LEAK)
	instance.on_died.connect(_on_boss_died)
	active_enemies.append(instance)
	_sync_enemy_list()

# ── CALLBACKS ──────────────────────────────────────────────
func _on_enemy_died(enemy_node: Node, enemy_type: int) -> void:
	active_enemies.erase(enemy_node)

	# Mark Necromancer → summon
	if is_instance_valid(enemy_node) and enemy_node.is_marked:
		var gw = get_parent()
		if gw.has_signal("request_summon_from_death"):
			gw.emit_signal("request_summon_from_death", enemy_node.global_position)

	enemy_balance.notify_enemy_killed(enemy_type, current_player_level)
	_sync_enemy_list()

func _on_boss_died(_node: Node, _type: int) -> void:
	print("[Spawner] Leak kalah! Game selesai.")
	GameManager.end_game(true)

# ── HELPERS ────────────────────────────────────────────────
func _sync_enemy_list() -> void:
	active_enemies = active_enemies.filter(func(e): return is_instance_valid(e))
	for p in get_tree().get_nodes_in_group("player"):
		p.enemies_in_scene = active_enemies

func _random_spawn_pos() -> Vector2:
	var m: float = 35.0
	match randi() % 4:
		0: return Vector2(randf_range(0, arena_size.x), -m)
		1: return Vector2(randf_range(0, arena_size.x), arena_size.y + m)
		2: return Vector2(-m, randf_range(0, arena_size.y))
		3: return Vector2(arena_size.x + m, randf_range(0, arena_size.y))
	return Vector2(arena_size.x / 2.0, -m)

func _get_scene(enemy_type: int) -> PackedScene:
	match enemy_type:
		0: return SCENE_POCONG      # EnemyType.POCONG
		1: return SCENE_BANASPATI   # EnemyType.BANASPATI
		2: return SCENE_GENDERUWO   # EnemyType.GENDERUWO
		_: return null
