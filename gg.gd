extends CharacterBody2D

# === НАСТРОЙКИ И КОНСТАНТЫ ===
const SPEED: float = 147.9
const ACCELERATION: float = 774.6
const DECELERATION: float = 915.5
const AIR_ACCELERATION: float = 774.6
const AIR_DECELERATION: float = 845.1

const JUMP_FORCE: float = -257.0
const JUMP_CUT_MULTIPLIER: float = 0.5
const FAST_FALL_SPEED: float = 493.0
const COYOTE_TIME: float = 0.12
const JUMP_BUFFER_TIME: float = 0.12
const GRAVITY: float = 563.4
const MAX_FALL_SPEED: float = 422.5

const WALL_SLIDE_SPEED: float = 28.2
const WALL_JUMP_FORCE_X: float = 105.6
const WALL_JUMP_FORCE_Y: float = -221.8
const MAX_STEP_HEIGHT: float = 4.2

const MIN_AIM_DISTANCE: float = 20.0
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
const SAW_PUSH_STUCK_TURN_SPEED: float = deg_to_rad(85.0) # Сделали резче и быстрее вместо 20.0 ✨
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

enum WeaponType { SAW, SHOTGUN, AK, FLAMETHROWER }
enum HandJumpState { NORMAL, JUMPING, FALLING, LANDING }

# === EXPORT ПЕРЕМЕННЫЕ ===
@export var bullet_scene: PackedScene
@export var flame_bullet_scene: PackedScene
@export var death_blood_scene: PackedScene
@export var blood_drop_scene: PackedScene
@export var restart_prompt: Node2D

# === КЭШ НОД ===
@onready var telo: Node2D = get_node_or_null("TELO")
@onready var tul: AnimatedSprite2D = get_node_or_null("TELO/TUL")
@onready var ruki: Node2D = get_node_or_null("TELO/RUKI")
@onready var camera: Camera2D = get_node_or_null("Camera2D")
@onready var collision_shape: CollisionShape2D = get_node_or_null("CollisionShape2D")
@onready var walk_particles: GPUParticles2D = get_node_or_null("WalkParticles")
@onready var chainsaw_hitbox: Area2D = get_node_or_null("TELO/RUKI/Hitbox")
@onready var blood_marker: Marker2D = get_node_or_null("TELO/RUKI/BloodMarker")
@onready var muzzle_marker: Marker2D = get_node_or_null("TELO/RUKI/MuzzleMarker")

# === СОСТОЯНИЕ ===
var current_weapon: WeaponType = WeaponType.SAW
var hand_jump_state: HandJumpState = HandJumpState.NORMAL

var coyote_timer: float = 0.0
var jump_buffer_timer: float = 0.0
var wall_jump_lock: float = 0.0
var hitstop_timer: float = 0.0
var shoot_cooldown: float = 0.0
var attack_cooldown_timer: float = 0.0
var shake_timer: float = 0.0

var can_double_jump: bool = true
var was_on_wall: bool = false
var was_on_floor_prev: bool = true
var is_shooting: bool = false
var is_attacking: bool = false
var is_dead: bool = false
var is_restarting: bool = false
var walk_particles_enabled: bool = false
var attack_manual_pose: bool = false

var is_saw_pushing: bool = false
var saw_push_damage_timer: float = 0.0
var saw_push_aim_angle: float = 0.0

# --- Состояние огнемета ---
var flame_heat: float = 0.0

var knockback: Vector2 = Vector2.ZERO
var facing: float = 1.0
var last_aim_angle: float = 0.0
var attack_combo_step: int = 0
var attack_combo_reset_timer: float = 0.0
var attack_hand_angle_locked: float = 0.0
var attack_swing_rotation: float = 0.0

var shake_intensity: float = 0.0
var shake_duration: float = 0.0
var chainsaw_shake_time: float = 0.0
var crouch_current: float = 0.0
var death_rotation_speed: float = 0.0
var death_bounces: int = 0

var tul_base_x: float = 0.0
var tul_base_y: float = 0.0
var tulo_original_scale: Vector2 = Vector2.ONE
var hands_original_position: Vector2 = Vector2.ZERO
var hands_original_rotation: float = 0.0
var camera_original_pos: Vector2 = Vector2.ZERO
var start_position: Vector2 = Vector2.ZERO
var restart_prompt_target_pos: Vector2 = Vector2.ZERO

var tulo_attack_tween: Tween
var hands_tween: Tween
var restart_prompt_tween: Tween

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_setup_fade_in()
	_cache_initial_transforms()
	_setup_nodes_process_mode()
	_setup_hitbox()

