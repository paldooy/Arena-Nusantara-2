extends CharacterBody2D

# ============================================================
# player_necromancer.gd  [BARU — script khusus Necromancer/Dukun]
#
# SERANGAN BASIC:
#   Klik kiri pada musuh → single-target hit
#   Saat hit terkena musuh → ledakan kecil AOE di titik musuh
#   Area ledakan ditampilkan dengan lingkaran ungu transparan
#
# SKILL (diisi saat level 5 & 10, maks 2):
#   Q = skill slot 1 | E = skill slot 2
#
# ANIMASI: idle, walk, attack, skill_1, skill_2, hit, dead
# ============================================================

signal request_passive_summon()

const SPEED:           float = 110.0
const ATTACK_RANGE:    float = 200.0  # jarak maksimal klik musuh
const ATTACK_INTERVAL: float = 0.80
const SPLASH_RADIUS:   float = 45.0  # ledakan kecil setelah single-target hit

# Injected oleh game_world.gd
var class_system:  Node = null
var skill_system:  Node = null
var damage_system: Node = null
var enemies_in_scene: Array = []

# ── Referensi ke node AttackArea (dibuat di scene Necromancer) ──
@onready var anim:        AnimatedSprite2D = $AnimatedSprite2D
@onready var attack_area: Node2D           = $AttackArea

# ── State ──────────────────────────────────────────────────
var facing_right:    bool  = true
var is_dead:         bool  = false
var is_stunned:      bool  = false
var stun_timer:      float = 0.0
var attack_cooldown: float = 0.0
var is_attacking:    bool  = false
var passive_timer:   float = 0.0
const PASSIVE_INTERVAL: float = 30.0

func _ready() -> void:
	add_to_group("player")

# ──────────────────────────────────────────────────────────
func _process(delta: float) -> void:
	if is_dead: return
	_tick_timers(delta)

func _physics_process(delta: float) -> void:
	if is_dead or is_stunned: return
	var dir := Vector2(
		Input.get_axis("move_left",  "move_right"),
		Input.get_axis("move_up",    "move_down")
	).normalized()
	velocity = dir * SPEED
	move_and_slide()
	_update_facing(dir)
	_update_animation(dir)

func _input(event: InputEvent) -> void:
	if is_dead or not GameManager.is_playing(): return

	# ── Basic attack: klik kiri → cari musuh terdekat dari kursor ──
	if event is InputEventMouseButton and event.pressed \
			and event.button_index == MOUSE_BUTTON_LEFT:
		if attack_cooldown <= 0.0 and not is_attacking:
			_do_basic_attack(get_global_mouse_position())
			get_viewport().set_input_as_handled()

	if event.is_action_pressed("skill_1"):
		_use_skill_slot(0)
	if event.is_action_pressed("skill_2"):
		_use_skill_slot(1)

