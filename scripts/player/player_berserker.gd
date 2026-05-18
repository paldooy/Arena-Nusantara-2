extends CharacterBody2D

# ============================================================
# player_berserker.gd  [REVISI v2]
# - Fix error blood_aura animation tidak ada → cek dulu exists
# - Skill visual area untuk semua skill
# - Animasi skill: spin, ground_smash (blood_aura hanya di aura_fx)
# ============================================================

signal request_passive_summon()

const ATTACK_RANGE:    float = 50.0
const BASE_INTERVAL:   float = 0.65

var class_system:     Node  = null
var skill_system:     Node  = null
var damage_system:    Node  = null
var enemies_in_scene: Array = []

var facing_right:      bool  = true
var is_dead:           bool  = false
var is_stunned:        bool  = false
var stun_timer:        float = 0.0
var attack_cooldown:   float = 0.0
var is_attacking:      bool  = false
var is_anim_locked:    bool  = false
var locked_anim:       String = ""
var blood_aura_active: bool  = false
var blood_aura_timer:  float = 0.0

@onready var anim:        AnimatedSprite2D = $AnimatedSprite2D
@onready var attack_area: Node2D           = $AttackArea
@onready var aura_fx:     AnimatedSprite2D = $Effects/Aura

func _ready() -> void:
	add_to_group("player")
	collision_layer = 1
	collision_mask  = 1 | 2 | 4
	anim.animation_finished.connect(_on_anim_finished)
	if aura_fx:
		aura_fx.visible = false
		aura_fx.stop()

func _process(delta: float) -> void:
	if is_dead or not GameManager.is_playing(): return
	_tick_timers(delta)

func _physics_process(_delta: float) -> void:
	if is_dead or is_stunned or not GameManager.is_playing(): return
	var dir := Vector2(
		Input.get_axis("move_left",  "move_right"),
		Input.get_axis("move_up",    "move_down")
	).normalized()
	var spd: float = class_system.stat_system.get_move_speed() if class_system else 145.0
	velocity = dir * spd
	move_and_slide()
	_update_facing(dir)
	_update_animation(dir)

func _input(event: InputEvent) -> void:
	if is_dead or not GameManager.is_playing(): return
	if event is InputEventMouseButton and event.pressed \
			and event.button_index == MOUSE_BUTTON_LEFT:
		if attack_cooldown <= 0.0:
			_do_basic_attack()
	if event.is_action_pressed("skill_1"):
		_use_skill_slot(0)
	if event.is_action_pressed("skill_2"):
		_use_skill_slot(1)

