extends CharacterBody2D

# ============================================================
# player_necromancer.gd  [REVISI — baca stat dinamis]
# attack_range & splash_radius dibaca dari stat_system.
# ============================================================

signal request_passive_summon()

const BASE_ATTACK_INTERVAL: float = 0.80
const PASSIVE_INTERVAL:     float = 30.0

var class_system:     Node  = null
var skill_system:     Node  = null
var damage_system:    Node  = null
var enemies_in_scene: Array = []

var facing_right:    bool  = true
var is_dead:         bool  = false
var is_stunned:      bool  = false
var stun_timer:      float = 0.0
var attack_cooldown: float = 0.0
var is_attacking:    bool  = false
var passive_timer:   float = 0.0
var _shield_hp:      int   = 0

@onready var anim:        AnimatedSprite2D = $AnimatedSprite2D
@onready var attack_area: Node2D           = $AttackArea

func _ready() -> void:
	add_to_group("player")
	# Layer 1 = Player, mask 1|2|4 agar bisa collide dengan semua enemy
	collision_layer = 1
	collision_mask  = 1 | 2 | 4

func _process(delta: float) -> void:
	if is_dead or not GameManager.is_playing(): return
	_tick_timers(delta)

func _physics_process(_delta: float) -> void:
	if is_dead or is_stunned or not GameManager.is_playing(): return
	var dir := Vector2(
		Input.get_axis("move_left",  "move_right"),
		Input.get_axis("move_up",    "move_down")
	).normalized()
	var spd: float = class_system.stat_system.get_move_speed() if class_system else 135.0
	velocity = dir * spd
	move_and_slide()
	_update_facing(dir)
	_update_animation(dir)

func _input(event: InputEvent) -> void:
	if is_dead or not GameManager.is_playing(): return
	if event is InputEventMouseButton and event.pressed \
			and event.button_index == MOUSE_BUTTON_LEFT:
		if attack_cooldown <= 0.0:
			_do_basic_attack(get_global_mouse_position())
	if event.is_action_pressed("skill_1"):
		_use_skill_slot(0)
	if event.is_action_pressed("skill_2"):
		_use_skill_slot(1)

func _do_basic_attack(mouse_pos: Vector2) -> void:
	# Baca range & splash dari stat_system
	var atk_range:    float = class_system.stat_system.get_attack_range() if class_system else 200.0
	var splash_r:     float = class_system.stat_system.get_splash_radius() if class_system else 40.0

	# Cari musuh yang diklik
	var target: Node  = null
	var min_d:  float = 36.0
	for enemy in enemies_in_scene:
		if not is_instance_valid(enemy): continue
		var d: float = mouse_pos.distance_to(enemy.global_position)
		if d < min_d:
			min_d  = d
			target = enemy
	if target == null: return
	if global_position.distance_to(target.global_position) > atk_range: return

	attack_cooldown = BASE_ATTACK_INTERVAL
	is_attacking    = true
	facing_right    = target.global_position.x >= global_position.x
	anim.flip_h     = not facing_right
	anim.play("attack")

	var dmg: int = damage_system.apply_damage(
		class_system.stat_system.stats, target, {},
		target.get("defense") if target.get("defense") != null else 0
	)

	# Splash di posisi musuh
	var hit_pos: Vector2 = target.global_position
	attack_area.show_circle_at(hit_pos, splash_r, Color(0.6, 0.1, 1.0, 0.28), 0.22)
	for enemy in enemies_in_scene:
		if not is_instance_valid(enemy) or enemy == target: continue
		if hit_pos.distance_to(enemy.global_position) <= splash_r:
			damage_system.apply_damage(
				class_system.stat_system.stats, enemy,
				{"damage_mult": 0.4},
				enemy.get("defense") if enemy.get("defense") != null else 0
			)

	await anim.animation_finished
	is_attacking = false

