extends Node

# ============================================================
# enemy_balance.gd  [DIREVISI — Hantu Nusantara v2]
#
# Tier 1 — POCONG     : melee biasa, cukup cepat, HP rendah
# Tier 2 — BANASPATI  : ranged bola api, HP sedang
# Tier 3 — GENDERUWO  : melee kuat, HP besar, lambat
# Boss   — LEAK       : boss final level 15
#
# Spawn progression:
#   Lv 1–4  : hanya Pocong
#   Lv 5–9  : Pocong + Banaspati mulai muncul
#   Lv 10–14: Banaspati + Genderuwo dominan
#   Lv 15   : Leak (boss)
# ============================================================

signal on_enemy_killed(exp_reward: int)

enum EnemyType {
	POCONG,      # 0 — melee tier 1
	BANASPATI,   # 1 — ranged tier 2
	GENDERUWO,   # 2 — melee tier 3
	LEAK,        # 3 — boss
}

# ─── BASE STAT ─────────────────────────────────────────────
# attack_range: jarak berhenti sebelum menyerang
# Banaspati berhenti lebih jauh (ranged), Pocong/Genderuwo dekat
const ENEMY_BASE: Dictionary = {
	EnemyType.POCONG: {
		"hp": 100, "damage": 15, "exp": 25,
		"speed": 80.0, "attack_range": 40.0,
		"is_ranged": false,
	},
	EnemyType.BANASPATI: {
		"hp": 60, "damage": 20, "exp": 38,
		"speed": 50.0, "attack_range": 170.0,   # berhenti jauh, tembak dari sana
		"is_ranged": true,
		"projectile_speed": 150.0,
	},
	EnemyType.GENDERUWO: {
		"hp": 130, "damage": 18, "exp": 55,
		"speed": 55.0, "attack_range": 52.0,
		"is_ranged": false,
	},
	EnemyType.LEAK: {
		"hp": 2500, "damage": 40, "exp": 0,
		"speed": 70.0, "attack_range": 85.0,
		"is_ranged": false,
	},
}

# ─── SPAWN TABLE ───────────────────────────────────────────
const SPAWN_TABLE: Dictionary = {
	1:  [
		EnemyType.POCONG,
		EnemyType.POCONG,
		EnemyType.POCONG,
	],
	5:  [
		EnemyType.POCONG,
		EnemyType.BANASPATI,
		EnemyType.BANASPATI,
	],
	10: [
		EnemyType.BANASPATI,
		EnemyType.GENDERUWO,
		EnemyType.GENDERUWO,
	],
	15: [EnemyType.LEAK],
}

# ─── SPAWN INTERVAL (detik) ────────────────────────────────
const SPAWN_INTERVALS: Dictionary = {
	1:  3.2,
	5:  2.5,
	10: 1.8,
	15: 0.0,
}

# ─── SCALING MULTIPLIER ────────────────────────────────────
func get_hp_multiplier(lv: int) -> float:
	if lv <= 4:   return 1.0 + (lv - 1) * 0.12
	elif lv <= 9: return 1.36 + (lv - 5) * 0.22
	else:         return 2.44 + (lv - 10) * 0.30

func get_damage_multiplier(lv: int) -> float:
	if lv <= 4:   return 1.0 + (lv - 1) * 0.08
	elif lv <= 9: return 1.24 + (lv - 5) * 0.12
	else:         return 1.84 + (lv - 10) * 0.18

func get_exp_multiplier(lv: int) -> float:
	if lv <= 4:   return 1.0
	elif lv <= 9: return 1.3
	else:         return 1.6

# ─── GENERATE STAT ─────────────────────────────────────────
func generate_enemy_stats(enemy_type: int, player_level: int) -> Dictionary:
	var base: Dictionary = ENEMY_BASE[enemy_type].duplicate(true)
	if enemy_type == EnemyType.LEAK:
		return base   # boss tidak di-scale
	base["hp"]     = int(ceil(base["hp"]     * get_hp_multiplier(player_level)))
	base["damage"] = int(ceil(base["damage"] * get_damage_multiplier(player_level)))
	base["exp"]    = int(ceil(base["exp"]    * get_exp_multiplier(player_level)))
	return base

# ─── HELPERS ───────────────────────────────────────────────
func get_spawn_table_for_level(lv: int) -> Array:
	var key: int = 1
	for k in SPAWN_TABLE.keys():
		if lv >= k: key = k
	return SPAWN_TABLE[key]

func get_spawn_interval(lv: int) -> float:
	var key: int = 1
	for k in SPAWN_INTERVALS.keys():
		if lv >= k and SPAWN_INTERVALS[k] > 0.0: key = k
	return SPAWN_INTERVALS[key]

func pick_random_enemy(lv: int) -> int:
	var table: Array = get_spawn_table_for_level(lv)
	return table[randi() % table.size()]

func notify_enemy_killed(enemy_type: int, player_level: int) -> void:
	if enemy_type == EnemyType.LEAK:
		emit_signal("on_enemy_killed", 0)
		return
	var stats: Dictionary = generate_enemy_stats(enemy_type, player_level)
	emit_signal("on_enemy_killed", stats["exp"])
