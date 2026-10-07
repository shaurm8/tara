class_name PlayerHands
extends Node2D

const MIN_AIM_DISTANCE := 20.0
const AIM_LIMIT := deg_to_rad(85.0)
const AIM_FORWARD_OFFSET := 3.0

const SHOTGUN_FIRE_RATE := 0.55
const PELLET_COUNT := 7
const SPREAD_ANGLE := deg_to_rad(18.0)
const AK_FIRE_RATE := 0.09
const AK_SPREAD_ANGLE := deg_to_rad(4.0)

const SLASH_ARC_HALF := deg_to_rad(58.0)
const SLASH_DURATION := 0.20
const SLASH_WINDUP_TIME := 0.03
const SLASH_ARC_RADIUS := 11.0
const SLASH_DASH_FORCE := 260.0
const SLASH_COOLDOWN_PADDING := 0.8
const SLASH_HIT_DAMAGE := 24.0
const SLASH_HIT_SHAKE_INTENSITY := 2.4
const SLASH_HIT_SHAKE_DURATION := 0.85
const BLOOD_BURST_COUNT := 20
const BLOOD_DROPS_PER_BURST_MIN := 70
const BLOOD_DROPS_PER_BURST_MAX := 80
const HITSTOP_DURATION := 0.3

const SAW_TAP_MAX_TIME := 0.15
const SAW_CHARGE_TIME := 1.0
const SAW_ULT_DAMAGE_MULT := 3.0
const SAW_ULT_ARC_MULT := 1.3
const SAW_ULT_RADIUS_MULT := 1.15
const SAW_ULT_DASH_MULT := 1.15
const SAW_ULT_HITBOX_SCALE := 1.2
const SAW_ULT_HITSTOP_DURATION := 0.5

const SAW_PUSH_HAND_OFFSET := 5.0
const SAW_PUSH_MOVE_SPEED := 18.0
const SAW_PUSH_DAMAGE_PER_TICK := 6.0
const SAW_PUSH_TICK_INTERVAL := 0.006
const SAW_PUSH_BLOOD_DROPS_MIN := 35
const SAW_PUSH_BLOOD_DROPS_MAX := 40
const SAW_PUSH_SHAKE_INTENSITY := 0.5
const SAW_PUSH_SHAKE_DURATION := 0.08
const SAW_PUSH_STUCK_TURN_SPEED := deg_to_rad(85.0)
const SAW_PUSH_FREE_TURN_SPEED := deg_to_rad(1000.0)

const FLAME_FIRE_RATE := 0.018
const FLAME_PARTICLES_PER_TICK := 2
const FLAME_SPREAD_ANGLE := deg_to_rad(13.0)
const FLAME_SPEED_MIN := 400.0
const FLAME_SPEED_MAX := 650.0
const FLAME_RAMP_UP_TIME := 0.12
const FLAME_RAMP_DOWN_TIME := 0.15

const TRAIL_LIFETIME := 0.1
const TRAIL_START_ALPHA := 0.3
const TRAIL_GHOSTS_PER_FRAME := 3
const TRAIL_Z_INDEX := 0

const WEAPON_PREFIX: Array[String] = ["saw_", "shotgun_", "ak_", "flame_"]
enum WeaponType { SAW, SHOTGUN, AK, FLAMETHROWER }

@export var bullet_scene: PackedScene
@export var flame_bullet_scene: PackedScene
@export var blood_drop_scene: PackedScene

@onready var sprite: AnimatedSprite2D = self as AnimatedSprite2D
@onready var chainsaw_hitbox: Area2D = get_node_or_null("Hitbox")
@onready var blood_marker: Marker2D = get_node_or_null("BloodMarker")
@onready var muzzle_marker: Marker2D = get_node_or_null("MuzzleMarker")

var player
var current_weapon: WeaponType = WeaponType.SAW

var shoot_cooldown := 0.0
var attack_cooldown_timer := 0.0

var is_attacking := false
var is_saw_pushing := false
var is_saw_charging := false
var current_attack_is_ult := false

var saw_push_damage_timer := 0.0
var saw_push_aim_angle := 0.0
var saw_charge_time := 0.0
var saw_rmb_hold := 0.0
var flame_heat := 0.0

