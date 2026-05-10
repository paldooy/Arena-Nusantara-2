extends CharacterBody2D

# ============================================================
# enemy_base.gd  [DIREVISI — Hantu Nusantara v2]
#
# Base class untuk semua musuh.
# Sistem proyektil TIDAK ada di sini — Banaspati punya sendiri.
#
# Child class yang extend ini:
#   pocong.gd     — melee biasa
#   banaspati.gd  — override _do_attack() dengan bola api
#   genderuwo.gd  — override _physics_process() dengan interval lebih lambat
#   leak.gd       — override dengan fase dan AOE berkala
# ============================================================

signal on_died(enemy_node: Node, enemy_type: int)

# ── Stat — diisi setup() dari spawner ──────────────────────
var enemy_type:       int   = 0
var max_hp:           int   = 40
var current_hp:       int   = 40
var damage:           int   = 7
var move_speed:       float = 80.0
var attack_range:     float = 40.0
var defense:          int   = 0
var exp_reward:       int   = 25
var is_ranged:        bool  = false

# ── State ──────────────────────────────────────────────────
var is_marked:        bool  = false
var is_stunned:       bool  = false
var stun_timer:       float = 0.0
var attack_cooldown:  float = 0.0
const ATTACK_INTERVAL: float = 1.4

var player: Node = null

@onready var anim_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var hp_bar:      ProgressBar      = $HpBar

func _ready() -> void:
	add_to_group("enemies")
	hp_bar.max_value = max_hp
	hp_bar.value     = current_hp
	# Tunggu 1 frame agar player sudah ada di scene tree
	await get_tree().process_frame
	var players = get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		player = players[0]

func setup(stats: Dictionary, type: int) -> void:
	enemy_type    = type
	max_hp        = stats.get("hp",           max_hp)
	current_hp    = max_hp
	damage        = stats.get("damage",       damage)
	move_speed    = stats.get("speed",        move_speed)
	attack_range  = stats.get("attack_range", attack_range)
	exp_reward    = stats.get("exp",          exp_reward)
	is_ranged     = stats.get("is_ranged",    false)
	if hp_bar:
		hp_bar.max_value = max_hp
		hp_bar.value     = current_hp

# ── AI UTAMA ───────────────────────────────────────────────
func _physics_process(delta: float) -> void:
	_tick_stun(delta)
	if is_stunned or player == null: return

	var dist: float = global_position.distance_to(player.global_position)

	if dist > attack_range:
		var dir: Vector2 = (player.global_position - global_position).normalized()
		velocity = dir * move_speed
		move_and_slide()
		anim_sprite.play("walk")
		anim_sprite.flip_h = velocity.x < 0
	else:
		velocity = Vector2.ZERO
		anim_sprite.play("idle")
		attack_cooldown -= delta
		if attack_cooldown <= 0.0:
			_do_attack()
			attack_cooldown = ATTACK_INTERVAL

# Override di child class untuk behavior berbeda
func _do_attack() -> void:
	anim_sprite.play("attack")
	if player and player.has_method("take_damage"):
		player.take_damage(damage)

# ── TERIMA DAMAGE ───────────────────────────────────────────
func take_damage(amount: int) -> void:
	var final_dmg: int = max(1, amount - defense)
	current_hp -= final_dmg
	current_hp  = max(current_hp, 0)
	if hp_bar:
		hp_bar.value = current_hp
	# Animasi hit — jangan interupsi kalau animasi attack sedang jalan
	if anim_sprite.animation != "attack":
		anim_sprite.play("hit")
	if current_hp <= 0:
		_die()

func _die() -> void:
	# Lepas dari group agar tidak di-target lagi
	remove_from_group("enemies")
	velocity = Vector2.ZERO
	anim_sprite.play("dead")
	emit_signal("on_died", self, enemy_type)
	await anim_sprite.animation_finished
	queue_free()

# ── MARK (Necromancer Soul Mark) ───────────────────────────
func apply_mark(duration: float) -> void:
	is_marked = true
	modulate  = Color(0.6, 0.2, 1.0)
	await get_tree().create_timer(duration).timeout
	if is_instance_valid(self):
		is_marked = false
		modulate  = Color.WHITE

# ── STUN ───────────────────────────────────────────────────
func apply_stun(duration: float) -> void:
	is_stunned = true
	stun_timer = duration

func _tick_stun(delta: float) -> void:
	if is_stunned:
		stun_timer -= delta
		if stun_timer <= 0.0: is_stunned = false
