class_name ThrownAxe
extends RigidBody2D

const THROW_DAMAGE: float = 35.0
const SPIN_SPEED: float = 80.0

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

var player_ref = null
var hands_ref = null
var can_be_picked_up: bool = false

var trail_timer: float = 0.0
var trail_prev_xform: Transform2D
var trail_has_prev: bool = false

func _ready() -> void:
	contact_monitor = true
	max_contacts_reported = 4
	angular_velocity = SPIN_SPEED
	
	if damage_area:
		damage_area.monitoring = true
		damage_area.monitorable = true
		if not damage_area.body_entered.is_connected(_on_damage_area_body_entered):
			damage_area.body_entered.connect(_on_damage_area_body_entered)
	
	await get_tree().create_timer(0.25).timeout
	can_be_picked_up = true

func _physics_process(delta: float) -> void:
	_update_trail(delta)

func setup(p_player, p_hands, aim_angle: float, speed: float) -> void:
	player_ref = p_player
	hands_ref = p_hands
	linear_velocity = Vector2.from_angle(aim_angle) * speed
	
	if player_ref:
		add_collision_exception_with(player_ref)

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

func _on_damage_area_body_entered(body: Node2D) -> void:
	if body == player_ref:
		if can_be_picked_up:
			_try_pickup()
		return
		
	if body.has_method("take_damage"):
		body.take_damage(THROW_DAMAGE)
		
		if player_ref and player_ref.has_method("start_shake"):
			player_ref.start_shake(2.0, 0.15)
			
		_spawn_hit_blood(body)

func _try_pickup() -> void:
	if hands_ref and hands_ref.has_method("pick_up_axe"):
		hands_ref.pick_up_axe()
		queue_free()
	elif player_ref:
		var h = player_ref.get_node_or_null("RUKI")
		if h and h.has_method("pick_up_axe"):
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
