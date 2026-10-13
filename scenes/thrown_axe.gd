class_name ThrownAxe
extends RigidBody2D

const THROW_DAMAGE: float = 35.0
const SPIN_SPEED: float = 80.0
const BLADE_REACH: float = 3.0
const BLADE_PROBE_BACK: float = 3.0
const MAX_STICK_ANGLE_DEG: float = 50.0
const MAX_STICK_ANGLE_FLOOR_DEG: float = 65.0
const MIN_STICK_NORMAL_SPEED: float = 60.0

const MIN_AIR_TIME_FOR_STICK: float = 0.05

const STICK_ROTATION_SAMPLES: Array[float] = [0.0, 0.5, 1.0]
const EMBED_DEPTH: float = 2.0
const STICK_SHAKE_INTENSITY: float = 1.5
const STICK_SHAKE_DURATION: float = 0.1
const STICK_WOBBLE_DEG: float = 9.0
const STICK_WOBBLE_TIME: float = 0.35
const STICK_WOBBLE_CYCLES: float = 3.0

# --- Отскок от врага ---
const BOUNCE_SPEED_X: float = 260.0
const BOUNCE_SPEED_UP: float = 220.0
## Один и тот же враг не получает урон от топора чаще, чем раз в это время
const HIT_COOLDOWN_MS: int = 250

# Настройки шлейфа (как в PlayerHands)
const TRAIL_SPAWN_INTERVAL: float = 0.0
const TRAIL_LIFETIME: float = 0.1
const TRAIL_START_ALPHA: float = 0.3
const TRAIL_GHOSTS_PER_FRAME: int = 3
const TRAIL_Z_INDEX: int = 0

# Настройки крови
const AXE_BLOOD_DROPS_MIN: int = 500
const AXE_BLOOD_DROPS_MAX: int = 600

@onready var damage_area: Area2D = $Area2D
@onready var sprite: Sprite2D = $Sprite2D # Убедись, что спрайт топора называется Sprite2D или укажи свой путь
## Точка на кончике лезвия. Должна быть прямым дочерним узлом топора.
@onready var blade_marker: Marker2D = get_node_or_null("BladeMarker")
## Необязательно: точка на конце рукояти. С ней направление топора считается точнее,
## без неё берётся линия от центра топора до BladeMarker.
@onready var handle_marker: Marker2D = get_node_or_null("HandleMarker")

var player_ref = null
var hands_ref = null
var can_be_picked_up: bool = false
var is_stuck: bool = false

var trail_timer: float = 0.0
var trail_prev_xform: Transform2D
var trail_has_prev: bool = false

var _picked: bool = false
var _last_free_velocity: Vector2 = Vector2.ZERO
var _air_time: float = 0.0
var _has_pending_bounce: bool = false
var _pending_bounce_velocity: Vector2 = Vector2.ZERO
var _last_hit_msec: Dictionary = {}
var _wobble_base_pos: Vector2 = Vector2.ZERO
var _wobble_base_rot: float = 0.0

func _ready() -> void:
	contact_monitor = true
	max_contacts_reported = 4
	freeze_mode = RigidBody2D.FREEZE_MODE_STATIC
	angular_velocity = SPIN_SPEED
	if not blade_marker:
		push_warning("ThrownAxe: нет узла BladeMarker, топор не сможет втыкаться")

	if damage_area:
		damage_area.monitoring = true
		damage_area.monitorable = true
		if not damage_area.body_entered.is_connected(_on_damage_area_body_entered):
			damage_area.body_entered.connect(_on_damage_area_body_entered)

	await get_tree().create_timer(0.25).timeout
	can_be_picked_up = true

func _physics_process(delta: float) -> void:
	if not is_stuck:
		_update_trail(delta)
	# Подбор и по «стоящему внутри» игроку, а не только по входу в зону
	if can_be_picked_up and not _picked and is_instance_valid(player_ref) and damage_area and damage_area.overlaps_body(player_ref):
		_try_pickup()

