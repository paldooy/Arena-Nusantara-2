extends Node2D

# ============================================================
# attack_area.gd  [BARU]
# Visual area serangan — muncul sebentar lalu hilang.
# Digunakan untuk attack arc, AOE skill, lingkaran skill.
# ============================================================

@onready var polygon: Polygon2D   = $Polygon2D    # untuk arc / semicircle
@onready var circle:  Polygon2D   = $CirclePolygon # untuk lingkaran penuh

# Gambar arc setengah lingkaran (untuk basic attack Berserker)
# angle_start / angle_end dalam radian, misal -PI/2 .. PI/2 = sisi kanan
static func make_arc_points(radius: float, angle_start: float, angle_end: float, steps: int = 24) -> PackedVector2Array:
	var pts := PackedVector2Array()
	pts.append(Vector2.ZERO)  # pusat
	for i in range(steps + 1):
		var a: float = lerp(angle_start, angle_end, float(i) / steps)
		pts.append(Vector2(cos(a), sin(a)) * radius)
	return pts

# Gambar lingkaran penuh (untuk AOE skill)
static func make_circle_points(radius: float, steps: int = 32) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in range(steps):
		var a: float = (float(i) / steps) * TAU
		pts.append(Vector2(cos(a), sin(a)) * radius)
	return pts

# ─── API PUBLIK ────────────────────────────────────────────

# Tampilkan area arc (basic attack Berserker)
func show_arc(radius: float, facing_right: bool, duration: float = 0.18) -> void:
	var start_angle: float = -PI * 0.5   # -90°
	var end_angle:   float =  PI * 0.5   #  90°
	if not facing_right:
		start_angle += PI
		end_angle   += PI
	polygon.polygon = make_arc_points(radius, start_angle, end_angle)
	polygon.color   = Color(1.0, 0.15, 0.15, 0.30)   # merah transparan
	polygon.visible = true
	circle.visible  = false
	visible = true
	await get_tree().create_timer(duration).timeout
	if is_instance_valid(self):
		polygon.visible = false

# Tampilkan area lingkaran penuh (AOE skill)
func show_circle(radius: float, color: Color, duration: float = 0.22) -> void:
	circle.polygon  = make_circle_points(radius)
	circle.color    = color
	circle.visible  = true
	polygon.visible = false
	visible = true
	await get_tree().create_timer(duration).timeout
	if is_instance_valid(self):
		circle.visible = false

# Tampilkan lingkaran di posisi dunia tertentu (misal ledakan Necromancer)
func show_circle_at(world_pos: Vector2, radius: float, color: Color, duration: float = 0.25) -> void:
	global_position = world_pos
	show_circle(radius, color, duration)
