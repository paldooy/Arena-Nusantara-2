extends Node

# ============================================================
# stat_upgrade_system.gd  [BARU]
# Mengelola upgrade stat manual tiap level up.
# Player memilih 1 dari 3 pilihan kartu upgrade.
# Setiap stat punya 3 tingkat (I, II, III) dengan bonus makin besar.
# ============================================================

signal on_upgrade_choices_ready(choices: Array)   # emit ke UI
signal on_upgrade_applied(upgrade_id: String)

enum CharacterClass { BERSERKER, NECROMANCER }

# ─── DEFINISI SEMUA UPGRADE ──────────────────────────────────
# Setiap upgrade punya: id, stat yang diubah, nilai bonus, tier (1/2/3)
# Upgrade bertingkat: player harus ambil tier I sebelum bisa tier II, dst.
const UPGRADE_DATA: Dictionary = {

	# ── BERSERKER UPGRADES ─────────────────────────────────
	"berserker_lifesteal_1": {
		"id": "berserker_lifesteal_1", "tier": 1,
		"name": "Lifesteal I",
		"description": "Setiap serangan memulihkan 5% damage sebagai HP.",
		"stat": "lifesteal", "value": 0.05,
		"class": "BERSERKER", "requires": "",
	},
	"berserker_lifesteal_2": {
		"id": "berserker_lifesteal_2", "tier": 2,
		"name": "Lifesteal II",
		"description": "Lifesteal meningkat jadi 12% (tambah 7%).",
		"stat": "lifesteal", "value": 0.07,
		"class": "BERSERKER", "requires": "berserker_lifesteal_1",
	},
	"berserker_lifesteal_3": {
		"id": "berserker_lifesteal_3", "tier": 3,
		"name": "Lifesteal III",
		"description": "Lifesteal meningkat jadi 22% (tambah 10%).",
		"stat": "lifesteal", "value": 0.10,
		"class": "BERSERKER", "requires": "berserker_lifesteal_2",
	},

	"berserker_defense_1": {
		"id": "berserker_defense_1", "tier": 1,
		"name": "Defense I",
		"description": "Menambah 5 Defense (kurangi damage masuk 5 flat).",
		"stat": "defense", "value": 5,
		"class": "BERSERKER", "requires": "",
	},
	"berserker_defense_2": {
		"id": "berserker_defense_2", "tier": 2,
		"name": "Defense II",
		"description": "Menambah 8 Defense lagi (total +13 dari upgrade).",
		"stat": "defense", "value": 8,
		"class": "BERSERKER", "requires": "berserker_defense_1",
	},
	"berserker_defense_3": {
		"id": "berserker_defense_3", "tier": 3,
		"name": "Defense III",
		"description": "Menambah 12 Defense lagi (total +25 dari upgrade).",
		"stat": "defense", "value": 12,
		"class": "BERSERKER", "requires": "berserker_defense_2",
	},

	"berserker_crit_1": {
		"id": "berserker_crit_1", "tier": 1,
		"name": "Critical I",
		"description": "Crit Chance +5% (menjadi 10%).",
		"stat": "crit_chance", "value": 0.05,
		"class": "BERSERKER", "requires": "",
	},
	"berserker_crit_2": {
		"id": "berserker_crit_2", "tier": 2,
		"name": "Critical II",
		"description": "Crit Chance +7% (menjadi 17%).",
		"stat": "crit_chance", "value": 0.07,
		"class": "BERSERKER", "requires": "berserker_crit_1",
	},
	"berserker_crit_3": {
		"id": "berserker_crit_3", "tier": 3,
		"name": "Critical III",
		"description": "Crit Chance +10% (menjadi 27%).",
		"stat": "crit_chance", "value": 0.10,
		"class": "BERSERKER", "requires": "berserker_crit_2",
	},

	"berserker_damage_1": {
		"id": "berserker_damage_1", "tier": 1,
		"name": "Brute Force I",
		"description": "Base Damage +8.",
		"stat": "damage", "value": 8,
		"class": "BERSERKER", "requires": "",
	},
	"berserker_damage_2": {
		"id": "berserker_damage_2", "tier": 2,
		"name": "Brute Force II",
		"description": "Base Damage +12.",
		"stat": "damage", "value": 12,
		"class": "BERSERKER", "requires": "berserker_damage_1",
	},
	"berserker_damage_3": {
		"id": "berserker_damage_3", "tier": 3,
		"name": "Brute Force III",
		"description": "Base Damage +18.",
		"stat": "damage", "value": 18,
		"class": "BERSERKER", "requires": "berserker_damage_2",
	},

	# ── NECROMANCER UPGRADES ───────────────────────────────
	"necro_summon_limit_1": {
		"id": "necro_summon_limit_1", "tier": 1,
		"name": "Raise Dead I",
		"description": "Batas summon +1 (menjadi 3).",
		"stat": "summon_limit", "value": 1,
		"class": "NECROMANCER", "requires": "",
	},
	"necro_summon_limit_2": {
		"id": "necro_summon_limit_2", "tier": 2,
		"name": "Raise Dead II",
		"description": "Batas summon +1 lagi (menjadi 4).",
		"stat": "summon_limit", "value": 1,
		"class": "NECROMANCER", "requires": "necro_summon_limit_1",
	},
	"necro_summon_limit_3": {
		"id": "necro_summon_limit_3", "tier": 3,
		"name": "Raise Dead III",
		"description": "Batas summon +2 lagi (menjadi 6). Maks!",
		"stat": "summon_limit", "value": 2,
		"class": "NECROMANCER", "requires": "necro_summon_limit_2",
	},

	"necro_summon_dmg_1": {
		"id": "necro_summon_dmg_1", "tier": 1,
		"name": "Bone Shatter I",
		"description": "Damage summon +10%.",
		"stat": "summon_damage_pct", "value": 0.10,
		"class": "NECROMANCER", "requires": "",
	},
	"necro_summon_dmg_2": {
		"id": "necro_summon_dmg_2", "tier": 2,
		"name": "Bone Shatter II",
		"description": "Damage summon +15% lagi.",
		"stat": "summon_damage_pct", "value": 0.15,
		"class": "NECROMANCER", "requires": "necro_summon_dmg_1",
	},
	"necro_summon_dmg_3": {
		"id": "necro_summon_dmg_3", "tier": 3,
		"name": "Bone Shatter III",
		"description": "Damage summon +20% lagi.",
		"stat": "summon_damage_pct", "value": 0.20,
		"class": "NECROMANCER", "requires": "necro_summon_dmg_2",
	},

	"necro_defense_1": {
		"id": "necro_defense_1", "tier": 1,
		"name": "Dark Ward I",
		"description": "Defense +4 (pengurangan damage flat).",
		"stat": "defense", "value": 4,
		"class": "NECROMANCER", "requires": "",
	},
	"necro_defense_2": {
		"id": "necro_defense_2", "tier": 2,
		"name": "Dark Ward II",
		"description": "Defense +6 lagi.",
		"stat": "defense", "value": 6,
		"class": "NECROMANCER", "requires": "necro_defense_1",
	},
	"necro_defense_3": {
		"id": "necro_defense_3", "tier": 3,
		"name": "Dark Ward III",
		"description": "Defense +10 lagi.",
		"stat": "defense", "value": 10,
		"class": "NECROMANCER", "requires": "necro_defense_2",
	},

	"necro_hp_1": {
		"id": "necro_hp_1", "tier": 1,
		"name": "Soul Vessel I",
		"description": "Max HP +30.",
		"stat": "hp", "value": 30,
		"class": "NECROMANCER", "requires": "",
	},
	"necro_hp_2": {
		"id": "necro_hp_2", "tier": 2,
		"name": "Soul Vessel II",
		"description": "Max HP +45.",
		"stat": "hp", "value": 45,
		"class": "NECROMANCER", "requires": "necro_hp_1",
	},
	"necro_hp_3": {
		"id": "necro_hp_3", "tier": 3,
		"name": "Soul Vessel III",
		"description": "Max HP +60.",
		"stat": "hp", "value": 60,
		"class": "NECROMANCER", "requires": "necro_hp_2",
	},
}

