extends "res://scripts/enemy_base.gd"

# ============================================================
# banaspati.gd — Tier 2 (Mid Game)
#
# Musuh ranged. Tembak bola api ke titik posisi player saat
# ditembakkan (bukan tracking).
#
# Bola api meledak saat mencapai target atau menyentuh player,
# meninggalkan area api 3 detik dengan damage per 0.5 detik.
# ============================================================

const FIRE_ZONE_DAMAGE_TICK: float = 0.5
const FIRE_ZONE_DURATION:    float = 3.0
const FIRE_ZONE_RADIUS:      float = 40.0

func _ready() -> void:
	super._ready()
	is_ranged = true
	if hp_bar:
		hp_bar.modulate = Color(1.0, 0.5, 0.1)

func _do_attack() -> void:
	if is_dying: return   # ← guard tambahan
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
	get_tree().current_scene.add_child(proj)

# ─── BOLA API ──────────────────────────────────────────────
class _FireBall extends Node2D:
	var target_pos:    Vector2 = Vector2.ZERO
	var travel_speed:  float   = 180.0
	var damage:        int     = 8
	var zone_duration: float   = 3.0
	var zone_radius:   float   = 40.0
	var zone_dmg_tick: float   = 0.5
	var player_ref:    Node    = null
	var _exploded:     bool    = false

	var _ball_rect: ColorRect = null

	func _ready() -> void:
		_ball_rect = ColorRect.new()
		_ball_rect.size     = Vector2(16, 16)
		_ball_rect.position = Vector2(-8, -8)
		_ball_rect.color    = Color(1.0, 0.55, 0.05)
		add_child(_ball_rect)

		var glow := ColorRect.new()
		glow.size     = Vector2(28, 28)
		glow.position = Vector2(-14, -14)
		glow.color    = Color(1.0, 0.3, 0.0, 0.25)
		add_child(glow)
		move_child(glow, 0)

	func _process(delta: float) -> void:
		if _exploded: return

		var dir: Vector2 = (target_pos - global_position)
		var dist: float  = dir.length()

		if dist < 6.0:
			_explode(global_position)
			return

		if player_ref and is_instance_valid(player_ref):
			var to_player: float = global_position.distance_to(player_ref.global_position)
			if to_player < 18.0:
				_explode(global_position)
				return

		global_position += dir.normalized() * travel_speed * delta

	func _explode(explosion_pos: Vector2) -> void:
		if _exploded: return
		_exploded = true

		if _ball_rect: _ball_rect.visible = false

		var zone := _FireZone.new()
		zone.global_position = explosion_pos
		zone.damage          = damage
		zone.duration        = zone_duration
		zone.radius          = zone_radius
		zone.dmg_tick        = zone_dmg_tick
		zone.player_ref      = player_ref
		get_tree().current_scene.add_child(zone)

		queue_free()

# ─── AREA API ──────────────────────────────────────────────
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
		var diameter: float = radius * 2.0

		_bg = ColorRect.new()
		_bg.size     = Vector2(diameter, diameter)
		_bg.position = Vector2(-radius, -radius)
		_bg.color    = Color(1.0, 0.30, 0.0, 0.38)
		add_child(_bg)

		var border := ColorRect.new()
		border.size     = Vector2(diameter - 4, diameter - 4)
		border.position = Vector2(-radius + 2, -radius + 2)
		border.color    = Color(1.0, 0.55, 0.0, 0.18)
		add_child(border)

	func _process(delta: float) -> void:
		_elapsed    += delta
		_tick_timer += delta

		if _bg:
			var alpha_ratio: float = 1.0 - (_elapsed / duration)
			_bg.color.a = 0.38 * alpha_ratio

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
		var summons = get_tree().get_nodes_in_group("summons")
		for s in summons:
			if is_instance_valid(s) and global_position.distance_to(s.global_position) <= radius:
				if s.has_method("take_damage"):
					s.take_damage(int(damage * 0.5))
