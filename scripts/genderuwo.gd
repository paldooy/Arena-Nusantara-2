extends "res://scripts/enemy_base.gd"

# ============================================================
# genderuwo.gd — Tier 3 (Late Game)
#
# Musuh melee kuat dengan HP besar.
# Tidak ada skill spesial, tapi:
#   - HP jauh lebih besar dari Pocong
#   - Damage per serangan lebih sakit
#   - Bergerak sedikit lebih lambat dari Pocong
#   - ATTACK_INTERVAL lebih panjang (sekali pukul = sakit)
#   - Defense flat (kurangi damage masuk)
# ============================================================

# Override interval serangan — Genderuwo lebih lambat tapi sakit
# Kita gunakan var agar bisa diubah runtime
var _attack_interval_override: float = 1.8   # lebih lambat dari base 1.4

func _ready() -> void:
	super._ready()
	defense = 5   # damage reduction flat
	if hp_bar:
		hp_bar.modulate = Color(0.35, 0.15, 0.05)   # coklat tua kehitaman

# Override _do_attack timing dengan interval berbeda
func _physics_process(delta: float) -> void:
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
		anim_sprite.play("idle")
		attack_cooldown -= delta
		if attack_cooldown <= 0.0:
			_do_attack()
			attack_cooldown = _attack_interval_override   # pakai override

func _do_attack() -> void:
	anim_sprite.play("attack")
	if player and player.has_method("take_damage"):
		player.take_damage(damage)
