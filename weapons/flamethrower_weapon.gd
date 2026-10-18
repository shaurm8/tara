class_name FlamethrowerWeapon
extends Weapon

const FIRE_RATE: float = 0.018
const PARTICLES_PER_TICK: int = 2
const SPREAD_ANGLE: float = deg_to_rad(13.0)
const SPEED_MIN: float = 400.0
const SPEED_MAX: float = 650.0
const RAMP_UP_TIME: float = 0.12
const RAMP_DOWN_TIME: float = 0.15
const COST_PER_SEC: float = 10.0

var flame_heat: float = 0.0

func _init() -> void:
	anim_prefix = "flame_"

## Работает и когда оружие не выбрано: огонь должен плавно остывать
func always_update(delta: float) -> void:
	var fire: bool = hands.current_weapon == type and hands.is_attack_pressed() and hands.ammo[type] > 0.0
	if fire: hands.drain(type, COST_PER_SEC * delta)
	flame_heat = clampf(flame_heat + delta / (RAMP_UP_TIME if fire else -RAMP_DOWN_TIME), 0.0, 1.0)
	if fire and hands.shoot_cooldown <= 0.0: _spawn_flame_burst()

func _spawn_flame_burst() -> void:
	hands.shoot_cooldown = FIRE_RATE
	player.start_shake(0.35, 0.06)
	if not hands.flame_bullet_scene: return
	var muzzle := hands.get_muzzle_position()
	var base := hands.aim_world()
	var spread := SPREAD_ANGLE * lerpf(0.5, 1.0, flame_heat)
	var speed_mult := lerpf(0.4, 1.0, flame_heat)
	var target_scale := Vector2.ONE * lerpf(0.5, 1.0, flame_heat)

	for i in PARTICLES_PER_TICK:
		var angle := base + randf_range(-spread / 2.0, spread / 2.0)
		var dir := Vector2.from_angle(angle)
		var bullet = hands.spawn(hands.flame_bullet_scene, muzzle + dir * randf_range(0.0, 8.0))
		bullet.rotation = angle
		if "velocity" in bullet: bullet.velocity = dir * randf_range(SPEED_MIN, SPEED_MAX) * speed_mult
		bullet.scale = Vector2.ZERO
		bullet.modulate.a = 0.0
		var tween = bullet.create_tween().set_parallel(true)
		tween.tween_property(bullet, "scale", target_scale, 0.05).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tween.tween_property(bullet, "modulate:a", 1.0, 0.04)