func setup(p_player, p_hands, aim_angle: float, speed: float) -> void:
	player_ref = p_player
	hands_ref = p_hands
	linear_velocity = Vector2.from_angle(aim_angle) * speed
	_last_free_velocity = linear_velocity

	# Бросок влево: зеркалим топор и крутим в обратную сторону, как будто это тот же бросок в зеркале
	if cos(aim_angle) < 0.0:
		_mirror_for_left_throw()

	if player_ref:
		add_collision_exception_with(player_ref)

func _mirror_for_left_throw() -> void:
	angular_velocity = -SPIN_SPEED
	if sprite:
		sprite.flip_h = true
	# Метки лежат отдельно от спрайта, поэтому зеркалим и их, иначе лезвие окажется не с той стороны
	if blade_marker:
		blade_marker.position.x = -blade_marker.position.x
	if handle_marker:
		handle_marker.position.x = -handle_marker.position.x

# --- Физика: впивание и отскок ---

func _integrate_forces(state: PhysicsDirectBodyState2D) -> void:
	if is_stuck:
		return

	# Отскок от врага применяем здесь, а не из сигнала Area2D, чтобы физика не перезаписала скорость
	if _has_pending_bounce:
		_has_pending_bounce = false
		state.linear_velocity = _pending_bounce_velocity
		state.angular_velocity = -state.angular_velocity
		_last_free_velocity = _pending_bounce_velocity
		return

	var contacts: int = state.get_contact_count()
	if contacts == 0:
		# Скорость до касания: после столкновения state.linear_velocity уже «испорчена» отражением
		_last_free_velocity = state.linear_velocity
		_air_time += state.step
		return

	# Втыкаться может только первое касание после полёта, лежащий и катящийся топор не втыкается
	var was_airborne: bool = _air_time >= MIN_AIR_TIME_FOR_STICK
	_air_time = 0.0
	if not was_airborne:
		return

	# Касаемся мира (а не игрока или врага)?
	var touching_world: bool = false
	for i in contacts:
		var col = state.get_contact_collider_object(i)
		if col == null or col == player_ref or col.has_method("take_damage"):
			continue
		touching_world = true
		break
	if not touching_world:
		return

	# Пробуем текущий поворот и несколько более ранних внутри этого кадра
	var hit: Dictionary = {}
	for frac in STICK_ROTATION_SAMPLES:
		hit = _probe_blade(state, -state.angular_velocity * state.step * frac)
		if not hit.is_empty():
			break
	if hit.is_empty():
		return

	is_stuck = true
	# Гасим движение сразу, чтобы к отложенному вызову топор не успел сместиться и провернуться
	state.linear_velocity = Vector2.ZERO
	state.angular_velocity = 0.0
	call_deferred("_finish_stick", hit["position"], hit["rotation"])