var last_aim_angle := 0.0
var attack_swing_rotation := 0.0
var chainsaw_shake_time := 0.0

var trail_prev_xform: Transform2D
var trail_has_prev := false

var _hit_bodies_this_attack: Array = []

var origin_position := Vector2.ZERO
var origin_rotation := 0.0
var hands_tween: Tween

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	player = get_parent()
	while player and not player is CharacterBody2D:
		player = player.get_parent()
	origin_position = position
	origin_rotation = rotation
	if sprite:
		sprite.play("saw_normal")
		sprite.speed_scale = 1.0
	if chainsaw_hitbox:
		chainsaw_hitbox.monitoring = false
		chainsaw_hitbox.monitorable = false
		if not chainsaw_hitbox.body_entered.is_connected(_on_chainsaw_body_entered):
			chainsaw_hitbox.body_entered.connect(_on_chainsaw_body_entered)

func is_busy() -> bool:
	return is_attacking or is_saw_pushing

func has_saw_targets() -> bool:
	return not _saw_targets().is_empty()

func on_player_died() -> void:
	_stop_saw_push()
	_cancel_saw_charge()

func _unhandled_input(event: InputEvent) -> void:
	if not player or player.is_dead or get_tree().paused or not (event is InputEventMouseButton and event.pressed):
		return
	match event.button_index:
		MOUSE_BUTTON_WHEEL_UP: switch_weapon(1)
		MOUSE_BUTTON_WHEEL_DOWN: switch_weapon(-1)

func _is_attack_pressed(just := false) -> bool:
	var saw := current_weapon == WeaponType.SAW
	var action := "pkm" if saw else "lkm"
	return Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT if saw else MOUSE_BUTTON_LEFT) or (Input.is_action_just_pressed(action) if just else Input.is_action_pressed(action))

func _is_saw_push_pressed() -> bool:
	return Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) or Input.is_action_pressed("lkm")

func switch_weapon(dir := 1) -> void:
	if not is_busy():
		current_weapon = posmod(current_weapon + dir, WeaponType.size()) as WeaponType

func get_aim_angle_local() -> float:
	var parent := get_parent() as Node2D
	if not parent:
		return 0.0
	var diff := parent.to_local(get_global_mouse_position()) - origin_position
	var target := clampf(diff.angle(), -AIM_LIMIT, AIM_LIMIT)
	last_aim_angle = lerp_angle(last_aim_angle, target, get_physics_process_delta_time() * 1.5) if diff.length() < MIN_AIM_DISTANCE else target
	return last_aim_angle

func _local_angle_to_world(a: float) -> float:
	return atan2(sin(a), player.facing * cos(a))

func _marker_pos(m: Node2D) -> Vector2:
	return (m if m else self).global_position

func _aim_world() -> float:
	return _local_angle_to_world(rotation)

func _spawn(scene: PackedScene, pos: Vector2):
	var n = scene.instantiate()
	get_tree().current_scene.add_child(n)
	n.global_position = pos
	return n

func _saw_targets() -> Array:
	return [] if not chainsaw_hitbox else chainsaw_hitbox.get_overlapping_bodies().filter(func(b): return b != player and b.has_method("take_damage"))

func _shake_offset(amp: float) -> Vector2:
	return Vector2(sin(chainsaw_shake_time * 1.7), cos(chainsaw_shake_time * 2.3)) * amp

func _new_tween(old: Tween = null) -> Tween:
	if old and old.is_valid():
		old.kill()
	return create_tween().set_pause_mode(Tween.TWEEN_PAUSE_STOP)

func _ult(base: float, mult: float, is_ult := current_attack_is_ult) -> float:
	return base * (mult if is_ult else 1.0)

func hit_stop(target: Node = null, duration := HITSTOP_DURATION) -> void:
	if target and (target.is_in_group("wall") or target.is_in_group("destructible")):
		return
	get_tree().paused = true
	await get_tree().create_timer(duration, true, false, true).timeout
	get_tree().paused = false

