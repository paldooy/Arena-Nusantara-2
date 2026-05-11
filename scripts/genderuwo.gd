extends "res://scripts/enemy_base.gd"

# ============================================================
# genderuwo.gd — Tier 3 (Late Game)
# Melee kuat, HP besar, lebih lambat, defense flat 5
# Attack interval 1.8s (lebih lambat dari base 1.4s)
# ============================================================

var _attack_interval_override: float = 1.8

func _ready() -> void:
	super._ready()
	defense = 5
	if hp_bar:
		hp_bar.modulate = Color(0.35, 0.15, 0.05)

func _physics_process(delta: float) -> void:
	# FIX: wajib cek is_dying karena kita override physics_process
	if is_dying: return

	_tick_stun(delta)
	if is_stunned or player == null: return

	var dist: float = global_position.distance_to(player.global_position)

	if dist > attack_range:
		var dir: Vector2 = (player.global_position - global_position).normalized()
		velocity = dir * move_speed
		move_and_slide()
		anim_sprite.play("walk")
		anim_sprite.flip_h = velocity.x < 0
	else:
		velocity = Vector2.ZERO
		attack_cooldown -= delta
		if attack_cooldown <= 0.0:
			_do_attack()
			attack_cooldown = _attack_interval_override
		elif anim_sprite.animation != "attack":
			anim_sprite.play("idle")