func _setup_fade_in() -> void:
	var fade_layer = get_tree().root.get_node_or_null("FADE_LAYER")
	if not fade_layer:
		return
	var fade_rect = fade_layer.get_child(0)
	fade_rect.color.a = 1.0
	var tween = create_tween()
	tween.tween_property(fade_rect, "color:a", 0.0, 0.5)
	tween.tween_callback(fade_layer.queue_free)

func _cache_initial_transforms() -> void:
	start_position = global_position
	if tul:
		tul_base_x = tul.position.x
		tul_base_y = tul.position.y
		tulo_original_scale = tul.scale
		tul.play("idle")
	if ruki:
		hands_original_position = ruki.position
		hands_original_rotation = ruki.rotation
	if camera:
		camera_original_pos = camera.position
	if walk_particles:
		walk_particles.emitting = false
	if restart_prompt:
		restart_prompt_target_pos = restart_prompt.position
		restart_prompt.visible = false

func _setup_nodes_process_mode() -> void:
	if ruki:
		ruki.process_mode = Node.PROCESS_MODE_ALWAYS
		if ruki is AnimatedSprite2D:
			ruki.play("saw_normal")
			ruki.speed_scale = 1.0
	if camera:
		camera.process_mode = Node.PROCESS_MODE_ALWAYS

func _setup_hitbox() -> void:
	if not chainsaw_hitbox:
		return
	chainsaw_hitbox.monitoring = false
	chainsaw_hitbox.monitorable = false
	if not chainsaw_hitbox.body_entered.is_connected(_on_chainsaw_body_entered):
		chainsaw_hitbox.body_entered.connect(_on_chainsaw_body_entered)

func _unhandled_input(event: InputEvent) -> void:
	if is_dead or get_tree().paused:
		return
	if event is InputEventMouseButton and event.is_pressed():
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			switch_weapon(1)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			switch_weapon(-1)

func _is_attack_pressed() -> bool:
	if current_weapon == WeaponType.SAW:
		return Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT) or Input.is_action_pressed("pkm")
	return Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) or Input.is_action_pressed("lkm")

func _is_attack_just_pressed() -> bool:
	if current_weapon == WeaponType.SAW:
		return Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT) or Input.is_action_just_pressed("pkm")
	return Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) or Input.is_action_just_pressed("lkm")

func _is_saw_push_pressed() -> bool:
	return Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) or Input.is_action_pressed("lkm")

func switch_weapon(dir: int = 1) -> void:
	if is_attacking or is_saw_pushing:
		return
	var weapon_count = WeaponType.size()
	current_weapon = posmod(current_weapon + dir, weapon_count) as WeaponType

func get_aim_angle_local() -> float:
	if not telo:
		return 0.0
	var local_mouse = telo.to_local(get_global_mouse_position())
	var diff = local_mouse - hands_original_position
	var target_angle = clamp(diff.angle(), deg_to_rad(-85.0), deg_to_rad(85.0))
	if diff.length() < MIN_AIM_DISTANCE:
		last_aim_angle = lerp_angle(last_aim_angle, target_angle, get_physics_process_delta_time() * 1.5)
		return last_aim_angle
	last_aim_angle = target_angle
	return target_angle

func _get_muzzle_position() -> Vector2:
	if muzzle_marker:
		return muzzle_marker.global_position
	if ruki:
		return ruki.global_position
	return global_position

func _physics_process(delta: float) -> void:
	_update_camera_shake(delta)
	if get_tree().paused:
		return
	if is_dead:
		_process_death_physics(delta)
		return
	if hitstop_timer > 0:
		hitstop_timer -= delta
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
	if shake_timer > 0:
		var progress: float = max(0.0, shake_timer / shake_duration)
		var intensity: float = shake_intensity * progress * progress
		if camera:
			camera.position = camera_original_pos + Vector2(randf_range(-intensity, intensity), randf_range(-intensity, intensity))
	else:
		if camera:
			camera.position = camera_original_pos
		shake_intensity = 0.0

func _decrement_timers(delta: float) -> void:
	wall_jump_lock = max(0.0, wall_jump_lock - delta)
	coyote_timer = max(0.0, coyote_timer - delta)
	jump_buffer_timer = max(0.0, jump_buffer_timer - delta)
	shoot_cooldown = max(0.0, shoot_cooldown - delta)
	attack_cooldown_timer = max(0.0, attack_cooldown_timer - delta)
	if not is_attacking:
		attack_combo_reset_timer = max(0.0, attack_combo_reset_timer - delta)
		if attack_combo_reset_timer <= 0.0:
			attack_combo_step = 0

