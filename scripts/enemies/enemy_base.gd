extends CharacterBody2D

# ============================================================
# enemy_base.gd  [REVISI v2]
# - Pathfinding pintar dengan NavigationAgent2D
#   (memutari batu, slime, musuh lain, obstacle apapun di NavMesh)
# - Tetap fallback ke direct movement bila NavigationServer belum siap
# ============================================================

signal on_died(enemy_node: Node, enemy_type: int)

const LAYER_PLAYER: int = 1
const LAYER_ENEMY:  int = 2
const LAYER_BOSS:   int = 4

var enemy_type:      int   = 0
var max_hp:          int   = 40
var current_hp:      int   = 40
var damage:          int   = 7
var move_speed:      float = 80.0
var attack_range:    float = 40.0
var defense:         int   = 0
var exp_reward:      int   = 25
var is_ranged:       bool  = false

var is_marked:       bool  = false
var is_stunned:      bool  = false
var is_dying:        bool  = false
var _in_attack_anim: bool  = false
var stun_timer:      float = 0.0
var attack_cooldown: float = 0.5
var is_ally:         bool  = false
var can_be_marked:   bool  = true

const ATTACK_INTERVAL: float = 1.4

var target: Node = null
var mark_fx: AnimatedSprite2D = null
var buff_fx: AnimatedSprite2D = null

const NECRO_SCENE: PackedScene = preload("res://scenes/characters/Necromancer.tscn")
static var _necro_frames: SpriteFrames = null

@onready var anim_sprite:  AnimatedSprite2D  = $AnimatedSprite2D
@onready var hp_bar:       ProgressBar       = $HpBar
@onready var nav_agent:    NavigationAgent2D = get_node_or_null("NavigationAgent2D") as NavigationAgent2D

func _ready() -> void:
	add_to_group("enemies")

	collision_layer = LAYER_ENEMY
	collision_mask  = LAYER_PLAYER

	hp_bar.max_value = max_hp
	hp_bar.value     = current_hp

	# Setup NavigationAgent2D
	if nav_agent:
		nav_agent.path_desired_distance    = 4.0
		nav_agent.target_desired_distance  = 12.0
		nav_agent.avoidance_enabled        = true
		nav_agent.radius                   = 14.0

	await get_tree().process_frame
	target = _find_target()

func setup(stats: Dictionary, type: int) -> void:
	enemy_type   = type
	max_hp       = stats.get("hp",           max_hp)
	current_hp   = max_hp
	damage       = stats.get("damage",       damage)
	move_speed   = stats.get("speed",        move_speed)
	attack_range = stats.get("attack_range", attack_range)
	defense      = stats.get("defense",      defense)
	exp_reward   = stats.get("exp",          exp_reward)
	is_ranged    = stats.get("is_ranged",    false)
	if hp_bar:
		hp_bar.max_value = max_hp
		hp_bar.value     = current_hp

func _find_target() -> Node:
	var candidates: Array = []
	if is_ally:
		candidates = get_tree().get_nodes_in_group("enemies")
	else:
		candidates = get_tree().get_nodes_in_group("player")
		candidates += get_tree().get_nodes_in_group("summons")
	var nearest: Node = null
	var nearest_dist: float = INF
	for c in candidates:
		if not is_instance_valid(c):
			continue
		var d: float = global_position.distance_to(c.global_position)
		if d < nearest_dist:
			nearest_dist = d
			nearest = c
	return nearest

func _physics_process(delta: float) -> void:
	if is_dying or not anim_sprite: return
	_tick_stun(delta)
	if is_stunned: return

	target = _find_target()
	if target == null: return

	var dist: float = global_position.distance_to(target.global_position)

	if dist > attack_range:
		if attack_cooldown < 0.5:
			attack_cooldown = 0.5
		_move_toward_target(target)
	else:
		velocity = Vector2.ZERO
		if not _in_attack_anim:
			anim_sprite.play("idle")
		attack_cooldown -= delta
		if attack_cooldown <= 0.0 and not _in_attack_anim:
			_do_attack()
			attack_cooldown = ATTACK_INTERVAL

