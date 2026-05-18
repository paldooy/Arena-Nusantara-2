extends CharacterBody2D

# ============================================================
# summon_unit.gd
# Unit summon Necromancer — cari musuh terdekat, serang otomatis
# ============================================================

var base_damage: int = 12
var base_hp:     int = 60
var move_speed: float = 90.0
var attack_range: float = 50.0
var current_hp: int = 60
var max_hp: int = 60
var attack_interval: float = 1.5

var summon_damage_pct: float = 1.0  # dari stat_system
var summon_hp_pct: float = 1.0

var target_enemy: Node = null
var attack_timer: float = 0.0
var owner_player: Node = null
var buff_fx: AnimatedSprite2D = null
var mark_fx: AnimatedSprite2D = null

const NECRO_SCENE: PackedScene = preload("res://scenes/characters/Necromancer.tscn")
static var _necro_frames: SpriteFrames = null

@onready var anim_sprite: AnimatedSprite2D = $AnimatedSprite2D

func _ready() -> void:
	add_to_group("summons")

func setup(dmg: int, hp: int, dmg_pct: float, hp_pct: float) -> void:
	base_damage      = dmg
	base_hp          = hp
	summon_damage_pct = dmg_pct
	summon_hp_pct    = hp_pct
	max_hp           = int(base_hp * hp_pct)
	current_hp       = max_hp

func apply_stat_bonuses(dmg_pct: float, hp_pct: float) -> void:
	var hp_ratio: float = float(current_hp) / float(max_hp) if max_hp > 0 else 1.0
	summon_damage_pct = dmg_pct
	summon_hp_pct    = hp_pct
	max_hp           = int(base_hp * hp_pct)
	current_hp       = max(1, int(max_hp * hp_ratio))

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

func set_marked(active: bool) -> void:
	if active:
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
	else:
		if mark_fx and is_instance_valid(mark_fx):
			mark_fx.queue_free()
			mark_fx = null

func _physics_process(delta: float) -> void:
	_find_target()
	if target_enemy == null or not is_instance_valid(target_enemy):
		# Ikuti player jika tidak ada target
		_follow_owner(delta)
		return

	var dist: float = global_position.distance_to(target_enemy.global_position)

	if dist > attack_range:
		var dir: Vector2 = (target_enemy.global_position - global_position).normalized()
		velocity = dir * move_speed
		move_and_slide()
		anim_sprite.play("walk")
	else:
		velocity = Vector2.ZERO
		anim_sprite.play("idle")
		attack_timer -= delta
		if attack_timer <= 0.0:
			_attack()
			attack_timer = attack_interval

func _find_target() -> void:
	var enemies = get_tree().get_nodes_in_group("enemies")
	var nearest: Node = null
	var nearest_dist: float = INF
	for enemy in enemies:
		if not is_instance_valid(enemy):
			continue
		var d: float = global_position.distance_to(enemy.global_position)
		if d < nearest_dist:
			nearest_dist = d
			nearest = enemy
	target_enemy = nearest

func _attack() -> void:
	if target_enemy == null or not is_instance_valid(target_enemy):
		return
	var final_dmg: int = max(1, int(base_damage * summon_damage_pct))
	if target_enemy.has_method("take_damage"):
		target_enemy.take_damage(final_dmg)
	anim_sprite.play("attack")

func _follow_owner(_delta: float) -> void:
	if owner_player == null:
		return
	var dist: float = global_position.distance_to(owner_player.global_position)
	if dist > 80.0:
		var dir: Vector2 = (owner_player.global_position - global_position).normalized()
		velocity = dir * move_speed
		move_and_slide()

func take_damage(amount: int) -> void:
	current_hp -= amount
	if current_hp <= 0:
		queue_free()

func _get_necro_frames() -> SpriteFrames:
	if _necro_frames != null:
		return _necro_frames
	var inst := NECRO_SCENE.instantiate()
	var sprite := inst.get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
	if sprite:
		_necro_frames = sprite.sprite_frames
	inst.free()
	return _necro_frames
