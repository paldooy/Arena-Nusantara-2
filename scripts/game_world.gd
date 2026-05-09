extends Node2D

# ============================================================
# game_world.gd  [DIREVISI]
# - Spawn player sesuai class (Berserker.tscn / Necromancer.tscn)
# - Sambungkan StatUpgradeUI (tiap level up)
# - Sambungkan SkillChoiceUI (level 5 & 10)
# - Urutan popup: upgrade stat dulu → lalu skill (jika level 5/10)
# ============================================================

const SCENE_BERSERKER   = preload("res://scenes/characters/Berserker.tscn")
const SCENE_NECROMANCER = preload("res://scenes/characters/Necromancer.tscn")
const SCENE_SUMMON_UNIT = preload("res://scenes/characters/SummonUnit.tscn")

const BASE_SUMMON_DAMAGE: int = 12
const BASE_SUMMON_HP: int     = 60

@onready var y_sort:            Node2D      = $YSort
@onready var enemy_spawner:     Node2D      = $EnemySpawner
@onready var camera:            Camera2D    = $Camera2D
@onready var hud:               CanvasLayer = $HUD
@onready var skill_choice_ui:   Control     = $SkillChoiceUI
@onready var stat_upgrade_ui:   Control     = $StatUpgradeUI   # ← BARU

# Systems
@onready var level_system:        Node = $Systems/LevelSystem
@onready var stat_system:         Node = $Systems/StatSystem
@onready var skill_system:        Node = $Systems/SkillSystem
@onready var class_system:        Node = $Systems/ClassSystem
@onready var enemy_balance:       Node = $Systems/EnemyBalance
@onready var damage_system:       Node = $Systems/DamageSystem
@onready var stat_upgrade_system: Node = $Systems/StatUpgradeSystem  # ← BARU

var player_node: Node = null
var summon_list: Array = []

# Antrian popup — upgrade stat dulu, lalu skill jika ada
var _pending_skill_choices: Array = []
var _upgrade_popup_open: bool = false

signal request_summon_from_death(spawn_pos: Vector2)

func _ready() -> void:
	# 1. Spawn player sesuai class yang dipilih
	var player_scene: PackedScene
	match GameManager.selected_class:
		GameManager.CharacterClass.BERSERKER:
			player_scene = SCENE_BERSERKER
		GameManager.CharacterClass.NECROMANCER:
			player_scene = SCENE_NECROMANCER

	player_node = player_scene.instantiate()
	player_node.position = Vector2(400, 300)
	y_sort.add_child(player_node)

	# 2. Inject referensi sistem ke player
	player_node.class_system  = class_system
	player_node.skill_system  = skill_system
	player_node.damage_system = damage_system

	# 3. Init class system
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

	# 6. Sambungkan StatUpgradeSystem ke UI
	stat_upgrade_system.on_upgrade_choices_ready.connect(_on_upgrade_choices_ready)
	stat_upgrade_ui.upgrade_confirmed.connect(_on_upgrade_confirmed)   # ← setelah upgrade, cek apakah ada skill pending

	# 7. Inject referensi ke HUD
	hud.class_system  = class_system
	hud.skill_system  = skill_system

	camera.position = player_node.position

func _process(_delta: float) -> void:
	if player_node:
		camera.global_position = player_node.global_position

# ─── LEVEL UP ───────────────────────────────────────────────
func _on_level_up(new_level: int) -> void:
	if enemy_spawner.has_method("update_level"):
		enemy_spawner.update_level(new_level)
	hud.show_level_up_text(new_level)
	# Popup upgrade stat dipicu oleh stat_upgrade_system.generate_choices()
	# yang sudah dipanggil dari class_system._on_level_up()

# ─── UPGRADE STAT CHOICES ───────────────────────────────────
func _on_upgrade_choices_ready(choices: Array) -> void:
	_upgrade_popup_open = true
	stat_upgrade_ui.show_upgrades(choices, stat_upgrade_system)

func _on_upgrade_confirmed(_upgrade_id: String) -> void:
	_upgrade_popup_open = false
	# Jika ada pilihan skill tertunda (level 5 atau 10), tampilkan sekarang
	if _pending_skill_choices.size() > 0:
		var pending: Array = _pending_skill_choices
		_pending_skill_choices = []
		skill_choice_ui.show_choices(pending, skill_system)

# ─── SKILL CHOICES ──────────────────────────────────────────
func _on_skill_choices_ready(choices: Array) -> void:
	if _upgrade_popup_open:
		# Tunda sampai upgrade stat selesai dipilih
		_pending_skill_choices = choices
	else:
		skill_choice_ui.show_choices(choices, skill_system)

# ─── BOSS ────────────────────────────────────────────────────
func _on_boss_trigger() -> void:
	if enemy_spawner.has_method("spawn_boss"):
		enemy_spawner.spawn_boss()

# ─── EXP ────────────────────────────────────────────────────
func _on_enemy_killed(exp_reward: int) -> void:
	if exp_reward > 0:
		level_system.add_exp(exp_reward)

# ─── SUMMON ──────────────────────────────────────────────────
func _on_passive_summon_request() -> void:
	_try_spawn_summon(player_node.global_position + Vector2(60, 0))

func _on_summon_from_death(spawn_pos: Vector2) -> void:
	_try_spawn_summon(spawn_pos)

func _try_spawn_summon(pos: Vector2) -> void:
	var limit: int = stat_system.get_summon_limit()
	summon_list = summon_list.filter(func(s): return is_instance_valid(s))
	if summon_list.size() >= limit:
		return

	var dmg_pct: float = stat_system.get_stat("summon_damage_pct")
	var hp_pct:  float = stat_system.get_stat("summon_hp_pct")

	var summon = SCENE_SUMMON_UNIT.instantiate()
	summon.position = pos
	y_sort.add_child(summon)
	if summon.has_method("setup"):
		summon.setup(BASE_SUMMON_DAMAGE, BASE_SUMMON_HP, dmg_pct, hp_pct)
	summon.owner_player = player_node
	summon_list.append(summon)
