extends Node2D

# ============================================================
# game_world.gd
# Inisialisasi semua sistem, hubungkan sinyal, kelola kamera
# ============================================================

const SCENE_PLAYER = preload("res://scenes/characters/Player.tscn")
const SCENE_SUMMON = preload("res://scenes/characters/SummonUnit.tscn")

const BASE_SUMMON_DAMAGE: int = 12
const BASE_SUMMON_HP:     int = 60

@onready var y_sort:          Node2D      = $YSort
@onready var enemy_spawner:   Node2D      = $EnemySpawner
@onready var camera:          Camera2D    = $Camera2D
@onready var hud:             CanvasLayer = $HUD
@onready var skill_choice_ui: Control     = $SkillChoiceUI

# Systems
@onready var level_system:  Node = $Systems/LevelSystem
@onready var stat_system:   Node = $Systems/StatSystem
@onready var skill_system:  Node = $Systems/SkillSystem
@onready var class_system:  Node = $Systems/ClassSystem
@onready var enemy_balance: Node = $Systems/EnemyBalance
@onready var damage_system: Node = $Systems/DamageSystem

var player_node: Node = null
var summon_list: Array = []

signal request_summon_from_death(spawn_pos: Vector2)

func _ready() -> void:
	# 1. Spawn player
	player_node = SCENE_PLAYER.instantiate()
	player_node.position = Vector2(400, 300)
	y_sort.add_child(player_node)

	# 2. Inject referensi sistem ke player
	player_node.class_system  = class_system
	player_node.skill_system  = skill_system
	player_node.damage_system = damage_system

	# 3. Init class sesuai pilihan di main menu
	class_system.init_class(GameManager.selected_class)

	# 4. Setup spawner
	if enemy_spawner.has_method("setup"):
		enemy_spawner.setup(enemy_balance, level_system)

	# 5. Sambungkan sinyal
	level_system.on_level_up.connect(_on_level_up)
	level_system.on_boss_trigger.connect(_on_boss_trigger)
	skill_system.on_skill_choices_ready.connect(_on_skill_choices_ready)
	enemy_balance.on_enemy_killed.connect(_on_enemy_killed)
	player_node.request_passive_summon.connect(_on_passive_summon_request)
	request_summon_from_death.connect(_on_summon_from_death)

	# 6. Inject ke HUD
	hud.class_system = class_system
	hud.skill_system = skill_system

	# 7. Kamera
	camera.global_position = player_node.global_position

func _process(_delta: float) -> void:
	if player_node and is_instance_valid(player_node):
		camera.global_position = player_node.global_position

# ─── LEVEL UP ──────────────────────────────────────────────
func _on_level_up(new_level: int) -> void:
	if enemy_spawner.has_method("update_level"):
		enemy_spawner.update_level(new_level)
	if hud.has_method("show_level_up_text"):
		hud.show_level_up_text(new_level)

# ─── BOSS TRIGGER ─────────────────────────────────────────
func _on_boss_trigger() -> void:
	if enemy_spawner.has_method("spawn_boss"):
		enemy_spawner.spawn_boss()

# ─── SKILL CHOICE ─────────────────────────────────────────
func _on_skill_choices_ready(choices: Array) -> void:
	if skill_choice_ui.has_method("show_choices"):
		skill_choice_ui.show_choices(choices, skill_system)

# ─── EXP DARI MUSUH ───────────────────────────────────────
func _on_enemy_killed(exp_reward: int) -> void:
	if exp_reward > 0:
		level_system.add_exp(exp_reward)

# ─── SUMMON PASIF ─────────────────────────────────────────
func _on_passive_summon_request() -> void:
	_try_spawn_summon(player_node.global_position + Vector2(60, 0))

# ─── SUMMON DARI MUSUH MATI ───────────────────────────────
func _on_summon_from_death(spawn_pos: Vector2) -> void:
	_try_spawn_summon(spawn_pos)

func _try_spawn_summon(pos: Vector2) -> void:
	var limit: int = stat_system.get_summon_limit()
	summon_list = summon_list.filter(func(s): return is_instance_valid(s))
	if summon_list.size() >= limit:
		return

	var dmg_pct: float = stat_system.get_stat("summon_damage_pct")
	var hp_pct:  float = stat_system.get_stat("summon_hp_pct")

	var summon = SCENE_SUMMON.instantiate()
	summon.position = pos
	y_sort.add_child(summon)

	if summon.has_method("setup"):
		summon.setup(BASE_SUMMON_DAMAGE, BASE_SUMMON_HP, dmg_pct, hp_pct)

	summon.owner_player = player_node
	summon_list.append(summon)