func _handle_weapon_inputs(delta: float) -> void:
	_update_flamethrower(delta)

	if current_weapon == WeaponType.SAW:
		var lmb_held = _is_saw_push_pressed()
		if lmb_held and not is_attacking:
			_handle_saw_push(delta)
		elif is_saw_pushing:
			_stop_saw_push()

		if not lmb_held and _is_attack_just_pressed() and shoot_cooldown <= 0.0 and attack_cooldown_timer <= 0.0:
			perform_chainsaw_attack_visual()
	else:
		if is_saw_pushing:
			_stop_saw_push()
		if current_weapon == WeaponType.AK:
			if _is_attack_pressed() and shoot_cooldown <= 0.0:
				shoot_ak()
		elif current_weapon == WeaponType.SHOTGUN:
			if _is_attack_just_pressed() and shoot_cooldown <= 0.0 and attack_cooldown_timer <= 0.0:
				shoot_shotgun()

func _handle_movement_and_gravity(delta: float) -> void:
	var dir = Input.get_axis("a", "d")
	if Input.is_action_just_pressed("w"):
		jump_buffer_timer = JUMP_BUFFER_TIME

	was_on_floor_prev = is_on_floor()

	if is_on_floor():
		coyote_timer = COYOTE_TIME
		can_double_jump = true

	if not is_on_floor():
		var fast_fall = Input.is_action_pressed("s")
		velocity.y = move_toward(velocity.y, FAST_FALL_SPEED if fast_fall else MAX_FALL_SPEED, (GRAVITY * 3.0 if fast_fall else GRAVITY) * delta)

	if wall_jump_lock <= 0:
		var accel = ACCELERATION if is_on_floor() else AIR_ACCELERATION
		var decel = DECELERATION if is_on_floor() else AIR_DECELERATION
		var current_speed = SPEED

		if is_saw_pushing and dir != 0.0 and sign(dir) == sign(facing):
			if _is_saw_hitting_enemy():
				current_speed = SPEED * 0.4 # Смягчили замедление (было 0.1) ✨

		velocity.x = move_toward(velocity.x, dir * current_speed, (accel if dir != 0 else decel) * delta)
	var on_wall = _check_is_on_wall()
	var wall_sliding = on_wall and not is_on_floor()
	if wall_sliding and velocity.y > WALL_SLIDE_SPEED:
		velocity.y = WALL_SLIDE_SPEED
	was_on_wall = on_wall

	if jump_buffer_timer > 0 and coyote_timer > 0:
		velocity.y = JUMP_FORCE
		jump_buffer_timer = 0.0
		coyote_timer = 0.0
	elif Input.is_action_just_pressed("w"):
		if wall_sliding:
			velocity.x = get_wall_normal().x * WALL_JUMP_FORCE_X
			velocity.y = WALL_JUMP_FORCE_Y
			wall_jump_lock = 0.04
		elif can_double_jump:
			velocity.y = JUMP_FORCE
			can_double_jump = false

	if Input.is_action_just_released("w") and velocity.y < 0:
		velocity.y *= JUMP_CUT_MULTIPLIER

	velocity += knockback
	knockback = knockback.move_toward(Vector2.ZERO, 880.3 * delta)

	move_and_slide()
	_handle_step_climb(dir)

func _check_is_on_wall() -> bool:
	for i in range(get_slide_collision_count()):
		var col = get_slide_collision(i)
		var collider = col.get_collider()
		if collider and abs(col.get_normal().x) > 0.5 and not collider.is_in_group("no_wall_slide"):
			return true
	return false

func _handle_step_climb(dir: float) -> void:
	if dir == 0 or not is_on_floor() or not is_on_wall():
		return
	for i in range(1, int(MAX_STEP_HEIGHT) + 1):
		var test_trans = global_transform.translated(Vector2(0, -i))
		if not test_move(test_trans, Vector2(sign(dir) * 1.4, 0)):
			global_position.y -= i
			global_position.x += sign(dir) * 0.7
			break

func _check_hazards() -> void:
	for i in range(get_slide_collision_count()):
		var collider = get_slide_collision(i).get_collider()
		if collider and collider.is_in_group("spikes"):
			take_hit(collider.global_position, true)
			return