# ──────────────────────────────────────────────────────────
# BASIC ATTACK — single target + ledakan kecil di titik kena
func _do_basic_attack(mouse_pos: Vector2) -> void:
	# Cari musuh yang diklik (dalam radius klik 32px dari kursor)
	var target: Node = null
	var closest_dist: float = 36.0  # pixel tolerance saat klik
	for enemy in enemies_in_scene:
		if not is_instance_valid(enemy): continue
		var d: float = mouse_pos.distance_to(enemy.global_position)
		if d < closest_dist:
			closest_dist = d
			target = enemy
	if target == null: return
	# Batas jarak dari player
	if global_position.distance_to(target.global_position) > ATTACK_RANGE: return

	attack_cooldown = ATTACK_INTERVAL
	is_attacking = true

	# Hadap ke arah musuh
	facing_right = target.global_position.x >= global_position.x
	anim.flip_h  = facing_right
	anim.play("attack")

	# Hit single target
	var _dmg: int = damage_system.apply_damage(
		class_system.stat_system.stats, target, {},
		target.get("defense") if target.get("defense") != null else 0
	)

	# Ledakan kecil AOE di posisi musuh
	var hit_pos: Vector2 = target.global_position
	attack_area.show_circle_at(hit_pos, SPLASH_RADIUS, Color(0.6, 0.1, 1.0, 0.28), 0.22)
	# Splash damage ke musuh lain di sekitar titik ledakan
	for enemy in enemies_in_scene:
		if not is_instance_valid(enemy): continue
		if enemy == target: continue
		if hit_pos.distance_to(enemy.global_position) <= SPLASH_RADIUS:
			damage_system.apply_damage(
				class_system.stat_system.stats, enemy,
				{"damage_mult": 0.4}, # splash 40% dmg
				enemy.get("defense") if enemy.get("defense") != null else 0
			)

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

		# ── Soul Mark ────────────────────────────────────
		"necromancer_mark":
			anim.play("skill_1")
			# Tampilkan area mark di sekitar necromancer (cari musuh terdekat)
			attack_area.show_circle(
				180.0, Color(0.5, 0.0, 1.0, 0.12), 0.3
			)
			_mark_nearest_enemy(data.get("mark_duration", 15.0))
			await get_tree().create_timer(0.4).timeout

		# ── Dark Circle ──────────────────────────────────
		"necromancer_dark_circle":
			anim.play("skill_2")
			# Tampilkan lingkaran area lebih lama agar kelihatan jelas
			attack_area.show_circle(
				data.get("radius", 90.0),
				Color(0.4, 0.0, 0.8, 0.30),
				0.40
			)
			await get_tree().create_timer(0.2).timeout
			damage_system.apply_aoe_damage(
				class_system.stat_system.stats,
				global_position, data.get("radius", 90.0),
				enemies_in_scene, data
			)
			await get_tree().create_timer(0.4).timeout

		# ── Bone Shield ──────────────────────────────────
		"necromancer_bone_shield":
			anim.play("skill_1")
			# Visual shield aura mengelilingi necromancer
			attack_area.show_circle(
				40.0, Color(0.8, 0.8, 1.0, 0.25),
				data.get("buff_duration", 10.0)
			)
			var shield_hp: int = int(class_system.max_hp * data.get("shield_pct", 0.20))
			# Simpan shield, akan dikurangi sebelum HP saat take_damage
			_shield_hp = shield_hp
			await get_tree().create_timer(data.get("buff_duration", 10.0)).timeout
			_shield_hp = 0
			await get_tree().create_timer(0.4).timeout

		# ── Dark Empowerment ─────────────────────────────
		"necromancer_summon_buff":
			anim.play("skill_2")
			attack_area.show_circle(
				70.0, Color(0.3, 0.0, 0.6, 0.20), 0.4
			)
			class_system.stat_system.apply_summon_buff_pct(data.get("buff_pct", 0.40))
			await get_tree().create_timer(data.get("buff_duration", 8.0)).timeout
			class_system.stat_system.remove_summon_buff_pct(data.get("buff_pct", 0.40))
			await get_tree().create_timer(0.4).timeout

		# ── Death Nova ───────────────────────────────────
		"necromancer_death_nova":
			anim.play("skill_2")
			attack_area.show_circle(
				data.get("radius", 150.0),
				Color(0.2, 0.0, 0.5, 0.28),
				0.50
			)
			await get_tree().create_timer(0.3).timeout
			# Hit semua musuh di area
			for enemy in enemies_in_scene:
				if not is_instance_valid(enemy): continue
				if global_position.distance_to(enemy.global_position) <= data.get("radius", 150.0):
					damage_system.apply_damage(
						class_system.stat_system.stats, enemy, data,
						enemy.get("defense") if enemy.get("defense") != null else 0
					)
					# Musuh yang mati karena nova ini → emit sinyal summon
					# (enemy_base sudah emit on_died yang dihandle spawner)
			await get_tree().create_timer(0.4).timeout

# ──────────────────────────────────────────────────────────
# TIMERS
var _shield_hp: int = 0

func _tick_timers(delta: float) -> void:
	if attack_cooldown > 0.0: attack_cooldown -= delta
	if is_stunned:
		stun_timer -= delta
		if stun_timer <= 0.0: is_stunned = false

	# Passive summon berkala
	if skill_system != null:
		passive_timer += delta
		if passive_timer >= PASSIVE_INTERVAL:
			passive_timer = 0.0
			emit_signal("request_passive_summon")

# ──────────────────────────────────────────────────────────
# DAMAGE MASUK
func take_damage(amount: int) -> void:
	if is_dead or class_system == null: return
	# Serap shield dulu
	if _shield_hp > 0:
		var absorbed: int = min(_shield_hp, amount)
		_shield_hp -= absorbed
		amount     -= absorbed
		if amount <= 0: return
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
func _mark_nearest_enemy(duration: float) -> void:
	var nearest: Node = null
	var nearest_dist: float = INF
	for enemy in enemies_in_scene:
		if not is_instance_valid(enemy): continue
		var d: float = global_position.distance_to(enemy.global_position)
		if d < nearest_dist:
			nearest_dist = d
			nearest = enemy
	if nearest and nearest.has_method("apply_mark"):
		nearest.apply_mark(duration)

func apply_stun(duration: float) -> void:
	is_stunned = true
	stun_timer = duration

func _update_facing(dir: Vector2) -> void:
	if dir.x > 0.05:
		facing_right = true
	elif dir.x < -0.05:
		facing_right = false
	anim.flip_h = facing_right

func _update_animation(dir: Vector2) -> void:
	if is_attacking: return
	if dir.length() > 0.1:
		anim.play("walk")
	else:
		anim.play("idle")
