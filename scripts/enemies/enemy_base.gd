extends CharacterBody2D

# ============================================================
# enemy_base.gd  [FIX — collision layer]
#
# LAYER & MASK di Godot Physics:
#   Layer 1 = Player
#   Layer 2 = Enemy
#   Layer 3 = Boss (bisa collide dengan semua)
#
# Enemy biasa (layer 2, mask 1):
#   - Berada di layer 2
#   - Hanya detect layer 1 (player) → sesama enemy tidak tabrakan
#   - Player (layer 1, mask 1|2) tetap bisa collide dengan enemy
#
# Boss (layer 3, mask 1|2|3):
#   - Collide dengan semua
#
# Layer diset via kode di _ready() karena .tscn tidak menyimpan
# collision_layer/mask secara reliable lintas import.
# ============================================================

signal on_died(enemy_node: Node, enemy_type: int)

# Konstanta layer — sesuaikan dengan Project Settings > Physics > 2D
const LAYER_PLAYER: int = 1   # bit 0 → value 1
const LAYER_ENEMY:  int = 2   # bit 1 → value 2
const LAYER_BOSS:   int = 4   # bit 2 → value 4

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
var attack_cooldown: float = 0.5   # initial delay 0.5s

const ATTACK_INTERVAL: float = 1.4

var player: Node = null

@onready var anim_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var hp_bar:      ProgressBar      = $HpBar

func _ready() -> void:
	add_to_group("enemies")

	# ── SET COLLISION LAYER ──────────────────────────────────
	# Enemy biasa: ada di layer ENEMY, hanya detect PLAYER
	# Sehingga sesama enemy TIDAK saling tabrakan
	collision_layer = LAYER_ENEMY
	collision_mask  = LAYER_PLAYER   # hanya mendeteksi/bertabrakan dengan player

	hp_bar.max_value = max_hp
	hp_bar.value     = current_hp
	await get_tree().process_frame
	var players = get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		player = players[0]

func setup(stats: Dictionary, type: int) -> void:
	enemy_type   = type
	max_hp       = stats.get("hp",           max_hp)
	current_hp   = max_hp
	damage       = stats.get("damage",       damage)
	move_speed   = stats.get("speed",        move_speed)
	attack_range = stats.get("attack_range", attack_range)
	exp_reward   = stats.get("exp",          exp_reward)
	is_ranged    = stats.get("is_ranged",    false)
	if hp_bar:
		hp_bar.max_value = max_hp
		hp_bar.value     = current_hp

func _physics_process(delta: float) -> void:
	if is_dying or not anim_sprite: return
	_tick_stun(delta)
	if is_stunned or player == null: return

	var dist: float = global_position.distance_to(player.global_position)

	if dist > attack_range:
		if attack_cooldown < 0.5:
			attack_cooldown = 0.5
		var dir: Vector2 = (player.global_position - global_position).normalized()
		velocity = dir * move_speed
		move_and_slide()
		anim_sprite.play("walk")
		anim_sprite.flip_h = velocity.x < 0
	else:
		velocity = Vector2.ZERO
		if not _in_attack_anim:
			anim_sprite.play("idle")
		attack_cooldown -= delta
		if attack_cooldown <= 0.0 and not _in_attack_anim:
			_do_attack()
			attack_cooldown = ATTACK_INTERVAL

func _do_attack() -> void:
	if is_dying or _in_attack_anim: return
	anim_sprite.play("attack")
	if player and is_instance_valid(player) and player.has_method("take_damage"):
		player.take_damage(damage)

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
	anim_sprite.play("dead")
	emit_signal("on_died", self, enemy_type)
	await anim_sprite.animation_finished
	await get_tree().create_timer(0.5).timeout
	if is_instance_valid(self):
		queue_free()

func apply_mark(duration: float) -> void:
	is_marked = true
	modulate  = Color(0.6, 0.2, 1.0)
	await get_tree().create_timer(duration).timeout
	if is_instance_valid(self) and not is_dying:
		is_marked = false
		modulate  = Color.WHITE

func apply_stun(duration: float) -> void:
	if is_dying: return
	is_stunned = true
	stun_timer = duration

func _tick_stun(delta: float) -> void:
	if is_stunned:
		stun_timer -= delta
		if stun_timer <= 0.0: is_stunned = false