# ─── POOL UPGRADE PER CLASS ──────────────────────────────────
const BERSERKER_POOL: Array = [
	"berserker_lifesteal_1", "berserker_lifesteal_2", "berserker_lifesteal_3",
	"berserker_defense_1",   "berserker_defense_2",   "berserker_defense_3",
	"berserker_crit_1",      "berserker_crit_2",      "berserker_crit_3",
	"berserker_damage_1",    "berserker_damage_2",    "berserker_damage_3",
]
const NECROMANCER_POOL: Array = [
	"necro_summon_limit_1", "necro_summon_limit_2", "necro_summon_limit_3",
	"necro_summon_dmg_1",   "necro_summon_dmg_2",   "necro_summon_dmg_3",
	"necro_defense_1",      "necro_defense_2",       "necro_defense_3",
	"necro_hp_1",           "necro_hp_2",            "necro_hp_3",
]

# ─── RUNTIME ─────────────────────────────────────────────────
var character_class: CharacterClass
var taken_upgrades: Array[String] = []  # upgrade yang sudah diambil
var stat_system: Node = null            # referensi diisi class_system

func init(cls: CharacterClass, stat_sys: Node) -> void:
	character_class = cls
	taken_upgrades.clear()
	stat_system = stat_sys

# Dipanggil tiap level up — generate 3 pilihan acak yang valid
func generate_choices() -> void:
	var pool: Array = _get_available_upgrades()
	pool.shuffle()
	var choices: Array = pool.slice(0, min(3, pool.size()))
	emit_signal("on_upgrade_choices_ready", choices)

func _get_available_upgrades() -> Array:
	var source_pool: Array
	match character_class:
		CharacterClass.BERSERKER:   source_pool = BERSERKER_POOL
		CharacterClass.NECROMANCER: source_pool = NECROMANCER_POOL

	var available: Array = []
	for upg_id in source_pool:
		if upg_id in taken_upgrades:
			continue  # sudah diambil
		var data: Dictionary = UPGRADE_DATA[upg_id]
		var req: String = data.get("requires", "")
		if req == "" or req in taken_upgrades:
			available.append(upg_id)  # tersedia: belum diambil & syarat terpenuhi
	return available

func apply_upgrade(upgrade_id: String) -> void:
	if upgrade_id in taken_upgrades:
		return
	if stat_system == null:
		return

	var data: Dictionary = UPGRADE_DATA[upgrade_id]
	var stat_key: String = data["stat"]
	var value = data["value"]

	# Tambahkan ke stat langsung
	if stat_system.stats.has(stat_key):
		stat_system.stats[stat_key] += value

	taken_upgrades.append(upgrade_id)
	emit_signal("on_upgrade_applied", upgrade_id)
	print("[UpgradeSystem] Upgrade diambil: ", data["name"], " | ", stat_key, " += ", value)

func get_upgrade_data(upgrade_id: String) -> Dictionary:
	return UPGRADE_DATA.get(upgrade_id, {})

func has_taken(upgrade_id: String) -> bool:
	return upgrade_id in taken_upgrades
