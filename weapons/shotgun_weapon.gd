class_name ShotgunWeapon
extends Weapon

const FIRE_RATE: float = 0.55
const PELLET_COUNT: int = 7
const SPREAD_ANGLE: float = deg_to_rad(18.0)
const SHOT_COST: float = 1.0
const DAMAGE: float = 12.0
const BULLET_SPEED: float = 1232.4
const RAY_LENGTH: float = 264.1
const SHAKE_INTENSITY: float = 1.2
const SHAKE_DURATION: float = 0.18
const SMOKE_COUNT: int = 12
const ANIM_TIME: float = 0.35                    # сколько секунд после выстрела играет анимация атаки

# --- Передёргивание цевья (ПКМ) ---
const PUMP_ANIM: String = "shotgun_pump"         # ИМЯ анимации передёргивания в SpriteFrames
const PUMP_DELAY: float = 0.25                   # через сколько секунд после выстрела можно начать передёргивать
const PUMP_TIME_FALLBACK: float = 0.5            # длительность, если анимации с таким именем нет

# --- Гильза (вылетает при передёргивании) ---
const EJECT_FRAME: int = 1                       # на каком кадре анимации вылетает (счёт с 0: 1 = второй кадр)
const SHELL_SIDE_MIN: float = 60.0               # горизонтальная скорость (в сторону, противоположную выстрелу)
const SHELL_SIDE_MAX: float = 120.0
const SHELL_UP_MIN: float = 120.0                # вертикальная скорость вверх
const SHELL_UP_MAX: float = 200.0
const SHELL_SPIN: float = 18.0                   # макс. скорость вращения (рад/сек)
const SHELL_GRAVITY: float = 900.0               # нужна только если у сцены гильзы нет своей физики
const SHELL_FALL_DISTANCE: float = 24.0          # на сколько пикселей ниже окна выброса она упадёт
const SHELL_LINGER: float = 1.5                  # сколько секунд лежит на земле до исчезновения
const SHELL_FADE: float = 0.4

# --- Отдача (крути эти цифры под вкус) ---
const KICK_DISTANCE: float = 6.0                 # на сколько пикселей руки отбрасывает назад
const KICK_ANGLE: float = deg_to_rad(12.0)       # на сколько ствол подбрасывает вверх
const KICK_RANDOM: float = 0.15                  # разброс силы отдачи (±15%)
const KICK_POS_STIFFNESS: float = 450.0          # жёсткость пружины отката (больше = быстрее возврат)
const KICK_POS_DAMPING: float = 26.0             # затухание (меньше = больше "пружинит")
const KICK_ROT_STIFFNESS: float = 300.0          # жёсткость пружины подброса ствола
const KICK_ROT_DAMPING: float = 16.0             # затухание подброса (чуть "проваливается" ниже и возвращается)
const POSE_FOLLOW_SPEED: float = 80.0            # как быстро руки следуют за целевой позой

var _anim_timer: float = 0.0

var _needs_pump: bool = false       # после выстрела: стрелять нельзя, пока не передёрнул
var _is_pumping: bool = false       # сейчас идёт анимация передёргивания
var _pump_queued: bool = false      # ПКМ нажали чуть раньше времени: передёрнем, как только можно
var _pump_timer: float = 0.0
var _pump_delay_timer: float = 0.0
var _shell_ejected: bool = false    # гильза уже вылетела в текущем передёргивании
var _rmb_prev: bool = false

var _kick: float = 0.0        # текущее смещение назад (px)
var _kick_vel: float = 0.0
var _rot_kick: float = 0.0    # текущий подброс ствола вверх (рад)
var _rot_vel: float = 0.0

func _init() -> void:
	anim_prefix = "shotgun_"

func has_ammo() -> bool:
	return hands.ammo[type] >= SHOT_COST

## Анимация атаки только после выстрела, а не пока зажата кнопка
func is_active() -> bool:
	return _anim_timer > 0.0

func get_animation_name() -> String:
	if _is_pumping: return PUMP_ANIM
	return super.get_animation_name()

