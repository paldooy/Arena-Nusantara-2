extends "res://scripts/enemy_base.gd"

# ============================================================
# pocong.gd — Tier 1
# Animasi attack: 4 frame × 0.6s = 2.4s total
# Damage masuk di frame ke-2/3 (0.36s dari awal animasi)
# ============================================================

func _ready() -> void:
	super._ready()
	if hp_bar:
		hp_bar.modulate = Color(0.9, 0.95, 1.0)

func _do_attack() -> void:
	if is_dying or _in_attack_anim: return
	_in_attack_anim = true
	anim_sprite.play("attack")

	# Damage masuk di frame ke-2/3 (0.36s dari 4 frame × 0.6s)
	await get_tree().create_timer(0.36).timeout

	if not is_instance_valid(self) or is_dying:
		_in_attack_anim = false
		return

	if player and is_instance_valid(player) and player.has_method("take_damage"):
		if global_position.distance_to(player.global_position) <= attack_range * 1.3:
			player.take_damage(damage)

	# Tunggu animasi selesai sebelum bisa attack lagi
	await anim_sprite.animation_finished
	_in_attack_anim = false
