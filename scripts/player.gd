extends CharacterBody2D

# ============================================================
# player.gd
# Input gerakan WASD, deteksi klik musuh, eksekusi skill
# ============================================================

const SPEED: float = 120.0

# Referensi ke sistem (diisi oleh game_world.gd setelah ready)
var class_system: Node = null
var skill_system: Node = null
var damage_system: Node = null

# Referensi ke semua musuh di scene (diisi spawner)
var enemies_in_scene: Array = []

# State
var is_stun: bool = false
var stun_timer: float = 0.0
var blood_aura_timer: float = 0.0
var is_blood_aura_active: bool = false
var passive_summon_timer: float = 0.0

@onready var anim_sprite: AnimatedSprite2D = $AnimatedSprite2D

func _ready() -> void:
	add_to_group("player")

func _process(delta: float) -> void:
	_tick_stun(delta)
	_tick_blood_aura(delta)
	_tick_passive_summon(delta)

func _physics_process(_delta: float) -> void:
	if is_stun:
		return
	var direction := Vector2(
		Input.get_axis("ui_left", "ui_right"),
		Input.get_axis("ui_up",   "ui_down")
	).normalized()
	velocity = direction * SPEED
	move_and_slide()
	_update_animation(direction)

func _input(event: InputEvent) -> void:
	if not GameManager.is_playing():
		return

	# Klik kiri = serang musuh yang diklik
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_try_attack_at(get_global_mouse_position())

	# Skill 1 — Q
	if event.is_action_pressed("skill_1"):
		_use_skill_1()
	# Skill 2 — E
	if event.is_action_pressed("skill_2"):
		_use_skill_2()
	# Skill 3 — R
	if event.is_action_pressed("skill_3"):
		_use_skill_3()

# ─── SERANGAN MANUAL ──────────────────────────────────────
func _try_attack_at(world_pos: Vector2) -> void:
	if class_system == null or damage_system == null:
		return
	for enemy in enemies_in_scene:
		if not is_instance_valid(enemy):
			continue
		if world_pos.distance_to(enemy.global_position) < 32.0:
			var dmg: int = damage_system.apply_damage(
				class_system.stat_system.stats,
				enemy,
				{},
				enemy.get("defense") if enemy.get("defense") != null else 0
			)
			# Lifesteal
			var ls: float = class_system.stat_system.get_stat("lifesteal")
			damage_system.apply_lifesteal(class_system, dmg, ls)
			break

# ─── SKILL 1 ──────────────────────────────────────────────
func _use_skill_1() -> void:
	if skill_system == null:
		return
	# Berserker: Whirlwind Slash | Necromancer: Soul Mark
	var learned: Array = skill_system.get_learned_skills()
	var skill_id: String = ""
	if "berserker_spin" in learned:
		skill_id = "berserker_spin"
	elif "necromancer_mark" in learned:
		skill_id = "necromancer_mark"

	if skill_id == "" or not skill_system.use_skill(skill_id):
		return

	var data: Dictionary = skill_system.get_skill_data(skill_id)

	if skill_id == "berserker_spin":
		# AOE di sekitar player
		damage_system.apply_aoe_damage(
			class_system.stat_system.stats,
			global_position,
			data.get("radius", 100.0),
			enemies_in_scene,
			data
		)
		anim_sprite.play("spin")

	elif skill_id == "necromancer_mark":
		# Tandai musuh terdekat
		_mark_nearest_enemy(data.get("mark_duration", 15.0))

# ─── SKILL 2 ──────────────────────────────────────────────
func _use_skill_2() -> void:
	if skill_system == null:
		return
	var learned: Array = skill_system.get_learned_skills()
	var skill_id: String = ""
	if "berserker_blood_aura" in learned:
		skill_id = "berserker_blood_aura"
	elif "necromancer_summon_buff" in learned:
		skill_id = "necromancer_summon_buff"

	if skill_id == "" or not skill_system.use_skill(skill_id):
		return

	var data: Dictionary = skill_system.get_skill_data(skill_id)

	if skill_id == "berserker_blood_aura":
		blood_aura_timer = data.get("buff_duration", 6.0)
		is_blood_aura_active = true
		class_system.stat_system.apply_blood_aura(blood_aura_timer)
		anim_sprite.play("aura")

	elif skill_id == "necromancer_summon_buff":
		_apply_summon_buff(data)