func _update_visuals_and_animations(delta: float) -> void:
	var dir = Input.get_axis("a", "d")
	var is_aiming_or_attacking = is_attacking or is_saw_pushing or _is_attack_pressed() or attack_cooldown_timer > 0.0

	if ruki is AnimatedSprite2D:
		var prefix = ["saw_", "shotgun_", "ak_", "flame_"][current_weapon]
		var target_anim = prefix + ("attack" if is_aiming_or_attacking else "normal")
		if ruki.animation != target_anim:
			ruki.play(target_anim)

	if not is_attacking and not is_saw_pushing:
		var to_mouse_x = get_global_mouse_position().x - global_position.x
		if abs(to_mouse_x) > 1.0:
			facing = sign(to_mouse_x)

	if telo: telo.scale.x = facing
	if collision_shape: collision_shape.scale.x = facing

	if tul:
		var body_anim = "walk" if (dir != 0 and is_on_floor()) else "idle"
		if tul.animation != body_anim:
			tul.play(body_anim)

	var should_crouch = is_on_floor() and dir == 0 and Input.is_action_pressed("s")
	crouch_current = lerp(crouch_current, 1.0 if should_crouch else 0.0, delta * CROUCH_SPEED)

	if tul:
		var breath = sin(Time.get_ticks_msec() * 0.003) * 0.15
		tul.position.y = tul_base_y + breath + crouch_current * CROUCH_OFFSET
		tul.scale = tulo_original_scale

	_update_hands_position(delta, is_aiming_or_attacking)

	var should_walk_particles = is_on_floor() and abs(velocity.x) > 1.0
	if should_walk_particles != walk_particles_enabled:
		walk_particles_enabled = should_walk_particles
		if walk_particles:
			walk_particles.emitting = walk_particles_enabled

func _update_hands_position(delta: float, is_aiming_or_attacking: bool) -> void:
	chainsaw_shake_time += delta * (25.0 if is_aiming_or_attacking else 10.0)
	var shake_dist = 1.23 if is_aiming_or_attacking else 0.35
	var shake_rot_deg = 3.5 if is_aiming_or_attacking else 1.0
	if current_weapon == WeaponType.FLAMETHROWER and flame_heat > 0.0:
		shake_dist += 0.6 * flame_heat
	var shake_offset = Vector2(sin(chainsaw_shake_time * 1.7), cos(chainsaw_shake_time * 2.3)) * shake_dist
	var shake_rot_val = sin(chainsaw_shake_time * 3.1) * deg_to_rad(shake_rot_deg * 0.8)

	if hand_jump_state == HandJumpState.NORMAL and not is_attacking and not is_saw_pushing and ruki:
		var aim_angle = get_aim_angle_local()
		var aim_dir = Vector2.RIGHT.rotated(aim_angle)
		var is_saw = current_weapon == WeaponType.SAW
		var s_offset = shake_offset if is_saw else Vector2.ZERO
		var s_rot = shake_rot_val if is_saw else 0.0
		var f_offset = 0.0 if is_saw else AIM_FORWARD_OFFSET

		ruki.position = ruki.position.lerp(hands_original_position + s_offset + aim_dir * f_offset, delta * 15.0)
		ruki.rotation = lerp_angle(ruki.rotation, aim_angle + s_rot * 0.3, delta * 20.0)

	if is_attacking and not attack_manual_pose and ruki:
		ruki.rotation = attack_hand_angle_locked + shake_rot_val * 0.5

func shoot_ak() -> void:
	_fire_weapon(AK_FIRE_RATE, AK_SPREAD_ANGLE, 1, 8.0, 1350.0, 300.0, 2.2, 0.03, 0.06, 0.4, 0.08, bullet_scene)

# === ОГНЕМЕТ ===
func _update_flamethrower(delta: float) -> void:
	var wants_fire := current_weapon == WeaponType.FLAMETHROWER and _is_attack_pressed()

	if wants_fire:
		flame_heat = min(1.0, flame_heat + delta / FLAME_RAMP_UP_TIME)
		if shoot_cooldown <= 0.0:
			_spawn_flame_burst()
	else:
		flame_heat = max(0.0, flame_heat - delta / FLAME_RAMP_DOWN_TIME)

func _spawn_flame_burst() -> void:
	shoot_cooldown = FLAME_FIRE_RATE
	start_shake(0.35, 0.06)

	if not flame_bullet_scene:
		return

	var muzzle_pos = _get_muzzle_position()
	var base_angle: float
	if ruki:
		base_angle = _local_angle_to_world(ruki.rotation)
	else:
		base_angle = (get_global_mouse_position() - muzzle_pos).angle()

	var spread = FLAME_SPREAD_ANGLE * lerp(0.5, 1.0, flame_heat)
	var speed_mult = lerp(0.4, 1.0, flame_heat)

	for i in range(FLAME_PARTICLES_PER_TICK):
		var angle = base_angle + randf_range(-spread / 2.0, spread / 2.0)
		var dir = Vector2.RIGHT.rotated(angle)
		var bullet = flame_bullet_scene.instantiate()
		get_tree().current_scene.add_child(bullet)
		bullet.global_position = muzzle_pos + dir * randf_range(0.0, 8.0)
		bullet.rotation = angle
		if "velocity" in bullet:
			bullet.velocity = dir * randf_range(FLAME_SPEED_MIN, FLAME_SPEED_MAX) * speed_mult

		var target_scale = Vector2.ONE * lerp(0.5, 1.0, flame_heat)
		bullet.scale = Vector2.ZERO
		if "modulate" in bullet:
			bullet.modulate.a = 0.0

		var tween = bullet.create_tween().set_parallel(true)
		tween.tween_property(bullet, "scale", target_scale, 0.05).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		if "modulate" in bullet:
			tween.tween_property(bullet, "modulate:a", 1.0, 0.04)

