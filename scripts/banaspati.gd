extends "res://scripts/enemy_base.gd"

# ============================================================
# banaspati.gd — Tier 2 (Mid Game)
#
# Musuh ranged. Menembakkan bola api ke TITIK POSISI player
# pada saat ditembakkan (bukan tracking/homing).
#
# Ketika bola api mencapai titik target ATAU mengenai player:
#   → Meledak dan meninggalkan area api (FireZone)
#   → FireZone bertahan 3 detik, damage per 0.5 detik
#
# Banaspati tidak mendekat ke player — dia berhenti di luar
# attack_range dan menembak dari sana.
# ============================================================

# Overriden — Banaspati tidak maju ke dalam jarak melee
# Dia berhenti di attack_range dan menembak terus

const FIRE_ZONE_DAMAGE_TICK: float = 0.5   # interval damage di area api
const FIRE_ZONE_DURATION:    float = 3.0
const FIRE_ZONE_RADIUS:      float = 40.0

func _ready() -> void:
	super._ready()
	is_ranged = true     # aktifkan mode ranged di enemy_base
	if hp_bar:
		hp_bar.modulate = Color(1.0, 0.5, 0.1)   # oranye api

# Override _do_attack dari enemy_base — tembak bola api
func _do_attack() -> void:
	anim_sprite.play("attack")
	if player and is_instance_valid(player):
		_fire_projectile(player.global_position)

# ─── TEMBAK BOLA API ────────────────────────────────────────
func _fire_projectile(target_world_pos: Vector2) -> void:
	var proj := _FireBall.new()
	proj.global_position  = global_position
	proj.target_pos       = target_world_pos
	proj.travel_speed     = 180.0
	proj.damage           = damage
	proj.zone_duration    = FIRE_ZONE_DURATION
	proj.zone_radius      = FIRE_ZONE_RADIUS
	proj.zone_dmg_tick    = FIRE_ZONE_DAMAGE_TICK
	proj.player_ref       = player

	# Tambahkan ke scene utama (bukan sebagai anak Banaspati)
	# agar tidak ikut terhapus saat Banaspati mati
	get_tree().current_scene.add_child(proj)

# ─── INNER CLASS: Bola Api ──────────────────────────────────
class _FireBall extends Node2D:
	var target_pos:    Vector2 = Vector2.ZERO
	var travel_speed:  float   = 180.0
	var damage:        int     = 8
	var zone_duration: float   = 3.0
	var zone_radius:   float   = 40.0
	var zone_dmg_tick: float   = 0.5
	var player_ref:    Node    = null
	var _exploded:     bool    = false

	# Visual bola api
	var _ball_rect: ColorRect = null

	func _ready() -> void:
		_ball_rect = ColorRect.new()
		_ball_rect.size     = Vector2(16, 16)
		_ball_rect.position = Vector2(-8, -8)
		_ball_rect.color    = Color(1.0, 0.55, 0.05)
		add_child(_ball_rect)

		# Tambahkan efek cahaya kecil (lingkaran lebih besar, transparan)
		var glow := ColorRect.new()
		glow.size     = Vector2(28, 28)
		glow.position = Vector2(-14, -14)
		glow.color    = Color(1.0, 0.3, 0.0, 0.25)
		add_child(glow)
		move_child(glow, 0)   # taruh di belakang bola

	func _process(delta: float) -> void:
		if _exploded: return

		# Gerak menuju target_pos
		var dir: Vector2 = (target_pos - global_position)
		var dist: float  = dir.length()

		if dist < 6.0:
			# Sudah sampai titik target → meledak
			_explode(global_position)
			return

		# Cek apakah mengenai player sebelum sampai target
		if player_ref and is_instance_valid(player_ref):
			var to_player: float = global_position.distance_to(player_ref.global_position)
			if to_player < 18.0:
				_explode(global_position)
				return

		# Gerak
		global_position += dir.normalized() * travel_speed * delta

	func _explode(explosion_pos: Vector2) -> void:
		if _exploded: return
		_exploded = true

		# Sembunyikan bola
		if _ball_rect: _ball_rect.visible = false

		# Buat FireZone di posisi ledakan
		var zone := _FireZone.new()
		zone.global_position = explosion_pos
		zone.damage          = damage
		zone.duration        = zone_duration
		zone.radius          = zone_radius
		zone.dmg_tick        = zone_dmg_tick
		zone.player_ref      = player_ref
		get_tree().current_scene.add_child(zone)

		queue_free()

# ─── INNER CLASS: Area Api (bertahan 3 detik) ────────────────
class _FireZone extends Node2D:
	var damage:     int   = 8
	var duration:   float = 3.0
	var radius:     float = 40.0
	var dmg_tick:   float = 0.5
	var player_ref: Node  = null

	var _elapsed:    float = 0.0
	var _tick_timer: float = 0.0
	var _bg:         ColorRect = null

	func _ready() -> void:
		# Visual area api — lingkaran kotak merah oranye transparan
		var diameter: float = radius * 2.0

		# Background area (transparan)
		_bg = ColorRect.new()
		_bg.size     = Vector2(diameter, diameter)
		_bg.position = Vector2(-radius, -radius)
		_bg.color    = Color(1.0, 0.30, 0.0, 0.38)
		add_child(_bg)

		# Border lebih terang
		var border := ColorRect.new()
		border.size     = Vector2(diameter - 4, diameter - 4)
		border.position = Vector2(-radius + 2, -radius + 2)
		border.color    = Color(1.0, 0.55, 0.0, 0.18)
		add_child(border)

	func _process(delta: float) -> void:
		_elapsed    += delta
		_tick_timer += delta

		# Fade out seiring waktu
		if _bg:
			var alpha_ratio: float = 1.0 - (_elapsed / duration)
			_bg.color.a = 0.38 * alpha_ratio

		# Damage tick
		if _tick_timer >= dmg_tick:
			_tick_timer = 0.0
			_deal_damage()

		if _elapsed >= duration:
			queue_free()

	func _deal_damage() -> void:
		if player_ref and is_instance_valid(player_ref):
			if global_position.distance_to(player_ref.global_position) <= radius:
				if player_ref.has_method("take_damage"):
					player_ref.take_damage(damage)
		# Juga damage summon Necromancer yang berdiri di area api
		var summons = get_tree().get_nodes_in_group("summons")
		for s in summons:
			if is_instance_valid(s) and global_position.distance_to(s.global_position) <= radius:
				if s.has_method("take_damage"):
					s.take_damage(int(damage * 0.5))
