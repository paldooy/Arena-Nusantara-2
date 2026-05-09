extends CharacterBody2D

# ============================================================
# player_berserker.gd  [BARU — menggantikan player.gd untuk Berserker]
# Ksatria / Berserker
#
# SERANGAN BASIC:
#   Klik kiri → AOE setengah lingkaran ke arah hadap
#   Ditampilkan area merah transparan saat menyerang
#
# SKILL (diisi saat level 5 & 10, maks 2):
#   Q = skill slot 1 | E = skill slot 2
#
# ANIMASI: idle, walk, attack, skill_1, skill_2, hit, dead
# ============================================================

signal request_passive_summon()   # tidak dipakai Berserker tapi wajib ada agar game_world tidak error

const SPEED:          float = 130.0
const ATTACK_RANGE:   float = 70.0   # radius setengah lingkaran
const ATTACK_INTERVAL:float = 0.55   # detik antar basic attack

# Injected oleh game_world.gd
var class_system:  Node = null
var skill_system:  Node = null
var damage_system: Node = null
var enemies_in_scene: Array = []

# ── State ──────────────────────────────────────────────────
var facing_right:      bool  = true
var is_dead:           bool  = false
var is_stunned:        bool  = false
var stun_timer:        float = 0.0
var attack_cooldown:   float = 0.0
var blood_aura_active: bool  = false
var blood_aura_timer:  float = 0.0
var warcry_active:     bool  = false
var warcry_timer:      float = 0.0
var is_attacking:      bool  = false   # mencegah interupsi animasi attack

@onready var anim:        AnimatedSprite2D = $AnimatedSprite2D
@onready var attack_area: Node2D           = $AttackArea   # node attack_area.gd

func _ready() -> void:
	add_to_group("player")

# ──────────────────────────────────────────────────────────
func _process(delta: float) -> void:
	if is_dead: return
	_tick_timers(delta)

func _physics_process(delta: float) -> void:
	if is_dead or is_stunned: return

	var dir := Vector2(
		Input.get_axis("move_left", "move_right"),
		Input.get_axis("move_up",   "move_down")
	).normalized()

	velocity = dir * SPEED
	move_and_slide()
	_update_facing(dir)
	_update_animation(dir)

func _input(event: InputEvent) -> void:
	if is_dead or not GameManager.is_playing(): return

	# ── Basic attack: klik kiri ──
	if event is InputEventMouseButton and event.pressed \
			and event.button_index == MOUSE_BUTTON_LEFT:
		if attack_cooldown <= 0.0 and not is_attacking:
			_do_basic_attack(get_global_mouse_position())
			get_viewport().set_input_as_handled()

	# ── Skill Q ──
	if event.is_action_pressed("skill_1"):
		_use_skill_slot(0)

	# ── Skill E ──
	if event.is_action_pressed("skill_2"):
		_use_skill_slot(1)

# ──────────────────────────────────────────────────────────
# BASIC ATTACK — AOE setengah lingkaran ke arah hadap (dari WASD)
func _do_basic_attack(mouse_pos: Vector2) -> void:
	attack_cooldown = ATTACK_INTERVAL
	is_attacking = true

	# Gunakan arah hadap saat ini (dari WASD), jangan ubah dari mouse
	# Tampilkan area visual
	attack_area.show_arc(ATTACK_RANGE, facing_right)

	# Hitung damage ke musuh di dalam arc
	var hit_count := 0
	for enemy in enemies_in_scene:
		if not is_instance_valid(enemy): continue
		var diff: Vector2 = enemy.global_position - global_position
		if diff.length() > ATTACK_RANGE: continue
		# Cek apakah musuh di sisi yang benar
		if facing_right and diff.x < -10.0: continue
		if not facing_right and diff.x > 10.0: continue
		var dmg: int = damage_system.apply_damage(
			class_system.stat_system.stats, enemy, {},
			enemy.get("defense") if enemy.get("defense") != null else 0
		)
		_apply_lifesteal(dmg)
		hit_count += 1

	anim.play("attack")
	await get_tree().create_timer(0.4).timeout
	is_attacking = false

# ──────────────────────────────────────────────────────────
# SKILL SLOT
func _use_skill_slot(slot_index: int) -> void:
	if skill_system == null: return
	var learned: Array = skill_system.get_learned_skills()
	if slot_index >= learned.size(): return
	var skill_id: String = learned[slot_index]
	if not skill_system.use_skill(skill_id): return
	_execute_skill(skill_id)

