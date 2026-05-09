extends Node

# ============================================================
# skill_system.gd
# Unlock skill di level tertentu, pilih skill, track cooldown
# ============================================================

signal on_skill_choices_ready(choices: Array)
signal on_skill_learned(skill_id: String)

enum CharacterClass { BERSERKER, NECROMANCER }

# ─── DEFINISI SKILL ───────────────────────────────────────
# Setiap skill punya: id, name, desc, cooldown (detik), damage_mult
const SKILL_DATA: Dictionary = {

	# ── BERSERKER ──────────────────────────────────────────
	"berserker_spin": {
		"id":          "berserker_spin",
		"name":        "Whirlwind Slash",
		"description": "Berputar dengan pedang besar, menyerang semua musuh di sekitar.",
		"cooldown":    5.0,
		"damage_mult": 1.2,
		"radius":      100.0,
		"unlock_level": 1,
	},
	"berserker_blood_aura": {
		"id":           "berserker_blood_aura",
		"name":         "Blood Aura",
		"description":  "Mendapatkan aura merah; ATK +35% dan lifesteal 20% selama 6 detik.",
		"cooldown":     18.0,
		"buff_duration": 6.0,
		"atk_bonus_pct": 0.35,
		"lifesteal":    0.20,
		"unlock_level": 5,
	},
	"berserker_ground_smash": {
		"id":           "berserker_ground_smash",
		"name":         "Ground Smash",
		"description":  "Memukul tanah keras, memberikan damage besar di area depan dan stun.",
		"cooldown":     12.0,
		"damage_mult":  2.8,
		"radius":       130.0,
		"stun_duration": 1.5,
		"unlock_level": 10,
	},

	# ── NECROMANCER ────────────────────────────────────────
	"necromancer_mark": {
		"id":           "necromancer_mark",
		"name":         "Soul Mark",
		"description":  "Menandai musuh. Musuh yang ditandai dan mati menjadi summon.",
		"cooldown":     3.0,
		"mark_duration": 15.0,
		"unlock_level": 1,
	},
	"necromancer_summon_buff": {
		"id":            "necromancer_summon_buff",
		"name":          "Dark Empowerment",
		"description":   "Memberi buff ke semua summon; DMG & HP +40% selama 8 detik.",
		"cooldown":      20.0,
		"buff_duration": 8.0,
		"buff_pct":      0.40,
		"unlock_level":  5,
	},
	"necromancer_dark_circle": {
		"id":           "necromancer_dark_circle",
		"name":         "Dark Circle",
		"description":  "Serangan area lingkaran kecil, memberikan damage ke musuh di dalamnya.",
		"cooldown":     8.0,
		"damage_mult":  1.6,
		"radius":       90.0,
		"unlock_level": 10,
	},
	"necromancer_passive": {
		"id":             "necromancer_passive",
		"name":           "Undead Ritual",
		"description":    "Secara pasif men-summon skeleton setiap 30 detik (maks sesuai summon_limit).",
		"passive":        true,
		"spawn_interval": 30.0,
		"unlock_level":   1,
	},
}

# ─── PILIHAN SKILL PER LEVEL ──────────────────────────────
# Key = level, value = array pilihan skill_id
const BERSERKER_UNLOCK_MAP: Dictionary = {
	5:  ["berserker_blood_aura", "berserker_ground_smash"],  # pilih salah satu
	10: [],  # otomatis dapat yang tersisa
}
const NECROMANCER_UNLOCK_MAP: Dictionary = {
	5:  ["necromancer_summon_buff", "necromancer_dark_circle"],
	10: [],
}

# ─── RUNTIME ──────────────────────────────────────────────
var character_class: CharacterClass
var learned_skills: Array[String] = []
var cooldowns: Dictionary = {}  # skill_id -> sisa cooldown (detik)

func init(cls: CharacterClass) -> void:
	character_class = cls
	learned_skills.clear()
	cooldowns.clear()

	# Skill level 1 otomatis
	match cls:
		CharacterClass.BERSERKER:
			learn_skill("berserker_spin")
		CharacterClass.NECROMANCER:
			learn_skill("necromancer_mark")
			learn_skill("necromancer_passive")

func learn_skill(skill_id: String) -> void:
	if skill_id not in learned_skills:
		learned_skills.append(skill_id)
		cooldowns[skill_id] = 0.0
		emit_signal("on_skill_learned", skill_id)
		print("[SkillSystem] Skill dipelajari: ", SKILL_DATA[skill_id]["name"])

func on_level_reached(level: int) -> void:
	var unlock_map: Dictionary
	match character_class:
		CharacterClass.BERSERKER:
			unlock_map = BERSERKER_UNLOCK_MAP
		CharacterClass.NECROMANCER:
			unlock_map = NECROMANCER_UNLOCK_MAP

	if not unlock_map.has(level):
		return

	var choices: Array = unlock_map[level]

	if choices.size() == 0:
		# Level 10: dapat skill yang belum dipilih secara otomatis
		_auto_unlock_remaining()
	else:
		# Level 5: tampilkan pilihan ke player
		emit_signal("on_skill_choices_ready", choices)

func player_chose_skill(skill_id: String) -> void:
	learn_skill(skill_id)

func _auto_unlock_remaining() -> void:
	var all_skills: Array
	match character_class:
		CharacterClass.BERSERKER:
			all_skills = ["berserker_blood_aura", "berserker_ground_smash"]
		CharacterClass.NECROMANCER:
			all_skills = ["necromancer_summon_buff", "necromancer_dark_circle"]

	for sk in all_skills:
		if sk not in learned_skills:
			learn_skill(sk)
			break

# ─── COOLDOWN TICK ────────────────────────────────────────
func _process(delta: float) -> void:
	for skill_id in cooldowns.keys():
		if cooldowns[skill_id] > 0.0:
			cooldowns[skill_id] = max(0.0, cooldowns[skill_id] - delta)

func can_use(skill_id: String) -> bool:
	return skill_id in learned_skills and cooldowns.get(skill_id, 0.0) <= 0.0

func use_skill(skill_id: String) -> bool:
	if not can_use(skill_id):
		return false
	var data: Dictionary = SKILL_DATA[skill_id]
	if data.get("passive", false):
		return false  # passive tidak di-trigger manual
	cooldowns[skill_id] = data["cooldown"]
	return true

func get_cooldown_ratio(skill_id: String) -> float:
	var data: Dictionary = SKILL_DATA.get(skill_id, {})
	var max_cd: float = data.get("cooldown", 1.0)
	return cooldowns.get(skill_id, 0.0) / max_cd

func get_learned_skills() -> Array[String]:
	return learned_skills

func get_skill_data(skill_id: String) -> Dictionary:
	return SKILL_DATA.get(skill_id, {})
