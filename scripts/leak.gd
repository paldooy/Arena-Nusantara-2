extends "res://scripts/enemy_base.gd"

# ============================================================
# leak.gd — Boss Final
# HP 2500, melee kuat, AOE api setiap 8 detik
# Fase 2 saat HP < 50%: kecepatan naik 30%
# ============================================================

const AOE_INTERVAL: float = 8.0
const AOE_RADIUS:   float = 120.0
const AOE_DMG_MULT: float = 1.5

var aoe_timer:         float = AOE_INTERVAL
var phase2_triggered:  bool  = false

func _ready() -> void:
	super._ready()
	if hp_bar:
		hp_bar.modulate = Color(1.0, 0.3, 0.0)

func _physics_process(delta: float) -> void:
	# FIX: wajib cek is_dying
	if is_dying: return
	super._physics_process(delta)
	_tick_aoe(delta)
	_check_phase2()

func _tick_aoe(delta: float) -> void:
	if is_dying or is_stunned or player == null: return
	aoe_timer -= delta
	if aoe_timer <= 0.0:
		aoe_timer = AOE_INTERVAL
		_do_aoe_attack()

func _do_aoe_attack() -> void:
	if is_dying: return
	modulate = Color(1.0, 0.4, 0.0)
	await get_tree().create_timer(0.15).timeout
	if not is_instance_valid(self) or is_dying: return
	modulate = Color.WHITE

	for t in get_tree().get_nodes_in_group("player") + get_tree().get_nodes_in_group("summons"):
		if is_instance_valid(t) and global_position.distance_to(t.global_position) <= AOE_RADIUS:
			if t.has_method("take_damage"):
				t.take_damage(int(damage * AOE_DMG_MULT))

func _check_phase2() -> void:
	if phase2_triggered or is_dying: return
	if float(current_hp) / float(max_hp) < 0.50:
		phase2_triggered = true
		move_speed *= 1.30
		print("[Leak] PHASE 2!")
		modulate = Color(0.8, 0.2, 1.0)
		await get_tree().create_timer(0.5).timeout
		if is_instance_valid(self) and not is_dying:
			modulate = Color.WHITE
