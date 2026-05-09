extends CharacterBody2D

# ============================================================
# summon_unit.gd
# Unit summon Necromancer — cari musuh terdekat, serang otomatis
# ============================================================

var base_damage:       int   = 12
var move_speed:        float = 90.0
var attack_range:      float = 50.0
var current_hp:        int   = 60
var max_hp:            int   = 60
var attack_interval:   float = 1.5

var summon_damage_pct: float = 1.0
var summon_hp_pct:     float = 1.0

var target_enemy: Node = null
var attack_timer: float = 0.0
var owner_player: Node  = null

@onready var anim_sprite: AnimatedSprite2D = $AnimatedSprite2D

func _ready() -> void:
	add_to_group("summons")

func setup(dmg: int, hp: int, dmg_pct: float, hp_pct: float) -> void:
	base_damage       = dmg
	summon_damage_pct = dmg_pct
	summon_hp_pct     = hp_pct
	max_hp            = int(hp * hp_pct)
	current_hp        = max_hp

func _physics_process(delta: float) -> void:
	_find_target()

	if target_enemy == null or not is_instance_valid(target_enemy):
		_follow_owner(delta)
		return

	var dist: float = global_position.distance_to(target_enemy.global_position)

	if dist > attack_range:
		var dir: Vector2 = (target_enemy.global_position - global_position).normalized()
		velocity = dir * move_speed
		move_and_slide()
		if anim_sprite.sprite_frames and anim_sprite.sprite_frames.has_animation("walk"):
			anim_sprite.play("walk")
		anim_sprite.flip_h = velocity.x < 0
	else:
		velocity = Vector2.ZERO
		move_and_slide()
		if anim_sprite.sprite_frames and anim_sprite.sprite_frames.has_animation("idle"):
			anim_sprite.play("idle")
		attack_timer -= delta
		if attack_timer <= 0.0:
			_attack()
			attack_timer = attack_interval

func _find_target() -> void:
	var enemies      = get_tree().get_nodes_in_group("enemies")
	var nearest: Node = null
	var nearest_dist: float = INF

	for enemy in enemies:
		if not is_instance_valid(enemy):
			continue
		var d: float = global_position.distance_to(enemy.global_position)
		if d < nearest_dist:
			nearest_dist = d
			nearest      = enemy

	target_enemy = nearest

func _attack() -> void:
	if target_enemy == null or not is_instance_valid(target_enemy):
		return
	var final_dmg: int = max(1, int(base_damage * summon_damage_pct))
	if target_enemy.has_method("take_damage"):
		target_enemy.take_damage(final_dmg)
	if anim_sprite.sprite_frames and anim_sprite.sprite_frames.has_animation("attack"):
		anim_sprite.play("attack")

func _follow_owner(_delta: float) -> void:
	if owner_player == null or not is_instance_valid(owner_player):
		return
	var dist: float = global_position.distance_to(owner_player.global_position)
	if dist > 80.0:
		var dir: Vector2 = (owner_player.global_position - global_position).normalized()
		velocity = dir * move_speed
		move_and_slide()
		anim_sprite.flip_h = velocity.x < 0

func take_damage(amount: int) -> void:
	current_hp -= amount
	if current_hp <= 0:
		queue_free()