func shoot_shotgun() -> void:
	_fire_weapon(SHOTGUN_FIRE_RATE, SPREAD_ANGLE, PELLET_COUNT, 12.0, 1232.4, 264.1, 4.93, 0.04, 0.18, 1.2, 0.18, bullet_scene)

func _fire_weapon(rate: float, spread: float, pellets: int, damage: float, bullet_speed: float, ray_len: float, recoil_dist: float, out_t: float, back_t: float, shake_i: float, shake_d: float, scene: PackedScene) -> void:
	shoot_cooldown = rate
	start_shake(shake_i, shake_d)

	var muzzle_pos = _get_muzzle_position()
	var base_angle: float
	if ruki:
		base_angle = _local_angle_to_world(ruki.rotation)
	else:
		base_angle = (get_global_mouse_position() - muzzle_pos).angle()

	_kill_tween(hands_tween)
	hands_tween = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_STOP)
	if ruki:
		var recoil_dir = -Vector2.RIGHT.rotated(base_angle) * recoil_dist
		hands_tween.tween_property(ruki, "position", hands_original_position + recoil_dir, out_t).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
		hands_tween.tween_property(ruki, "position", hands_original_position, back_t).set_trans(Tween.TRANS_SPRING)

	var space_state = get_world_2d().direct_space_state
	for i in range(pellets):
		var pellet_angle = base_angle + randf_range(-spread / 2.0, spread / 2.0)
		var pellet_dir = Vector2.RIGHT.rotated(pellet_angle)

		var depth_offset = randf_range(-10.0, 14.0)
		var actual_speed = bullet_speed * randf_range(0.88, 1.12)
		var spawn_pos = muzzle_pos + pellet_dir * depth_offset

		if scene:
			var bullet = scene.instantiate()
			get_tree().current_scene.add_child(bullet)
			bullet.global_position = spawn_pos
			if "velocity" in bullet: bullet.velocity = pellet_dir * actual_speed
			if "rotation" in bullet: bullet.rotation = pellet_angle
		else:
			var query = PhysicsRayQueryParameters2D.create(spawn_pos, spawn_pos + pellet_dir * ray_len)
			query.exclude = [get_rid()]
			var result = space_state.intersect_ray(query)
			if result and result.collider and result.collider.has_method("take_damage"):
				result.collider.take_damage(damage)
				spawn_shotgun_hit_blood(result.position, pellet_dir)

func spawn_shotgun_hit_blood(hit_pos: Vector2, hit_dir: Vector2) -> void:
	if not blood_drop_scene:
		return
	for i in range(6):
		var drop = blood_drop_scene.instantiate()
		get_tree().current_scene.add_child(drop)
		drop.global_position = hit_pos
		var vel_dir = hit_dir.rotated(randf_range(-deg_to_rad(28.0), deg_to_rad(28.0)))
		drop.velocity = vel_dir * randf_range(88.0, 246.5)

func perform_chainsaw_attack_visual() -> void:
	is_attacking = true
	attack_manual_pose = false
	attack_combo_reset_timer = COMBO_RESET_WINDOW

	if chainsaw_hitbox: chainsaw_hitbox.monitoring = true

	var mouse_pos = get_global_mouse_position()
	var dir_x = sign(mouse_pos.x - global_position.x)
	if dir_x != 0:
		facing = dir_x
		if telo: telo.scale.x = facing
		if collision_shape: collision_shape.scale.x = facing

	var base_angle = get_aim_angle_local()
	attack_hand_angle_locked = base_angle
	attack_swing_rotation = base_angle

	var current_step = attack_combo_step
	attack_combo_step = (attack_combo_step + 1) % 2

	match current_step:
		0: await _perform_slash_attack(base_angle, true)
		1: await _perform_slash_attack(base_angle, false)

	if chainsaw_hitbox: chainsaw_hitbox.monitoring = false
	attack_manual_pose = false
	is_attacking = false

	reset_hands_position()

