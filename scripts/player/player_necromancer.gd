extends CharacterBody2D

# ============================================================
# player_necromancer.gd  [REVISI v2]
# - Skill ikuti posisi kursor
# - Basic attack pakai animasi attack_particle dulu sebelum hit
# - Visual area jangkauan attack (stroke circle, tidak solid)
# - Animasi skill: mark, summon_buff, dark_circle diterapkan
# ============================================================

signal request_passive_summon()

const BASE_ATTACK_INTERVAL: float = 0.80
const PASSIVE_INTERVAL:     float = 10.0

# Kecepatan proyektil basic attack (pixel per detik)
const PROJECTILE_SPEED: float = 350.0

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
var passive_timer:   float = 15.0
var _shield_hp:      int   = 0

# Untuk stroke circle area range
var _range_circle_node: Node2D = null

@onready var anim:        AnimatedSprite2D = $AnimatedSprite2D
@onready var attack_area: Node2D           = $AttackArea

func _ready() -> void:
	add_to_group("player")
	collision_layer = 1
	collision_mask  = 1 | 2 | 4
	anim.animation_finished.connect(_on_anim_finished)
	_create_range_indicator()

# ─── RANGE INDICATOR (stroke circle, tidak solid) ──────────
func _create_range_indicator() -> void:
	# Buat node Line2D sebagai stroke lingkaran range attack
	_range_circle_node = Node2D.new()
	_range_circle_node.name = "RangeIndicator"
	add_child(_range_circle_node)

	var line := Line2D.new()
	line.name = "RangeCircleLine"
	line.width = 1.5
	line.default_color = Color(0.6, 0.1, 1.0, 0.45)
	line.closed = true

	# Gambar stroke lingkaran
	var pts := PackedVector2Array()
	var steps: int = 48
	var r: float = 200.0  # default, akan di-update saat ready
	for i in range(steps):
		var a: float = (float(i) / steps) * TAU
		pts.append(Vector2(cos(a), sin(a)) * r)
	line.points = pts
	_range_circle_node.add_child(line)
	_range_circle_node.visible = true

func _update_range_indicator() -> void:
	if _range_circle_node == null: return
	var line := _range_circle_node.get_node_or_null("RangeCircleLine") as Line2D
	if line == null: return
	var atk_range: float = class_system.stat_system.get_attack_range() if class_system else 200.0
	var pts := PackedVector2Array()
	var steps: int = 48
	for i in range(steps):
		var a: float = (float(i) / steps) * TAU
		pts.append(Vector2(cos(a), sin(a)) * atk_range)
	line.points = pts

# ─── PROCESS ───────────────────────────────────────────────
func _process(delta: float) -> void:
	if is_dead or not GameManager.is_playing(): return
	_tick_timers(delta)
	_update_range_indicator()

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

# ─── BASIC ATTACK — pakai proyektil animasi dulu ───────────
func _do_basic_attack(mouse_pos: Vector2) -> void:
	var atk_range: float = class_system.stat_system.get_attack_range() if class_system else 200.0
	var splash_r:  float = class_system.stat_system.get_splash_radius() if class_system else 40.0

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

	# Mainkan animasi attack_particle sebagai proyektil visual
	# Proyektil bergerak dari player ke target, lalu deal damage
	_launch_attack_particle(target, splash_r)
	is_attacking = false

func _launch_attack_particle(target: Node, splash_r: float) -> void:
	if not is_instance_valid(target): return

	# Buat node proyektil visual
	var proj := AnimatedSprite2D.new()
	proj.sprite_frames = anim.sprite_frames
	if anim.sprite_frames.get_animation_names().has("attack_particle"):
		proj.play("attack_particle")
	proj.global_position = global_position
	proj.z_index = 2
	get_parent().add_child(proj)

	# Gerakkan proyektil menuju target secara smooth
	var start_pos: Vector2 = global_position
	var target_node_ref: Node = target
	var travel_time: float = global_position.distance_to(target.global_position) / PROJECTILE_SPEED
	var elapsed: float = 0.0

	while elapsed < travel_time:
		var dt: float = get_process_delta_time()
		elapsed += dt
		if not is_instance_valid(proj): return
		if not is_instance_valid(target_node_ref):
			proj.queue_free()
			return

		var t: float = clamp(elapsed / travel_time, 0.0, 1.0)
		proj.global_position = start_pos.lerp(target_node_ref.global_position, t)
		await get_tree().process_frame

	# Proyektil tiba — deal damage
	if is_instance_valid(proj):
		proj.queue_free()
	if not is_instance_valid(target_node_ref): return

	var hit_pos: Vector2 = target_node_ref.global_position
	var dmg: int = damage_system.apply_damage(
		class_system.stat_system.stats, target_node_ref, {},
		target_node_ref.get("defense") if target_node_ref.get("defense") != null else 0
	)

	# Splash di posisi musuh
	attack_area.show_circle_at(hit_pos, splash_r, Color(0.6, 0.1, 1.0, 0.28), 0.22)
	for enemy in enemies_in_scene:
		if not is_instance_valid(enemy) or enemy == target_node_ref: continue
		if hit_pos.distance_to(enemy.global_position) <= splash_r:
			damage_system.apply_damage(
				class_system.stat_system.stats, enemy,
				{"damage_mult": 0.4},
				enemy.get("defense") if enemy.get("defense") != null else 0
			)