func enter() -> void:
	# Если ПКМ уже зажат при выборе дробовика, это не должно считаться нажатием
	_rmb_prev = _rmb_down()

func exit() -> void:
	_cancel_pump()

func on_player_died() -> void:
	_cancel_pump()

## Пружина работает всегда, даже если дробовик убрали: отдача доигрывает до конца
func always_update(delta: float) -> void:
	_anim_timer = maxf(0.0, _anim_timer - delta)
	_pump_delay_timer = maxf(0.0, _pump_delay_timer - delta)
	if _is_pumping:
		_update_eject()
		_pump_timer -= delta
		if _pump_timer <= 0.0: _finish_pump()
	_kick_vel += (-KICK_POS_STIFFNESS * _kick - KICK_POS_DAMPING * _kick_vel) * delta
	_kick += _kick_vel * delta
	_rot_vel += (-KICK_ROT_STIFFNESS * _rot_kick - KICK_ROT_DAMPING * _rot_vel) * delta
	_rot_kick += _rot_vel * delta

## ЛКМ: выстрел по нажатию. ПКМ: передёрнуть цевьё после выстрела.
func physics_update(_delta: float) -> void:
	var rmb := _rmb_down()
	if rmb and not _rmb_prev: _pump_queued = true
	_rmb_prev = rmb

	if _is_pumping: return

	if _needs_pump:
		if _pump_queued and _pump_delay_timer <= 0.0: _start_pump()
		return

	if hands.is_attack_pressed(true) and hands.shoot_cooldown <= 0.0 and hands.attack_cooldown_timer <= 0.0:
		shoot()

func _rmb_down() -> bool:
	return Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT) or Input.is_action_pressed("pkm")

# ---------- Передёргивание ----------

func _start_pump() -> void:
	_is_pumping = true
	_pump_queued = false
	_shell_ejected = false
	_pump_timer = _pump_duration()

func _finish_pump() -> void:
	_is_pumping = false
	_needs_pump = false
	hands.shoot_cooldown = 0.0   # после передёргивания можно стрелять сразу

func _cancel_pump() -> void:
	# Смена оружия или смерть прерывают передёргивание, но патрон так и остаётся не взведённым
	_is_pumping = false
	_pump_queued = false

## Ждём нужный кадр анимации передёргивания и тогда выбрасываем гильзу
func _update_eject() -> void:
	if _shell_ejected: return
	var frames: SpriteFrames = hands.sprite.sprite_frames if hands.sprite else null
	if not (frames and frames.has_animation(PUMP_ANIM)):
		_eject_shell()   # анимации нет: выбрасываем сразу
		return
	if hands.sprite.animation == PUMP_ANIM and hands.sprite.frame >= EJECT_FRAME:
		_eject_shell()

func _eject_shell() -> void:
	_shell_ejected = true
	if not hands.shell_scene: return
	var shell = hands.spawn(hands.shell_scene, hands.get_eject_position())
	# Вбок, противоположно направлению выстрела, и вверх
	var side := -signf(cos(hands.aim_world()))
	if side == 0.0: side = 1.0
	var vel := Vector2(side * randf_range(SHELL_SIDE_MIN, SHELL_SIDE_MAX), -randf_range(SHELL_UP_MIN, SHELL_UP_MAX))
	var spin := randf_range(-SHELL_SPIN, SHELL_SPIN)
	shell.rotation = randf_range(0.0, TAU)
	if shell is RigidBody2D:
		shell.linear_velocity = vel
		shell.angular_velocity = spin
	elif "velocity" in shell:
		shell.velocity = vel
		if "angular_velocity" in shell: shell.angular_velocity = spin
	else:
		_animate_shell(shell, vel, spin)

