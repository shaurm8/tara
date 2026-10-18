class_name AxeWeapon
extends Weapon

const ARC_HALF: float = deg_to_rad(60.0)
const ARC_RADIUS: float = 16.0
const WINDUP_EXTRA: float = 0.35
const TIME_FRACTION: float = 0.85
const TIME_MIN: float = 0.07
const TIME_MAX: float = 0.30
const WINDUP_SHARE: float = 0.2
const DASH_FORCE: float = 22.0
const HIT_DAMAGE: float = 24.0
const STAMINA_COST: float = 4.0
const COMBO_RESET_TIME: float = 0.4
const INTERVAL_FULL: float = 0.10
const INTERVAL_MID: float = 0.18
const INTERVAL_LOW: float = 0.45
const INTERVAL_EMPTY: float = 0.9
const FRAC_MID: float = 0.6
const FRAC_LOW: float = 0.2
const REGEN_DELAY: float = 0.5
const REGEN_DELAY_EMPTY: float = 1.0
const REGEN_RATE_MIN: float = 4.0
const REGEN_RATE_MAX: float = 24.0
const REGEN_RAMP_TIME: float = 3.0
const SWING_SHAKE_INTENSITY: float = 1.6
const HIT_SHAKE_INTENSITY: float = 2.0
const HIT_SHAKE_DURATION: float = 0.15

const THROW_COST: float = 40.0
const THROW_SPEED: float = 750.0
const THROW_WINDUP_TIME: float = 0.08
const THROW_FOLLOW_THROUGH_TIME: float = 0.12
const THROW_EXTENDED_RADIUS: float = 35.0

var cooldown_timer: float = 0.0
var time_since_swing: float = 999.0
var next_down: bool = true
var regen_delay_timer: float = 0.0
var regen_time: float = 0.0

var _sweep_prev_t: float = 0.0
var _hitbox_shape_node: CollisionShape2D
var _hit_bodies: Array = []

func _init() -> void:
	anim_prefix = "axe_"

# ---------- Общие обновления ----------

func always_update(delta: float) -> void:
	cooldown_timer = maxf(0.0, cooldown_timer - delta)
	time_since_swing += delta
	_update_stamina(delta)

func has_ammo() -> bool:
	return not hands.is_axe_thrown

func physics_update(_delta: float) -> void:
	if hands.is_axe_thrown: return
	if (Input.is_action_just_pressed("pkm") or Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT)) and hands.ammo[type] >= THROW_COST:
		if hands.spend(type, THROW_COST):
			_throw_axe()
			return
	if hands.is_attack_pressed() and cooldown_timer <= 0.0 and not hands.is_attacking:
		perform_attack()

func on_hitbox_body_entered(body: Node2D) -> void:
	_hit(body)

# ---------- Стамина ----------

func _interval() -> float:
	var stamina: float = hands.ammo[type]
	if stamina <= 0.0: return INTERVAL_EMPTY
	var f: float = stamina / float(PlayerHands.AMMO_MAX[type])
	if f >= FRAC_MID: return lerpf(INTERVAL_MID, INTERVAL_FULL, (f - FRAC_MID) / (1.0 - FRAC_MID))
	if f >= FRAC_LOW: return lerpf(INTERVAL_LOW, INTERVAL_MID, (f - FRAC_LOW) / (FRAC_MID - FRAC_LOW))
	return INTERVAL_LOW

func _update_stamina(delta: float) -> void:
	regen_delay_timer = maxf(0.0, regen_delay_timer - delta)
	if regen_delay_timer > 0.0 or hands.ammo[type] >= PlayerHands.AMMO_MAX[type]:
		regen_time = 0.0
		return
	regen_time += delta
	hands.add_ammo(type, lerpf(REGEN_RATE_MIN, REGEN_RATE_MAX, clampf(regen_time / REGEN_RAMP_TIME, 0.0, 1.0)) * delta)

# ---------- Бросок ----------

func _throw_axe() -> void:
	hands.is_attacking = true
	var windup_angle := hands.get_aim_angle_local() - ARC_HALF * (1.0 + WINDUP_EXTRA)

	var windup_tween := hands.new_tween(hands.hands_tween).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	hands.hands_tween = windup_tween
	windup_tween.tween_method(hands.apply_slash_pose.bind(hands.rotation, windup_angle, ARC_RADIUS), 0.0, 1.0, THROW_WINDUP_TIME)
	player.body_lean(-0.1 * player.facing, THROW_WINDUP_TIME)
	await windup_tween.finished

	var fresh_aim_local := hands.get_aim_angle_local()
	hands.rotation = fresh_aim_local
	hands.position = hands.origin_position + Vector2.from_angle(fresh_aim_local) * ARC_RADIUS

	hands.is_axe_thrown = true
	if hands.sprite: hands.sprite.play("axe_empty")

	if hands.thrown_axe_scene:
		var axe_node = hands.spawn(hands.thrown_axe_scene, hands.get_muzzle_position())
		if axe_node.has_method("setup"):
			axe_node.setup(player, hands, hands.local_angle_to_world(fresh_aim_local), THROW_SPEED)

	player.start_shake(6.0, 0.15)
	player.body_lean_strike(0.35 * player.facing, THROW_FOLLOW_THROUGH_TIME)

	var throw_pose_angle := fresh_aim_local + ARC_HALF * 0.4
	var follow_tween := hands.new_tween().set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT).set_parallel(true)
	hands.hands_tween = follow_tween
	follow_tween.tween_property(hands, "rotation", throw_pose_angle, THROW_FOLLOW_THROUGH_TIME)
	follow_tween.tween_property(hands, "position", hands.origin_position + Vector2.from_angle(throw_pose_angle) * THROW_EXTENDED_RADIUS, THROW_FOLLOW_THROUGH_TIME)

	await get_tree().create_timer(THROW_FOLLOW_THROUGH_TIME).timeout
	hands.is_attacking = false
	hands.reset_hands_position()

