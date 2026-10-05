extends CharacterBody2D

# === КОНСТАНТЫ ===
const SPEED: float = 147.9
const ACCELERATION: float = 774.6
const DECELERATION: float = 915.5
const AIR_ACCELERATION: float = 774.6
const AIR_DECELERATION: float = 845.1

const JUMP_FORCE: float = -257.0
const JUMP_CUT_MULTIPLIER: float = 0.5
const FAST_FALL_SPEED: float = 493.0
const COYOTE_TIME: float = 0.12
const JUMP_BUFFER_TIME: float = 0.06
const GRAVITY: float = 563.4
const MAX_FALL_SPEED: float = 422.5

const WALL_SLIDE_SPEED: float = 28.2
const WALL_JUMP_FORCE_X: float = 105.6
const WALL_JUMP_FORCE_Y: float = -221.8
const MAX_STEP_HEIGHT: float = 4.2

const MIN_AIM_DISTANCE: float = 20.0
const AIM_LIMIT: float = deg_to_rad(85.0)
const AIM_FORWARD_OFFSET: float = 3.0
const SHOTGUN_FIRE_RATE: float = 0.55
const PELLET_COUNT: int = 7
const SPREAD_ANGLE: float = deg_to_rad(18.0)
const AK_FIRE_RATE: float = 0.09
const AK_SPREAD_ANGLE: float = deg_to_rad(4.0)

const SLASH_ARC_HALF: float = deg_to_rad(58.0)
const SLASH_DURATION: float = 0.20
const SLASH_WINDUP_TIME: float = 0.03
const SLASH_ARC_RADIUS: float = 11.0
const SLASH_DASH_FORCE: float = 260.0
const SLASH_COOLDOWN_PADDING: float = 0.4
const SLASH_HIT_DAMAGE: float = 24.0
const SLASH_HIT_SHAKE_INTENSITY: float = 2.4
const SLASH_HIT_SHAKE_DURATION: float = 0.85
const COMBO_RESET_WINDOW: float = 0.6
const BLOOD_BURST_COUNT: int = 10
const BLOOD_DROPS_PER_BURST_MIN: int = 70
const BLOOD_DROPS_PER_BURST_MAX: int = 80
const HITSTOP_DURATION: float = 0.3

# --- Непрерывная атака пилой ---
const SAW_PUSH_HAND_OFFSET: float = 5.0
const SAW_PUSH_MOVE_SPEED: float = 18.0
const SAW_PUSH_DAMAGE_PER_TICK: float = 6.0
const SAW_PUSH_TICK_INTERVAL: float = 0.006
const SAW_PUSH_BLOOD_DROPS_MIN: int = 35
const SAW_PUSH_BLOOD_DROPS_MAX: int = 40
const SAW_PUSH_SHAKE_INTENSITY: float = 0.5
const SAW_PUSH_SHAKE_DURATION: float = 0.08
const SAW_PUSH_STUCK_TURN_SPEED: float = deg_to_rad(85.0)
const SAW_PUSH_FREE_TURN_SPEED: float = deg_to_rad(1000.0)

# --- Огнемет ---
const FLAME_FIRE_RATE: float = 0.018
const FLAME_PARTICLES_PER_TICK: int = 2
const FLAME_SPREAD_ANGLE: float = deg_to_rad(13.0)
const FLAME_SPEED_MIN: float = 400.0
const FLAME_SPEED_MAX: float = 650.0
const FLAME_RAMP_UP_TIME: float = 0.12
const FLAME_RAMP_DOWN_TIME: float = 0.15

const CROUCH_OFFSET: float = 4.2
const CROUCH_SPEED: float = 12.0

const WEAPON_PREFIX: Array[String] = ["saw_", "shotgun_", "ak_", "flame_"]
enum WeaponType { SAW, SHOTGUN, AK, FLAMETHROWER }

# === EXPORT ===
@export var bullet_scene: PackedScene
@export var flame_bullet_scene: PackedScene
@export var death_blood_scene: PackedScene
@export var blood_drop_scene: PackedScene
@export var restart_prompt: Node2D

