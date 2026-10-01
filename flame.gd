extends Area2D

var velocity: Vector2 = Vector2.ZERO
var lifetime: float = 0.0
var hit_targets: Array[Node2D] = [] # Цели, которым этот огонь уже нанёс урон

# === НАСТРОЙКИ ОГНЯ ===
@export var damage: float = 6.0
@export var anim_name: StringName = &"fly"
@export var max_lifetime: float = 2.0 # Страховка: если анимация зациклена, огонь всё равно исчезнет

# === ЭФФЕКТЫ КРОВИ ===
@export var blood_drop_scene: PackedScene
@export var blood_back_count: int = 20
@export var blood_front_count: int = 5

var sprite: AnimatedSprite2D

func _ready() -> void:
	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)
	if not area_entered.is_connected(_on_area_entered):
		area_entered.connect(_on_area_entered)

	sprite = _find_sprite()
	if sprite:
		if not sprite.animation_finished.is_connected(_on_animation_finished):
			sprite.animation_finished.connect(_on_animation_finished)
		sprite.play(anim_name)

func _find_sprite() -> AnimatedSprite2D:
	var by_name = get_node_or_null("AnimatedSprite2D")
	if by_name is AnimatedSprite2D:
		return by_name
	for child in get_children():
		if child is AnimatedSprite2D:
			return child
	return null

func _physics_process(delta: float) -> void:
	lifetime += delta
	position += velocity * delta

	if lifetime >= max_lifetime:
		queue_free()

# Огонь исчезает, когда проигралась анимация fly
func _on_animation_finished() -> void:
	queue_free()

# Удаление за пределами экрана (если подключён VisibleOnScreenNotifier2D)
func _on_visible_on_screen_notifier_2d_screen_exited() -> void:
	queue_free()

func _on_body_entered(body: Node2D) -> void:
	_handle_hit(body)

func _on_area_entered(area: Area2D) -> void:
	_handle_hit(area)

func _handle_hit(target: Node2D) -> void:
	var parent = target.get_parent()
	var is_player = target.is_in_group("player") or (parent and parent.is_in_group("player")) or "player" in target.name.to_lower()

	if is_player or target.is_in_group("bullet") or "bullet" in target.name.to_lower():
		return

	# Каждой цели урон наносится только один раз
	if target in hit_targets:
		return

	if target.has_method("take_damage"):
		hit_targets.append(target)
		target.take_damage(damage)

		if target.has_method("set_on_fire"):
			target.set_on_fire()

		spawn_hit_blood(global_position, velocity.normalized())
		# Огонь НЕ удаляется при попадании — летит дальше и сквозь врагов

func spawn_hit_blood(hit_pos: Vector2, hit_dir: Vector2) -> void:
	if not blood_drop_scene:
		return

	# 1. Основной веер сзади
	var back_angle = hit_dir.angle()
	for i in range(blood_back_count):
		var drop = blood_drop_scene.instantiate()
		get_tree().current_scene.add_child(drop)
		drop.global_position = hit_pos + hit_dir * randf_range(0.0, 10.0)

		var spread = randf_range(-deg_to_rad(50.0), deg_to_rad(50.0))
		var final_angle = back_angle + spread
		var speed = randf_range(150.0, 600.0)
		drop.velocity = Vector2(cos(final_angle), sin(final_angle)) * speed

	# 2. Облачко спереди
	var front_angle = hit_dir.angle() + PI
	for i in range(blood_front_count):
		var drop = blood_drop_scene.instantiate()
		get_tree().current_scene.add_child(drop)
		drop.global_position = hit_pos

		var spread = randf_range(-deg_to_rad(70.0), deg_to_rad(70.0))
		var final_angle = front_angle + spread
		var speed = randf_range(50.0, 200.0)
		drop.velocity = Vector2(cos(final_angle), sin(final_angle)) * speed
