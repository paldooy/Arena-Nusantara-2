extends Node

# ============================================================
# stat_system.gd
# Auto-scaling stat karakter berdasarkan level
# ============================================================

enum CharacterClass { BERSERKER, NECROMANCER }

# ─── BASE STATS ───────────────────────────────────────────
const BERSERKER_BASE: Dictionary = {
	"hp":           220,
	"damage":       25,
	"attack_speed": 0.9,   # serangan per detik
	"crit_chance":  0.05,  # 5%
	"crit_mult":    1.5,
	"lifesteal":    0.0,
	"defense":      8,
}

const NECROMANCER_BASE: Dictionary = {
	"hp":            160,
	"damage":        18,
	"attack_speed":  1.1,
	"crit_chance":   0.03,
	"crit_mult":     1.4,
	"lifesteal":     0.0,
	"defense":       5,
	"summon_limit":  2,
	"summon_damage_pct": 1.0,  # multiplier (1.0 = 100%)
	"summon_hp_pct":     1.0,
}

# ─── GROWTH PER LEVEL ─────────────────────────────────────
const BERSERKER_GROWTH: Dictionary = {
	"hp":          20,
	"damage":       4,
	"crit_chance":  0.005,  # +0.5% per level
	"defense":      1,
}

const NECROMANCER_GROWTH: Dictionary = {
	"hp":               12,
	"damage":            3,
	"summon_damage_pct": 0.02,  # +2% per level
	"summon_hp_pct":     0.02,
}

# ─── STAT CAPS (anti-abuse) ────────────────────────────────
const BERSERKER_CAPS: Dictionary = {
	"lifesteal":   0.25,  # max 25% lifesteal dari skill
	"crit_chance": 0.60,  # max 60%
}

const NECROMANCER_CAPS: Dictionary = {
	"summon_limit": 6,
}

# ─── RUNTIME ──────────────────────────────────────────────
var character_class: CharacterClass
var stats: Dictionary = {}

func init(cls: CharacterClass) -> void:
	character_class = cls
	match cls:
		CharacterClass.BERSERKER:
			stats = BERSERKER_BASE.duplicate(true)
		CharacterClass.NECROMANCER:
			stats = NECROMANCER_BASE.duplicate(true)
	print("[StatSystem] Stats awal untuk ", CharacterClass.keys()[cls], ": ", stats)

func apply_level_up(new_level: int) -> void:
	# Dipanggil oleh level_system saat level naik
	var growth: Dictionary
	match character_class:
		CharacterClass.BERSERKER:
			growth = BERSERKER_GROWTH
		CharacterClass.NECROMANCER:
			growth = NECROMANCER_GROWTH

	for stat in growth.keys():
		if stats.has(stat):
			stats[stat] += growth[stat]

	# Terapkan cap
	_apply_caps()

	print("[StatSystem] Level ", new_level, " stats: ", stats)

func _apply_caps() -> void:
	var caps: Dictionary
	match character_class:
		CharacterClass.BERSERKER:
			caps = BERSERKER_CAPS
		CharacterClass.NECROMANCER:
			caps = NECROMANCER_CAPS

	for cap_stat in caps.keys():
		if stats.has(cap_stat):
			stats[cap_stat] = min(stats[cap_stat], caps[cap_stat])

# ─── SKILL BUFF MODIFIERS ─────────────────────────────────
# Dipanggil dari skill_system saat skill aktif

func apply_blood_aura(duration_timer: float) -> void:
	# Berserker skill 2: buff ATK + lifesteal sementara
	# Nilai sudah dibatasi oleh cap
	stats["damage"] *= 1.35          # +35% damage
	stats["lifesteal"] = min(0.20, BERSERKER_CAPS["lifesteal"])
	print("[StatSystem] Blood Aura aktif selama ", duration_timer, "s")

func remove_blood_aura() -> void:
	stats["damage"] /= 1.35
	stats["lifesteal"] = 0.0
	print("[StatSystem] Blood Aura berakhir")

func apply_summon_buff_pct(buff_pct: float) -> void:
	# Necromancer skill 2: buff summon sementara
	stats["summon_damage_pct"] += buff_pct
	stats["summon_hp_pct"] += buff_pct

func remove_summon_buff_pct(buff_pct: float) -> void:
	stats["summon_damage_pct"] -= buff_pct
	stats["summon_hp_pct"] -= buff_pct

# ─── GETTERS ──────────────────────────────────────────────
func get_stat(stat_name: String) -> float:
	return stats.get(stat_name, 0.0)

func get_max_hp() -> int:
	return int(stats.get("hp", 100))

func get_damage() -> int:
	return int(stats.get("damage", 10))

func get_attack_speed() -> float:
	return stats.get("attack_speed", 1.0)

func get_crit_roll() -> bool:
	return randf() < stats.get("crit_chance", 0.0)

func get_summon_limit() -> int:
	return int(stats.get("summon_limit", 2))

func compute_lifesteal_heal(damage_dealt: int) -> int:
	var ls: float = stats.get("lifesteal", 0.0)
	return int(damage_dealt * ls)