# === НОДЫ ===
@onready var telo: Node2D = get_node_or_null("TELO")
@onready var tul: AnimatedSprite2D = get_node_or_null("TELO/TUL")
@onready var ruki: Node2D = get_node_or_null("TELO/RUKI")
@onready var camera: Camera2D = get_node_or_null("Camera2D")
@onready var collision_shape: CollisionShape2D = get_node_or_null("CollisionShape2D")
@onready var chainsaw_hitbox: Area2D = get_node_or_null("TELO/RUKI/Hitbox")
@onready var blood_marker: Marker2D = get_node_or_null("TELO/RUKI/BloodMarker")
@onready var muzzle_marker: Marker2D = get_node_or_null("TELO/RUKI/MuzzleMarker")

# === СОСТОЯНИЕ ===
var current_weapon: WeaponType = WeaponType.SAW

var coyote_timer: float = 0.0
var jump_buffer_timer: float = 0.0
var wall_jump_lock: float = 0.0
var shoot_cooldown: float = 0.0
var attack_cooldown_timer: float = 0.0
var shake_timer: float = 0.0
var shake_intensity: float = 0.0
var shake_duration: float = 0.0

var is_attacking: bool = false
var is_saw_pushing: bool = false
var is_dead: bool = false
var is_restarting: bool = false

var saw_push_damage_timer: float = 0.0
var saw_push_aim_angle: float = 0.0
var flame_heat: float = 0.0

var knockback: Vector2 = Vector2.ZERO
var facing: float = 1.0
var last_aim_angle: float = 0.0
var attack_combo_step: int = 0
var attack_combo_reset_timer: float = 0.0
var attack_swing_rotation: float = 0.0
var chainsaw_shake_time: float = 0.0
var crouch_current: float = 0.0
var death_rotation_speed: float = 0.0
var death_bounces: int = 0

var tul_base_y: float = 0.0
var hands_original_position: Vector2 = Vector2.ZERO
var hands_original_rotation: float = 0.0
var camera_original_pos: Vector2 = Vector2.ZERO
var restart_prompt_target_pos: Vector2 = Vector2.ZERO

var tulo_attack_tween: Tween
var hands_tween: Tween

# === ИНИЦИАЛИЗАЦИЯ ===
func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_setup_fade_in()
	if tul:
		tul_base_y = tul.position.y
		tul.play("idle")
	if ruki:
		hands_original_position = ruki.position
		hands_original_rotation = ruki.rotation
		ruki.process_mode = Node.PROCESS_MODE_ALWAYS
		if ruki is AnimatedSprite2D:
			ruki.play("saw_normal")
			ruki.speed_scale = 1.0
	if camera:
		camera_original_pos = camera.position
		camera.process_mode = Node.PROCESS_MODE_ALWAYS
	if restart_prompt:
		restart_prompt_target_pos = restart_prompt.position
		restart_prompt.visible = false
	if chainsaw_hitbox:
		chainsaw_hitbox.monitoring = false
		chainsaw_hitbox.monitorable = false
		if not chainsaw_hitbox.body_entered.is_connected(_on_chainsaw_body_entered):
			chainsaw_hitbox.body_entered.connect(_on_chainsaw_body_entered)

func _setup_fade_in() -> void:
	var layer = get_tree().root.get_node_or_null("FADE_LAYER")
	if not layer:
		return
	var rect = layer.get_child(0)
	rect.color.a = 1.0
	var tween = create_tween()
	tween.tween_property(rect, "color:a", 0.0, 0.5)
	tween.tween_callback(layer.queue_free)

# === ВВОД ===
func _unhandled_input(event: InputEvent) -> void:
	if is_dead or get_tree().paused or not (event is InputEventMouseButton and event.pressed):
		return
	match event.button_index:
		MOUSE_BUTTON_WHEEL_UP: switch_weapon(1)
		MOUSE_BUTTON_WHEEL_DOWN: switch_weapon(-1)

func _is_attack_pressed(just: bool = false) -> bool:
	var saw := current_weapon == WeaponType.SAW
	var action := "pkm" if saw else "lkm"
	var mouse := Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT if saw else MOUSE_BUTTON_LEFT)
	return mouse or (Input.is_action_just_pressed(action) if just else Input.is_action_pressed(action))

func _is_saw_push_pressed() -> bool:
	return Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) or Input.is_action_pressed("lkm")

