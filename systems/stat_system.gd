extends Node

# ============================================================
# stat_system.gd  [REVISI BESAR]
#
# Base stat dibuat SANGAT LEMAH di lv1 — progression lewat upgrade.
# Stat baru:
#   move_speed      — kecepatan gerak player (px/s)
#   attack_pct      — bonus damage % (1.0 = +0%, 1.20 = +20%)
#   cd_reduction    — pengurangan cooldown skill (0.0–0.50 max)
#   attack_range    — jangkauan basic attack (Necromancer)
#   splash_radius   — radius ledakan kecil setelah hit (Necromancer)
#   summon_hp_pct   — bonus HP summon
#   summon_limit    — jumlah maksimal summon
#
# Berserker: HP sangat rendah, DMG rendah, speed tinggi
# Necromancer: HP rendah, DMG sangat rendah, summon_limit awal 1
# ============================================================

enum CharacterClass { BERSERKER, NECROMANCER }

# ─── BASE STAT LEVEL 1 ─────────────────────────────────────
const BERSERKER_BASE: Dictionary = {
	"hp":           70,     # sangat rendah — naik lewat upgrade
	"damage":        25,     # rendah — naik lewat upgrade attack%
	"attack_speed":  1.3,
	"crit_chance":   0.1,  # 2% base
	"crit_mult":     1.4,   # 140% base
	"lifesteal":     0.1,
	"defense":       3,     # hampir nol
	"move_speed":  160.0,   # lebih cepat dari musuh (80–95)
	"attack_pct":    1.0,   # multiplier damage (1.0 = normal)
	"cd_reduction":  0.0,   # 0% pengurangan cooldown
}

const NECROMANCER_BASE: Dictionary = {
	"hp":                70,    # sangat rendah
	"damage":             20,    # sangat rendah
	"attack_speed":       1.1,
	"crit_chance":        0.02,
	"crit_mult":          1.3,
	"lifesteal":          0.0,
	"defense":            1,
	"move_speed":       135.0,  # lebih cepat dari musuh
	"attack_pct":         1.0,
	"cd_reduction":       0.0,
	"summon_limit":       1,    # awal hanya 1 summon
	"summon_damage_pct":  1.0,
	"summon_hp_pct":      1.0,
	"attack_range":     200.0,  # jangkauan klik musuh
	"splash_radius":     40.0,  # radius ledakan setelah hit
}

# ─── GROWTH PER LEVEL (auto) ───────────────────────────────
# Sedikit saja — sebagian besar naik dari upgrade manual
const BERSERKER_GROWTH: Dictionary = {
	"hp":        8,      # +8 per level → lv15 = 70 + 8×14 = 182
	"damage":    1,      # +1 per level → lv15 = 7 + 14 = 21
	"defense":   0,      # tidak naik otomatis, hanya dari upgrade
}

const NECROMANCER_GROWTH: Dictionary = {
	"hp":               6,     # +6 per level → lv15 = 70 + 6×14 = 154
	"damage":           1,     # +1 per level
	"summon_damage_pct":0.01,  # +1% per level
	"summon_hp_pct":    0.01,
}

# ─── CAPS ──────────────────────────────────────────────────
const BERSERKER_CAPS: Dictionary = {
	"lifesteal":    0.20,   # maks 20% lifesteal
	"crit_chance":  0.65,
	"cd_reduction": 0.50,   # maks 50% CD reduction
	"attack_pct":   3.0,    # maks 300% damage multiplier
}
const NECROMANCER_CAPS: Dictionary = {
	"summon_limit":  6,
	"cd_reduction":  0.50,
	"attack_pct":    3.0,
	"splash_radius": 120.0,
}

var character_class: CharacterClass
var stats: Dictionary = {}

func init(cls: CharacterClass) -> void:
	character_class = cls
	match cls:
		CharacterClass.BERSERKER:
			stats = BERSERKER_BASE.duplicate(true)
		CharacterClass.NECROMANCER:
			stats = NECROMANCER_BASE.duplicate(true)
	print("[StatSystem] Init stats: ", stats)

func apply_level_up(new_level: int) -> void:
	var growth: Dictionary
	match character_class:
		CharacterClass.BERSERKER:   growth = BERSERKER_GROWTH
		CharacterClass.NECROMANCER: growth = NECROMANCER_GROWTH
	for stat in growth.keys():
		if stats.has(stat):
			stats[stat] += growth[stat]
	_apply_caps()
	print("[StatSystem] Lv%d → HP:%d DMG:%d DEF:%d SPD:%.0f" % [
		new_level, stats.get("hp",0), stats.get("damage",0),
		stats.get("defense",0), stats.get("move_speed",0)])

func _apply_caps() -> void:
	var caps: Dictionary
	match character_class:
		CharacterClass.BERSERKER:   caps = BERSERKER_CAPS
		CharacterClass.NECROMANCER: caps = NECROMANCER_CAPS
	for k in caps.keys():
		if stats.has(k):
			stats[k] = min(stats[k], caps[k])

# ─── BLOOD AURA (Berserker skill) ──────────────────────────
func apply_blood_aura(_dur: float) -> void:
	stats["attack_pct"] *= 1.35
	stats["lifesteal"]   = min(0.20, BERSERKER_CAPS["lifesteal"])

func remove_blood_aura() -> void:
	stats["attack_pct"] /= 1.35
	stats["lifesteal"]   = 0.0

# ─── SUMMON BUFF (Necromancer skill) ───────────────────────
func apply_summon_buff_pct(pct: float) -> void:
	stats["summon_damage_pct"] += pct
	stats["summon_hp_pct"]     += pct

func remove_summon_buff_pct(pct: float) -> void:
	stats["summon_damage_pct"] -= pct
	stats["summon_hp_pct"]     -= pct

# ─── GETTERS ───────────────────────────────────────────────
func get_stat(k: String) -> float:     return stats.get(k, 0.0)
func get_max_hp() -> int:              return int(stats.get("hp", 70))
func get_damage() -> int:
	# Damage final = base_damage × attack_pct
	return int(stats.get("damage", 7) * stats.get("attack_pct", 1.0))
func get_attack_speed() -> float:      return stats.get("attack_speed", 1.0)
func get_move_speed() -> float:        return stats.get("move_speed", 130.0)
func get_crit_roll() -> bool:          return randf() < stats.get("crit_chance", 0.0)
func get_summon_limit() -> int:        return int(stats.get("summon_limit", 1))
func get_attack_range() -> float:      return stats.get("attack_range", 200.0)
func get_splash_radius() -> float:     return stats.get("splash_radius", 40.0)
func get_cd_multiplier() -> float:
	# Kembalikan multiplier cooldown: 1.0 = normal, 0.5 = 50% lebih cepat
	return max(0.5, 1.0 - stats.get("cd_reduction", 0.0))
func compute_lifesteal_heal(dmg: int) -> int:
	return int(dmg * stats.get("lifesteal", 0.0))