## Запасной вариант для простой сцены без физики: дуга с гравитацией, падение, исчезновение
func _animate_shell(shell: Node2D, vel: Vector2, spin: float) -> void:
	var start: Vector2 = shell.global_position
	var rot0: float = shell.rotation
	# Время, за которое гильза вернётся на SHELL_FALL_DISTANCE ниже точки вылета
	var fall_time := (-vel.y + sqrt(vel.y * vel.y + 2.0 * SHELL_GRAVITY * SHELL_FALL_DISTANCE)) / SHELL_GRAVITY
	var tween := shell.create_tween()
	tween.tween_method(func(t: float):
		shell.global_position = start + vel * t + Vector2(0.0, 0.5 * SHELL_GRAVITY * t * t)
		shell.rotation = rot0 + spin * t, 0.0, fall_time, fall_time)
	tween.tween_interval(SHELL_LINGER)
	tween.tween_property(shell, "modulate:a", 0.0, SHELL_FADE)
	tween.tween_callback(shell.queue_free)

## Длительность берём из самой анимации (кадры / скорость), чтобы блок стрельбы совпадал с ней
func _pump_duration() -> float:
	var frames: SpriteFrames = hands.sprite.sprite_frames if hands.sprite else null
	if frames and frames.has_animation(PUMP_ANIM):
		var speed := frames.get_animation_speed(PUMP_ANIM)
		if speed > 0.0:
			return frames.get_frame_count(PUMP_ANIM) / speed / maxf(hands.sprite.speed_scale, 0.01)
	return PUMP_TIME_FALLBACK

## Поза с учётом отдачи: руки едут назад вдоль прицела, ствол задирается вверх
func update_pose(delta: float) -> void:
	var aim := hands.get_aim_angle_local()
	var dir := Vector2.from_angle(aim)
	var target_pos := hands.origin_position + dir * (PlayerHands.AIM_FORWARD_OFFSET - _kick)
	# Отрицательный угол в локальных координатах = вверх на экране
	var target_rot := aim - _rot_kick
	var weight := 1.0 - exp(-POSE_FOLLOW_SPEED * delta)
	hands.position = hands.position.lerp(target_pos, weight)
	hands.rotation = lerp_angle(hands.rotation, target_rot, weight)

# ---------- Выстрел ----------

func shoot() -> void:
	if not hands.spend(type, SHOT_COST): return
	hands.shoot_cooldown = FIRE_RATE
	_anim_timer = ANIM_TIME
	_needs_pump = true
	_pump_queued = false
	_pump_delay_timer = PUMP_DELAY
	player.start_shake(SHAKE_INTENSITY, SHAKE_DURATION)
	# Направление и точка выстрела берутся ДО того, как ствол подбросит вверх
	var muzzle := hands.get_muzzle_position()
	var base := hands.aim_world()
	_apply_kick()
	_spawn_smoke(muzzle, base)
	_fire_pellets(muzzle, base)

func _apply_kick() -> void:
	var power := 1.0 + randf_range(-KICK_RANDOM, KICK_RANDOM)
	_kick = KICK_DISTANCE * power
	_kick_vel = 0.0
	_rot_kick = KICK_ANGLE * power
	_rot_vel = 0.0

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

func _fire_pellets(muzzle: Vector2, base: float) -> void:
	var space := hands.get_world_2d().direct_space_state
	for i in PELLET_COUNT:
		var angle := base + randf_range(-SPREAD_ANGLE / 2.0, SPREAD_ANGLE / 2.0)
		var dir := Vector2.from_angle(angle)
		var pos := muzzle + dir * randf_range(-10.0, 14.0)
		if hands.bullet_scene:
			var bullet = hands.spawn(hands.bullet_scene, pos)
			bullet.rotation = angle
			if "velocity" in bullet: bullet.velocity = dir * BULLET_SPEED * randf_range(0.88, 1.12)
		else:
			var query := PhysicsRayQueryParameters2D.create(pos, pos + dir * RAY_LENGTH)
			query.exclude = [player.get_rid()]
			var hit := space.intersect_ray(query)
			if hit and hit.collider.has_method("take_damage"):
				hit.collider.take_damage(DAMAGE)
				hands.spawn_shotgun_hit_blood(hit.position, dir)