func _use_skill_slot(slot_index: int) -> void:
	if skill_system == null: return
	var learned: Array = skill_system.get_learned_skills()
	if slot_index >= learned.size(): return
	var skill_id: String = learned[slot_index]
	if not skill_system.use_skill(skill_id): return
	await _execute_skill(skill_id)

func _execute_skill(skill_id: String) -> void:
	var data: Dictionary = skill_system.get_skill_data(skill_id)
	# Extract animation name dari skill_id (buang prefix "necromancer_")
	var anim_name: String = skill_id.trim_prefix("necromancer_")

	match skill_id:
		"necromancer_mark":
			anim.play(anim_name)
			attack_area.show_circle(180.0, Color(0.5, 0.0, 1.0, 0.12), 0.35)
			_mark_nearest_enemy(data.get("mark_duration", 15.0))
			await anim.animation_finished

		"necromancer_summon_buff":
			anim.play(anim_name)
			attack_area.show_circle(70.0, Color(0.3, 0.0, 0.6, 0.20), 0.40)
			var buff_pct: float = data.get("buff_pct", 0.40)
			class_system.stat_system.apply_summon_buff_pct(buff_pct)
			await get_tree().create_timer(data.get("buff_duration", 8.0)).timeout
			if is_instance_valid(self):
				class_system.stat_system.remove_summon_buff_pct(buff_pct)
			await anim.animation_finished

		"necromancer_dark_circle":
			anim.play(anim_name)
			attack_area.show_circle(
				data.get("radius", 90.0), Color(0.40, 0.0, 0.80, 0.30), 0.40)
			await get_tree().create_timer(0.20).timeout
			var total_dmg: int = damage_system.apply_aoe_damage(
				class_system.stat_system.stats,
				global_position, data.get("radius", 90.0),
				enemies_in_scene, data
			)
			# Apply lifesteal if any
			var ls: float = class_system.stat_system.get_stat("lifesteal")
			if ls > 0.0 and total_dmg > 0:
				damage_system.apply_lifesteal(self, total_dmg, ls)
			await anim.animation_finished

func _tick_timers(delta: float) -> void:
	if attack_cooldown > 0.0: attack_cooldown -= delta
	if is_stunned:
		stun_timer -= delta
		if stun_timer <= 0.0: is_stunned = false
	passive_timer += delta
	if passive_timer >= PASSIVE_INTERVAL:
		passive_timer = 0.0
		emit_signal("request_passive_summon")

func take_damage(amount: int) -> void:
	if is_dead or class_system == null: return
	if _shield_hp > 0:
		var absorbed: int = min(_shield_hp, amount)
		_shield_hp -= absorbed
		amount     -= absorbed
		if amount <= 0: return
	class_system.take_damage(amount)
	if not is_attacking:
		if anim.sprite_frames.get_animation_names().has("hit"):
			anim.play("hit")
	if not class_system.is_alive():
		_die()

func heal(amount: int) -> void:
	if class_system: class_system.heal(amount)

func _die() -> void:
	if is_dead: return
	is_dead = true
	if anim.sprite_frames.get_animation_names().has("dead"):
		anim.play("dead")
	GameManager.end_game(false)

func _mark_nearest_enemy(duration: float) -> void:
	var nearest: Node  = null
	var min_d:   float = INF
	for enemy in enemies_in_scene:
		if not is_instance_valid(enemy): continue
		var d: float = global_position.distance_to(enemy.global_position)
		if d < min_d:
			min_d   = d
			nearest = enemy
	if nearest and nearest.has_method("apply_mark"):
		nearest.apply_mark(duration)

func apply_stun(duration: float) -> void:
	is_stunned = true
	stun_timer = duration

func _update_facing(dir: Vector2) -> void:
	if dir.x > 0.05:    facing_right = true
	elif dir.x < -0.05: facing_right = false
	anim.flip_h = not facing_right

func _update_animation(dir: Vector2) -> void:
	if is_attacking: return
	if dir.length() > 0.1: anim.play("walk")
	else:                   anim.play("idle")