func switch_weapon(dir: int = 1) -> void:
	if not (is_attacking or is_saw_pushing):
		current_weapon = posmod(current_weapon + dir, WeaponType.size()) as WeaponType

# === УТИЛИТЫ ===
func get_aim_angle_local() -> float:
	if not telo:
		return 0.0
	var diff = telo.to_local(get_global_mouse_position()) - hands_original_position
	var target = clampf(diff.angle(), -AIM_LIMIT, AIM_LIMIT)
	last_aim_angle = lerp_angle(last_aim_angle, target, get_physics_process_delta_time() * 1.5) if diff.length() < MIN_AIM_DISTANCE else target
	return last_aim_angle

func _face_mouse(min_dist: float = 0.0) -> void:
	var dx = get_global_mouse_position().x - global_position.x
	if absf(dx) <= min_dist:
		return
	facing = signf(dx)
	if telo: telo.scale.x = facing
	if collision_shape: collision_shape.scale.x = facing

func _local_angle_to_world(local_angle: float) -> float:
	return atan2(sin(local_angle), facing * cos(local_angle))

func _get_muzzle_position() -> Vector2:
	var n: Node2D = muzzle_marker if muzzle_marker else ruki if ruki else self
	return n.global_position

func _get_saw_blood_pos(body: Node2D) -> Vector2:
	var n: Node2D = blood_marker if blood_marker else ruki if ruki else body
	return n.global_position

## Мировой угол прицеливания (по рукам, либо по мыши)
func _aim_world() -> float:
	if ruki:
		return _local_angle_to_world(ruki.rotation)
	return (get_global_mouse_position() - _get_muzzle_position()).angle()

func _spawn(scene: PackedScene, pos: Vector2):
	var n = scene.instantiate()
	get_tree().current_scene.add_child(n)
	n.global_position = pos
	return n

func _saw_targets() -> Array:
	if not chainsaw_hitbox:
		return []
	return chainsaw_hitbox.get_overlapping_bodies().filter(func(b): return b != self and b.has_method("take_damage"))

func _shake_offset(amp: float) -> Vector2:
	return Vector2(sin(chainsaw_shake_time * 1.7), cos(chainsaw_shake_time * 2.3)) * amp

func _kill_tween(tween: Tween) -> void:
	if tween and tween.is_valid():
		tween.kill()

func _new_tween(old: Tween = null) -> Tween:
	_kill_tween(old)
	return create_tween().set_pause_mode(Tween.TWEEN_PAUSE_STOP)

func start_shake(intensity: float = 1.0, duration: float = 0.3) -> void:
	shake_intensity = intensity
	shake_duration = duration
	shake_timer = duration

func hit_stop(target: Node = null, duration: float = HITSTOP_DURATION) -> void:
	if target and (target.is_in_group("wall") or target.is_in_group("destructible")):
		return
	get_tree().paused = true
	await get_tree().create_timer(duration, true, false, true).timeout
	get_tree().paused = false

# === ГЛАВНЫЙ ЦИКЛ ===
func _physics_process(delta: float) -> void:
	_update_camera_shake(delta)
	if get_tree().paused:
		return
	if is_dead:
		_process_death_physics(delta)
		return
	_decrement_timers(delta)
	_handle_weapon_inputs(delta)
	_handle_movement_and_gravity(delta)
	_update_visuals_and_animations(delta)
	_check_hazards()

func _update_camera_shake(delta: float) -> void:
	if shake_timer <= 0:
		return
	shake_timer -= delta
	var k = maxf(shake_timer / shake_duration, 0.0)
	var i = shake_intensity * k * k
	if camera:
		camera.position = camera_original_pos + Vector2(randf_range(-i, i), randf_range(-i, i))

func _decrement_timers(delta: float) -> void:
	wall_jump_lock = maxf(0.0, wall_jump_lock - delta)
	coyote_timer = maxf(0.0, coyote_timer - delta)
	jump_buffer_timer = maxf(0.0, jump_buffer_timer - delta)
	shoot_cooldown = maxf(0.0, shoot_cooldown - delta)
	attack_cooldown_timer = maxf(0.0, attack_cooldown_timer - delta)
	if not is_attacking:
		attack_combo_reset_timer = maxf(0.0, attack_combo_reset_timer - delta)
		if attack_combo_reset_timer <= 0.0:
			attack_combo_step = 0

