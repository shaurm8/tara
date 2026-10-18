class_name AkWeapon
extends Weapon

const FIRE_RATE: float = 0.09
const SPREAD_ANGLE: float = deg_to_rad(4.0)
const SHOT_COST: float = 1.0
const DAMAGE: float = 8.0
const BULLET_SPEED: float = 1350.0
const RAY_LENGTH: float = 300.0
const RECOIL: float = 2.2
const RECOIL_OUT_TIME: float = 0.03
const RECOIL_BACK_TIME: float = 0.06
const SHAKE_INTENSITY: float = 0.4
const SHAKE_DURATION: float = 0.08
const SMOKE_COUNT: int = 3

func _init() -> void:
	anim_prefix = "ak_"

func has_ammo() -> bool:
	return hands.ammo[type] >= SHOT_COST

## АК стреляет по удержанию кнопки
func physics_update(_delta: float) -> void:
	if hands.is_attack_pressed() and hands.shoot_cooldown <= 0.0:
		shoot()

func shoot() -> void:
	if not hands.spend(type, SHOT_COST): return
	hands.shoot_cooldown = FIRE_RATE
	player.start_shake(SHAKE_INTENSITY, SHAKE_DURATION)
	var muzzle := hands.get_muzzle_position()
	var base := hands.aim_world()
	_spawn_smoke(muzzle, base)
	_play_recoil(base)
	_fire_bullet(muzzle, base)

func _spawn_smoke(muzzle: Vector2, base: float) -> void:
	if not hands.smoke_scene: return
	var base_dir := Vector2.from_angle(base)
	for j in SMOKE_COUNT:
		var smoke_pos := muzzle + Vector2(randf_range(-2.0, 3.0), randf_range(5.0, 6.0))
		var smoke = hands.spawn(hands.smoke_scene, smoke_pos)
		smoke.rotation = randf_range(0.0, TAU)
		smoke.scale = Vector2.ONE
		var final_pos: Vector2 = smoke_pos + base_dir * randf_range(16.0, 42.0) + base_dir.rotated(PI / 2.0) * randf_range(-14.0, 14.0) + Vector2(0.0, -randf_range(14.0, 26.0))
		var duration := randf_range(0.38, 0.65)
		var stween = smoke.create_tween().set_parallel(true)
		stween.tween_property(smoke, "position", final_pos, duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		stween.tween_property(smoke, "rotation", smoke.rotation + randf_range(-PI, PI), duration)
		stween.tween_property(smoke, "modulate:a", 0.0, duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)

func _play_recoil(base: float) -> void:
	hands.hands_tween = hands.new_tween(hands.hands_tween)
	hands.hands_tween.tween_property(hands, "position", hands.origin_position - Vector2.from_angle(base) * RECOIL, RECOIL_OUT_TIME).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	hands.hands_tween.tween_property(hands, "position", hands.origin_position, RECOIL_BACK_TIME).set_trans(Tween.TRANS_SPRING)

func _fire_bullet(muzzle: Vector2, base: float) -> void:
	var angle := base + randf_range(-SPREAD_ANGLE / 2.0, SPREAD_ANGLE / 2.0)
	var dir := Vector2.from_angle(angle)
	var pos := muzzle + dir * randf_range(-10.0, 14.0)
	if hands.bullet_scene:
		var bullet = hands.spawn(hands.bullet_scene, pos)
		bullet.rotation = angle
		if "velocity" in bullet: bullet.velocity = dir * BULLET_SPEED * randf_range(0.88, 1.12)
	else:
		var space := hands.get_world_2d().direct_space_state
		var query := PhysicsRayQueryParameters2D.create(pos, pos + dir * RAY_LENGTH)
		query.exclude = [player.get_rid()]
		var hit := space.intersect_ray(query)
		if hit and hit.collider.has_method("take_damage"):
			hit.collider.take_damage(DAMAGE)
			hands.spawn_shotgun_hit_blood(hit.position, dir)