func _perform_slash_attack(base_angle: float, is_downward: bool) -> void:
	attack_cooldown_timer = SLASH_DURATION + SLASH_WINDUP_TIME + SLASH_COOLDOWN_PADDING
	attack_manual_pose = true

	var start_angle = (base_angle - SLASH_ARC_HALF) if is_downward else (base_angle + SLASH_ARC_HALF)
	var end_angle = (base_angle + SLASH_ARC_HALF) if is_downward else (base_angle - SLASH_ARC_HALF)
	var initial_rot = ruki.rotation if ruki else 0.0

	_kill_tween(hands_tween)
	hands_tween = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_STOP).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	hands_tween.tween_method(_apply_slash_pose.bind(initial_rot, start_angle), 0.0, 1.0, SLASH_WINDUP_TIME)

	_kill_tween(tulo_attack_tween)
	tulo_attack_tween = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_STOP)
	if tul:
		tulo_attack_tween.tween_property(tul, "rotation", (-0.12 if is_downward else 0.12) * facing, SLASH_WINDUP_TIME)

	start_shake(1.4, 0.12)
	await get_tree().create_timer(SLASH_WINDUP_TIME, false).timeout

	var swing_dir_x = cos(base_angle) * facing
	var dash_sign = sign(swing_dir_x) if swing_dir_x != 0.0 else facing
	velocity.x += dash_sign * SLASH_DASH_FORCE

	var swing_tween = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_STOP).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	swing_tween.tween_method(_apply_slash_pose.bind(start_angle, end_angle), 0.0, 1.0, SLASH_DURATION)

	start_shake(4.0, SLASH_DURATION)

	_kill_tween(tulo_attack_tween)
	tulo_attack_tween = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_STOP)
	if tul:
		tulo_attack_tween.tween_property(tul, "rotation", (0.12 if is_downward else -0.12) * facing, SLASH_DURATION * 0.6)
		tulo_attack_tween.tween_property(tul, "rotation", 0.0, SLASH_DURATION * 0.4)

	await swing_tween.finished

func _apply_slash_pose(t: float, start_angle: float, end_angle: float) -> void:
	var current_angle = lerp_angle(start_angle, end_angle, t)
	attack_swing_rotation = current_angle
	if ruki:
		ruki.rotation = current_angle
		ruki.position = hands_original_position + Vector2.RIGHT.rotated(current_angle) * SLASH_ARC_RADIUS

func _get_saw_blood_pos(fallback_body: Node2D = null) -> Vector2:
	if blood_marker:
		return blood_marker.global_position
	if ruki:
		return ruki.global_position
	if fallback_body:
		return fallback_body.global_position
	return global_position

func _on_chainsaw_body_entered(body: Node2D) -> void:
	if is_saw_pushing:
		return
	if not body.has_method("take_damage"):
		return
	body.take_damage(SLASH_HIT_DAMAGE)
	start_shake(SLASH_HIT_SHAKE_INTENSITY, SLASH_HIT_SHAKE_DURATION)

	_kill_tween(hands_tween)
	if ruki: ruki.position = hands_original_position + Vector2.RIGHT.rotated(attack_swing_rotation) * SLASH_ARC_RADIUS

	hit_stop()
	var saw_tip_pos = _get_saw_blood_pos(body)
	spawn_chainsaw_blood(saw_tip_pos, _local_angle_to_world(attack_swing_rotation))

func spawn_chainsaw_blood(spawn_pos: Vector2, cut_angle: float) -> void:
	if not blood_drop_scene:
		return

	var center_angle = cut_angle + PI
	var burst_interval = HITSTOP_DURATION / float(BLOOD_BURST_COUNT)

	for burst in range(BLOOD_BURST_COUNT):
		var drops_this_burst = randi_range(BLOOD_DROPS_PER_BURST_MIN, BLOOD_DROPS_PER_BURST_MAX)
		for i in range(drops_this_burst):
			var drop = blood_drop_scene.instantiate()
			get_tree().current_scene.add_child(drop)
			drop.process_mode = Node.PROCESS_MODE_ALWAYS

			var spawn_offset = Vector2.RIGHT.rotated(center_angle) * randf_range(0.0, 21.1)
			var random_jitter = Vector2(randf_range(-1.76, 1.76), randf_range(-1.76, 1.76))
			drop.global_position = spawn_pos + spawn_offset + random_jitter

			var final_angle = center_angle + randf_range(-deg_to_rad(30.0), deg_to_rad(30.0))
			var roll = randf()
			var speed = randf_range(28.2, 211.3) if roll < 0.25 else (randf_range(211.3, 528.2) if roll < 0.75 else randf_range(528.2, 845.1))
			drop.velocity = Vector2(cos(final_angle), sin(final_angle)) * speed

		if burst < BLOOD_BURST_COUNT - 1:
			await get_tree().create_timer(burst_interval, true, false, true).timeout