func _physics_process(delta: float) -> void:
	if get_tree().paused or not player or player.is_dead:
		return
	shoot_cooldown = maxf(0.0, shoot_cooldown - delta)
	attack_cooldown_timer = maxf(0.0, attack_cooldown_timer - delta)
	_handle_weapon_inputs(delta)
	_update_animation()
	_update_hands_position(delta)
	_update_trail(delta)

func _is_active() -> bool:
	return is_attacking or is_saw_pushing or _is_attack_pressed() or attack_cooldown_timer > 0.0

func _handle_weapon_inputs(delta: float) -> void:
	_update_flamethrower(delta)
	if current_weapon == WeaponType.SAW:
		_handle_saw_inputs(delta)
		return
	if is_saw_pushing:
		_stop_saw_push()
	if is_saw_charging:
		_cancel_saw_charge()
	if shoot_cooldown > 0.0:
		return
	if current_weapon == WeaponType.AK and _is_attack_pressed():
		shoot_ak()
	elif current_weapon == WeaponType.SHOTGUN and attack_cooldown_timer <= 0.0 and _is_attack_pressed(true):
		shoot_shotgun()

func _handle_saw_inputs(delta: float) -> void:
	var rmb_held := _is_attack_pressed()
	if rmb_held or is_saw_charging or saw_rmb_hold > 0.0:
		if is_saw_pushing:
			_stop_saw_push()
		if not is_attacking:
			_handle_saw_charge(delta, rmb_held)
	elif _is_saw_push_pressed() and not is_attacking:
		_handle_saw_push(delta)
	elif is_saw_pushing:
		_stop_saw_push()

func _handle_saw_charge(delta: float, rmb_held: bool) -> void:
	if not is_saw_charging and attack_cooldown_timer > 0.0:
		saw_rmb_hold = 0.0
		return
	if rmb_held:
		saw_rmb_hold += delta
		if saw_rmb_hold >= SAW_TAP_MAX_TIME and not is_saw_charging:
			is_saw_charging = true
			saw_charge_time = 0.0
		if is_saw_charging:
			saw_charge_time = minf(saw_charge_time + delta, SAW_CHARGE_TIME)
		return
	var was_charging := is_saw_charging
	var was_full := saw_charge_time >= SAW_CHARGE_TIME
	var was_tap := saw_rmb_hold > 0.0 and saw_rmb_hold < SAW_TAP_MAX_TIME
	_cancel_saw_charge()
	if was_charging and was_full:
		perform_chainsaw_attack_visual(true)
	elif not was_charging and was_tap:
		perform_chainsaw_attack_visual(false)

func _cancel_saw_charge() -> void:
	is_saw_charging = false
	saw_charge_time = 0.0
	saw_rmb_hold = 0.0

func _update_animation() -> void:
	if not sprite:
		return
	var anim := WEAPON_PREFIX[current_weapon] + ("attack" if _is_active() else "normal")
	if sprite.animation != anim:
		sprite.play(anim)

func _update_hands_position(delta: float) -> void:
	var active := _is_active()
	chainsaw_shake_time += delta * (25.0 if active else 10.0)
	if is_attacking or is_saw_pushing:
		return
	if is_saw_charging:
		_update_charge_pose(delta)
		return
	var aim := get_aim_angle_local()
	var pos := origin_position
	var rot := aim
	if current_weapon == WeaponType.SAW:
		pos += _shake_offset(1.23 if active else 0.35)
		rot += sin(chainsaw_shake_time * 3.1) * deg_to_rad((3.5 if active else 1.0) * 0.8) * 0.3
	else:
		pos += Vector2.from_angle(aim) * AIM_FORWARD_OFFSET
	position = position.lerp(pos, delta * 15.0)
	rotation = lerp_angle(rotation, rot, delta * 20.0)

func _update_charge_pose(delta: float) -> void:
	var t := saw_charge_time / SAW_CHARGE_TIME
	var windup := get_aim_angle_local() - SLASH_ARC_HALF * t
	var target_pos := origin_position + _shake_offset(lerpf(0.35, 3.0, t)) + Vector2.from_angle(windup) * SLASH_ARC_RADIUS * t
	var target_rot := windup + sin(chainsaw_shake_time * 3.1) * deg_to_rad(2.0) * t
	position = position.lerp(target_pos, delta * 15.0)
	rotation = lerp_angle(rotation, target_rot, delta * 18.0)