# ─── BASIC ATTACK ──────────────────────────────────────────
func _do_basic_attack() -> void:
	attack_cooldown = BASE_INTERVAL
	is_attacking    = true

	attack_area.show_arc(ATTACK_RANGE, facing_right, 0.5)

	for enemy in enemies_in_scene:
		if not is_instance_valid(enemy): continue
		var diff: Vector2 = enemy.global_position - global_position
		if diff.length() > ATTACK_RANGE: continue
		if facing_right  and diff.x < -8.0: continue
		if not facing_right and diff.x > 8.0: continue
		var dmg: int = damage_system.apply_damage(
			class_system.stat_system.stats, enemy, {},
			enemy.get("defense") if enemy.get("defense") != null else 0
		)
		_apply_lifesteal(dmg)

	anim.play("attack")
	await anim.animation_finished
	is_attacking = false

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
	var anim_name: String = skill_id.trim_prefix("berserker_")

	match skill_id:
		"berserker_spin":
			# Animasi: spin
			_is_lock_and_play(anim_name)
			var radius: float = 80.0
			attack_area.show_circle(radius, Color(1.0, 0.20, 0.10, 0.22), 0.5)
			await get_tree().create_timer(0.15).timeout
			var total_dmg: int = damage_system.apply_aoe_damage(
				class_system.stat_system.stats,
				global_position, radius, enemies_in_scene, data
			)
			var ls: float = class_system.stat_system.get_stat("lifesteal")
			if ls > 0.0 and total_dmg > 0:
				damage_system.apply_lifesteal(self, total_dmg, ls)
			await anim.animation_finished
			_unlock_anim_if(anim_name)

		"berserker_blood_aura":
			# Tidak ada animasi "blood_aura" di SpriteFrames utama,
			# efek visual hanya dari aura_fx node terpisah.
			# Jika suatu saat animasi ditambahkan, baris ini akan memakainya.
			if anim.sprite_frames.get_animation_names().has(anim_name):
				_is_lock_and_play(anim_name)

			if blood_aura_active:
				class_system.stat_system.remove_blood_aura()
			blood_aura_timer  = data.get("buff_duration", 6.0)
			blood_aura_active = true
			class_system.stat_system.apply_blood_aura(blood_aura_timer)

			# Tampilkan efek aura di node Effects/Aura
			if aura_fx:
				aura_fx.visible = true
				# Coba "aura" dulu (nama di .tscn), fallback ke nama lain
				if aura_fx.sprite_frames.get_animation_names().has("aura"):
					aura_fx.play("aura")
				elif aura_fx.sprite_frames.get_animation_names().has("blood_aura"):
					aura_fx.play("blood_aura")

			# Visual area lingkaran aura selama durasi buff
			attack_area.show_circle(55.0, Color(1.0, 0.05, 0.05, 0.14),
				data.get("buff_duration", 6.0))

			if anim.sprite_frames.get_animation_names().has(anim_name):
				await anim.animation_finished
				_unlock_anim_if(anim_name)

		"berserker_ground_smash":
			# Animasi: ground_smash
			_is_lock_and_play(anim_name)
			var smash_r: float = 100.0
			attack_area.show_circle(smash_r, Color(1.0, 0.30, 0.0, 0.22), 0.5)
			await get_tree().create_timer(0.25).timeout
			var total_dmg: int = damage_system.apply_aoe_damage(
				class_system.stat_system.stats,
				global_position, smash_r, enemies_in_scene, data
			)
			var ls: float = class_system.stat_system.get_stat("lifesteal")
			if ls > 0.0 and total_dmg > 0:
				damage_system.apply_lifesteal(self, total_dmg, ls)
			for enemy in enemies_in_scene:
				if not is_instance_valid(enemy): continue
				if global_position.distance_to(enemy.global_position) <= smash_r:
					if enemy.has_method("apply_stun"):
						enemy.apply_stun(data.get("stun_duration", 1.5))
			await anim.animation_finished
			_unlock_anim_if(anim_name)

# ─── TIMERS ────────────────────────────────────────────────
func _tick_timers(delta: float) -> void:
	if attack_cooldown > 0.0: attack_cooldown -= delta
	if is_stunned:
		stun_timer -= delta
		if stun_timer <= 0.0: is_stunned = false
	if blood_aura_active:
		blood_aura_timer -= delta
		if blood_aura_timer <= 0.0:
			blood_aura_active = false
			class_system.stat_system.remove_blood_aura()
			if aura_fx:
				aura_fx.stop()
				aura_fx.visible = false

func take_damage(amount: int) -> void:
	if is_dead or class_system == null: return
	class_system.take_damage(amount)
	if not is_attacking:
		if anim.sprite_frames.get_animation_names().has("hit"):
			_is_lock_and_play("hit")
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

func _apply_lifesteal(dmg: int) -> void:
	var ls: float = class_system.stat_system.get_stat("lifesteal")
	if ls > 0.0:
		damage_system.apply_lifesteal(class_system, dmg, ls)

func apply_stun(duration: float) -> void:
	is_stunned = true
	stun_timer = duration

func _update_facing(dir: Vector2) -> void:
	if dir.x > 0.05:    facing_right = true
	elif dir.x < -0.05: facing_right = false
	anim.flip_h = facing_right

func _update_animation(dir: Vector2) -> void:
	if is_attacking or is_anim_locked: return
	if dir.length() > 0.1: anim.play("walk")
	else:                   anim.play("idle")

func _is_lock_and_play(anim_name: String) -> void:
	if not anim.sprite_frames.get_animation_names().has(anim_name):
		return
	is_anim_locked = true
	locked_anim = anim_name
	anim.play(anim_name)

func _unlock_anim_if(anim_name: String) -> void:
	if locked_anim == anim_name:
		is_anim_locked = false
		locked_anim = ""

func _on_anim_finished() -> void:
	_unlock_anim_if(anim.animation)
