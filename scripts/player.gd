extends CharacterBody2D

# ============================================================
# player.gd
# Input gerakan WASD/Arrow, klik musuh untuk serang manual,
# eksekusi skill Q / E / R
# ============================================================

const SPEED: float = 120.0

# Referensi sistem — diisi oleh game_world.gd setelah _ready
var class_system:  Node = null
var skill_system:  Node = null
var damage_system: Node = null

# Daftar musuh aktif di scene — diperbarui oleh spawner
var enemies_in_scene: Array = []

# ─── STATE ────────────────────────────────────────────────
var is_stun: bool = false
var stun_timer: float = 0.0

var blood_aura_timer: float = 0.0
var is_blood_aura_active: bool = false

var passive_summon_timer: float = 0.0

# ─── SINYAL ───────────────────────────────────────────────
signal request_passive_summon()

# ─── CHILD NODES ──────────────────────────────────────────
@onready var anim_sprite: AnimatedSprite2D = $AnimatedSprite2D

# ──────────────────────────────────────────────────────────
func _ready() -> void:
	add_to_group("player")

# ─── PROCESS (timer tick) ─────────────────────────────────
func _process(delta: float) -> void:
	_tick_stun(delta)
	_tick_blood_aura(delta)
	_tick_passive_summon(delta)

# ─── PHYSICS (gerak) ──────────────────────────────────────
func _physics_process(_delta: float) -> void:
	if is_stun:
		velocity = Vector2.ZERO
		move_and_slide()
		return

	var direction := Vector2(
		Input.get_axis("ui_left", "ui_right"),
		Input.get_axis("ui_up",   "ui_down")
	).normalized()

	velocity = direction * SPEED
	move_and_slide()
	_update_animation(direction)

# ─── INPUT ────────────────────────────────────────────────
func _input(event: InputEvent) -> void:
	if not GameManager.is_playing():
		return

	# Klik kiri → serang musuh yang diklik
	if event is InputEventMouseButton \
			and event.pressed \
			and event.button_index == MOUSE_BUTTON_LEFT:
		_try_attack_at(get_global_mouse_position())

	# Skill Q
	if event.is_action_pressed("skill_1"):
		_use_skill_1()

	# Skill E
	if event.is_action_pressed("skill_2"):
		_use_skill_2()

	# Skill R
	if event.is_action_pressed("skill_3"):
		_use_skill_3()

# ─── SERANGAN MANUAL (klik musuh) ─────────────────────────
func _try_attack_at(world_pos: Vector2) -> void:
	if class_system == null or damage_system == null:
		return

	# Bersihkan referensi yang sudah tidak valid
	enemies_in_scene = enemies_in_scene.filter(func(e): return is_instance_valid(e))

	for enemy in enemies_in_scene:
		# Radius klik 36px — sesuaikan jika sprite musuh lebih besar
		if world_pos.distance_to(enemy.global_position) < 36.0:
			var def: int = int(enemy.get("defense")) if enemy.get("defense") != null else 0
			var dmg: int = damage_system.apply_damage(
				class_system.stat_system.stats,
				enemy,
				{},
				def
			)
			# Lifesteal
			var ls: float = class_system.stat_system.get_stat("lifesteal")
			damage_system.apply_lifesteal(class_system, dmg, ls)
			_play_attack_anim()
			break

# ─── SKILL 1 — Q ──────────────────────────────────────────
# Berserker : Whirlwind Slash (AOE sekitar player)
# Necromancer: Soul Mark (tandai musuh terdekat)
func _use_skill_1() -> void:
	if skill_system == null:
		return

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
		damage_system.apply_aoe_damage(
			class_system.stat_system.stats,
			global_position,
			data.get("radius", 100.0),
			enemies_in_scene,
			data
		)
		if anim_sprite.sprite_frames and anim_sprite.sprite_frames.has_animation("spin"):
			anim_sprite.play("spin")

	elif skill_id == "necromancer_mark":
		_mark_nearest_enemy(data.get("mark_duration", 15.0))

# ─── SKILL 2 — E ──────────────────────────────────────────
# Berserker : Blood Aura (buff ATK + lifesteal)
# Necromancer: Dark Empowerment (buff summon)
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
		if not is_blood_aura_active:
			blood_aura_timer = data.get("buff_duration", 6.0)
			is_blood_aura_active = true
			class_system.stat_system.apply_blood_aura(blood_aura_timer)
			if anim_sprite.sprite_frames and anim_sprite.sprite_frames.has_animation("aura"):
				anim_sprite.play("aura")

	elif skill_id == "necromancer_summon_buff":
		_apply_summon_buff(data)