# === ОРУЖИЕ: ВВОД ===
func _handle_weapon_inputs(delta: float) -> void:
	_update_flamethrower(delta)

	if current_weapon == WeaponType.SAW:
		var lmb_held = _is_saw_push_pressed()
		if lmb_held and not is_attacking:
			_handle_saw_push(delta)
		elif is_saw_pushing:
			_stop_saw_push()
		if not lmb_held and _is_attack_pressed(true) and shoot_cooldown <= 0.0 and attack_cooldown_timer <= 0.0:
			perform_chainsaw_attack_visual()
		return

	if is_saw_pushing:
		_stop_saw_push()
	if current_weapon == WeaponType.AK and _is_attack_pressed() and shoot_cooldown <= 0.0:
		shoot_ak()
	elif current_weapon == WeaponType.SHOTGUN and _is_attack_pressed(true) and shoot_cooldown <= 0.0 and attack_cooldown_timer <= 0.0:
		shoot_shotgun()

# === ДВИЖЕНИЕ ===
func _handle_movement_and_gravity(delta: float) -> void:
	var dir := Input.get_axis("a", "d")
	var on_floor := is_on_floor()
	if Input.is_action_just_pressed("w"):
		jump_buffer_timer = JUMP_BUFFER_TIME

	if on_floor:
		coyote_timer = COYOTE_TIME
	else:
		var fast_fall := Input.is_action_pressed("s")
		velocity.y = move_toward(velocity.y, FAST_FALL_SPEED if fast_fall else MAX_FALL_SPEED, GRAVITY * (3.0 if fast_fall else 1.0) * delta)

	if wall_jump_lock <= 0:
		var speed := SPEED
		if is_saw_pushing and dir != 0.0 and signf(dir) == facing and not _saw_targets().is_empty():
			speed *= 0.2
		var rate := (ACCELERATION if on_floor else AIR_ACCELERATION) if dir != 0.0 else (DECELERATION if on_floor else AIR_DECELERATION)
		velocity.x = move_toward(velocity.x, dir * speed, rate * delta)

	var wall_sliding := not on_floor and _check_is_on_wall()
	if wall_sliding:
		velocity.y = minf(velocity.y, WALL_SLIDE_SPEED)

	if jump_buffer_timer > 0 and coyote_timer > 0:
		velocity.y = JUMP_FORCE
		jump_buffer_timer = 0.0
		coyote_timer = 0.0
	elif wall_sliding and Input.is_action_just_pressed("w"):
		velocity.x = get_wall_normal().x * WALL_JUMP_FORCE_X
		velocity.y = WALL_JUMP_FORCE_Y
		wall_jump_lock = 0.04

	if Input.is_action_just_released("w") and velocity.y < 0:
		velocity.y *= JUMP_CUT_MULTIPLIER

	velocity += knockback
	knockback = knockback.move_toward(Vector2.ZERO, 880.3 * delta)

	move_and_slide()
	_handle_step_climb(dir)

func _check_is_on_wall() -> bool:
	for i in get_slide_collision_count():
		var col = get_slide_collision(i)
		var c = col.get_collider()
		if c and absf(col.get_normal().x) > 0.5 and not c.is_in_group("no_wall_slide"):
			return true
	return false

func _handle_step_climb(dir: float) -> void:
	if dir == 0 or not is_on_floor() or not is_on_wall():
		return
	var s := signf(dir)
	for i in range(1, int(MAX_STEP_HEIGHT) + 1):
		if not test_move(global_transform.translated(Vector2(0, -i)), Vector2(s * 1.4, 0)):
			global_position += Vector2(s * 0.7, -i)
			break

func _check_hazards() -> void:
	for i in get_slide_collision_count():
		var c = get_slide_collision(i).get_collider()
		if c and c.is_in_group("spikes"):
			take_hit(c.global_position, true)
			return

