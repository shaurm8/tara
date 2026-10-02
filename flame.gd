extends Area2D

var velocity: Vector2 = Vector2.ZERO
var lifetime: float = 0.0

# === НАСТРОЙКИ ОГНЯ ===
@export var anim_name: StringName = &"fly"
@export var max_lifetime: float = 0.65        # базовое время жизни частицы
@export var lifetime_variation: float = 0.2   # +-20% разброс времени жизни
@export var drag: float = 1.8                 # торможение частицы
@export var buoyancy: float = 140.0           # 🔥 Увеличен подъём вверх
@export var spin_speed: float = 2.0           # 🔄 Скорость вращения
@export var start_scale: float = 1.0          # начальный размер
@export var end_scale: float = 1.0            # конечный размер
@export var fade_start: float = 0.55          # с какой доли жизни начинает гаснуть

# === НАСТРОЙКИ СВЕТА 🔥 ===
@export_range(0.0, 1.0) var light_chance: float = 0.3    # 30% шанс появить свет
@export var light_color: Color = Color(1.0, 0.5, 0.15)   # Тёплый огненный цвет
@export var max_light_energy: float = 1              # Максимальная яркость
@export var light_fade_in_ratio: float = 0.15            # Скорость появления (15% от жизни)

# === УРОН ===
@export var tick_damage: float = 3.0          # урон за тик
@export var tick_interval: float = 0.1        # интервал урона
@export var wall_slow: float = 0.15           # торможение о стену

# === КРОВЬ ===
@export var blood_drop_scene: PackedScene
@export var blood_back_count: int = 6
@export var blood_front_count: int = 2

var sprite: AnimatedSprite2D
var _life_total: float = 0.65
var _rot_direction: float = 1.0
var _light: PointLight2D = null

func _ready() -> void:
	_life_total = max_lifetime * randf_range(1.0 - lifetime_variation, 1.0 + lifetime_variation)
	scale = Vector2.ONE * start_scale

	# Каждый огонёк слегка случайно повернут при рождении и крутится в случайную сторону ❤️
	rotation += randf_range(-0.4, 0.4)
	_rot_direction = [-1.0, 1.0].pick_random()

	# 30% шанс создать свечение ^_^
	if randf() < light_chance:
		_setup_light()

	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)

	sprite = _find_sprite()
	if sprite:
		sprite.play(anim_name)
		var frames := sprite.sprite_frames
		if frames and frames.has_animation(anim_name):
			var fps := frames.get_animation_speed(anim_name)
			if fps > 0.0:
				var anim_len := frames.get_frame_count(anim_name) / fps
				sprite.speed_scale = anim_len / _life_total

func _setup_light() -> void:
	_light = PointLight2D.new()
	_light.name = "FireLight"
	
	# Генерируем мягкую круговую текстуру для света
	var grad_tex := GradientTexture2D.new()
	grad_tex.fill = GradientTexture2D.FILL_RADIAL
	grad_tex.fill_from = Vector2(0.5, 0.5)
	grad_tex.fill_to = Vector2(0.5, 0.0)
	
	var grad := Gradient.new()
	grad.set_color(0, Color(1.0, 1.0, 1.0, 1.0))
	grad.set_color(1, Color(1.0, 1.0, 1.0, 0.0))
	grad_tex.gradient = grad
	grad_tex.width = 64
	grad_tex.height = 64
	
	_light.texture = grad_tex
	_light.color = light_color
	_light.energy = 0.0
	add_child(_light)

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
	var t: float = clamp(lifetime / _life_total, 0.0, 1.0)

	# Замедление + мощный подъём вверх
	velocity *= exp(-drag * delta)
	velocity.y -= buoyancy * delta
	position += velocity * delta

	# Поворачиваем частицу по направлению полёта + закручиваем для динамики ✨
	if velocity != Vector2.ZERO:
		rotation = lerp_angle(rotation, velocity.angle(), 10.0 * delta)
	rotation += spin_speed * _rot_direction * delta

	# Рост и затухание спрайта
	scale = Vector2.ONE * lerp(start_scale, end_scale, t)
	var alpha := 1.0
	if t > fade_start:
		alpha = 1.0 - (t - fade_start) / (1.0 - fade_start)
	modulate.a = alpha

	# Управление плавной яркостью света
	if _light:
		var light_factor := 1.0
		if t < light_fade_in_ratio:
			# Быстрое плавное появление в начале
			light_factor = t / light_fade_in_ratio
		elif t > fade_start:
			# Плавное угасание к концу
			light_factor = 1.0 - (t - fade_start) / (1.0 - fade_start)
		
		_light.energy = max_light_energy * clamp(light_factor, 0.0, 1.0)

	_apply_damage_ticks()

	if lifetime >= _life_total:
		queue_free()

func _apply_damage_ticks() -> void:
	for body in get_overlapping_bodies():
		_try_burn(body)
	for area in get_overlapping_areas():
		_try_burn(area)

func _is_ignored(target: Node) -> bool:
	var parent = target.get_parent()
	if target.is_in_group("player") or (parent and parent.is_in_group("player")):
		return true
	if "player" in target.name.to_lower():
		return true
	if target.is_in_group("bullet") or "bullet" in target.name.to_lower():
		return true
	return false

func _try_burn(target: Node2D) -> void:
	if _is_ignored(target) or not target.has_method("take_damage"):
		return

	var now := Time.get_ticks_msec() / 1000.0
	var next_tick: float = target.get_meta("fire_next_tick", 0.0)
	if now < next_tick:
		return
	target.set_meta("fire_next_tick", now + tick_interval)

	target.take_damage(tick_damage)
	if target.has_method("set_on_fire"):
		target.set_on_fire()

	spawn_hit_blood(global_position, velocity.normalized())

func _on_body_entered(body: Node2D) -> void:
	if _is_ignored(body) or body.has_method("take_damage"):
		return
	velocity *= wall_slow
	lifetime = max(lifetime, _life_total * 0.7)

func _on_visible_on_screen_notifier_2d_screen_exited() -> void:
	queue_free()

func spawn_hit_blood(hit_pos: Vector2, hit_dir: Vector2) -> void:
	if not blood_drop_scene:
		return
	if hit_dir == Vector2.ZERO:
		hit_dir = Vector2.RIGHT

	var back_angle = hit_dir.angle()
	for i in range(blood_back_count):
		var drop = blood_drop_scene.instantiate()
		get_tree().current_scene.add_child(drop)
		drop.global_position = hit_pos + hit_dir * randf_range(0.0, 10.0)
		var final_angle = back_angle + randf_range(-deg_to_rad(50.0), deg_to_rad(50.0))
		drop.velocity = Vector2(cos(final_angle), sin(final_angle)) * randf_range(100.0, 400.0)

	var front_angle = hit_dir.angle() + PI
	for i in range(blood_front_count):
		var drop = blood_drop_scene.instantiate()
		get_tree().current_scene.add_child(drop)
		drop.global_position = hit_pos
		var final_angle = front_angle + randf_range(-deg_to_rad(70.0), deg_to_rad(70.0))
		drop.velocity = Vector2(cos(final_angle), sin(final_angle)) * randf_range(50.0, 150.0)
