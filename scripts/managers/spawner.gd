extends Node2D

# ============================================================
# spawner.gd  [REVISI v2]
# - Musuh hanya spawn di tile "ground" TileMap
# - Menggunakan NavigationRegion2D / TileMap untuk validasi posisi
# ============================================================

@export var arena_size: Vector2 = Vector2(800, 600)

# Path ke TileMap ground — sesuaikan dengan scene tree kamu
# Contoh: jika TileMap ada di GameWorld > TileMap, path = "../TileMap"
@export var ground_tilemap_path: NodePath = NodePath("")

const SCENE_POCONG    = preload("res://scenes/characters/Pocong.tscn")
const SCENE_BANASPATI = preload("res://scenes/characters/Banaspati.tscn")
const SCENE_GENDERUWO = preload("res://scenes/characters/Genderuwo.tscn")
const SCENE_LEAK      = preload("res://scenes/characters/Leak.tscn")

var enemy_balance:        Node    = null
var level_system:         Node    = null
var ground_tilemap:       Node = null
var current_player_level: int     = 1
var spawn_timer:          float   = 0.0
var spawn_interval:       float   = 3.2
var is_boss_spawned:      bool    = false
var active_enemies:       Array   = []

# Layer index TileMap untuk "ground" — sesuaikan dengan project kamu
# Biasanya layer 0 adalah ground
const GROUND_LAYER_INDEX: int = 0

func _ready() -> void:
	print("[Spawner] Siap. Arena: ", arena_size)
	# Coba ambil TileMap dari path yang di-export
	if ground_tilemap_path != NodePath(""):
		ground_tilemap = get_node_or_null(ground_tilemap_path) as TileMap
	# Jika tidak di-set via export, cari otomatis dari parent
	if ground_tilemap == null:
		ground_tilemap = _find_ground_tilemap()
	if ground_tilemap:
		print("[Spawner] Ground TileMap ditemukan: ", ground_tilemap.name)
	else:
		push_warning("[Spawner] Ground TileMap tidak ditemukan! Spawn akan pakai posisi random biasa.")

func _find_ground_tilemap() -> Node:
	# Cari TileMap di parent (GameWorld)
	var parent = get_parent()
	if parent == null: return null
	for child in parent.get_children():
		if child is TileMapLayer and child.name == "Ground":
			return child
		if child is TileMap:
			return child
	return null

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

	var spawn_pos: Vector2 = _get_valid_spawn_pos()

	var instance = scene.instantiate()
	instance.position = spawn_pos

	get_parent().add_child(instance)

	await get_tree().process_frame
	if not is_instance_valid(instance): return

	instance.setup(stats, enemy_type)
	instance.on_died.connect(_on_enemy_died)
	active_enemies.append(instance)
	_sync_enemy_list()

	print("[Spawner] Spawn %s @ %s | HP:%d DMG:%d" % [
		instance.name, str(spawn_pos), stats.get("hp", 0), stats.get("damage", 0)
	])

# ── DAPATKAN POSISI SPAWN YANG VALID DI GROUND ─────────────
func _get_valid_spawn_pos() -> Vector2:
	# Coba cari posisi valid di ground tilemap sampai MAX_TRIES kali
	const MAX_TRIES: int = 20
	for _i in range(MAX_TRIES):
		var candidate: Vector2 = _random_spawn_pos()
		if _is_on_ground(candidate):
			return candidate
	# Fallback jika tidak ketemu posisi valid
	push_warning("[Spawner] Tidak menemukan posisi ground yang valid, pakai posisi random.")
	return _random_spawn_pos()

func _is_on_ground(world_pos: Vector2) -> bool:
	if ground_tilemap == null: return true  # Jika tidak ada TileMap, loloskan semua

	# Konversi posisi dunia ke koordinat tile
	if ground_tilemap is TileMapLayer:
		var layer_map := ground_tilemap as TileMapLayer
		var tile_pos: Vector2i = layer_map.local_to_map(layer_map.to_local(world_pos))
		var tile_data: TileData = layer_map.get_cell_tile_data(tile_pos)
		return tile_data != null
	if ground_tilemap is TileMap:
		var tile_map := ground_tilemap as TileMap
		var tile_pos: Vector2i = tile_map.local_to_map(tile_map.to_local(world_pos))
		var tile_data: TileData = tile_map.get_cell_tile_data(GROUND_LAYER_INDEX, tile_pos)
		return tile_data != null
	return true

func _random_spawn_pos() -> Vector2:
	var m: float = 50.0
	if randi() % 2 == 0:
		return Vector2(randf_range(100, arena_size.x - 100), -m)
	else:
		return Vector2(randf_range(100, arena_size.x - 100), arena_size.y + m)

func _get_random_ground_world_pos() -> Vector2:
	if ground_tilemap == null:
		return _random_spawn_pos()
	var cells: Array = []
	if ground_tilemap is TileMapLayer:
		cells = (ground_tilemap as TileMapLayer).get_used_cells()
	elif ground_tilemap is TileMap:
		cells = (ground_tilemap as TileMap).get_used_cells(GROUND_LAYER_INDEX)
	if cells.size() == 0:
		return _random_spawn_pos()
	var cell: Vector2i = cells[randi() % cells.size()]
	var local_pos: Vector2
	if ground_tilemap is TileMapLayer:
		local_pos = (ground_tilemap as TileMapLayer).map_to_local(cell)
	else:
		local_pos = (ground_tilemap as TileMap).map_to_local(cell)
	var tile_size: Vector2 = Vector2(64, 64)
	if ground_tilemap is TileMapLayer and (ground_tilemap as TileMapLayer).tile_set:
		tile_size = Vector2((ground_tilemap as TileMapLayer).tile_set.tile_size)
	elif ground_tilemap is TileMap and (ground_tilemap as TileMap).tile_set:
		tile_size = Vector2((ground_tilemap as TileMap).tile_set.tile_size)
	return ground_tilemap.to_global(local_pos + tile_size * 0.5)

# ── SPAWN BOSS ─────────────────────────────────────────────
func spawn_boss() -> void:
	if is_boss_spawned: return
	is_boss_spawned = true
	print("[Spawner] BOSS — Leak muncul!")

	var stats: Dictionary = enemy_balance.generate_enemy_stats(
		enemy_balance.EnemyType.LEAK, 15
	)
	var instance = SCENE_LEAK.instantiate()
	# Spawn boss di posisi random pada tile ground
	instance.position = _get_random_ground_world_pos()
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

	if is_instance_valid(enemy_node) and enemy_node.is_marked:
		var gw = get_parent()
		if gw.has_signal("request_convert_from_death"):
			var stats: Dictionary = {}
			if enemy_node.has_method("get_stats_snapshot"):
				stats = enemy_node.get_stats_snapshot()
			gw.emit_signal("request_convert_from_death", enemy_type, enemy_node.global_position, stats)

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

func _get_scene(enemy_type: int) -> PackedScene:
	match enemy_type:
		0: return SCENE_POCONG
		1: return SCENE_BANASPATI
		2: return SCENE_GENDERUWO
		_: return null
