extends "res://scripts/enemy_base.gd"

# ============================================================
# leak.gd
# BOSS FINAL — Leak (mitologi Bali)
# Ciri khas:
#   - HP sangat besar (2500)
#   - Melee kuat
#   - Setiap 8 detik: serangan area api (AOE lingkaran besar)
#   - Saat HP < 50%: kecepatan naik 30%
# ============================================================

const AOE_INTERVAL:   float = 8.0
const AOE_RADIUS:     float = 120.0
const AOE_DMG_MULT:   float = 1.5

var aoe_timer:        float = AOE_INTERVAL
var phase2_triggered: bool  = false

func _ready() -> void:
	super._ready()
	if hp_bar:
		hp_bar.modulate = Color(1.0, 0.3, 0.0)   # oranye api

func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	_tick_aoe(delta)
	_check_phase2()

func _tick_aoe(delta: float) -> void:
	if is_stunned or player == null: return
	aoe_timer -= delta
	if aoe_timer <= 0.0:
		aoe_timer = AOE_INTERVAL
		_do_aoe_attack()

func _do_aoe_attack() -> void:
	# Visual: modulate kilat merah sesaat
	modulate = Color(1.0, 0.4, 0.0)
	await get_tree().create_timer(0.15).timeout
	if not is_instance_valid(self): return
	modulate = Color.WHITE

	# Damage ke semua enemy group "player" di radius
	var targets = get_tree().get_nodes_in_group("player")
	targets += get_tree().get_nodes_in_group("summons")
	for t in targets:
		if not is_instance_valid(t): continue
		if global_position.distance_to(t.global_position) <= AOE_RADIUS:
			if t.has_method("take_damage"):
				t.take_damage(int(damage * AOE_DMG_MULT))

func _check_phase2() -> void:
	if phase2_triggered: return
	if float(current_hp) / float(max_hp) < 0.50:
		phase2_triggered = true
		move_speed *= 1.30
		print("[Leak] PHASE 2 — speed naik!")
		# Visual: modulate berkedip ungu
		modulate = Color(0.8, 0.2, 1.0)
		await get_tree().create_timer(0.5).timeout
		if is_instance_valid(self): modulate = Color.WHITE

func _get_projectile_color() -> Color:
	return Color(1.0, 0.4, 0.0)   # oranye api (tidak dipakai karena melee)
