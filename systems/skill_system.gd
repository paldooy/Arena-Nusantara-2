extends Node

# ============================================================
# skill_system.gd  [DIREVISI v3]
# - Awal game : TIDAK ada skill
# - Level 5   : pilih 1 dari 3 pilihan  → slot 1
# - Level 10  : pilih 1 dari 2 tersisa  → slot 2
# - Total max : 2 skill aktif
# ============================================================

signal on_skill_choices_ready(choices: Array)
signal on_skill_learned(skill_id: String)

enum CharacterClass { BERSERKER, NECROMANCER }

const SKILL_DATA: Dictionary = {
	# ── BERSERKER ──────────────────────────────────────────
	"berserker_spin": {
		"id": "berserker_spin", "name": "Whirlwind Slash",
		"description": "Berputar — serang semua musuh di sekitar (radius 100).",
		"cooldown": 5.0, "damage_mult": 1.2, "radius": 100.0,
	},
	"berserker_blood_aura": {
		"id": "berserker_blood_aura", "name": "Blood Aura",
		"description": "Aura merah: ATK +35% & Lifesteal 20% selama 6 detik.",
		"cooldown": 18.0, "buff_duration": 6.0, "atk_bonus_pct": 0.35, "lifesteal": 0.20,
	},
	"berserker_ground_smash": {
		"id": "berserker_ground_smash", "name": "Ground Smash",
		"description": "Hantam tanah — AOE radius 130, DMG x2.8, stun 1.5 detik.",
		"cooldown": 12.0, "damage_mult": 2.8, "radius": 130.0, "stun_duration": 1.5,
	},
	"berserker_warcry": {
		"id": "berserker_warcry", "name": "War Cry",
		"description": "Attack speed & move speed +40% selama 5 detik.",
		"cooldown": 15.0, "buff_duration": 5.0, "spd_bonus_pct": 0.40,
	},
	"berserker_charge": {
		"id": "berserker_charge", "name": "Berserker Charge",
		"description": "Melesat maju — hit musuh pertama, stun 2 detik + DMG x1.5.",
		"cooldown": 10.0, "damage_mult": 1.5, "stun_duration": 2.0, "charge_distance": 200.0,
	},
	# ── NECROMANCER ────────────────────────────────────────
	"necromancer_mark": {
		"id": "necromancer_mark", "name": "Soul Mark",
		"description": "Tandai musuh terdekat — jika mati, jadi summon kamu.",
		"cooldown": 3.0, "mark_duration": 15.0,
	},
	"necromancer_summon_buff": {
		"id": "necromancer_summon_buff", "name": "Dark Empowerment",
		"description": "Buff semua summon: DMG & HP +40% selama 8 detik.",
		"cooldown": 20.0, "buff_duration": 8.0, "buff_pct": 0.40,
	},
	"necromancer_dark_circle": {
		"id": "necromancer_dark_circle", "name": "Dark Circle",
		"description": "Ledakan AOE lingkaran (radius 90) — DMG x1.6.",
		"cooldown": 8.0, "damage_mult": 1.6, "radius": 90.0,
	},
	"necromancer_bone_shield": {
		"id": "necromancer_bone_shield", "name": "Bone Shield",
		"description": "Perisai tulang menyerap 20% max HP selama 10 detik.",
		"cooldown": 25.0, "buff_duration": 10.0, "shield_pct": 0.20,
	},
	"necromancer_death_nova": {
		"id": "necromancer_death_nova", "name": "Death Nova",
		"description": "Ledakan besar (radius 150) — musuh yang mati jadi summon.",
		"cooldown": 20.0, "damage_mult": 1.0, "radius": 150.0,
	},
}

const BERSERKER_FULL_POOL: Array = [
	"berserker_spin", "berserker_blood_aura", "berserker_ground_smash",
	"berserker_warcry", "berserker_charge",
]
const NECROMANCER_FULL_POOL: Array = [
	"necromancer_mark", "necromancer_summon_buff", "necromancer_dark_circle",
	"necromancer_bone_shield", "necromancer_death_nova",
]

var character_class: CharacterClass
var learned_skills:  Array[String] = []
var cooldowns:       Dictionary    = {}
var _lv5_offered:    Array         = []

func init(cls: CharacterClass) -> void:
	character_class = cls
	learned_skills.clear()
	cooldowns.clear()
	_lv5_offered.clear()

func on_level_reached(level: int) -> void:
	match level:
		5:  _offer_lv5()
		10: _offer_lv10()

func _get_full_pool() -> Array:
	match character_class:
		CharacterClass.BERSERKER:   return BERSERKER_FULL_POOL.duplicate()
		CharacterClass.NECROMANCER: return NECROMANCER_FULL_POOL.duplicate()
	return []

func _offer_lv5() -> void:
	var pool: Array = _get_full_pool()
	pool.shuffle()
	_lv5_offered = pool.slice(0, 3)
	emit_signal("on_skill_choices_ready", _lv5_offered.duplicate())

func _offer_lv10() -> void:
	var pool: Array = _get_full_pool()
	var chosen_lv5: String = learned_skills[0] if learned_skills.size() > 0 else ""
	# Kumpulkan yang tidak muncul di lv5 sama sekali
	var remaining: Array = []
	for sk in pool:
		if sk not in _lv5_offered:
			remaining.append(sk)
	# Kalau kurang dari 2, isi dari lv5 yang tidak dipilih
	for sk in _lv5_offered:
		if sk != chosen_lv5 and remaining.size() < 2:
			remaining.append(sk)
	remaining.shuffle()
	emit_signal("on_skill_choices_ready", remaining.slice(0, 2))

func player_chose_skill(skill_id: String) -> void:
	if skill_id in learned_skills: return
	if learned_skills.size() >= 2: return
	learned_skills.append(skill_id)
	cooldowns[skill_id] = 0.0
	emit_signal("on_skill_learned", skill_id)
	print("[SkillSystem] Dipelajari: ", SKILL_DATA[skill_id]["name"])

func _process(delta: float) -> void:
	for sid in cooldowns.keys():
		if cooldowns[sid] > 0.0:
			cooldowns[sid] = max(0.0, cooldowns[sid] - delta)

func can_use(skill_id: String) -> bool:
	return skill_id in learned_skills and cooldowns.get(skill_id, 0.0) <= 0.0

func use_skill(skill_id: String) -> bool:
	if not can_use(skill_id): return false
	cooldowns[skill_id] = SKILL_DATA[skill_id]["cooldown"]
	return true

func get_cooldown_ratio(skill_id: String) -> float:
	var max_cd: float = SKILL_DATA.get(skill_id, {}).get("cooldown", 1.0)
	if max_cd == 0.0: return 0.0
	return cooldowns.get(skill_id, 0.0) / max_cd

func get_learned_skills() -> Array[String]:
	return learned_skills

func get_skill_data(skill_id: String) -> Dictionary:
	return SKILL_DATA.get(skill_id, {})