## Пускает короткий луч вдоль топора через кончик лезвия при заданном довороте.
## Возвращает итоговые позицию и поворот топора, если лезвие реально упирается в мир
## и смотрит в него под допустимым углом, иначе пустой словарь.
func _probe_blade(state: PhysicsDirectBodyState2D, angle_offset: float) -> Dictionary:
	if not blade_marker:
		return {}

	var origin: Vector2 = state.transform.origin
	var rot: float = state.transform.get_rotation() + angle_offset
	var xf := Transform2D(rot, origin)

	var blade_pos: Vector2 = xf * blade_marker.position
	var start: Vector2 = xf * (handle_marker.position if handle_marker else Vector2.ZERO)
	var axis: Vector2 = blade_pos - start
	if axis.length() < 0.5:
		return {}
	var axis_dir: Vector2 = axis.normalized()

	var params := PhysicsRayQueryParameters2D.create(blade_pos - axis_dir * BLADE_PROBE_BACK, blade_pos + axis_dir * BLADE_REACH)
	params.collision_mask = collision_mask
	var exclude: Array[RID] = [get_rid()]
	if is_instance_valid(player_ref):
		exclude.append(player_ref.get_rid())
	params.exclude = exclude

	var result: Dictionary = state.get_space_state().intersect_ray(params)
	if result.is_empty():
		return {}
	var collider = result.get("collider")
	if collider == null or collider.has_method("take_damage"):
		return {}

	# Нормаль торчит из поверхности наружу. Лезвие должно смотреть против неё, а сам топор лететь в поверхность.
	var normal: Vector2 = result.get("normal", Vector2.ZERO)
	if normal == Vector2.ZERO:
		normal = -_last_free_velocity.normalized()
	var max_deg: float = MAX_STICK_ANGLE_FLOOR_DEG if normal.y < -0.7 else MAX_STICK_ANGLE_DEG
	if axis_dir.dot(-normal) < cos(deg_to_rad(max_deg)):
		return {}
	if _last_free_velocity.dot(-normal) < MIN_STICK_NORMAL_SPEED:
		return {}

	# Сдвигаем так, чтобы лезвие оказалось в точке касания и чуть глубже в поверхность
	var target: Vector2 = origin + (result["position"] - blade_pos) - normal * EMBED_DEPTH
	return {"position": target, "rotation": rot}

func _finish_stick(target_pos: Vector2, target_rot: float) -> void:
	linear_velocity = Vector2.ZERO
	angular_velocity = 0.0
	global_position = target_pos
	global_rotation = target_rot
	freeze = true
	# Воткнувшийся топор больше ни с кем не сталкивается (врагов не блокирует), работает только зона подбора
	collision_layer = 0
	collision_mask = 0

	if is_instance_valid(player_ref) and player_ref.has_method("start_shake"):
		player_ref.start_shake(STICK_SHAKE_INTENSITY, STICK_SHAKE_DURATION)

	# Дрожь после втыкания: одинаковая для стены и пола, топор качается вокруг кончика лезвия
	if sprite:
		_wobble_base_pos = sprite.position
		_wobble_base_rot = sprite.rotation
		var tw := create_tween()
		tw.tween_method(_apply_wobble, 0.0, 1.0, STICK_WOBBLE_TIME)

func _apply_wobble(t: float) -> void:
	if not sprite:
		return
	# Колебания затухают к концу; при t = 1 угол ровно 0 и спрайт возвращается на место
	var angle: float = deg_to_rad(STICK_WOBBLE_DEG) * sin(t * TAU * STICK_WOBBLE_CYCLES) * pow(1.0 - t, 2.0)
	var pivot: Vector2 = blade_marker.position if blade_marker else Vector2.ZERO
	sprite.position = pivot + (_wobble_base_pos - pivot).rotated(angle)
	sprite.rotation = _wobble_base_rot + angle

func _queue_bounce(body: Node2D) -> void:
	# Отскакиваем назад относительно того, откуда прилетели
	var side: float = -signf(_last_free_velocity.x)
	if absf(_last_free_velocity.x) < 20.0:
		side = signf(global_position.x - body.global_position.x)
	if side == 0.0:
		side = 1.0
	_pending_bounce_velocity = Vector2(side * BOUNCE_SPEED_X, -BOUNCE_SPEED_UP)
	_has_pending_bounce = true

# --- Шлейф ---

func _update_trail(delta: float) -> void:
	if not sprite:
		return

	var current: Transform2D = global_transform
	if not trail_has_prev:
		trail_prev_xform = current
		trail_has_prev = true

	trail_timer -= delta
	if trail_timer > 0.0:
		return
	trail_timer = TRAIL_SPAWN_INTERVAL

	for i in TRAIL_GHOSTS_PER_FRAME:
		var w := float(i + 1) / float(TRAIL_GHOSTS_PER_FRAME)
		_spawn_trail_ghost(trail_prev_xform.interpolate_with(current, w))
	trail_prev_xform = current