# ─── MOVEMENT DENGAN PATHFINDING ───────────────────────────
func _move_toward_target(tgt: Node) -> void:
	if nav_agent and NavigationServer2D.get_maps().size() > 0:
		# Update destination ke target
		nav_agent.target_position = tgt.global_position

		if nav_agent.is_navigation_finished():
			velocity = Vector2.ZERO
			anim_sprite.play("idle")
			return

		# Ambil next waypoint dari NavMesh
		var next_pos: Vector2 = nav_agent.get_next_path_position()
		var dir: Vector2 = (next_pos - global_position).normalized()
		velocity = dir * move_speed
	else:
		# Fallback: jalan lurus jika NavMesh belum ready
		var dir: Vector2 = (tgt.global_position - global_position).normalized()
		velocity = dir * move_speed

	move_and_slide()
	anim_sprite.play("walk")
	anim_sprite.flip_h = velocity.x < 0

func _do_attack() -> void:
	if is_dying or _in_attack_anim: return
	anim_sprite.play("attack")
	if target and is_instance_valid(target) and target.has_method("take_damage"):
		target.take_damage(damage)

func take_damage(amount: int) -> void:
	if is_dying or not anim_sprite: return
	var final_dmg: int = max(1, amount - defense)
	current_hp -= final_dmg
	current_hp  = max(current_hp, 0)
	if hp_bar:
		hp_bar.value = current_hp
	if anim_sprite.animation != "attack" and not _in_attack_anim:
		if anim_sprite.sprite_frames.get_animation_names().has("hit"):
			anim_sprite.play("hit")
	if current_hp <= 0:
		_die()

func _die() -> void:
	if is_dying or not anim_sprite: return
	is_dying = true
	velocity = Vector2.ZERO
	remove_from_group("enemies")
	hp_bar.visible = false
	if mark_fx and is_instance_valid(mark_fx):
		mark_fx.queue_free()
	if buff_fx and is_instance_valid(buff_fx):
		buff_fx.queue_free()
	anim_sprite.play("dead")
	emit_signal("on_died", self, enemy_type)
	await anim_sprite.animation_finished
	await get_tree().create_timer(0.5).timeout
	if is_instance_valid(self):
		queue_free()

func apply_mark(duration: float) -> void:
	if is_marked or not can_be_marked: return
	is_marked = true
	if mark_fx == null:
		var frames: SpriteFrames = _get_necro_frames()
		if frames and frames.get_animation_names().has("mark"):
			mark_fx = AnimatedSprite2D.new()
			mark_fx.sprite_frames = frames
			mark_fx.animation = "mark"
			mark_fx.position = Vector2(0, -32)
			mark_fx.z_index = 5
			add_child(mark_fx)
			mark_fx.play("mark")

func set_faction_ally() -> void:
	if is_ally: return
	is_ally = true
	remove_from_group("enemies")
	add_to_group("summons")
	collision_layer = LAYER_PLAYER
	collision_mask  = LAYER_ENEMY

func set_buff_active(active: bool) -> void:
	if active:
		if buff_fx == null:
			var frames: SpriteFrames = _get_necro_frames()
			if frames and frames.get_animation_names().has("summon_buff"):
				buff_fx = AnimatedSprite2D.new()
				buff_fx.sprite_frames = frames
				buff_fx.animation = "summon_buff"
				buff_fx.position = Vector2(0, -20)
				buff_fx.z_index = 4
				add_child(buff_fx)
				buff_fx.play("summon_buff")
		elif buff_fx:
			buff_fx.visible = true
	else:
		if buff_fx and is_instance_valid(buff_fx):
			buff_fx.queue_free()
			buff_fx = null

func apply_stun(duration: float) -> void:
	if is_dying: return
	is_stunned = true
	stun_timer = duration

func _tick_stun(delta: float) -> void:
	if is_stunned:
		stun_timer -= delta
		if stun_timer <= 0.0: is_stunned = false

func get_stats_snapshot() -> Dictionary:
	return {
		"hp": max_hp,
		"damage": damage,
		"speed": move_speed,
		"attack_range": attack_range,
		"exp": exp_reward,
		"is_ranged": is_ranged,
		"defense": defense,
	}

func _get_necro_frames() -> SpriteFrames:
	if _necro_frames != null:
		return _necro_frames
	var inst := NECRO_SCENE.instantiate()
	var sprite := inst.get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
	if sprite:
		_necro_frames = sprite.sprite_frames
	inst.free()
	return _necro_frames