# === ВИЗУАЛ ===
func _update_visuals_and_animations(delta: float) -> void:
	var dir := Input.get_axis("a", "d")
	var active := is_attacking or is_saw_pushing or _is_attack_pressed() or attack_cooldown_timer > 0.0

	if ruki is AnimatedSprite2D:
		var anim: String = WEAPON_PREFIX[current_weapon] + ("attack" if active else "normal")
		if ruki.animation != anim:
			ruki.play(anim)

	if not is_attacking and not is_saw_pushing:
		_face_mouse(1.0)

	crouch_current = lerpf(crouch_current, float(is_on_floor() and dir == 0 and Input.is_action_pressed("s")), delta * CROUCH_SPEED)
	if tul:
		var anim := "walk" if (dir != 0 and is_on_floor()) else "idle"
		if tul.animation != anim:
			tul.play(anim)
		tul.position.y = tul_base_y + crouch_current * CROUCH_OFFSET

	_update_hands_position(delta, active)

func _update_hands_position(delta: float, active: bool) -> void:
	chainsaw_shake_time += delta * (25.0 if active else 10.0)
	if is_attacking or is_saw_pushing or not ruki:
		return
	var aim = get_aim_angle_local()
	var pos = hands_original_position
	var rot = aim
	if current_weapon == WeaponType.SAW:
		pos += _shake_offset(1.23 if active else 0.35)
		rot += sin(chainsaw_shake_time * 3.1) * deg_to_rad((3.5 if active else 1.0) * 0.8) * 0.3
	else:
		pos += Vector2.from_angle(aim) * AIM_FORWARD_OFFSET
	ruki.position = ruki.position.lerp(pos, delta * 15.0)
	ruki.rotation = lerp_angle(ruki.rotation, rot, delta * 20.0)

func reset_hands_position() -> void:
	if not ruki:
		return
	hands_tween = _new_tween(hands_tween)
	hands_tween.tween_property(ruki, "position", hands_original_position, 0.1)
	hands_tween.parallel().tween_property(ruki, "rotation", hands_original_rotation, 0.1)

# === СТРЕЛЬБА ===
func shoot_ak() -> void:
	_fire_weapon(AK_FIRE_RATE, AK_SPREAD_ANGLE, 1, 8.0, 1350.0, 300.0, 2.2, 0.03, 0.06, 0.4, 0.08)

func shoot_shotgun() -> void:
	_fire_weapon(SHOTGUN_FIRE_RATE, SPREAD_ANGLE, PELLET_COUNT, 12.0, 1232.4, 264.1, 4.93, 0.04, 0.18, 1.2, 0.18)

func _fire_weapon(rate: float, spread: float, pellets: int, damage: float, bullet_speed: float, ray_len: float, recoil: float, out_t: float, back_t: float, shake_i: float, shake_d: float) -> void:
	shoot_cooldown = rate
	start_shake(shake_i, shake_d)
	var muzzle = _get_muzzle_position()
	var base = _aim_world()

	if ruki:
		hands_tween = _new_tween(hands_tween)
		hands_tween.tween_property(ruki, "position", hands_original_position - Vector2.from_angle(base) * recoil, out_t).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
		hands_tween.tween_property(ruki, "position", hands_original_position, back_t).set_trans(Tween.TRANS_SPRING)

	var space = get_world_2d().direct_space_state
	for i in pellets:
		var angle = base + randf_range(-spread / 2.0, spread / 2.0)
		var dir = Vector2.from_angle(angle)
		var pos = muzzle + dir * randf_range(-10.0, 14.0)
		if bullet_scene:
			var bullet = _spawn(bullet_scene, pos)
			bullet.rotation = angle
			if "velocity" in bullet:
				bullet.velocity = dir * bullet_speed * randf_range(0.88, 1.12)
		else:
			var query = PhysicsRayQueryParameters2D.create(pos, pos + dir * ray_len)
			query.exclude = [get_rid()]
			var hit = space.intersect_ray(query)
			if hit and hit.collider.has_method("take_damage"):
				hit.collider.take_damage(damage)
				spawn_shotgun_hit_blood(hit.position, dir)

func spawn_shotgun_hit_blood(hit_pos: Vector2, hit_dir: Vector2) -> void:
	if not blood_drop_scene:
		return
	for i in 6:
		_blood_drop(hit_pos, hit_dir.angle(), 0.0, 0.0, 28.0, randf_range(88.0, 246.5))