func _spawn_trail_ghost(local_xform: Transform2D) -> void:
	if not sprite.texture:
		return

	var ghost := Sprite2D.new()
	ghost.process_mode = Node.PROCESS_MODE_ALWAYS
	ghost.texture = sprite.texture
	ghost.centered = sprite.centered
	ghost.offset = sprite.offset
	ghost.flip_h = sprite.flip_h
	ghost.flip_v = sprite.flip_v
	ghost.material = sprite.material
	ghost.texture_filter = sprite.texture_filter
	ghost.z_as_relative = false
	ghost.z_index = TRAIL_Z_INDEX
	ghost.modulate = Color(1.0, 1.0, 1.0, TRAIL_START_ALPHA)

	get_tree().current_scene.add_child(ghost)
	ghost.global_transform = local_xform

	var tween := ghost.create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.tween_property(ghost, "modulate:a", 0.0, TRAIL_LIFETIME)
	tween.tween_callback(ghost.queue_free)

# --- Урон и подбор ---

func _on_damage_area_body_entered(body: Node2D) -> void:
	if body == player_ref:
		if can_be_picked_up:
			_try_pickup()
		return

	# Воткнувшийся топор никого не рубит
	if is_stuck or not body.has_method("take_damage"):
		return

	var id: int = body.get_instance_id()
	var now: int = Time.get_ticks_msec()
	if now - int(_last_hit_msec.get(id, -HIT_COOLDOWN_MS)) < HIT_COOLDOWN_MS:
		return
	_last_hit_msec[id] = now

	body.take_damage(THROW_DAMAGE)

	if player_ref and player_ref.has_method("start_shake"):
		player_ref.start_shake(2.0, 0.15)

	_spawn_hit_blood(body)
	_queue_bounce(body)

func _try_pickup() -> void:
	if _picked:
		return
	var h = hands_ref
	if not (h and h.has_method("pick_up_axe")) and player_ref:
		h = player_ref.get_node_or_null("RUKI")
	if h and h.has_method("pick_up_axe"):
		_picked = true
		h.pick_up_axe()
		queue_free()

func _spawn_hit_blood(body: Node2D) -> void:
	if not hands_ref or not ("blood_drop_scene" in hands_ref) or not hands_ref.blood_drop_scene:
		return

	var blood_scene = hands_ref.blood_drop_scene
	var spawn_pos = body.global_position
	var cut_angle = linear_velocity.angle()

	for i in randi_range(AXE_BLOOD_DROPS_MIN, AXE_BLOOD_DROPS_MAX):
		var roll = randf()
		var speed = randf_range(28.2, 211.3) if roll < 0.25 else (randf_range(211.3, 528.2) if roll < 0.75 else randf_range(528.2, 845.1))
		var dir_roll = randf()
		var angle = cut_angle
		var spread = 50.0

		if dir_roll < 0.55:
			angle = cut_angle
			spread = 50.0
		elif dir_roll < 0.85:
			angle = randf() * TAU
			spread = 0.0
			speed *= 0.6
		else:
			angle = cut_angle + PI
			spread = 35.0
			speed *= 0.7

		_blood_drop(blood_scene, spawn_pos, angle, 21.1, 1.76, spread, speed)

func _blood_drop(scene: PackedScene, pos: Vector2, center: float, off: float, jit: float, spread_deg: float, speed: float) -> void:
	var drop = scene.instantiate()
	get_tree().current_scene.add_child(drop)
	drop.global_position = pos + Vector2.from_angle(center) * randf_range(0.0, off) + Vector2(randf_range(-jit, jit), randf_range(-jit, jit))
	drop.process_mode = Node.PROCESS_MODE_ALWAYS
	drop.velocity = Vector2.from_angle(center + deg_to_rad(randf_range(-spread_deg, spread_deg))) * speed
