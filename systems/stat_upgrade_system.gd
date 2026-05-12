extends Node

# ============================================================
# stat_upgrade_system.gd  [REVISI BESAR]
#
# Tier I → II → III → ★ (star/IV), harus urut.
# Nilai bonus kecil per tier agar tidak OP, akumulasinya terasa.
#
# BERSERKER (8 kategori):
#   defense, attack%, lifesteal, crit_chance, crit_dmg,
#   move_speed, health%, cd_reduction
#
# NECROMANCER (8 kategori):
#   move_speed, att_range, attack%, base_health (flat),
#   attack_speed, splash_radius, summon_hp%, summon_limit
# ============================================================

signal on_upgrade_choices_ready(choices: Array)
signal on_upgrade_applied(upgrade_id: String)

enum CharacterClass { BERSERKER, NECROMANCER }

# ─── HELPER LABEL TIER ─────────────────────────────────────
const TIER_LABEL: Array = ["", "I", "II", "III", "★"]

const UPGRADE_DATA: Dictionary = {

	# ══════════════════════════════════════════════════════════
	# BERSERKER — 8 kategori × 4 tier = 32 upgrade
	# ══════════════════════════════════════════════════════════

	# 1. Defense (flat reduction damage)
	"b_def_1": { "tier":1, "name":"Iron Skin I",    "stat":"defense",     "value":3,    "requires":"",       "class":"B", "desc":"+3 Defense." },
	"b_def_2": { "tier":2, "name":"Iron Skin II",   "stat":"defense",     "value":4,    "requires":"b_def_1","class":"B", "desc":"+4 Defense (total +7)." },
	"b_def_3": { "tier":3, "name":"Iron Skin III",  "stat":"defense",     "value":6,    "requires":"b_def_2","class":"B", "desc":"+6 Defense (total +13)." },
	"b_def_4": { "tier":4, "name":"Iron Skin ★",    "stat":"defense",     "value":9,    "requires":"b_def_3","class":"B", "desc":"+9 Defense (total +22)." },

	# 2. Attack % (multiplier damage)
	"b_atk_1": { "tier":1, "name":"Warlust I",      "stat":"attack_pct",  "value":0.10, "requires":"",       "class":"B", "desc":"Damage +10%." },
	"b_atk_2": { "tier":2, "name":"Warlust II",     "stat":"attack_pct",  "value":0.12, "requires":"b_atk_1","class":"B", "desc":"Damage +12% (total +22%)." },
	"b_atk_3": { "tier":3, "name":"Warlust III",    "stat":"attack_pct",  "value":0.15, "requires":"b_atk_2","class":"B", "desc":"Damage +15% (total +37%)." },
	"b_atk_4": { "tier":4, "name":"Warlust ★",      "stat":"attack_pct",  "value":0.20, "requires":"b_atk_3","class":"B", "desc":"Damage +20% (total +57%)." },

	# 3. Lifesteal (mulai kecil, 3%)
	"b_ls_1":  { "tier":1, "name":"Bloodthirst I",  "stat":"lifesteal",   "value":0.03, "requires":"",       "class":"B", "desc":"Lifesteal 3% dari damage." },
	"b_ls_2":  { "tier":2, "name":"Bloodthirst II", "stat":"lifesteal",   "value":0.04, "requires":"b_ls_1", "class":"B", "desc":"Lifesteal +4% (total 7%)." },
	"b_ls_3":  { "tier":3, "name":"Bloodthirst III","stat":"lifesteal",   "value":0.05, "requires":"b_ls_2", "class":"B", "desc":"Lifesteal +5% (total 12%)." },
	"b_ls_4":  { "tier":4, "name":"Bloodthirst ★",  "stat":"lifesteal",   "value":0.08, "requires":"b_ls_3", "class":"B", "desc":"Lifesteal +8% (total 20%, maks)." },

	# 4. Crit Chance
	"b_cc_1":  { "tier":1, "name":"Sharp Eye I",    "stat":"crit_chance", "value":0.05, "requires":"",       "class":"B", "desc":"Crit Chance +5%." },
	"b_cc_2":  { "tier":2, "name":"Sharp Eye II",   "stat":"crit_chance", "value":0.07, "requires":"b_cc_1", "class":"B", "desc":"Crit Chance +7% (total +12%)." },
	"b_cc_3":  { "tier":3, "name":"Sharp Eye III",  "stat":"crit_chance", "value":0.09, "requires":"b_cc_2", "class":"B", "desc":"Crit Chance +9% (total +21%)." },
	"b_cc_4":  { "tier":4, "name":"Sharp Eye ★",    "stat":"crit_chance", "value":0.12, "requires":"b_cc_3", "class":"B", "desc":"Crit Chance +12% (total +33%)." },

	# 5. Crit Damage (multiplier)
	"b_cd_1":  { "tier":1, "name":"Lethal I",       "stat":"crit_mult",   "value":0.15, "requires":"",       "class":"B", "desc":"Crit Damage ×1.55 (dari ×1.4)." },
	"b_cd_2":  { "tier":2, "name":"Lethal II",      "stat":"crit_mult",   "value":0.20, "requires":"b_cd_1", "class":"B", "desc":"Crit Damage ×1.75." },
	"b_cd_3":  { "tier":3, "name":"Lethal III",     "stat":"crit_mult",   "value":0.25, "requires":"b_cd_2", "class":"B", "desc":"Crit Damage ×2.00." },
	"b_cd_4":  { "tier":4, "name":"Lethal ★",       "stat":"crit_mult",   "value":0.30, "requires":"b_cd_3", "class":"B", "desc":"Crit Damage ×2.30." },

	# 6. Movement Speed
	"b_spd_1": { "tier":1, "name":"Swift I",        "stat":"move_speed",  "value":10.0, "requires":"",       "class":"B", "desc":"Move Speed +10." },
	"b_spd_2": { "tier":2, "name":"Swift II",       "stat":"move_speed",  "value":12.0, "requires":"b_spd_1","class":"B", "desc":"Move Speed +12 (total +22)." },
	"b_spd_3": { "tier":3, "name":"Swift III",      "stat":"move_speed",  "value":15.0, "requires":"b_spd_2","class":"B", "desc":"Move Speed +15 (total +37)." },
	"b_spd_4": { "tier":4, "name":"Swift ★",        "stat":"move_speed",  "value":18.0, "requires":"b_spd_3","class":"B", "desc":"Move Speed +18 (total +55)." },

	# 7. Health % (dari max HP saat upgrade diambil)
	"b_hp_1":  { "tier":1, "name":"Berserker Body I",  "stat":"hp_pct",  "value":0.12, "requires":"",        "class":"B", "desc":"Max HP +12%." },
	"b_hp_2":  { "tier":2, "name":"Berserker Body II", "stat":"hp_pct",  "value":0.15, "requires":"b_hp_1",  "class":"B", "desc":"Max HP +15%." },
	"b_hp_3":  { "tier":3, "name":"Berserker Body III","stat":"hp_pct",  "value":0.18, "requires":"b_hp_2",  "class":"B", "desc":"Max HP +18%." },
	"b_hp_4":  { "tier":4, "name":"Berserker Body ★",  "stat":"hp_pct",  "value":0.22, "requires":"b_hp_3",  "class":"B", "desc":"Max HP +22%." },

	# 8. CD Reduction
	"b_cdr_1": { "tier":1, "name":"Momentum I",     "stat":"cd_reduction","value":0.08, "requires":"",        "class":"B", "desc":"Cooldown skill -8%." },
	"b_cdr_2": { "tier":2, "name":"Momentum II",    "stat":"cd_reduction","value":0.10, "requires":"b_cdr_1", "class":"B", "desc":"Cooldown skill -10% (total -18%)." },
	"b_cdr_3": { "tier":3, "name":"Momentum III",   "stat":"cd_reduction","value":0.12, "requires":"b_cdr_2", "class":"B", "desc":"Cooldown skill -12% (total -30%)." },
	"b_cdr_4": { "tier":4, "name":"Momentum ★",     "stat":"cd_reduction","value":0.15, "requires":"b_cdr_3", "class":"B", "desc":"Cooldown skill -15% (total -45%)." },

	# ══════════════════════════════════════════════════════════
	# NECROMANCER — 8 kategori × 4 tier = 32 upgrade
	# ══════════════════════════════════════════════════════════

	# 1. Movement Speed
	"n_spd_1": { "tier":1, "name":"Phantom Step I",   "stat":"move_speed",  "value":10.0,"requires":"",        "class":"N", "desc":"Move Speed +10." },
	"n_spd_2": { "tier":2, "name":"Phantom Step II",  "stat":"move_speed",  "value":12.0,"requires":"n_spd_1", "class":"N", "desc":"Move Speed +12 (total +22)." },
	"n_spd_3": { "tier":3, "name":"Phantom Step III", "stat":"move_speed",  "value":15.0,"requires":"n_spd_2", "class":"N", "desc":"Move Speed +15 (total +37)." },
	"n_spd_4": { "tier":4, "name":"Phantom Step ★",   "stat":"move_speed",  "value":18.0,"requires":"n_spd_3", "class":"N", "desc":"Move Speed +18 (total +55)." },

	# 2. Attack Range
	"n_rng_1": { "tier":1, "name":"Far Sight I",      "stat":"attack_range","value":25.0,"requires":"",        "class":"N", "desc":"Attack Range +25." },
	"n_rng_2": { "tier":2, "name":"Far Sight II",     "stat":"attack_range","value":30.0,"requires":"n_rng_1", "class":"N", "desc":"Attack Range +30 (total +55)." },
	"n_rng_3": { "tier":3, "name":"Far Sight III",    "stat":"attack_range","value":35.0,"requires":"n_rng_2", "class":"N", "desc":"Attack Range +35 (total +90)." },
	"n_rng_4": { "tier":4, "name":"Far Sight ★",      "stat":"attack_range","value":40.0,"requires":"n_rng_3", "class":"N", "desc":"Attack Range +40 (total +130)." },

	# 3. Attack %
	"n_atk_1": { "tier":1, "name":"Dark Arts I",      "stat":"attack_pct",  "value":0.10,"requires":"",        "class":"N", "desc":"Damage +10%." },
	"n_atk_2": { "tier":2, "name":"Dark Arts II",     "stat":"attack_pct",  "value":0.12,"requires":"n_atk_1", "class":"N", "desc":"Damage +12% (total +22%)." },
	"n_atk_3": { "tier":3, "name":"Dark Arts III",    "stat":"attack_pct",  "value":0.15,"requires":"n_atk_2", "class":"N", "desc":"Damage +15% (total +37%)." },
	"n_atk_4": { "tier":4, "name":"Dark Arts ★",      "stat":"attack_pct",  "value":0.20,"requires":"n_atk_3", "class":"N", "desc":"Damage +20% (total +57%)." },

	# 4. Base Health (flat, bukan %)
	"n_hp_1":  { "tier":1, "name":"Soul Vessel I",    "stat":"hp",          "value":20,  "requires":"",        "class":"N", "desc":"Max HP +20." },
	"n_hp_2":  { "tier":2, "name":"Soul Vessel II",   "stat":"hp",          "value":28,  "requires":"n_hp_1",  "class":"N", "desc":"Max HP +28 (total +48)." },
	"n_hp_3":  { "tier":3, "name":"Soul Vessel III",  "stat":"hp",          "value":36,  "requires":"n_hp_2",  "class":"N", "desc":"Max HP +36 (total +84)." },
	"n_hp_4":  { "tier":4, "name":"Soul Vessel ★",    "stat":"hp",          "value":45,  "requires":"n_hp_3",  "class":"N", "desc":"Max HP +45 (total +129)." },

	# 5. Attack Speed (interval berkurang)
	"n_aspd_1":{ "tier":1, "name":"Curse Speed I",    "stat":"attack_speed","value":0.08,"requires":"",        "class":"N", "desc":"Attack Speed +0.08 (lebih cepat)." },
	"n_aspd_2":{ "tier":2, "name":"Curse Speed II",   "stat":"attack_speed","value":0.10,"requires":"n_aspd_1","class":"N", "desc":"Attack Speed +0.10 (total +0.18)." },
	"n_aspd_3":{ "tier":3, "name":"Curse Speed III",  "stat":"attack_speed","value":0.12,"requires":"n_aspd_2","class":"N", "desc":"Attack Speed +0.12 (total +0.30)." },
	"n_aspd_4":{ "tier":4, "name":"Curse Speed ★",    "stat":"attack_speed","value":0.15,"requires":"n_aspd_3","class":"N", "desc":"Attack Speed +0.15 (total +0.45)." },

	# 6. Splash Radius (area ledakan setelah hit)
	"n_spl_1": { "tier":1, "name":"Curse Burst I",    "stat":"splash_radius","value":12.0,"requires":"",       "class":"N", "desc":"Splash radius +12 (jadi 52)." },
	"n_spl_2": { "tier":2, "name":"Curse Burst II",   "stat":"splash_radius","value":15.0,"requires":"n_spl_1","class":"N", "desc":"Splash radius +15 (total +27)." },
	"n_spl_3": { "tier":3, "name":"Curse Burst III",  "stat":"splash_radius","value":18.0,"requires":"n_spl_2","class":"N", "desc":"Splash radius +18 (total +45)." },
	"n_spl_4": { "tier":4, "name":"Curse Burst ★",    "stat":"splash_radius","value":20.0,"requires":"n_spl_3","class":"N", "desc":"Splash radius +20 (total +65, maks 120)." },

	# 7. Summon HP %
	"n_shp_1": { "tier":1, "name":"Undead Vitality I",   "stat":"summon_hp_pct","value":0.15,"requires":"",        "class":"N", "desc":"HP summon +15%." },
	"n_shp_2": { "tier":2, "name":"Undead Vitality II",  "stat":"summon_hp_pct","value":0.20,"requires":"n_shp_1", "class":"N", "desc":"HP summon +20% (total +35%)." },
	"n_shp_3": { "tier":3, "name":"Undead Vitality III", "stat":"summon_hp_pct","value":0.25,"requires":"n_shp_2", "class":"N", "desc":"HP summon +25% (total +60%)." },
	"n_shp_4": { "tier":4, "name":"Undead Vitality ★",   "stat":"summon_hp_pct","value":0.30,"requires":"n_shp_3", "class":"N", "desc":"HP summon +30% (total +90%)." },

	# 8. Jumlah Summon (+1 tiap tier, konsisten)
	"n_sl_1":  { "tier":1, "name":"Raise Dead I",     "stat":"summon_limit","value":1,   "requires":"",        "class":"N", "desc":"Batas summon +1 (jadi 2)." },
	"n_sl_2":  { "tier":2, "name":"Raise Dead II",    "stat":"summon_limit","value":1,   "requires":"n_sl_1",  "class":"N", "desc":"Batas summon +1 (jadi 3)." },
	"n_sl_3":  { "tier":3, "name":"Raise Dead III",   "stat":"summon_limit","value":1,   "requires":"n_sl_2",  "class":"N", "desc":"Batas summon +1 (jadi 4)." },
	"n_sl_4":  { "tier":4, "name":"Raise Dead ★",     "stat":"summon_limit","value":1,   "requires":"n_sl_3",  "class":"N", "desc":"Batas summon +1 (jadi 5, maks 6 dengan Necro lv15 auto)." },
}

