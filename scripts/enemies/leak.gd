extends "res://scripts/enemies/enemy_base.gd"

# ============================================================
# leak.gd — Boss Final
# HP 2500, melee kuat, AOE api setiap 8 detik
# Fase 2 saat HP < 50%: kecepatan naik 30%
# ============================================================

const AOE_INTERVAL: float = 8.0
const AOE_RADIUS:   float = 120.0
const AOE_DMG_MULT: float = 1.5
const PROJECTILE_SPEED: float = 220.0

var aoe_timer:         float = AOE_INTERVAL
var phase2_triggered:  bool  = false

func _ready() -> void:
	super._ready()
	if hp_bar:
		hp_bar.modulate = Color(1.0, 0.3, 0.0)
	can_be_marked = false
	# Boss collide dengan semua: layer 1|2|4, mask 1|2|4
	collision_layer = LAYER_PLAYER | LAYER_ENEMY | LAYER_BOSS
	collision_mask  = LAYER_PLAYER | LAYER_ENEMY | LAYER_BOSS
	is_ranged = true

func _physics_process(delta: float) -> void:
	# FIX: wajib cek is_dying
	if is_dying: return
	super._physics_process(delta)
	_tick_aoe(delta)
	_check_phase2()

func _do_attack() -> void:
	if is_dying or _in_attack_anim: return
	_in_attack_anim = true
	anim_sprite.play("attack")
	if target and is_instance_valid(target):
		_fire_projectile(target.global_position, target, is_ally)
	await anim_sprite.animation_finished
	_in_attack_anim = false

func _fire_projectile(target_world_pos: Vector2, target_ref: Node, owner_is_ally: bool) -> void:
	var proj := _LeakProjectile.new()
	proj.global_position = global_position
	proj.target_pos = target_world_pos
	proj.travel_speed = PROJECTILE_SPEED
	proj.damage = damage
	proj.target_ref = target_ref if is_instance_valid(target_ref) else null
	proj.owner_is_ally = owner_is_ally
	get_tree().current_scene.add_child(proj)

class _LeakProjectile extends Node2D:
	var target_pos: Vector2 = Vector2.ZERO
	var travel_speed: float = 220.0
	var damage: int = 20
	var target_ref: Node = null
	var owner_is_ally: bool = false

	func _ready() -> void:
		var core := ColorRect.new()
		core.size = Vector2(14, 14)
		core.position = Vector2(-7, -7)
		core.color = Color(1.0, 0.35, 0.1)
		add_child(core)

		var glow := ColorRect.new()
		glow.size = Vector2(26, 26)
		glow.position = Vector2(-13, -13)
		glow.color = Color(1.0, 0.2, 0.0, 0.25)
		add_child(glow)
		move_child(glow, 0)

	func _process(delta: float) -> void:
		var dir: Vector2 = (target_pos - global_position)
		var dist: float = dir.length()
		if dist < 6.0:
			_apply_hit()
			queue_free()
			return
		global_position += dir.normalized() * travel_speed * delta

	func _apply_hit() -> void:
		if target_ref and is_instance_valid(target_ref):
			if target_ref.has_method("take_damage"):
				target_ref.take_damage(damage)

func _tick_aoe(delta: float) -> void:
	if is_dying or is_stunned or target == null: return
	aoe_timer -= delta
	if aoe_timer <= 0.0:
		aoe_timer = AOE_INTERVAL
		_do_aoe_attack()

func _do_aoe_attack() -> void:
	if is_dying: return
	modulate = Color(1.0, 0.4, 0.0)
	await get_tree().create_timer(0.15).timeout
	if not is_instance_valid(self) or is_dying: return
	modulate = Color.WHITE

	for t in get_tree().get_nodes_in_group("player") + get_tree().get_nodes_in_group("summons"):
		if is_ally:
			break
		if is_instance_valid(t) and global_position.distance_to(t.global_position) <= AOE_RADIUS:
			if t.has_method("take_damage"):
				t.take_damage(int(damage * AOE_DMG_MULT))
	if is_ally:
		for e in get_tree().get_nodes_in_group("enemies"):
			if is_instance_valid(e) and global_position.distance_to(e.global_position) <= AOE_RADIUS:
				if e.has_method("take_damage"):
					e.take_damage(int(damage * AOE_DMG_MULT))

func _check_phase2() -> void:
	if phase2_triggered or is_dying: return
	if float(current_hp) / float(max_hp) < 0.50:
		phase2_triggered = true
		move_speed *= 1.30
		print("[Leak] PHASE 2!")
		modulate = Color(0.8, 0.2, 1.0)
		await get_tree().create_timer(0.5).timeout
		if is_instance_valid(self) and not is_dying:
			modulate = Color.WHITE
