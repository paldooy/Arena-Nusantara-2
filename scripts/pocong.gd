extends "res://scripts/enemy_base.gd"

# ============================================================
# pocong.gd — Tier 1 (Early Game)
#
# Musuh melee paling dasar.
# Tidak ada kemampuan spesial — hanya jalan ke player dan pukul.
# Kelebihan: muncul banyak di early game, cukup cepat.
# ============================================================

func _ready() -> void:
	super._ready()
	if hp_bar:
		hp_bar.modulate = Color(0.9, 0.95, 1.0)   # putih agak biru (kain kafan)
