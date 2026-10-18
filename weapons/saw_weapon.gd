class_name SawWeapon
extends Weapon

const SLASH_ARC_HALF: float = deg_to_rad(58.0)
const SLASH_DURATION: float = 0.20
const SLASH_WINDUP_TIME: float = 0.03
const SLASH_ARC_RADIUS: float = 11.0
const SLASH_DASH_FORCE: float = 260.0
const SLASH_COOLDOWN_PADDING: float = 0.8
const SLASH_HIT_DAMAGE: float = 24.0
const SLASH_HIT_SHAKE_INTENSITY: float = 2.4
const SLASH_HIT_SHAKE_DURATION: float = 0.85
const SLASH_COST: float = 8.0

const SAW_TAP_MAX_TIME: float = 0.15
const SAW_CHARGE_TIME: float = 1.0
const SAW_ULT_DAMAGE_MULT: float = 3.0
const SAW_ULT_ARC_MULT: float = 1.3
const SAW_ULT_RADIUS_MULT: float = 1.15
const SAW_ULT_DASH_MULT: float = 1.15
const SAW_ULT_HITBOX_SCALE: float = 1.2
const SAW_ULT_HITSTOP_DURATION: float = 0.5

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
const SAW_PUSH_COST_PER_SEC: float = 6.0

var is_saw_charging: bool = false
var saw_charge_time: float = 0.0
var saw_rmb_hold: float = 0.0
var saw_push_damage_timer: float = 0.0
var saw_push_aim_angle: float = 0.0
var current_attack_is_ult: bool = false

var _hit_bodies: Array = []

func _init() -> void:
	anim_prefix = "saw_"

# ---------- Общие обновления ----------

func has_ammo() -> bool:
	return hands.ammo[type] >= SLASH_COST

func is_active() -> bool:
	return hands.is_saw_pushing or super.is_active()

func exit() -> void:
	_stop_push()
	_cancel_charge()

func on_player_died() -> void:
	_stop_push()
	_cancel_charge()

func physics_update(delta: float) -> void:
	var lmb_held: bool = _is_push_pressed() and hands.ammo[type] > 0.0
	var rmb_held: bool = hands.is_attack_pressed() and hands.ammo[type] >= SLASH_COST

	if rmb_held or is_saw_charging or saw_rmb_hold > 0.0:
		if hands.is_saw_pushing: _stop_push()
		if not hands.is_attacking: _handle_charge(delta, rmb_held)
		return

	if lmb_held and not hands.is_attacking: _handle_push(delta)
	elif hands.is_saw_pushing: _stop_push()

func _is_push_pressed() -> bool:
	return Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) or Input.is_action_pressed("lkm")

# ---------- Поза рук ----------

func update_pose(delta: float) -> void:
	if is_saw_charging:
		_update_charge_pose(delta)
		return
	var active := is_active()
	var aim := hands.get_aim_angle_local()
	var pos := hands.origin_position + hands.shake_offset(1.23 if active else 0.35)
	var rot := aim + sin(hands.chainsaw_shake_time * 3.1) * deg_to_rad((3.5 if active else 1.0) * 0.8) * 0.3
	hands.position = hands.position.lerp(pos, delta * 45.0)
	hands.rotation = lerp_angle(hands.rotation, rot, delta * 50.0)

func _update_charge_pose(delta: float) -> void:
	var t := saw_charge_time / SAW_CHARGE_TIME
	var windup_angle := hands.get_aim_angle_local() - SLASH_ARC_HALF * t
	var target_pos := hands.origin_position + hands.shake_offset(lerpf(0.35, 3.0, t)) + Vector2.from_angle(windup_angle) * SLASH_ARC_RADIUS * t
	var target_rot := windup_angle + sin(hands.chainsaw_shake_time * 3.1) * deg_to_rad(2.0) * t
	hands.position = hands.position.lerp(target_pos, delta * 15.0)
	hands.rotation = lerp_angle(hands.rotation, target_rot, delta * 18.0)

# ---------- Зарядка и удар ----------

func _handle_charge(delta: float, rmb_held: bool) -> void:
	if not is_saw_charging and hands.attack_cooldown_timer > 0.0:
		saw_rmb_hold = 0.0
		return

	if rmb_held:
		saw_rmb_hold += delta
		if saw_rmb_hold >= SAW_TAP_MAX_TIME and not is_saw_charging:
			is_saw_charging = true
			saw_charge_time = 0.0
		if is_saw_charging: saw_charge_time = minf(saw_charge_time + delta, SAW_CHARGE_TIME)
		return

	if is_saw_charging:
		var was_full := saw_charge_time >= SAW_CHARGE_TIME
		is_saw_charging = false
		saw_charge_time = 0.0
		saw_rmb_hold = 0.0
		if was_full: perform_slash(true)
	elif saw_rmb_hold > 0.0 and saw_rmb_hold < SAW_TAP_MAX_TIME:
		saw_rmb_hold = 0.0
		perform_slash(false)
	else:
		saw_rmb_hold = 0.0

func _cancel_charge() -> void:
	is_saw_charging = false
	saw_charge_time = 0.0
	saw_rmb_hold = 0.0

func perform_slash(is_ult: bool = false) -> void:
	if not hands.spend(type, SLASH_COST): return
	hands.is_attacking = true
	current_attack_is_ult = is_ult
	_hit_bodies.clear()
	if hands.chainsaw_hitbox and is_ult: hands.chainsaw_hitbox.scale = Vector2.ONE * SAW_ULT_HITBOX_SCALE
	player.face_mouse()
	var base_angle := hands.get_aim_angle_local()
	hands.attack_swing_rotation = base_angle
	await _perform_slash_attack(base_angle, true, is_ult)

	if hands.chainsaw_hitbox:
		hands.chainsaw_hitbox.monitoring = false
		hands.chainsaw_hitbox.scale = Vector2.ONE
	hands.is_attacking = false
	current_attack_is_ult = false
	hands.reset_hands_position()