# === ОГНЕМЕТ ===
func _update_flamethrower(delta: float) -> void:
	var fire := current_weapon == WeaponType.FLAMETHROWER and _is_attack_pressed()
	flame_heat = clampf(flame_heat + delta / (FLAME_RAMP_UP_TIME if fire else -FLAME_RAMP_DOWN_TIME), 0.0, 1.0)
	if fire and shoot_cooldown <= 0.0:
		_spawn_flame_burst()

func _spawn_flame_burst() -> void:
	shoot_cooldown = FLAME_FIRE_RATE
	start_shake(0.35, 0.06)
	if not flame_bullet_scene:
		return

	var muzzle = _get_muzzle_position()
	var base = _aim_world()
	var spread = FLAME_SPREAD_ANGLE * lerpf(0.5, 1.0, flame_heat)
	var speed_mult = lerpf(0.4, 1.0, flame_heat)
	var target_scale = Vector2.ONE * lerpf(0.5, 1.0, flame_heat)

	for i in FLAME_PARTICLES_PER_TICK:
		var angle = base + randf_range(-spread / 2.0, spread / 2.0)
		var dir = Vector2.from_angle(angle)
		var bullet = _spawn(flame_bullet_scene, muzzle + dir * randf_range(0.0, 8.0))
		bullet.rotation = angle
		if "velocity" in bullet:
			bullet.velocity = dir * randf_range(FLAME_SPEED_MIN, FLAME_SPEED_MAX) * speed_mult
		bullet.scale = Vector2.ZERO
		bullet.modulate.a = 0.0
		var tween = bullet.create_tween().set_parallel(true)
		tween.tween_property(bullet, "scale", target_scale, 0.05).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tween.tween_property(bullet, "modulate:a", 1.0, 0.04)

# === УДАР ПИЛОЙ ===
func perform_chainsaw_attack_visual() -> void:
	is_attacking = true
	attack_combo_reset_timer = COMBO_RESET_WINDOW
	if chainsaw_hitbox: chainsaw_hitbox.monitoring = true
	_face_mouse()

	var base_angle = get_aim_angle_local()
	attack_swing_rotation = base_angle
	var step = attack_combo_step
	attack_combo_step = 1 - step

	await _perform_slash_attack(base_angle, step == 0)

	if chainsaw_hitbox: chainsaw_hitbox.monitoring = false
	is_attacking = false
	reset_hands_position()

func _perform_slash_attack(base_angle: float, is_downward: bool) -> void:
	attack_cooldown_timer = SLASH_DURATION + SLASH_WINDUP_TIME + SLASH_COOLDOWN_PADDING
	var arc = SLASH_ARC_HALF if is_downward else -SLASH_ARC_HALF
	var start_angle = base_angle - arc
	var end_angle = base_angle + arc
	var lean = (0.12 if is_downward else -0.12) * facing

	# Замах
	hands_tween = _new_tween(hands_tween).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	hands_tween.tween_method(_apply_slash_pose.bind(ruki.rotation if ruki else 0.0, start_angle), 0.0, 1.0, SLASH_WINDUP_TIME)
	if tul:
		tulo_attack_tween = _new_tween(tulo_attack_tween)
		tulo_attack_tween.tween_property(tul, "rotation", -lean, SLASH_WINDUP_TIME)
	start_shake(1.4, 0.12)
	await get_tree().create_timer(SLASH_WINDUP_TIME, false).timeout

	# Удар (cos(base_angle) > 0, т.к. угол ограничен ±85°, поэтому рывок всегда по facing)
	velocity.x += facing * SLASH_DASH_FORCE
	var swing_tween = _new_tween().set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	swing_tween.tween_method(_apply_slash_pose.bind(start_angle, end_angle), 0.0, 1.0, SLASH_DURATION)
	start_shake(4.0, SLASH_DURATION)
	if tul:
		tulo_attack_tween = _new_tween(tulo_attack_tween)
		tulo_attack_tween.tween_property(tul, "rotation", lean, SLASH_DURATION * 0.6)
		tulo_attack_tween.tween_property(tul, "rotation", 0.0, SLASH_DURATION * 0.4)
	await swing_tween.finished