# ─── SKILL 3 ──────────────────────────────────────────────
func _use_skill_3() -> void:
	if skill_system == null:
		return
	var learned: Array = skill_system.get_learned_skills()
	var skill_id: String = ""
	if "berserker_ground_smash" in learned:
		skill_id = "berserker_ground_smash"
	elif "necromancer_dark_circle" in learned:
		skill_id = "necromancer_dark_circle"

	if skill_id == "" or not skill_system.use_skill(skill_id):
		return

	var data: Dictionary = skill_system.get_skill_data(skill_id)

	if skill_id == "berserker_ground_smash":
		damage_system.apply_aoe_damage(
			class_system.stat_system.stats,
			global_position,
			data.get("radius", 130.0),
			enemies_in_scene,
			data
		)
		# Stun musuh di dalam radius
		for enemy in enemies_in_scene:
			if is_instance_valid(enemy) and global_position.distance_to(enemy.global_position) <= data.get("radius", 130.0):
				if enemy.has_method("apply_stun"):
					enemy.apply_stun(data.get("stun_duration", 1.5))
		anim_sprite.play("ground_smash")

	elif skill_id == "necromancer_dark_circle":
		damage_system.apply_aoe_damage(
			class_system.stat_system.stats,
			global_position,
			data.get("radius", 90.0),
			enemies_in_scene,
			data
		)
		anim_sprite.play("dark_circle")

# ─── HELPERS ──────────────────────────────────────────────
func _mark_nearest_enemy(duration: float) -> void:
	var nearest: Node = null
	var nearest_dist: float = INF
	for enemy in enemies_in_scene:
		if not is_instance_valid(enemy):
			continue
		var d: float = global_position.distance_to(enemy.global_position)
		if d < nearest_dist:
			nearest_dist = d
			nearest = enemy
	if nearest and nearest.has_method("apply_mark"):
		nearest.apply_mark(duration)

func _apply_summon_buff(data: Dictionary) -> void:
	var buff_pct: float = data.get("buff_pct", 0.40)
	var duration: float = data.get("buff_duration", 8.0)
	class_system.stat_system.apply_summon_buff_pct(buff_pct)
	# Hilangkan buff setelah durasi lewat
	await get_tree().create_timer(duration).timeout
	class_system.stat_system.remove_summon_buff_pct(buff_pct)

# ─── TICK TIMERS ──────────────────────────────────────────
func _tick_stun(delta: float) -> void:
	if is_stun:
		stun_timer -= delta
		if stun_timer <= 0.0:
			is_stun = false

func _tick_blood_aura(delta: float) -> void:
	if is_blood_aura_active:
		blood_aura_timer -= delta
		if blood_aura_timer <= 0.0:
			is_blood_aura_active = false
			class_system.stat_system.remove_blood_aura()

func _tick_passive_summon(delta: float) -> void:
	if skill_system == null:
		return
	if "necromancer_passive" not in skill_system.get_learned_skills():
		return
	var data: Dictionary = skill_system.get_skill_data("necromancer_passive")
	passive_summon_timer += delta
	if passive_summon_timer >= data.get("spawn_interval", 30.0):
		passive_summon_timer = 0.0
		_try_spawn_passive_summon()

func _try_spawn_passive_summon() -> void:
	# Sinyal ke game_world untuk spawn summon
	emit_signal("request_passive_summon")

signal request_passive_summon()

# ─── DAMAGE DARI MUSUH ────────────────────────────────────
func take_damage(amount: int) -> void:
	if class_system == null:
		return
	class_system.take_damage(amount)
	if not class_system.is_alive():
		GameManager.end_game(false)

func heal(amount: int) -> void:
	if class_system:
		class_system.heal(amount)

# ─── ANIMASI ──────────────────────────────────────────────
func _update_animation(direction: Vector2) -> void:
	if direction.length() > 0.1:
		anim_sprite.play("walk")
		anim_sprite.flip_h = direction.x < 0
	else:
		anim_sprite.play("idle")