func _execute_skill(skill_id: String) -> void:
	var data: Dictionary = skill_system.get_skill_data(skill_id)

	match skill_id:

		# ── Whirlwind Slash ──────────────────────────────
		"berserker_spin":
			anim.play("skill_1")
			# AOE lingkaran penuh di sekitar player
			attack_area.show_circle(
				data.get("radius", 100.0),
				Color(1.0, 0.2, 0.1, 0.22),
				0.35
			)
			damage_system.apply_aoe_damage(
				class_system.stat_system.stats,
				global_position, data.get("radius", 100.0),
				enemies_in_scene, data
			)
			await get_tree().create_timer(0.4).timeout

		# ── Blood Aura ───────────────────────────────────
		"berserker_blood_aura":
			anim.play("skill_2")
			blood_aura_timer  = data.get("buff_duration", 6.0)
			blood_aura_active = true
			class_system.stat_system.apply_blood_aura(blood_aura_timer)
			# Efek visual aura (lingkaran merah besar, bertahan)
			attack_area.show_circle(
				55.0, Color(1.0, 0.1, 0.1, 0.15), data.get("buff_duration", 6.0)
			)
			await get_tree().create_timer(0.4).timeout

		# ── War Cry ──────────────────────────────────────
		"berserker_warcry":
			anim.play("skill_1")
			warcry_active = true
			warcry_timer  = data.get("buff_duration", 5.0)
			# buff speed sementara
			SPEED  # (speed di-boost via warcry flag, lihat _physics_process)
			attack_area.show_circle(40.0, Color(1.0, 0.8, 0.0, 0.18), 0.4)
			await get_tree().create_timer(0.4).timeout

		# ── Ground Smash ─────────────────────────────────
		"berserker_ground_smash":
			anim.play("skill_2")
			attack_area.show_circle(
				data.get("radius", 130.0),
				Color(1.0, 0.3, 0.0, 0.20),
				0.45
			)
			await get_tree().create_timer(0.25).timeout  # jeda sedikit, lalu hit
			damage_system.apply_aoe_damage(
				class_system.stat_system.stats,
				global_position, data.get("radius", 130.0),
				enemies_in_scene, data
			)
			for enemy in enemies_in_scene:
				if is_instance_valid(enemy) \
						and global_position.distance_to(enemy.global_position) <= data.get("radius", 130.0) \
						and enemy.has_method("apply_stun"):
					enemy.apply_stun(data.get("stun_duration", 1.5))
			await get_tree().create_timer(0.4).timeout

		# ── Berserker Charge ─────────────────────────────
		"berserker_charge":
			anim.play("skill_1")
			var charge_dir: Vector2 = Vector2.RIGHT if facing_right else Vector2.LEFT
			var dist: float = data.get("charge_distance", 200.0)
			# Dash maju
			var tween = create_tween()
			tween.tween_property(self, "global_position",
				global_position + charge_dir * dist, 0.18)
			await tween.finished
			# Hit musuh di ujung dash
			attack_area.show_arc(
				50.0, facing_right, 0.25
			)
			for enemy in enemies_in_scene:
				if not is_instance_valid(enemy): continue
				if global_position.distance_to(enemy.global_position) <= 50.0:
					damage_system.apply_damage(
						class_system.stat_system.stats, enemy, data,
						enemy.get("defense") if enemy.get("defense") != null else 0
					)
					if enemy.has_method("apply_stun"):
						enemy.apply_stun(data.get("stun_duration", 2.0))
					break  # charge hanya hit satu musuh
			await get_tree().create_timer(0.4).timeout

# ──────────────────────────────────────────────────────────
# TIMERS
func _tick_timers(delta: float) -> void:
	if attack_cooldown > 0.0:
		attack_cooldown -= delta

	if is_stunned:
		stun_timer -= delta
		if stun_timer <= 0.0: is_stunned = false

	if blood_aura_active:
		blood_aura_timer -= delta
		if blood_aura_timer <= 0.0:
			blood_aura_active = false
			class_system.stat_system.remove_blood_aura()

	if warcry_active:
		warcry_timer -= delta
		if warcry_timer <= 0.0:
			warcry_active = false

# ──────────────────────────────────────────────────────────
# ANIMASI & FACING
func _update_facing(dir: Vector2) -> void:
	if dir.x > 0.05:
		facing_right = true
	elif dir.x < -0.05:
		facing_right = false
	anim.flip_h = facing_right

func _update_animation(dir: Vector2) -> void:
	if is_attacking: return   # jangan interupsi animasi attack
	if dir.length() > 0.1:
		anim.play("walk")
	else:
		anim.play("idle")

# ──────────────────────────────────────────────────────────
# DAMAGE MASUK
func take_damage(amount: int) -> void:
	if is_dead or class_system == null: return
	class_system.take_damage(amount)
	if not is_attacking:
		anim.play("hit")
		await get_tree().create_timer(0.4).timeout
	if not class_system.is_alive():
		_die()

func heal(amount: int) -> void:
	if class_system: class_system.heal(amount)

func _die() -> void:
	if is_dead: return
	is_dead = true
	anim.play("dead")
	await get_tree().create_timer(0.4).timeout
	GameManager.end_game(false)

# ──────────────────────────────────────────────────────────
# HELPERS
func _apply_lifesteal(dmg: int) -> void:
	var ls: float = class_system.stat_system.get_stat("lifesteal")
	if ls > 0.0:
		damage_system.apply_lifesteal(class_system, dmg, ls)

func apply_stun(duration: float) -> void:
	is_stunned = true
	stun_timer = duration

func get_effective_speed() -> float:
	return SPEED * (1.4 if warcry_active else 1.0)
