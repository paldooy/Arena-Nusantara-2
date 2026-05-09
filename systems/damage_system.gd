extends Node

# ============================================================
# damage_system.gd
# Kalkulasi damage akhir, aplikasi lifesteal, dan crit
# ============================================================

signal on_damage_applied(target: Node, final_damage: int, is_crit: bool)
signal on_heal_applied(target: Node, heal_amount: int)

# ─── KALKULASI DAMAGE ─────────────────────────────────────

func calc_damage(
		base_damage:   int,
		crit_chance:   float,
		crit_mult:     float,
		target_defense: int = 0,
		damage_mult:   float = 1.0   # dari skill
) -> Dictionary:

	var raw: float = base_damage * damage_mult
	var is_crit: bool = randf() < crit_chance
	if is_crit:
		raw *= crit_mult

	# Defense: flat reduction, minimum 1 damage
	var final_dmg: int = max(1, int(raw) - target_defense)

	return {
		"damage":  final_dmg,
		"is_crit": is_crit,
	}

# ─── APPLY DAMAGE KE TARGET ───────────────────────────────
# target harus punya method take_damage(amount: int)
func apply_damage(
		attacker_stats: Dictionary,
		target: Node,
		skill_data: Dictionary = {},
		target_defense: int = 0
) -> int:

	var base:       int   = int(attacker_stats.get("damage", 10))
	var crit_c:     float = attacker_stats.get("crit_chance", 0.0)
	var crit_m:     float = attacker_stats.get("crit_mult",   1.5)
	var dmg_mult:   float = skill_data.get("damage_mult", 1.0)

	var result: Dictionary = calc_damage(base, crit_c, crit_m, target_defense, dmg_mult)
	var final_dmg: int     = result["damage"]
	var is_crit: bool      = result["is_crit"]

	if target.has_method("take_damage"):
		target.take_damage(final_dmg)

	emit_signal("on_damage_applied", target, final_dmg, is_crit)

	return final_dmg

# ─── LIFESTEAL ─────────────────────────────────────────────
func apply_lifesteal(attacker: Node, damage_dealt: int, lifesteal: float) -> void:
	if lifesteal <= 0.0:
		return
	var heal_amount: int = int(damage_dealt * lifesteal)
	if heal_amount > 0 and attacker.has_method("heal"):
		attacker.heal(heal_amount)
		emit_signal("on_heal_applied", attacker, heal_amount)

# ─── AOE DAMAGE ────────────────────────────────────────────
# Untuk skill Whirlwind, Ground Smash, Dark Circle
func apply_aoe_damage(
		attacker_stats: Dictionary,
		center_pos:     Vector2,
		radius:         float,
		enemies:        Array,       # Array[Node]
		skill_data:     Dictionary = {},
		max_targets:    int = 999
) -> void:

	var hit_count: int = 0
	for enemy in enemies:
		if hit_count >= max_targets:
			break
		if not enemy.has_method("take_damage"):
			continue
		var enemy_pos: Vector2 = enemy.global_position
		if center_pos.distance_to(enemy_pos) <= radius:
			var defense: int = enemy.get("defense") if enemy.get("defense") != null else 0
			var dmg: int     = apply_damage(attacker_stats, enemy, skill_data, defense)
			hit_count += 1

	print("[DamageSystem] AOE hit ", hit_count, " enemies")

# ─── DAMAGE SUMMON ────────────────────────────────────────
# Kalkulasi damage untuk unit summon necromancer
func calc_summon_damage(
		base_summon_damage: int,
		summon_damage_pct:  float  # dari stat_system
) -> int:
	return max(1, int(base_summon_damage * summon_damage_pct))

# ─── UTILITY ──────────────────────────────────────────────
func format_damage_text(amount: int, is_crit: bool) -> String:
	if is_crit:
		return "CRIT! " + str(amount)
	return str(amount)
