extends Node2D

# ============================================================
# game_world.gd  [FIX — urutan inisialisasi diperbaiki]
#
# BUG SEBELUMNYA:
#   init_class() dipanggil di step 3, sedangkan sinyal
#   stat_upgrade_system baru disambungkan di step 6.
#   Akibatnya: generate_choices() emit sinyal, tapi listener
#   belum terpasang → popup tidak pernah muncul.
#
# FIX:
#   Connect SEMUA sinyal terlebih dahulu (step 3),
#   BARU panggil init_class() (step 4).
# ============================================================

const SCENE_BERSERKER   = preload("res://scenes/characters/Berserker.tscn")
const SCENE_NECROMANCER = preload("res://scenes/characters/Necromancer.tscn")
const SCENE_SUMMON_UNIT = preload("res://scenes/characters/SummonUnit.tscn")

const BASE_SUMMON_DAMAGE: int = 12
const BASE_SUMMON_HP:     int = 60

@onready var y_sort:            Node2D      = $YSort
@onready var enemy_spawner:     Node2D      = $EnemySpawner
@onready var camera:            Camera2D    = $Camera2D
@onready var hud:               CanvasLayer = $HUD
@onready var stat_upgrade_ui:   CanvasLayer = $StatUpgradeUI
@onready var skill_choice_ui:   CanvasLayer = $SkillChoiceUI

@onready var level_system:        Node = $Systems/LevelSystem
@onready var stat_system:         Node = $Systems/StatSystem
@onready var skill_system:        Node = $Systems/SkillSystem
@onready var class_system:        Node = $Systems/ClassSystem
@onready var enemy_balance:       Node = $Systems/EnemyBalance
@onready var damage_system:       Node = $Systems/DamageSystem
@onready var stat_upgrade_system: Node = $Systems/StatUpgradeSystem

var player_node: Node  = null
var summon_list:  Array = []

# Antrian: jika skill unlock datang saat popup upgrade masih terbuka
var _pending_skill_choices: Array = []
var _upgrade_popup_open:    bool  = false

signal request_summon_from_death(spawn_pos: Vector2)

func _ready() -> void:
	# ── Step 1: Spawn player ────────────────────────────────
	var player_scene: PackedScene = SCENE_BERSERKER
	if GameManager.selected_class == GameManager.CharacterClass.NECROMANCER:
		player_scene = SCENE_NECROMANCER

	player_node          = player_scene.instantiate()
	player_node.position = Vector2(400, 300)
	y_sort.add_child(player_node)

	# ── Step 2: Inject referensi sistem ke player ───────────
	player_node.class_system  = class_system
	player_node.skill_system  = skill_system
	player_node.damage_system = damage_system

	# ── Step 3: Connect SEMUA sinyal dulu ───────────────────
	# (harus sebelum init_class() agar tidak ada sinyal yang terlewat)

	# Level system
	level_system.on_level_up.connect(_on_level_up)
	level_system.on_boss_trigger.connect(_on_boss_trigger)

	# Skill system → UI pilih skill
	skill_system.on_skill_choices_ready.connect(_on_skill_choices_ready)

	# StatUpgradeSystem → UI pilih upgrade stat  ← INI YANG SEBELUMNYA TELAT
	stat_upgrade_system.on_upgrade_choices_ready.connect(_on_upgrade_choices_ready)
	stat_upgrade_ui.upgrade_confirmed.connect(_on_upgrade_confirmed)

	# EXP dari musuh mati
	enemy_balance.on_enemy_killed.connect(_on_enemy_killed)

	# Sinyal dari player
	player_node.request_passive_summon.connect(_on_passive_summon_request)
	request_summon_from_death.connect(_on_summon_from_death)

	# ── Step 4: Init class SETELAH semua sinyal terpasang ───
	class_system.init_class(GameManager.selected_class)

	# ── Step 5: Setup spawner ───────────────────────────────
	if enemy_spawner.has_method("setup"):
		enemy_spawner.setup(enemy_balance, level_system)

	# ── Step 6: Inject ke HUD ───────────────────────────────
	hud.class_system = class_system
	hud.skill_system = skill_system

	camera.position = player_node.position
	print("[GameWorld] Init selesai. Class: ", GameManager.selected_class)

func _process(_delta: float) -> void:
	if not GameManager.is_playing(): return
	if player_node:
		camera.global_position = player_node.global_position

# ─── LEVEL UP ──────────────────────────────────────────────
func _on_level_up(new_level: int) -> void:
	if enemy_spawner.has_method("update_level"):
		enemy_spawner.update_level(new_level)
	hud.show_level_up_text(new_level)
	# generate_choices() sudah dipanggil dari class_system._on_level_up()
	# → sinyal on_upgrade_choices_ready → _on_upgrade_choices_ready() di bawah

# ─── POPUP UPGRADE STAT ────────────────────────────────────
func _on_upgrade_choices_ready(choices: Array) -> void:
	_upgrade_popup_open = true
	stat_upgrade_ui.show_upgrades(choices, stat_upgrade_system)

func _on_upgrade_confirmed(_upgrade_id: String) -> void:
	_upgrade_popup_open = false
	# Kalau ada pilihan skill yang pending (level 5 atau 10),
	# tampilkan sekarang setelah upgrade stat selesai
	if _pending_skill_choices.size() > 0:
		var pending: Array = _pending_skill_choices.duplicate()
		_pending_skill_choices.clear()
		skill_choice_ui.show_choices(pending, skill_system)

# ─── POPUP PILIH SKILL ─────────────────────────────────────
func _on_skill_choices_ready(choices: Array) -> void:
	if _upgrade_popup_open:
		# Tunda — tunggu sampai popup upgrade stat ditutup
		_pending_skill_choices = choices.duplicate()
	else:
		skill_choice_ui.show_choices(choices, skill_system)

# ─── BOSS ──────────────────────────────────────────────────
func _on_boss_trigger() -> void:
	if enemy_spawner.has_method("spawn_boss"):
		enemy_spawner.spawn_boss()

# ─── EXP ───────────────────────────────────────────────────
func _on_enemy_killed(exp_reward: int) -> void:
	if exp_reward > 0:
		level_system.add_exp(exp_reward)

# ─── SUMMON ────────────────────────────────────────────────
func _on_passive_summon_request() -> void:
	_try_spawn_summon(player_node.global_position + Vector2(60, 0))

func _on_summon_from_death(spawn_pos: Vector2) -> void:
	_try_spawn_summon(spawn_pos)

func _try_spawn_summon(pos: Vector2) -> void:
	var limit: int = stat_system.get_summon_limit()
	summon_list = summon_list.filter(func(s): return is_instance_valid(s))
	if summon_list.size() >= limit: return

	var dmg_pct: float = stat_system.get_stat("summon_damage_pct")
	var hp_pct:  float = stat_system.get_stat("summon_hp_pct")

	var summon = SCENE_SUMMON_UNIT.instantiate()
	summon.position = pos
	y_sort.add_child(summon)
	if summon.has_method("setup"):
		summon.setup(BASE_SUMMON_DAMAGE, BASE_SUMMON_HP, dmg_pct, hp_pct)
	summon.owner_player = player_node
	summon_list.append(summon)
