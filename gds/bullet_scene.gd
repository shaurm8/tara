extends Area2D

var velocity: Vector2 = Vector2.ZERO
var lifetime: float = 0.0 # Время жизни пули ✨
var hit_targets: Array[Node2D] = [] # Запомненные цели ✨

# === НАСТРОЙКИ АККУРАТНОГО ШЛЕЙФА ===
@export var enable_trail: bool = true
@export var MAX_POINTS: int = 3
@export var PIXEL_SIZE: float = 1.0
@export var TRAIL_COLOR: Color = Color(1.0, 0.75, 0.3, 0.5) # Мягкий, полупрозрачный тон ✨

# === ЭФФЕКТЫ КРОВИ ===
@export var blood_drop_scene: PackedScene
@export var blood_back_count: int = 60
@export var blood_front_count: int = 15

var points_queue: Array[Vector2] = []
var trail_drawer: PixelTrailDrawer

func _ready() -> void:
	if not is_connected("body_entered", Callable(self, "_on_body_entered")):
		body_entered.connect(_on_body_entered)
	if not is_connected("area_entered", Callable(self, "_on_area_entered")):
		area_entered.connect(_on_area_entered)
		
	if enable_trail:
		_setup_trail()

func _setup_trail() -> void:
	trail_drawer = PixelTrailDrawer.new()
	trail_drawer.top_level = true
	trail_drawer.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	get_parent().call_deferred("add_child", trail_drawer)

func _physics_process(delta: float) -> void:
	lifetime += delta
	
	# Движение пули
	position += velocity * delta
	if enable_trail:
		_update_trail()

func _update_trail() -> void:
	if not is_instance_valid(trail_drawer):
		return
		
	points_queue.push_front(global_position.round())
	if points_queue.size() > MAX_POINTS:
		points_queue.pop_back()
		
	trail_drawer.points = points_queue
	trail_drawer.pixel_size = PIXEL_SIZE
	trail_drawer.trail_color = TRAIL_COLOR
	trail_drawer.queue_redraw()

# Удаление пули за пределами экрана
func _on_visible_on_screen_notifier_2d_screen_exited() -> void:
	_destroy_bullet()

# Попадание в физическое тело (CharacterBody2D / RigidBody2D)
func _on_body_entered(body: Node2D) -> void:
	_handle_hit(body)

# Попадание в другую Area2D
func _on_area_entered(area: Area2D) -> void:
	_handle_hit(area)

# === НАСТРОЙКИ ПРОБИТИЯ В УПОР ===
@export var point_blank_time: float = 0.04 # Максимальное время жизни пули для выстрела в упор ✨
@export_range(0.0, 1.0) var pierce_chance: float = 0.5 # Шанс 50% ✨

func _handle_hit(target: Node2D) -> void:
	# Проверяем сам объект, его родителя и название на случай, если попали в Hurtbox игрока ✨
	var parent = target.get_parent()
	var is_player = target.is_in_group("player") or (parent and parent.is_in_group("player")) or "player" in target.name.to_lower()
	
	if is_player or target.is_in_group("bullet") or "bullet" in target.name.to_lower():
		return
		
	# Если мы уже попали в эту цель — пропускаем
	if target in hit_targets:
		return
		
	if target.has_method("take_damage"):
		var is_first_target = hit_targets.is_empty()
		hit_targets.append(target)
		target.take_damage(10.0)
		
		# Спавним кровь ✨
		spawn_shotgun_hit_blood(global_position, velocity.normalized())
		
		# Если выстрел в упор и это первый враг — с вероятностью 50% пуля не уничтожается ❤️
		var is_point_blank = lifetime <= point_blank_time
		if is_first_target and is_point_blank and randf() < pierce_chance:
			return # Пуля прошивает первого врага насквозь ✨
		
		_destroy_bullet()

func spawn_shotgun_hit_blood(hit_pos: Vector2, hit_dir: Vector2) -> void:
	if not blood_drop_scene:
		return

	# 1. ОСНОВНОЙ ВЕЕР СЗАДИ
	var back_angle = hit_dir.angle()
	for i in range(blood_back_count):
		var drop = blood_drop_scene.instantiate()
		get_tree().current_scene.add_child(drop)
		drop.global_position = hit_pos + hit_dir * randf_range(0.0, 10.0)
		
		var spread = randf_range(-deg_to_rad(50.0), deg_to_rad(50.0))
		var final_angle = back_angle + spread
		var speed = randf_range(150.0, 600.0)
		drop.velocity = Vector2(cos(final_angle), sin(final_angle)) * speed

	# 2. ОБЛАЧКО СПЕРЕДИ
	var front_angle = hit_dir.angle() + PI
	for i in range(blood_front_count):
		var drop = blood_drop_scene.instantiate()
		get_tree().current_scene.add_child(drop)
		drop.global_position = hit_pos
		
		var spread = randf_range(-deg_to_rad(70.0), deg_to_rad(70.0))
		var final_angle = front_angle + spread
		var speed = randf_range(50.0, 200.0)
		drop.velocity = Vector2(cos(final_angle), sin(final_angle)) * speed

# Мгновенное удаление пули и её шлейфа
func _destroy_bullet() -> void:
	if is_instance_valid(trail_drawer):
		trail_drawer.queue_free()
	queue_free()

# === ПЛАВНАЯ НЕЗАМЕТНАЯ ОТРИСОВКА ===
class PixelTrailDrawer extends Node2D:
	var points: Array[Vector2] = []
	var pixel_size: float = 1.0
	var trail_color: Color = Color.WHITE

	func _draw() -> void:
		var total: int = points.size()
		if total < 2:
			return
			
		for i in range(total - 1):
			var p1: Vector2 = points[i]
			var p2: Vector2 = points[i + 1]
			
			var t: float = float(i) / float(total - 1)
			var alpha: float = pow(1.0 - t, 2.0)
			
			var col: Color = Color(trail_color.r, trail_color.g, trail_color.b, trail_color.a * alpha)
			
			draw_line(p1, p2, col, pixel_size, false)