func _apply_slash_pose(t: float, start_angle: float, end_angle: float) -> void:
	attack_swing_rotation = lerp_angle(start_angle, end_angle, t)
	if ruki:
		ruki.rotation = attack_swing_rotation
		ruki.position = hands_original_position + Vector2.from_angle(attack_swing_rotation) * SLASH_ARC_RADIUS

func _on_chainsaw_body_entered(body: Node2D) -> void:
	if is_saw_pushing or not body.has_method("take_damage"):
		return
	body.take_damage(SLASH_HIT_DAMAGE)
	start_shake(SLASH_HIT_SHAKE_INTENSITY, SLASH_HIT_SHAKE_DURATION)
	_kill_tween(hands_tween)
	if ruki: ruki.position = hands_original_position + Vector2.from_angle(attack_swing_rotation) * SLASH_ARC_RADIUS
	hit_stop()
	spawn_chainsaw_blood(_get_saw_blood_pos(body), _local_angle_to_world(attack_swing_rotation))

# === КРОВЬ ===
## Одна капля: pos — центр, center — направление, off — разброс вдоль направления, jit — случайный сдвиг, spread_deg — конус
func _blood_drop(pos: Vector2, center: float, off: float, jit: float, spread_deg: float, speed: float) -> void:
	var jitter = Vector2(randf_range(-jit, jit), randf_range(-jit, jit))
	var drop = _spawn(blood_drop_scene, pos + Vector2.from_angle(center) * randf_range(0.0, off) + jitter)
	drop.process_mode = Node.PROCESS_MODE_ALWAYS
	drop.velocity = Vector2.from_angle(center + deg_to_rad(randf_range(-spread_deg, spread_deg))) * speed

func spawn_chainsaw_blood(spawn_pos: Vector2, cut_angle: float) -> void:
	if not blood_drop_scene:
		return
	var center = cut_angle + PI
	var interval = HITSTOP_DURATION / float(BLOOD_BURST_COUNT)
	for burst in BLOOD_BURST_COUNT:
		for i in randi_range(BLOOD_DROPS_PER_BURST_MIN, BLOOD_DROPS_PER_BURST_MAX):
			var roll = randf()
			var speed = randf_range(28.2, 211.3) if roll < 0.25 else (randf_range(211.3, 528.2) if roll < 0.75 else randf_range(528.2, 845.1))
			_blood_drop(spawn_pos, center, 21.1, 1.76, 30.0, speed)
		if burst < BLOOD_BURST_COUNT - 1:
			await get_tree().create_timer(interval, true, false, true).timeout

# === НЕПРЕРЫВНАЯ ПИЛА ===
func _handle_saw_push(delta: float) -> void:
	if not is_saw_pushing:
		is_saw_pushing = true
		saw_push_damage_timer = 0.0
		saw_push_aim_angle = get_aim_angle_local()
		if chainsaw_hitbox:
			chainsaw_hitbox.monitoring = true
			chainsaw_hitbox.monitorable = true

	var stuck = not _saw_targets().is_empty()
	if not stuck:
		_face_mouse()

	var turn_speed = SAW_PUSH_STUCK_TURN_SPEED if stuck else SAW_PUSH_FREE_TURN_SPEED
	saw_push_aim_angle = move_toward(saw_push_aim_angle, get_aim_angle_local(), turn_speed * delta)
	if stuck:
		saw_push_aim_angle += randf_range(-deg_to_rad(4.5), deg_to_rad(4.5))

	chainsaw_shake_time += delta * 25.0
	if ruki:
		var target_pos = hands_original_position + _shake_offset(1.23) + Vector2.from_angle(saw_push_aim_angle) * SAW_PUSH_HAND_OFFSET
		var target_rot = saw_push_aim_angle + sin(chainsaw_shake_time * 3.1) * deg_to_rad(2.8)
		ruki.position = ruki.position.lerp(target_pos, delta * SAW_PUSH_MOVE_SPEED)
		ruki.rotation = lerp_angle(ruki.rotation, target_rot, delta * SAW_PUSH_MOVE_SPEED)

	saw_push_damage_timer -= delta
	if saw_push_damage_timer <= 0.0:
		saw_push_damage_timer = SAW_PUSH_TICK_INTERVAL
		_apply_saw_push_damage()