func _perform_slash_attack(base_angle: float, is_downward: bool, is_ult: bool = false) -> void:
	hands.attack_cooldown_timer = SLASH_DURATION + SLASH_WINDUP_TIME + SLASH_COOLDOWN_PADDING
	var arc_half := SLASH_ARC_HALF * (SAW_ULT_ARC_MULT if is_ult else 1.0)
	var arc := arc_half if is_downward else -arc_half
	var arc_radius := SLASH_ARC_RADIUS * (SAW_ULT_RADIUS_MULT if is_ult else 1.0)
	var lean: float = (0.12 if is_downward else -0.12) * player.facing

	var windup_tween := hands.new_tween(hands.hands_tween).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	hands.hands_tween = windup_tween
	windup_tween.tween_method(hands.apply_slash_pose.bind(hands.rotation, base_angle - arc, arc_radius), 0.0, 1.0, SLASH_WINDUP_TIME)
	player.body_lean(-lean, SLASH_WINDUP_TIME)
	player.start_shake(1.4, 0.12)
	await get_tree().create_timer(SLASH_WINDUP_TIME, false).timeout

	if hands.chainsaw_hitbox: hands.chainsaw_hitbox.monitoring = true
	player.add_dash(SLASH_DASH_FORCE * (SAW_ULT_DASH_MULT if is_ult else 1.0))
	var swing_tween := hands.new_tween().set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	swing_tween.tween_method(hands.apply_slash_pose.bind(base_angle - arc, base_angle + arc, arc_radius), 0.0, 1.0, SLASH_DURATION)
	player.start_shake(4.0 * (1.5 if is_ult else 1.0), SLASH_DURATION)
	player.body_lean_strike(lean, SLASH_DURATION)
	await swing_tween.finished

func on_hitbox_body_entered(body: Node2D) -> void:
	if body in _hit_bodies: return
	_hit_bodies.append(body)

	body.take_damage(SLASH_HIT_DAMAGE * (SAW_ULT_DAMAGE_MULT if current_attack_is_ult else 1.0))
	player.start_shake(SLASH_HIT_SHAKE_INTENSITY, SLASH_HIT_SHAKE_DURATION)
	hands.kill_tween(hands.hands_tween)
	hands.position = hands.origin_position + Vector2.from_angle(hands.attack_swing_rotation) * (SLASH_ARC_RADIUS * (SAW_ULT_RADIUS_MULT if current_attack_is_ult else 1.0))

	var stop_time := SAW_ULT_HITSTOP_DURATION if current_attack_is_ult else PlayerHands.HITSTOP_DURATION
	hands.spawn_chainsaw_blood(hands.get_blood_pos(body), hands.local_angle_to_world(hands.attack_swing_rotation), stop_time)
	hands.hit_stop(null, stop_time)

# ---------- Режим "давить пилой" ----------

func _handle_push(delta: float) -> void:
	if not hands.is_saw_pushing:
		hands.is_saw_pushing = true
		saw_push_damage_timer = 0.0
		saw_push_aim_angle = hands.get_aim_angle_local()
		if hands.chainsaw_hitbox:
			hands.chainsaw_hitbox.monitoring = true
			hands.chainsaw_hitbox.monitorable = true

	hands.drain(type, SAW_PUSH_COST_PER_SEC * delta)
	var stuck := not hands.saw_targets().is_empty()
	if not stuck: player.face_mouse()

	saw_push_aim_angle = move_toward(saw_push_aim_angle, hands.get_aim_angle_local(), (SAW_PUSH_STUCK_TURN_SPEED if stuck else SAW_PUSH_FREE_TURN_SPEED) * delta)
	if stuck: saw_push_aim_angle += randf_range(-deg_to_rad(4.5), deg_to_rad(4.5))

	hands.chainsaw_shake_time += delta * 25.0
	hands.position = hands.position.lerp(hands.origin_position + hands.shake_offset(1.23) + Vector2.from_angle(saw_push_aim_angle) * SAW_PUSH_HAND_OFFSET, delta * SAW_PUSH_MOVE_SPEED)
	hands.rotation = lerp_angle(hands.rotation, saw_push_aim_angle + sin(hands.chainsaw_shake_time * 3.1) * deg_to_rad(2.8), delta * SAW_PUSH_MOVE_SPEED)

	saw_push_damage_timer -= delta
	if saw_push_damage_timer <= 0.0:
		saw_push_damage_timer = SAW_PUSH_TICK_INTERVAL
		_apply_push_damage()

func _stop_push() -> void:
	hands.is_saw_pushing = false
	if hands.chainsaw_hitbox: hands.chainsaw_hitbox.monitoring = false
	hands.reset_hands_position()

func _apply_push_damage() -> void:
	for body in hands.saw_targets():
		body.take_damage(SAW_PUSH_DAMAGE_PER_TICK)
		player.start_shake(SAW_PUSH_SHAKE_INTENSITY, SAW_PUSH_SHAKE_DURATION)
		if hands.blood_drop_scene:
			var center: float = hands.local_angle_to_world(saw_push_aim_angle) + PI
			for i in randi_range(SAW_PUSH_BLOOD_DROPS_MIN, SAW_PUSH_BLOOD_DROPS_MAX):
				hands.blood_drop(hands.get_blood_pos(body), center, 14.0, 1.5, 32.0, randf_range(120.0, 420.0))
