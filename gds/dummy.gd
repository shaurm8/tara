extends CharacterBody2D

# Настройки здоровья и бессмертия
@export var max_health: float = 100.0
var current_health: float = max_health
@export var is_immortal: bool = false # Поставь галочку в Инспекторе, если нужно бессмертие

# Включать или выключать брызги крови в Инспекторе
@export var spawn_blood: bool = true

# Ссылка на сцену капли крови
@export var blood_scene: PackedScene = preload("res://scenes/Blood_Drop.tscn")

# Настройки спавна крови
@export var min_drops: int = 10
@export var max_drops: int = 12
@export var min_speed: float = 150.0
@export var max_speed: float = 500.0

# Путь к контейнеру для крови (чтобы они спавнились за манекеном)
@export var blood_container_path: NodePath

# Ссылка на твой AnimatedSprite2D
@onready var animated_sprite: AnimatedSprite2D = $Hit

func _ready() -> void:
	current_health = max_health
	if animated_sprite:
		animated_sprite.play("idle") # Название твоей idle-анимации
		# Подключаем отслеживание завершения анимации
		animated_sprite.animation_finished.connect(_on_animation_finished)

func take_damage(damage_amount: float = 10.0) -> void:
	# Прерываем текущую анимацию и запускаем "Hit" с самого первого кадра
	if animated_sprite:
		animated_sprite.stop()
		animated_sprite.play("Hit")
		
	if spawn_blood:
		spawn_blood_burst()

	# Если бессмертие выключено — отнимаем здоровье
	if not is_immortal:
		current_health -= damage_amount
		print("Осталось ХП: ", current_health, " / ", max_health)
		if current_health <= 0:
			die()
	else:
		print("Манекен бессмертен! Текущее ХП: ", current_health)

func die() -> void:
	# Логика смерти (по умолчанию удаляем манекен со сцены)
	queue_free()

func _on_animation_finished() -> void:
	# Когда анимация удара заканчивается, возвращаем idle
	if animated_sprite and animated_sprite.animation == "Hit":
		animated_sprite.play("idle")

func spawn_blood_burst() -> void:
	if not blood_scene:
		return

	# Находим контейнер для крови или спавним в родительский узел
	var container: Node = get_parent()
	if blood_container_path and has_node(blood_container_path):
		container = get_node(blood_container_path)

	var drop_count = randi_range(min_drops, max_drops)

	for i in range(drop_count):
		var blood = blood_scene.instantiate()
		blood.position = global_position
		
		# Случайное направление во все 360 градусов
		var random_angle = randf_range(0.0, TAU)
		var random_direction = Vector2.RIGHT.rotated(random_angle)
		var random_speed = randf_range(min_speed, max_speed)
		
		# Задаем вектор скорости капли
		blood.velocity = random_direction * random_speed
		
		# Задаем случайное время полёта до стены (от 0.04 до 0.18 сек)
		blood.lifetime = randf_range(0.04, 0.18)

		container.add_child(blood)