func reset_hands_position() -> void:
	hands_tween = _new_tween(hands_tween)
	hands_tween.tween_property(self, "position", origin_position, 0.1)
	hands_tween.parallel().tween_property(self, "rotation", origin_rotation, 0.1)

func _update_trail(delta: float) -> void:
	if not sprite or not (is_attacking or is_saw_pushing):
		trail_has_prev = false
		return
	var current := sprite.global_transform
	if not trail_has_prev:
		trail_prev_xform = current
		trail_has_prev = true
	for i in TRAIL_GHOSTS_PER_FRAME:
		_spawn_trail_ghost(trail_prev_xform.interpolate_with(current, float(i + 1) / TRAIL_GHOSTS_PER_FRAME))
	trail_prev_xform = current

func _spawn_trail_ghost(xform: Transform2D) -> void:
	if not sprite.sprite_frames:
		return
	var tex := sprite.sprite_frames.get_frame_texture(sprite.animation, sprite.frame)
	if not tex:
		return
	var ghost := Sprite2D.new()
	ghost.process_mode = Node.PROCESS_MODE_ALWAYS
	ghost.texture = tex
	ghost.centered = sprite.centered
	ghost.offset = sprite.offset
	ghost.flip_h = sprite.flip_h
	ghost.flip_v = sprite.flip_v
	ghost.material = sprite.material
	ghost.texture_filter = sprite.texture_filter
	ghost.z_index = TRAIL_Z_INDEX
	ghost.modulate = Color(1.0, 1.0, 1.0, TRAIL_START_ALPHA)
	get_tree().current_scene.add_child(ghost)
	ghost.global_transform = xform
	var tween := ghost.create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.tween_property(ghost, "modulate:a", 0.0, TRAIL_LIFETIME)
	tween.tween_callback(ghost.queue_free)

func shoot_ak() -> void:
	_fire_weapon(AK_FIRE_RATE, AK_SPREAD_ANGLE, 1, 8.0, 1350.0, 300.0, 2.2, 0.03, 0.06, 0.4, 0.08)

func shoot_shotgun() -> void:
	_fire_weapon(SHOTGUN_FIRE_RATE, SPREAD_ANGLE, PELLET_COUNT, 12.0, 1232.4, 264.1, 4.93, 0.04, 0.18, 1.2, 0.18)

func _fire_weapon(rate: float, spread: float, pellets: int, damage: float, bullet_speed: float, ray_len: float, recoil: float, out_t: float, back_t: float, shake_i: float, shake_d: float) -> void:
	shoot_cooldown = rate
	player.start_shake(shake_i, shake_d)
	var muzzle := _marker_pos(muzzle_marker)
	var base := _aim_world()

	hands_tween = _new_tween(hands_tween)
	hands_tween.tween_property(self, "position", origin_position - Vector2.from_angle(base) * recoil, out_t).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	hands_tween.tween_property(self, "position", origin_position, back_t).set_trans(Tween.TRANS_SPRING)

	var space := get_world_2d().direct_space_state
	for i in pellets:
		var angle := base + randf_range(-spread / 2.0, spread / 2.0)
		var dir := Vector2.from_angle(angle)
		var pos := muzzle + dir * randf_range(-10.0, 14.0)
		if bullet_scene:
			var bullet = _spawn(bullet_scene, pos)
			bullet.rotation = angle
			if "velocity" in bullet:
				bullet.velocity = dir * bullet_speed * randf_range(0.88, 1.12)
			continue
		var query := PhysicsRayQueryParameters2D.create(pos, pos + dir * ray_len)
		query.exclude = [player.get_rid()]
		var hit := space.intersect_ray(query)
		if hit and hit.collider.has_method("take_damage"):
			hit.collider.take_damage(damage)
			spawn_shotgun_hit_blood(hit.position, dir)

func spawn_shotgun_hit_blood(hit_pos: Vector2, hit_dir: Vector2) -> void:
	if blood_drop_scene:
		for i in 6:
			_blood_drop(hit_pos, hit_dir.angle(), 0.0, 0.0, 28.0, randf_range(88.0, 246.5))