# ─── SKILL ─────────────────────────────────────────────────
func _use_skill_slot(slot_index: int) -> void:
	if skill_system == null: return
	var learned: Array = skill_system.get_learned_skills()
	if slot_index >= learned.size(): return
	var skill_id: String = learned[slot_index]
	if not skill_system.use_skill(skill_id): return
	await _execute_skill(skill_id)

func _execute_skill(skill_id: String) -> void:
	var data: Dictionary = skill_system.get_skill_data(skill_id)
	# Nama animasi mengikuti suffix skill_id (trim prefix "necromancer_")
	var anim_name: String = skill_id.trim_prefix("necromancer_")
	# Posisi kursor saat skill diaktifkan
	var cursor_pos: Vector2 = get_global_mouse_position()

	match skill_id:
		"necromancer_mark":
			# Area visual di posisi kursor
			attack_area.show_circle_at(cursor_pos, 180.0, Color(0.5, 0.0, 1.0, 0.12), 0.35)
			_mark_nearest_enemy_to(cursor_pos, data.get("mark_duration", 15.0))

		"necromancer_summon_buff":
			var buff_pct: float = data.get("buff_pct", 0.40)
			var buff_duration: float = data.get("buff_duration", 8.0)
			class_system.stat_system.apply_summon_buff_pct(buff_pct)
			var dmg_pct: float = class_system.stat_system.get_stat("summon_damage_pct")
			var hp_pct:  float = class_system.stat_system.get_stat("summon_hp_pct")
			for s in get_tree().get_nodes_in_group("summons"):
				if not is_instance_valid(s):
					continue
				if s.has_method("apply_stat_bonuses"):
					s.apply_stat_bonuses(dmg_pct, hp_pct)
				if s.has_method("set_buff_active"):
					s.set_buff_active(true)
			await get_tree().create_timer(buff_duration).timeout
			if is_instance_valid(self):
				class_system.stat_system.remove_summon_buff_pct(buff_pct)
			var dmg_pct_after: float = class_system.stat_system.get_stat("summon_damage_pct")
			var hp_pct_after:  float = class_system.stat_system.get_stat("summon_hp_pct")
			for s in get_tree().get_nodes_in_group("summons"):
				if not is_instance_valid(s):
					continue
				if s.has_method("apply_stat_bonuses"):
					s.apply_stat_bonuses(dmg_pct_after, hp_pct_after)
				if s.has_method("set_buff_active"):
					s.set_buff_active(false)

		"necromancer_dark_circle":
			var radius: float = data.get("radius", 90.0)
			_spawn_skill_fx("dark_circle", cursor_pos, 4, 0.9)
			# Area visual meledak di posisi kursor
			attack_area.show_circle_at(cursor_pos, radius, Color(0.40, 0.0, 0.80, 0.30), 0.40)
			await get_tree().create_timer(0.20).timeout
			# Damage dihitung dari posisi kursor, bukan posisi player
			var total_dmg: int = damage_system.apply_aoe_damage(
				class_system.stat_system.stats,
				cursor_pos, radius, enemies_in_scene, data
			)
			var ls: float = class_system.stat_system.get_stat("lifesteal")
			if ls > 0.0 and total_dmg > 0:
				damage_system.apply_lifesteal(self, total_dmg, ls)
			pass

# ─── MARK MUSUH TERDEKAT KE KURSOR ─────────────────────────
func _mark_nearest_enemy_to(pos: Vector2, duration: float) -> Node:
	var nearest: Node  = null
	var min_d:   float = INF
	for enemy in enemies_in_scene:
		if not is_instance_valid(enemy): continue
		var d: float = pos.distance_to(enemy.global_position)
		if d < min_d:
			min_d   = d
			nearest = enemy
	if nearest and nearest.has_method("apply_mark"):
		nearest.apply_mark(duration)
	return nearest

# ─── TIMERS ────────────────────────────────────────────────
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

func apply_stun(duration: float) -> void:
	is_stunned = true
	stun_timer = duration

func _update_facing(dir: Vector2) -> void:
	if dir.x > 0.05:    facing_right = true
	elif dir.x < -0.05: facing_right = false
	anim.flip_h = facing_right

func _update_animation(dir: Vector2) -> void:
	if is_attacking: return
	if dir.length() > 0.1: anim.play("walk")
	else:                   anim.play("idle")

func _on_anim_finished() -> void:
	pass

func _spawn_skill_fx(anim_name: String, world_pos: Vector2, z: int, lifetime: float) -> void:
	if anim_name == "" or anim.sprite_frames == null:
		return
	if not anim.sprite_frames.get_animation_names().has(anim_name):
		return
	var fx := AnimatedSprite2D.new()
	fx.sprite_frames = anim.sprite_frames
	fx.animation = anim_name
	fx.z_index = z
	fx.global_position = world_pos
	get_parent().add_child(fx)
	fx.play(anim_name)
	await get_tree().create_timer(lifetime).timeout
	if is_instance_valid(fx):
		fx.queue_free()