# ─── SKILL 3 — R ──────────────────────────────────────────
# Berserker : Ground Smash (AOE besar + stun)
# Necromancer: Dark Circle (AOE lingkaran)
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
		var radius: float = data.get("radius", 130.0)
		damage_system.apply_aoe_damage(
			class_system.stat_system.stats,
			global_position,
			radius,
			enemies_in_scene,
			data
		)
		# Stun semua musuh dalam radius
		for enemy in enemies_in_scene:
			if is_instance_valid(enemy) \
					and global_position.distance_to(enemy.global_position) <= radius \
					and enemy.has_method("apply_stun"):
				enemy.apply_stun(data.get("stun_duration", 1.5))
		if anim_sprite.sprite_frames and anim_sprite.sprite_frames.has_animation("ground_smash"):
			anim_sprite.play("ground_smash")

	elif skill_id == "necromancer_dark_circle":
		damage_system.apply_aoe_damage(
			class_system.stat_system.stats,
			global_position,
			data.get("radius", 90.0),
			enemies_in_scene,
			data
		)
		if anim_sprite.sprite_frames and anim_sprite.sprite_frames.has_animation("dark_circle"):
			anim_sprite.play("dark_circle")

# ─── HELPER: MARK MUSUH TERDEKAT ──────────────────────────
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

	if nearest != null and nearest.has_method("apply_mark"):
		nearest.apply_mark(duration)

# ─── HELPER: BUFF SUMMON ──────────────────────────────────
func _apply_summon_buff(data: Dictionary) -> void:
	var buff_pct: float = data.get("buff_pct",      0.40)
	var duration: float = data.get("buff_duration", 8.0)
	class_system.stat_system.apply_summon_buff_pct(buff_pct)
	await get_tree().create_timer(duration).timeout
	if is_instance_valid(class_system):
		class_system.stat_system.remove_summon_buff_pct(buff_pct)

# ─── HELPER: ANIMASI SERANGAN DASAR ───────────────────────
func _play_attack_anim() -> void:
	if anim_sprite.sprite_frames == null:
		return
	if anim_sprite.sprite_frames.has_animation("attack"):
		anim_sprite.play("attack")

# ─── TICK: STUN ───────────────────────────────────────────
func _tick_stun(delta: float) -> void:
	if is_stun:
		stun_timer -= delta
		if stun_timer <= 0.0:
			is_stun = false

# ─── TICK: BLOOD AURA ─────────────────────────────────────
func _tick_blood_aura(delta: float) -> void:
	if is_blood_aura_active:
		blood_aura_timer -= delta
		if blood_aura_timer <= 0.0:
			is_blood_aura_active = false
			if class_system != null:
				class_system.stat_system.remove_blood_aura()

# ─── TICK: PASSIVE SUMMON (Necromancer) ───────────────────
func _tick_passive_summon(delta: float) -> void:
	if skill_system == null:
		return
	if "necromancer_passive" not in skill_system.get_learned_skills():
		return

	var data: Dictionary = skill_system.get_skill_data("necromancer_passive")
	passive_summon_timer += delta
	if passive_summon_timer >= data.get("spawn_interval", 30.0):
		passive_summon_timer = 0.0
		emit_signal("request_passive_summon")

# ─── TERIMA DAMAGE ────────────────────────────────────────
func take_damage(amount: int) -> void:
	if class_system == null:
		return
	class_system.take_damage(amount)
	if not class_system.is_alive():
		GameManager.end_game(false)

func heal(amount: int) -> void:
	if class_system != null:
		class_system.heal(amount)

# ─── ANIMASI GERAK ────────────────────────────────────────
func _update_animation(direction: Vector2) -> void:
	if anim_sprite.sprite_frames == null:
		return
	if direction.length() > 0.1:
		if anim_sprite.sprite_frames.has_animation("walk"):
			anim_sprite.play("walk")
		anim_sprite.flip_h = direction.x < 0
	else:
		if anim_sprite.sprite_frames.has_animation("idle"):
			anim_sprite.play("idle")