func _handle_saw_push(delta: float) -> void:
	if not is_saw_pushing:
		is_saw_pushing = true
		attack_manual_pose = true
		saw_push_damage_timer = 0.0
		saw_push_aim_angle = get_aim_angle_local()
		if chainsaw_hitbox:
			chainsaw_hitbox.monitoring = true
			chainsaw_hitbox.monitorable = true

	var stuck_in_enemy = _is_saw_hitting_enemy()

	if not stuck_in_enemy:
		var mouse_pos = get_global_mouse_position()
		var dir_x = sign(mouse_pos.x - global_position.x)
		if dir_x != 0:
			facing = dir_x
			if telo: telo.scale.x = facing
			if collision_shape: collision_shape.scale.x = facing

	var target_aim = get_aim_angle_local()
	var turn_speed = SAW_PUSH_STUCK_TURN_SPEED if stuck_in_enemy else SAW_PUSH_FREE_TURN_SPEED
	saw_push_aim_angle = move_toward(saw_push_aim_angle, target_aim, turn_speed * delta)

	# ⚡ Добавляем резкие микро-рывки и нестабильность при пилении врага ✨
	if stuck_in_enemy:
		saw_push_aim_angle += randf_range(-deg_to_rad(4.5), deg_to_rad(4.5))

	var aim_angle = saw_push_aim_angle
	attack_hand_angle_locked = aim_angle

	chainsaw_shake_time += delta * 25.0
	var shake_offset = Vector2(sin(chainsaw_shake_time * 1.7), cos(chainsaw_shake_time * 2.3)) * 1.23
	var shake_rot_val = sin(chainsaw_shake_time * 3.1) * deg_to_rad(2.8)

	if ruki:
		var push_dir = Vector2.RIGHT.rotated(aim_angle)
		var target_pos = hands_original_position + shake_offset + push_dir * SAW_PUSH_HAND_OFFSET
		ruki.position = ruki.position.lerp(target_pos, delta * SAW_PUSH_MOVE_SPEED)
		ruki.rotation = lerp_angle(ruki.rotation, aim_angle + shake_rot_val, delta * SAW_PUSH_MOVE_SPEED)

	saw_push_damage_timer -= delta
	if saw_push_damage_timer <= 0.0:
		saw_push_damage_timer = SAW_PUSH_TICK_INTERVAL
		_apply_saw_push_damage()

func _stop_saw_push() -> void:
	is_saw_pushing = false
	attack_manual_pose = false
	if chainsaw_hitbox:
		chainsaw_hitbox.monitoring = false
	reset_hands_position()

func _apply_saw_push_damage() -> void:
	if not chainsaw_hitbox:
		return
	for body in chainsaw_hitbox.get_overlapping_bodies():
		if body == self:
			continue
		if body.has_method("take_damage"):
			body.take_damage(SAW_PUSH_DAMAGE_PER_TICK)
			start_shake(SAW_PUSH_SHAKE_INTENSITY, SAW_PUSH_SHAKE_DURATION)
			var saw_tip_pos = _get_saw_blood_pos(body)
			_spawn_saw_push_blood(saw_tip_pos, _local_angle_to_world(attack_hand_angle_locked))

func _spawn_saw_push_blood(spawn_pos: Vector2, cut_angle: float) -> void:
	if not blood_drop_scene:
		return
	var center_angle = cut_angle + PI
	var drops = randi_range(SAW_PUSH_BLOOD_DROPS_MIN, SAW_PUSH_BLOOD_DROPS_MAX)
	for i in range(drops):
		var drop = blood_drop_scene.instantiate()
		get_tree().current_scene.add_child(drop)
		drop.process_mode = Node.PROCESS_MODE_ALWAYS

		var spawn_offset = Vector2.RIGHT.rotated(center_angle) * randf_range(0.0, 14.0)
		var random_jitter = Vector2(randf_range(-1.5, 1.5), randf_range(-1.5, 1.5))
		drop.global_position = spawn_pos + spawn_offset + random_jitter

		var final_angle = center_angle + randf_range(-deg_to_rad(32.0), deg_to_rad(32.0))
		var speed = randf_range(120.0, 420.0)
		drop.velocity = Vector2(cos(final_angle), sin(final_angle)) * speed

func reset_hands_position() -> void:
	if not ruki: return
	_kill_tween(hands_tween)
	hands_tween = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_STOP)
	hands_tween.tween_property(ruki, "position", hands_original_position, 0.1)
	hands_tween.parallel().tween_property(ruki, "rotation", hands_original_rotation, 0.1)
	hand_jump_state = HandJumpState.NORMAL

func take_hit(from_position: Vector2, _ignore_dash: bool = false) -> void:
	var dir = global_position - from_position
	knockback = dir.normalized() * 123.2
	knockback.y = -776.8
	die(from_position)