func _update_flamethrower(delta: float) -> void:
	var fire := current_weapon == WeaponType.FLAMETHROWER and _is_attack_pressed()
	flame_heat = clampf(flame_heat + delta / (FLAME_RAMP_UP_TIME if fire else -FLAME_RAMP_DOWN_TIME), 0.0, 1.0)
	if fire and shoot_cooldown <= 0.0:
		_spawn_flame_burst()

func _spawn_flame_burst() -> void:
	shoot_cooldown = FLAME_FIRE_RATE
	player.start_shake(0.35, 0.06)
	if not flame_bullet_scene:
		return
	var muzzle := _marker_pos(muzzle_marker)
	var base := _aim_world()
	var spread := FLAME_SPREAD_ANGLE * lerpf(0.5, 1.0, flame_heat)
	var speed_mult := lerpf(0.4, 1.0, flame_heat)
	var target_scale := Vector2.ONE * lerpf(0.5, 1.0, flame_heat)
	for i in FLAME_PARTICLES_PER_TICK:
		var angle := base + randf_range(-spread / 2.0, spread / 2.0)
		var dir := Vector2.from_angle(angle)
		var bullet = _spawn(flame_bullet_scene, muzzle + dir * randf_range(0.0, 8.0))
		bullet.rotation = angle
		if "velocity" in bullet:
			bullet.velocity = dir * randf_range(FLAME_SPEED_MIN, FLAME_SPEED_MAX) * speed_mult
		bullet.scale = Vector2.ZERO
		bullet.modulate.a = 0.0
		var tween: Tween = bullet.create_tween().set_parallel(true)
		tween.tween_property(bullet, "scale", target_scale, 0.05).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tween.tween_property(bullet, "modulate:a", 1.0, 0.04)

func perform_chainsaw_attack_visual(is_ult := false) -> void:
	is_attacking = true
	current_attack_is_ult = is_ult
	_hit_bodies_this_attack.clear()
	if chainsaw_hitbox and is_ult:
		chainsaw_hitbox.scale = Vector2.ONE * SAW_ULT_HITBOX_SCALE
	player.face_mouse()

	var base_angle := get_aim_angle_local()
	attack_swing_rotation = base_angle
	var arc := _ult(SLASH_ARC_HALF, SAW_ULT_ARC_MULT)
	var radius := _ult(SLASH_ARC_RADIUS, SAW_ULT_RADIUS_MULT)
	var start_angle := base_angle - arc
	var lean: float = 0.12 * player.facing
	attack_cooldown_timer = SLASH_DURATION + SLASH_WINDUP_TIME + SLASH_COOLDOWN_PADDING

	hands_tween = _new_tween(hands_tween).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	hands_tween.tween_method(_apply_slash_pose.bind(rotation, start_angle, radius), 0.0, 1.0, SLASH_WINDUP_TIME)
	player.body_lean(-lean, SLASH_WINDUP_TIME)
	player.start_shake(1.4, 0.12)
	await get_tree().create_timer(SLASH_WINDUP_TIME, false).timeout

	if chainsaw_hitbox:
		chainsaw_hitbox.monitoring = true
	player.add_dash(_ult(SLASH_DASH_FORCE, SAW_ULT_DASH_MULT))
	var swing := _new_tween().set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	swing.tween_method(_apply_slash_pose.bind(start_angle, base_angle + arc, radius), 0.0, 1.0, SLASH_DURATION)
	player.start_shake(_ult(4.0, 1.5), SLASH_DURATION)
	player.body_lean_strike(lean, SLASH_DURATION)
	await swing.finished

	if chainsaw_hitbox:
		chainsaw_hitbox.monitoring = false
		chainsaw_hitbox.scale = Vector2.ONE
	is_attacking = false
	current_attack_is_ult = false
	reset_hands_position()

func _apply_slash_pose(t: float, start_angle: float, end_angle: float, radius := SLASH_ARC_RADIUS) -> void:
	attack_swing_rotation = lerp_angle(start_angle, end_angle, t)
	rotation = attack_swing_rotation
	position = origin_position + Vector2.from_angle(attack_swing_rotation) * radius