func _stop_saw_push() -> void:
	is_saw_pushing = false
	if chainsaw_hitbox:
		chainsaw_hitbox.monitoring = false
	reset_hands_position()

func _apply_saw_push_damage() -> void:
	for body in _saw_targets():
		body.take_damage(SAW_PUSH_DAMAGE_PER_TICK)
		start_shake(SAW_PUSH_SHAKE_INTENSITY, SAW_PUSH_SHAKE_DURATION)
		if blood_drop_scene:
			var center = _local_angle_to_world(saw_push_aim_angle) + PI
			for i in randi_range(SAW_PUSH_BLOOD_DROPS_MIN, SAW_PUSH_BLOOD_DROPS_MAX):
				_blood_drop(_get_saw_blood_pos(body), center, 14.0, 1.5, 32.0, randf_range(120.0, 420.0))

# === СМЕРТЬ И РЕСТАРТ ===
func take_hit(from_position: Vector2, _ignore_dash: bool = false) -> void:
	die(from_position)

func die(from_position: Vector2 = global_position) -> void:
	if is_dead:
		return
	is_dead = true

	_stop_saw_push()
	_kill_tween(tulo_attack_tween)

	var away = (global_position - from_position).normalized()
	if absf(away.x) < 0.2:
		away.x = -facing

	if death_blood_scene:
		var blood = _spawn(death_blood_scene, global_position)
		if away.x < 0: blood.scale.x = -1
	if has_node("DeathBleedParticles"):
		$DeathBleedParticles.emitting = true

	collision_layer = 0
	collision_mask = 1
	attack_combo_step = 0
	crouch_current = 0.0
	start_shake(5.0, 0.25)

	if tul:
		tul.position.y = tul_base_y
		tul.rotation = 0.0
		if tul.sprite_frames and tul.sprite_frames.has_animation("dead"):
			tul.play("dead")
		else:
			tul.stop()

	velocity = Vector2(away.x * 440.1, -387.3)
	death_rotation_speed = randf_range(28.0, 38.0) * signf(away.x)
	death_bounces = 0

	if restart_prompt:
		restart_prompt.visible = true
		restart_prompt.position = restart_prompt_target_pos + Vector2(0, 52.8)
		var tween = _new_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tween.tween_property(restart_prompt, "position", restart_prompt_target_pos, 2)

func _process_death_physics(delta: float) -> void:
	velocity.y = move_toward(velocity.y, MAX_FALL_SPEED * 1.5, GRAVITY * 1.5 * delta)
	if death_bounces < 2 and telo:
		telo.rotation += death_rotation_speed * delta

	var collision = move_and_collide(velocity * delta)
	if collision:
		var normal = collision.get_normal()
		if death_bounces == 0:
			death_bounces = 1
			velocity = velocity.bounce(normal) * 0.45
			death_rotation_speed = 3.0 * signf(velocity.x)
		elif death_bounces == 1:
			var landed = normal.y < -0.7
			if landed: death_bounces = 2
			velocity = velocity.bounce(normal) * (0.15 if landed else 0.3)

	if death_bounces >= 2:
		velocity.x = move_toward(velocity.x, 0.0, 1056.3 * delta)
		death_rotation_speed = 0.0
		if telo:
			telo.rotation = lerp_angle(telo.rotation, facing * AIM_LIMIT, delta * 12.0)

	if (Input.is_key_pressed(KEY_R) or Input.is_action_just_pressed("r")) and not is_restarting:
		start_fade_and_restart()

func start_fade_and_restart() -> void:
	is_restarting = true
	var layer = CanvasLayer.new()
	layer.name = "FADE_LAYER"
	layer.layer = 128
	get_tree().root.add_child(layer)

	var rect = ColorRect.new()
	rect.color = Color(0, 0, 0, 0)
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(rect)

	var tween = _new_tween().set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(rect, "color:a", 1.0, 0.5)
	tween.tween_callback(respawn)

func respawn() -> void:
	# Сцена пересоздаётся целиком — ручной сброс состояния игрока не нужен
	get_tree().reload_current_scene()