# ---------- Рубящая атака ----------

func perform_attack() -> void:
	hands.is_attacking = true
	_hit_bodies.clear()
	var was_empty: bool = hands.ammo[type] <= 0.0
	hands.drain(type, STAMINA_COST)
	regen_delay_timer = REGEN_DELAY_EMPTY if (was_empty or hands.ammo[type] <= 0.0) else REGEN_DELAY
	regen_time = 0.0
	cooldown_timer = _interval()

	if time_since_swing > COMBO_RESET_TIME: next_down = true
	var is_down: bool = next_down
	next_down = not next_down
	time_since_swing = 0.0

	if hands.chainsaw_hitbox: hands.chainsaw_hitbox.scale = Vector2.ONE
	player.face_mouse()
	var base_angle := hands.get_aim_angle_local()
	hands.attack_swing_rotation = base_angle
	await _perform_slash(base_angle, is_down)

	for b in hands.saw_targets(): _hit(b)
	if hands.chainsaw_hitbox: hands.chainsaw_hitbox.monitoring = false
	hands.is_attacking = false
	if hands.sprite: hands.sprite.flip_v = false
	hands.reset_hands_position()

func _perform_slash(base_angle: float, is_downward: bool) -> void:
	var total: float = clampf(_interval() * TIME_FRACTION, TIME_MIN, TIME_MAX)
	var windup_time: float = total * WINDUP_SHARE
	var swing_time: float = total - windup_time
	var arc := ARC_HALF if is_downward else -ARC_HALF
	var windup_angle := base_angle - arc * (1.0 + WINDUP_EXTRA)
	var end_angle := base_angle + arc
	var lean: float = (0.08 if is_downward else -0.08) * player.facing

	hands.kill_tween(hands.hands_tween)
	if hands.sprite: hands.sprite.flip_v = not is_downward

	var windup_tween := hands.new_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	windup_tween.tween_method(hands.apply_slash_pose.bind(hands.rotation, windup_angle, ARC_RADIUS), 0.0, 1.0, windup_time)
	player.body_lean(-lean, windup_time)
	await windup_tween.finished

	if hands.chainsaw_hitbox: hands.chainsaw_hitbox.monitoring = true
	player.add_dash(DASH_FORCE)
	player.start_shake(SWING_SHAKE_INTENSITY, swing_time)
	player.body_lean_strike(lean, swing_time)

	_sweep_prev_t = 0.0
	var swing_tween := hands.new_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	swing_tween.tween_method(_swing_step.bind(windup_angle, end_angle, ARC_RADIUS), 0.0, 1.0, swing_time)
	await swing_tween.finished

func _swing_step(t: float, start_angle: float, end_angle: float, radius: float) -> void:
	var prev_t := _sweep_prev_t
	_sweep_prev_t = t
	hands.apply_slash_pose(t, start_angle, end_angle, radius)
	_sweep(prev_t, t, start_angle, end_angle, radius)

func _get_hitbox_shape_node() -> CollisionShape2D:
	if is_instance_valid(_hitbox_shape_node): return _hitbox_shape_node
	if not hands.chainsaw_hitbox: return null
	for c in hands.chainsaw_hitbox.get_children():
		if c is CollisionShape2D and c.shape:
			_hitbox_shape_node = c
			return c
	return null

## Проверяет весь пройденный за кадр сектор, чтобы быстрый взмах не пролетал сквозь врагов
func _sweep(t0: float, t1: float, start_angle: float, end_angle: float, radius: float) -> void:
	var hitbox := hands.chainsaw_hitbox
	if not hitbox or not hitbox.monitoring: return
	var shape_node := _get_hitbox_shape_node()
	var parent := hands.get_parent() as Node2D
	if not shape_node or not parent or not player: return

	var params := PhysicsShapeQueryParameters2D.new()
	params.shape = shape_node.shape
	params.collision_mask = hitbox.collision_mask
	params.collide_with_bodies = true
	params.exclude = [player.get_rid()]

	var shape_in_hands: Transform2D = hitbox.transform * shape_node.transform
	var space := hands.get_world_2d().direct_space_state
	for i in range(1, 6):
		var ang: float = lerp_angle(start_angle, end_angle, lerpf(t0, t1, float(i) / 5.0))
		params.transform = parent.global_transform * Transform2D(ang, hands.scale, 0.0, hands.origin_position + Vector2.from_angle(ang) * radius) * shape_in_hands
		for r in space.intersect_shape(params, 16):
			var col = r.get("collider")
			if col is Node2D: _hit(col)

func _hit(body: Node2D) -> void:
	if not is_instance_valid(body) or body == player or not body.has_method("take_damage") or body in _hit_bodies: return
	_hit_bodies.append(body)
	body.take_damage(HIT_DAMAGE)
	player.start_shake(HIT_SHAKE_INTENSITY, HIT_SHAKE_DURATION)
	hands.spawn_axe_blood(hands.get_blood_pos(body), hands.local_angle_to_world(hands.attack_swing_rotation))
