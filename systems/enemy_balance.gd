extends Node

# ============================================================
# enemy_balance.gd
# Scaling HP, damage, EXP, dan spawn rate musuh
# berdasarkan level player saat ini
# ============================================================

signal on_enemy_killed(exp_reward: int)

enum EnemyType {
	SLIME,       # musuh dasar, lambat
	GOBLIN,      # musuh cepat, damage sedikit lebih tinggi
	SKELETON,    # mid-tier, sedikit armor
	DARK_KNIGHT, # late-tier, tanky
	BOSS,        # boss final level 15
}

# ─── BASE STAT PER TIPE ───────────────────────────────────
const ENEMY_BASE: Dictionary = {
	EnemyType.SLIME: {
		"hp": 30, "damage": 4, "exp": 22,
		"speed": 60.0, "attack_range": 40.0,
	},
	EnemyType.GOBLIN: {
		"hp": 40, "damage": 6, "exp": 28,
		"speed": 90.0, "attack_range": 45.0,
	},
	EnemyType.SKELETON: {
		"hp": 55, "damage": 8, "exp": 35,
		"speed": 70.0, "attack_range": 50.0,
	},
	EnemyType.DARK_KNIGHT: {
		"hp": 90, "damage": 12, "exp": 50,
		"speed": 55.0, "attack_range": 55.0,
	},
	EnemyType.BOSS: {
		"hp": 2400, "damage": 35, "exp": 0,
		"speed": 65.0, "attack_range": 80.0,
	},
}

# ─── SPAWN TABLE PER FASE ────────────────────────────────
# key = level player, value = Array[EnemyType] yang bisa spawn
const SPAWN_TABLE: Dictionary = {
	1:  [EnemyType.SLIME, EnemyType.SLIME, EnemyType.GOBLIN],
	5:  [EnemyType.GOBLIN, EnemyType.SKELETON, EnemyType.SKELETON],
	10: [EnemyType.SKELETON, EnemyType.DARK_KNIGHT, EnemyType.DARK_KNIGHT],
	15: [EnemyType.BOSS],
}

# ─── SPAWN INTERVAL PER FASE (detik) ─────────────────────
const SPAWN_INTERVALS: Dictionary = {
	1:  3.5,  # early game - lebih longgar
	5:  2.5,  # mid game
	10: 1.8,  # late game - lebih padat
	15: 0.0,  # hanya boss, tidak ada spawn biasa
}

# ─── SCALING MULTIPLIER BERDASARKAN LEVEL ─────────────────
# HP & damage musuh tumbuh bertahap mengikuti level player
func get_hp_multiplier(player_level: int) -> float:
	# Fase early (1-4)
	if player_level <= 4:
		return 1.0 + (player_level - 1) * 0.10
	# Fase mid (5-9)
	elif player_level <= 9:
		return 1.5 + (player_level - 5) * 0.20
	# Fase late (10-14)
	else:
		return 2.5 + (player_level - 10) * 0.30

func get_damage_multiplier(player_level: int) -> float:
	if player_level <= 4:
		return 1.0 + (player_level - 1) * 0.08
	elif player_level <= 9:
		return 1.35 + (player_level - 5) * 0.12
	else:
		return 1.95 + (player_level - 10) * 0.18

func get_exp_multiplier(player_level: int) -> float:
	# EXP reward juga meningkat agar target waktu terjaga
	if player_level <= 4:
		return 1.0
	elif player_level <= 9:
		return 1.3
	else:
		return 1.6

# ─── GENERATE STAT MUSUH ─────────────────────────────────
func generate_enemy_stats(enemy_type: EnemyType, player_level: int) -> Dictionary:
	var base: Dictionary = ENEMY_BASE[enemy_type].duplicate()

	if enemy_type == EnemyType.BOSS:
		# Boss punya scaling khusus agar tetap menantang
		base["hp"]     = _scale_boss_hp(player_level)
		base["damage"] = _scale_boss_damage(player_level)
		return base

	var hp_mult:  float = get_hp_multiplier(player_level)
	var dmg_mult: float = get_damage_multiplier(player_level)
	var exp_mult: float = get_exp_multiplier(player_level)

	base["hp"]     = int(ceil(base["hp"]     * hp_mult))
	base["damage"] = int(ceil(base["damage"] * dmg_mult))
	base["exp"]    = int(ceil(base["exp"]    * exp_mult))

	return base

func _scale_boss_hp(player_level: int) -> int:
	# Boss harusnya mati dalam 2-4 menit, tapi tetap terasa berat
	# Level 15 player berserker punya ~80 damage per hit
	# Asumsi player hit ~30x dalam 3 menit = 2400 damage (tanpa skill)
	# Boss HP: 2400 base sudah cukup, tapi bisa naik sedikit berdasarkan waktu
	return 2400  # fixed, sudah dikalibrasi

func _scale_boss_damage(player_level: int) -> int:
	# Player max HP berserker ~500, necromancer ~320
	# Boss harus mematikan tapi bisa dihindari
	return 38  # ~7.6% HP berserker per hit, ~11.9% HP necromancer

# ─── HELPER UNTUK SPAWNER ────────────────────────────────
func get_spawn_table_for_level(player_level: int) -> Array:
	var result_key: int = 1
	for key in SPAWN_TABLE.keys():
		if player_level >= key:
			result_key = key
	return SPAWN_TABLE[result_key]

func get_spawn_interval(player_level: int) -> float:
	var result_key: int = 1
	for key in SPAWN_INTERVALS.keys():
		if player_level >= key and SPAWN_INTERVALS[key] > 0.0:
			result_key = key
	return SPAWN_INTERVALS[result_key]

func pick_random_enemy(player_level: int) -> EnemyType:
	var table: Array = get_spawn_table_for_level(player_level)
	return table[randi() % table.size()]

# ─── SIGNAL SAAT MUSUH MATI ──────────────────────────────
func notify_enemy_killed(enemy_type: EnemyType, player_level: int) -> void:
	if enemy_type == EnemyType.BOSS:
		emit_signal("on_enemy_killed", 0)  # boss tidak beri EXP
		return
	var stats: Dictionary = generate_enemy_stats(enemy_type, player_level)
	emit_signal("on_enemy_killed", stats["exp"])
