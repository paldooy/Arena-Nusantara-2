extends "res://scripts/enemies/enemy_base.gd"

# ============================================================
# genderuwo.gd — Tier 3
# Animasi attack: 4 frame × 0.6s = 2.4s total
# Damage masuk di frame ke-3 (0.48s dari awal animasi)
# Attack interval: 1.8s | Defense: 5
# ============================================================

var _attack_interval_override: float = 1.8

func _ready() -> void:
	super._ready()
	defense = 5
	if hp_bar:
		hp_bar.modulate = Color(0.35, 0.15, 0.05)

func _physics_process(delta: float) -> void:
	if is_dying: return
	_tick_stun(delta)
	if is_stunned: return

	target = _find_target()
	if target == null: return

	var dist: float = global_position.distance_to(target.global_position)

	if dist > attack_range:
		if attack_cooldown < 0.5:
			attack_cooldown = 0.5
		var dir: Vector2 = (target.global_position - global_position).normalized()
		velocity = dir * move_speed
		move_and_slide()
		anim_sprite.play("walk")
		anim_sprite.flip_h = velocity.x < 0
	else:
		velocity = Vector2.ZERO
		if not _in_attack_anim:
			anim_sprite.play("idle")
		attack_cooldown -= delta
		if attack_cooldown <= 0.0 and not _in_attack_anim:
			_do_attack()
			attack_cooldown = _attack_interval_override

func _do_attack() -> void:
	if is_dying or _in_attack_anim: return
	_in_attack_anim = true
	anim_sprite.play("attack")

	# Damage masuk di frame ke-3 (0.48s dari 4 frame × 0.6s)
	await get_tree().create_timer(0.48).timeout

	if not is_instance_valid(self) or is_dying:
		_in_attack_anim = false
		return

	if target and is_instance_valid(target) and target.has_method("take_damage"):
		if global_position.distance_to(target.global_position) <= attack_range * 1.3:
			target.take_damage(damage)

	await anim_sprite.animation_finished
	_in_attack_anim = false
