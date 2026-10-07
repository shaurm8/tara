class_name Player
extends CharacterBody2D
@export var max_hp: int = 100
@onready var hp: int = max_hp
const SPEED: float = 147.9
const ACCELERATION: float = 774.6
const DECELERATION: float = 915.5
const AIR_ACCELERATION: float = 774.6
const AIR_DECELERATION: float = 845.1

const JUMP_FORCE: float = -310.0
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

const CROUCH_OFFSET: float = 4.2
const CROUCH_SPEED: float = 12.0

const SAW_STUCK_SPEED_MULT: float = 0.1
const DEATH_LIE_ANGLE: float = deg_to_rad(85.0)

const JUMP_PUFF_SCENE = preload("res://scenes/jump_puff.tscn")

@onready var telo: Node2D = get_node_or_null("TELO")
@onready var tul: AnimatedSprite2D = get_node_or_null("TELO/TUL")
@onready var hands: PlayerHands = get_node_or_null("TELO/RUKI")
@onready var camera: Camera2D = get_node_or_null("Camera2D")
@onready var collision_shape: CollisionShape2D = get_node_or_null("CollisionShape2D")

var coyote_timer: float = 0.0
var jump_buffer_timer: float = 0.0
var wall_jump_lock: float = 0.0
var shake_timer: float = 0.0
var shake_intensity: float = 0.0
var shake_duration: float = 0.0

var is_dead: bool = false
var is_restarting: bool = false
var was_on_floor: bool = true

var knockback: Vector2 = Vector2.ZERO
var facing: float = 1.0
var crouch_current: float = 0.0
var death_rotation_speed: float = 0.0
var death_bounces: int = 0

var tul_base_y: float = 0.0
var camera_original_pos: Vector2 = Vector2.ZERO

var tulo_attack_tween: Tween

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_setup_fade_in()
	if tul:
		tul_base_y = tul.position.y
		tul.play("idle")
	if camera:
		camera_original_pos = camera.position
		camera.process_mode = Node.PROCESS_MODE_ALWAYS

func _setup_fade_in() -> void:
	var layer = get_tree().root.get_node_or_null("FADE_LAYER")
	if not layer:
		return
	var rect = layer.get_child(0)
	rect.color.a = 1.0
	var tween = create_tween()
	tween.tween_property(rect, "color:a", 0.0, 0.5)
	tween.tween_callback(layer.queue_free)

func face_mouse(min_dist: float = 0.0) -> void:
	var dx = get_global_mouse_position().x - global_position.x
	if absf(dx) <= min_dist:
		return
	facing = signf(dx)
	if telo: telo.scale.x = facing
	if collision_shape: collision_shape.scale.x = facing

func add_dash(force: float) -> void:
	velocity.x += facing * force

func body_lean(target_rotation: float, time: float) -> void:
	if not tul:
		return
	tulo_attack_tween = _new_tween(tulo_attack_tween)
	tulo_attack_tween.tween_property(tul, "rotation", target_rotation, time)

func body_lean_strike(lean: float, duration: float) -> void:
	if not tul:
		return
	tulo_attack_tween = _new_tween(tulo_attack_tween)
	tulo_attack_tween.tween_property(tul, "rotation", lean, duration * 0.6)
	tulo_attack_tween.tween_property(tul, "rotation", 0.0, duration * 0.4)

func start_shake(intensity: float = 1.0, duration: float = 0.3) -> void:
	shake_intensity = intensity
	shake_duration = duration
	shake_timer = duration

func _kill_tween(tween: Tween) -> void:
	if tween and tween.is_valid():
		tween.kill()

func _new_tween(old: Tween = null) -> Tween:
	_kill_tween(old)
	return create_tween().set_pause_mode(Tween.TWEEN_PAUSE_STOP)

func _physics_process(delta: float) -> void:
	_update_camera_shake(delta)
	if get_tree().paused:
		return
	if is_dead:
		_process_death_physics(delta)
		return
	_decrement_timers(delta)
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
		if hands and hands.is_saw_pushing and dir != 0.0 and signf(dir) == facing and hands.has_saw_targets():
			speed *= SAW_STUCK_SPEED_MULT
		var rate := (ACCELERATION if on_floor else AIR_ACCELERATION) if dir != 0.0 else (DECELERATION if on_floor else AIR_DECELERATION)
		velocity.x = move_toward(velocity.x, dir * speed, rate * delta)

	var wall_sliding := not on_floor and _check_is_on_wall()
	if wall_sliding:
		velocity.y = minf(velocity.y, WALL_SLIDE_SPEED)

	if jump_buffer_timer > 0 and coyote_timer > 0:
		velocity.y = JUMP_FORCE
		jump_buffer_timer = 0.0
		coyote_timer = 0.0
		_spawn_puff("jump", -1)
	elif wall_sliding and Input.is_action_just_pressed("w"):
		velocity.x = get_wall_normal().x * WALL_JUMP_FORCE_X
		velocity.y = WALL_JUMP_FORCE_Y
		wall_jump_lock = 0.04
		_spawn_puff("jump", -1)

	if Input.is_action_just_released("w") and velocity.y < 0:
		velocity.y *= JUMP_CUT_MULTIPLIER

	velocity += knockback
	knockback = knockback.move_toward(Vector2.ZERO, 880.3 * delta)

	move_and_slide()
	_handle_step_climb(dir)

	if is_on_floor() and not was_on_floor:
		_spawn_puff("land", 1)

	was_on_floor = is_on_floor()

func _spawn_puff(anim_name: String, z_idx: int = 0) -> void:
	var puff = JUMP_PUFF_SCENE.instantiate()
	puff.global_position = global_position + Vector2(-1, 4.5)
	puff.z_index = z_idx
	get_tree().current_scene.add_child(puff)
	if puff is AnimatedSprite2D:
		puff.play(anim_name)
	elif puff.has_method("play"):
		puff.play(anim_name)
	elif puff.has_node("AnimatedSprite2D"):
		puff.get_node("AnimatedSprite2D").play(anim_name)

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

func _update_visuals_and_animations(delta: float) -> void:
	var dir := Input.get_axis("a", "d")

	if not (hands and hands.is_busy()):
		face_mouse(1.0)

	crouch_current = lerpf(crouch_current, float(is_on_floor() and dir == 0 and Input.is_action_pressed("s")), delta * CROUCH_SPEED)
	if tul:
		var anim := "walk" if (dir != 0 and is_on_floor()) else "idle"
		if tul.animation != anim:
			tul.play(anim)
		tul.position.y = tul_base_y + crouch_current * CROUCH_OFFSET

func take_hit(arg1, arg2 = null, _ignore_dash: bool = false) -> void:
	var damage = 1
	var from_position = global_position
	
	if arg1 is int:
		damage = arg1
		if arg2 is Vector2:
			from_position = arg2
	elif arg1 is Vector2:
		from_position = arg1
		if arg2 is bool and arg2:
			damage = hp
			
	hp -= damage
	if hp <= 0:
		die(from_position)
	else:
		start_shake(2.0, 0.15)

func die(from_position: Vector2 = global_position) -> void:
	if is_dead:
		return
	is_dead = true

	if hands:
		hands.on_player_died()
	_kill_tween(tulo_attack_tween)

	var away = (global_position - from_position).normalized()
	if absf(away.x) < 0.2:
		away.x = -facing

	if has_node("DeathBleedParticles"):
		$DeathBleedParticles.emitting = true

	collision_layer = 0
	collision_mask = 1
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
			telo.rotation = lerp_angle(telo.rotation, facing * DEATH_LIE_ANGLE, delta * 12.0)

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
	get_tree().reload_current_scene()
