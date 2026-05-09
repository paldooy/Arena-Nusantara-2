extends CharacterBody2D

# ============================================================
# enemy_base.gd
# AI gerak ke player, terima damage, mati → emit EXP
# Di-inherit oleh Slime, Goblin, Skeleton, DarkKnight, Boss
# ============================================================

signal on_died(enemy_node: Node, enemy_type: int)

# Di-set oleh spawner saat instantiate
var enemy_type: int = 0       # EnemyBalance.EnemyType
var max_hp: int = 30
var current_hp: int = 30
var damage: int = 5
var move_speed: float = 60.0
var attack_range: float = 40.0
var defense: int = 0
var exp_reward: int = 22

# State
var is_marked: bool = false     # untuk Soul Mark Necromancer
var is_stunned: bool = false
var stun_timer: float = 0.0
var attack_cooldown: float = 0.0
const ATTACK_INTERVAL: float = 1.2  # detik antar serangan

var player: Node = null

@onready var anim_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var hp_bar: ProgressBar = $HpBar

func _ready() -> void:
	add_to_group("enemies")
	hp_bar.max_value = max_hp
	hp_bar.value = current_hp
	# Cari player di scene
	await get_tree().process_frame
	var players = get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		player = players[0]

func setup(stats: Dictionary, type: int) -> void:
	# Dipanggil spawner setelah instantiate
	enemy_type  = type
	max_hp      = stats.get("hp",     max_hp)
	current_hp  = max_hp
	damage      = stats.get("damage", damage)
	move_speed  = stats.get("speed",  move_speed)
	attack_range= stats.get("attack_range", attack_range)
	exp_reward  = stats.get("exp",    exp_reward)
	if hp_bar:
		hp_bar.max_value = max_hp
		hp_bar.value = current_hp

func _physics_process(delta: float) -> void:
	_tick_stun(delta)
	if is_stunned or player == null:
		return

	var dist: float = global_position.distance_to(player.global_position)

	if dist > attack_range:
		# Gerak ke player
		var dir: Vector2 = (player.global_position - global_position).normalized()
		velocity = dir * move_speed
		move_and_slide()
		anim_sprite.play("walk")
		anim_sprite.flip_h = velocity.x < 0
	else:
		# Dalam range serangan
		velocity = Vector2.ZERO
		anim_sprite.play("idle")
		attack_cooldown -= delta
		if attack_cooldown <= 0.0:
			_attack_player()
			attack_cooldown = ATTACK_INTERVAL

func _attack_player() -> void:
	if player and player.has_method("take_damage"):
		player.take_damage(damage)
	anim_sprite.play("attack")

# ─── TERIMA DAMAGE ────────────────────────────────────────
func take_damage(amount: int) -> void:
	current_hp -= amount
	current_hp = max(current_hp, 0)
	if hp_bar:
		hp_bar.value = current_hp
	if current_hp <= 0:
		_die()

func _die() -> void:
	emit_signal("on_died", self, enemy_type)
	queue_free()

# ─── MARK (Soul Mark Necromancer) ─────────────────────────
func apply_mark(duration: float) -> void:
	is_marked = true
	# Visual: tampilkan indikator mark (opsional, pakai modulate)
	modulate = Color(0.6, 0.2, 1.0)
	await get_tree().create_timer(duration).timeout
	if is_instance_valid(self):
		is_marked = false
		modulate = Color.WHITE

# ─── STUN ─────────────────────────────────────────────────
func apply_stun(duration: float) -> void:
	is_stunned = true
	stun_timer = duration

func _tick_stun(delta: float) -> void:
	if is_stunned:
		stun_timer -= delta
		if stun_timer <= 0.0:
			is_stunned = false