# ─── POOL PER CLASS ────────────────────────────────────────
const BERSERKER_POOL: Array[String] = [
	"b_def_1","b_def_2","b_def_3","b_def_4",
	"b_atk_1","b_atk_2","b_atk_3","b_atk_4",
	"b_ls_1", "b_ls_2", "b_ls_3", "b_ls_4",
	"b_cc_1", "b_cc_2", "b_cc_3", "b_cc_4",
	"b_cd_1", "b_cd_2", "b_cd_3", "b_cd_4",
	"b_spd_1","b_spd_2","b_spd_3","b_spd_4",
	"b_hp_1", "b_hp_2", "b_hp_3", "b_hp_4",
	"b_cdr_1","b_cdr_2","b_cdr_3","b_cdr_4",
]
const NECROMANCER_POOL: Array[String] = [
	"n_spd_1","n_spd_2","n_spd_3","n_spd_4",
	"n_rng_1","n_rng_2","n_rng_3","n_rng_4",
	"n_atk_1","n_atk_2","n_atk_3","n_atk_4",
	"n_hp_1", "n_hp_2", "n_hp_3", "n_hp_4",
	"n_aspd_1","n_aspd_2","n_aspd_3","n_aspd_4",
	"n_spl_1","n_spl_2","n_spl_3","n_spl_4",
	"n_shp_1","n_shp_2","n_shp_3","n_shp_4",
	"n_sl_1", "n_sl_2", "n_sl_3", "n_sl_4",
]