func _on_chainsaw_body_entered(body: Node2D) -> void:
	if is_saw_pushing or not body.has_method("take_damage") or body in _hit_bodies_this_attack:
		return
	_hit_bodies_this_attack.append(body)
	body.take_damage(_ult(SLASH_HIT_DAMAGE, SAW_ULT_DAMAGE_MULT))
	player.start_shake(SLASH_HIT_SHAKE_INTENSITY, SLASH_HIT_SHAKE_DURATION)
	if hands_tween and hands_tween.is_valid():
		hands_tween.kill()
	position = origin_position + Vector2.from_angle(attack_swing_rotation) * _ult(SLASH_ARC_RADIUS, SAW_ULT_RADIUS_MULT)
	var stop_time := _ult(HITSTOP_DURATION, SAW_ULT_HITSTOP_DURATION / HITSTOP_DURATION)
	spawn_chainsaw_blood(_marker_pos(blood_marker), _local_angle_to_world(attack_swing_rotation), stop_time)
	hit_stop(null, stop_time)

func _blood_drop(pos: Vector2, center: float, off: float, jit: float, spread_deg: float, speed: float) -> void:
	var jitter := Vector2(randf_range(-jit, jit), randf_range(-jit, jit))
	var drop = _spawn(blood_drop_scene, pos + Vector2.from_angle(center) * randf_range(0.0, off) + jitter)
	drop.process_mode = Node.PROCESS_MODE_ALWAYS
	drop.velocity = Vector2.from_angle(center + deg_to_rad(randf_range(-spread_deg, spread_deg))) * speed

func spawn_chainsaw_blood(spawn_pos: Vector2, cut_angle: float, hitstop_duration := HITSTOP_DURATION) -> void:
	if not blood_drop_scene:
		return
	var center := cut_angle + PI
	var interval := hitstop_duration / BLOOD_BURST_COUNT
	for burst in BLOOD_BURST_COUNT:
		for i in randi_range(BLOOD_DROPS_PER_BURST_MIN, BLOOD_DROPS_PER_BURST_MAX):
			var roll := randf()
			var speed := randf_range(28.2, 211.3) if roll < 0.25 else (randf_range(211.3, 528.2) if roll < 0.75 else randf_range(528.2, 845.1))
			_blood_drop(spawn_pos, center, 21.1, 1.76, 30.0, speed)
		if burst < BLOOD_BURST_COUNT - 1:
			await get_tree().create_timer(interval, true, false, true).timeout

func _handle_saw_push(delta: float) -> void:
	if not is_saw_pushing:
		is_saw_pushing = true
		saw_push_damage_timer = 0.0
		saw_push_aim_angle = get_aim_angle_local()
		if chainsaw_hitbox:
			chainsaw_hitbox.monitoring = true
			chainsaw_hitbox.monitorable = true

	var stuck := has_saw_targets()
	if not stuck:
		player.face_mouse()
	saw_push_aim_angle = move_toward(saw_push_aim_angle, get_aim_angle_local(), (SAW_PUSH_STUCK_TURN_SPEED if stuck else SAW_PUSH_FREE_TURN_SPEED) * delta)
	if stuck:
		saw_push_aim_angle += randf_range(-deg_to_rad(4.5), deg_to_rad(4.5))

	chainsaw_shake_time += delta * 25.0
	var target_pos := origin_position + _shake_offset(1.23) + Vector2.from_angle(saw_push_aim_angle) * SAW_PUSH_HAND_OFFSET
	var target_rot := saw_push_aim_angle + sin(chainsaw_shake_time * 3.1) * deg_to_rad(2.8)
	position = position.lerp(target_pos, delta * SAW_PUSH_MOVE_SPEED)
	rotation = lerp_angle(rotation, target_rot, delta * SAW_PUSH_MOVE_SPEED)

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
		player.start_shake(SAW_PUSH_SHAKE_INTENSITY, SAW_PUSH_SHAKE_DURATION)
		if blood_drop_scene:
			var center := _local_angle_to_world(saw_push_aim_angle) + PI
			for i in randi_range(SAW_PUSH_BLOOD_DROPS_MIN, SAW_PUSH_BLOOD_DROPS_MAX):
				_blood_drop(_marker_pos(blood_marker), center, 14.0, 1.5, 32.0, randf_range(120.0, 420.0))