func die(from_position: Vector2 = global_position) -> void:
	if is_dead:
		return
	is_dead = true

	if is_saw_pushing:
		_stop_saw_push()

	if chainsaw_hitbox: chainsaw_hitbox.monitoring = false

	if death_blood_scene:
		var blood_instance = death_blood_scene.instantiate()
		get_tree().current_scene.add_child(blood_instance)
		blood_instance.global_position = global_position
		var away_dir_x = (global_position - from_position).x
		if abs(away_dir_x) < 0.2: away_dir_x = -facing
		if away_dir_x < 0: blood_instance.scale.x = -1

	if has_node("DeathBleedParticles"):
		$DeathBleedParticles.emitting = true

	collision_layer = 0
	collision_mask = 1
	hitstop_timer = 0
	start_shake(5.0, 0.25)

	attack_manual_pose = false
	attack_combo_step = 0
	crouch_current = 0.0

	if tul:
		tul.scale = tulo_original_scale
		tul.position.x = tul_base_x
		tul.position.y = tul_base_y
		tul.rotation = 0.0
		if tul.sprite_frames and tul.sprite_frames.has_animation("dead"):
			tul.play("dead")
		else:
			tul.stop()

	_kill_tween(hands_tween)
	_kill_tween(tulo_attack_tween)

	reset_hands_position()

	var away_dir = (global_position - from_position).normalized()
	if abs(away_dir.x) < 0.2: away_dir.x = -facing

	velocity = Vector2(away_dir.x * 440.1, -387.3)
	death_rotation_speed = randf_range(28.0, 38.0) * sign(away_dir.x)
	death_bounces = 0

	if restart_prompt:
		restart_prompt.visible = true
		restart_prompt.position = restart_prompt_target_pos + Vector2(0, 52.8)
		_kill_tween(restart_prompt_tween)
		restart_prompt_tween = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_STOP).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		restart_prompt_tween.tween_property(restart_prompt, "position", restart_prompt_target_pos, 2)

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
			death_rotation_speed = 3.0 * sign(velocity.x)
		elif death_bounces == 1:
			if normal.y < -0.7:
				death_bounces = 2
				velocity = velocity.bounce(normal) * 0.15
			else:
				velocity = velocity.bounce(normal) * 0.3

	if death_bounces >= 2:
		velocity.x = move_toward(velocity.x, 0.0, 1056.3 * delta)
		death_rotation_speed = 0.0
		if telo:
			telo.rotation = lerp_angle(telo.rotation, sign(facing) * deg_to_rad(85.0), delta * 12.0)

	if (Input.is_key_pressed(KEY_R) or Input.is_action_just_pressed("r")) and not is_restarting:
		start_fade_and_restart()

func start_fade_and_restart() -> void:
	is_restarting = true

	var fade_layer = CanvasLayer.new()
	fade_layer.name = "FADE_LAYER"
	fade_layer.layer = 128
	get_tree().root.add_child(fade_layer)

	var fade_rect = ColorRect.new()
	fade_rect.color = Color(0, 0, 0, 0)
	fade_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fade_layer.add_child(fade_rect)

	var tween = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_STOP).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(fade_rect, "color:a", 1.0, 0.5)
	tween.tween_callback(respawn)

func respawn() -> void:
	is_restarting = false

	if restart_prompt:
		restart_prompt.visible = false
		restart_prompt.position = restart_prompt_target_pos + Vector2(0, 52.8)

	get_tree().reload_current_scene()
	is_dead = false

	if has_node("DeathBleedParticles"):
		$DeathBleedParticles.emitting = false

	if telo:
		telo.visible = true
		telo.rotation = 0.0
	collision_layer = 1
	collision_mask = 1

	if tul:
		tul.play("idle")

	global_position = start_position
	velocity = Vector2.ZERO
	knockback = Vector2.ZERO
	hitstop_timer = 0
	can_double_jump = true
	death_bounces = 0
	attack_combo_step = 0
	attack_manual_pose = false
	is_saw_pushing = false

	flame_heat = 0.0

	if ruki is AnimatedSprite2D:
		ruki.play("saw_normal")
		ruki.speed_scale = 1.0
	reset_hands_position()

	if camera:
		camera_original_pos = camera.position

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

func _kill_tween(tween: Tween) -> void:
	if tween and tween.is_valid():
		tween.kill()

func _local_angle_to_world(local_angle: float) -> float:
	return atan2(sin(local_angle), facing * cos(local_angle))

func _is_saw_hitting_enemy() -> bool:
	if not chainsaw_hitbox:
		return false
	for body in chainsaw_hitbox.get_overlapping_bodies():
		if body != self and body.has_method("take_damage"):
			return true
	return false