# ─── RUNTIME ───────────────────────────────────────────────
var character_class: CharacterClass
var taken_upgrades:  Array[String] = []
var stat_system:     Node          = null

func init(cls: CharacterClass, stat_sys: Node) -> void:
	character_class = cls
	taken_upgrades.clear()
	stat_system = stat_sys

func generate_choices() -> void:
	var pool: Array = _get_available()
	pool.shuffle()
	emit_signal("on_upgrade_choices_ready", pool.slice(0, min(3, pool.size())))

func _get_available() -> Array:
	var source: Array
	match character_class:
		CharacterClass.BERSERKER:   source = BERSERKER_POOL
		CharacterClass.NECROMANCER: source = NECROMANCER_POOL

	var out: Array = []
	for id in source:
		if id in taken_upgrades: continue
		var req: String = UPGRADE_DATA[id].get("requires","")
		if req == "" or req in taken_upgrades:
			out.append(id)
	return out

func apply_upgrade(upgrade_id: String) -> void:
	if upgrade_id in taken_upgrades or stat_system == null: return
	var data  = UPGRADE_DATA[upgrade_id]
	var key   : String = data["stat"]
	var value          = data["value"]

	# hp_pct: tambah persentase dari HP saat ini
	if key == "hp_pct":
		var bonus: int = int(stat_system.stats.get("hp", 70) * value)
		stat_system.stats["hp"] = stat_system.stats.get("hp", 70) + bonus
	elif stat_system.stats.has(key):
		stat_system.stats[key] += value

	taken_upgrades.append(upgrade_id)
	emit_signal("on_upgrade_applied", upgrade_id)
	print("[UpgradeSys] %s — %s += %s" % [data["name"], key, str(value)])

func get_upgrade_data(id: String) -> Dictionary:
	return UPGRADE_DATA.get(id, {})

func has_taken(id: String) -> bool:
	return id in taken_upgrades
