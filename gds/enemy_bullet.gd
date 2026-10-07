extends Area2D
class_name Bullet

# === НАСТРОЙКИ ===
@export var damage: int = 5
@export var speed: float = 2000.0             # Скорость полёта (перезаписывается врагом через bullet_speed)
@export var lifetime: float = 3.0            # Через сколько секунд пуля исчезнет сама, если никуда не попала
@export var knockback_force: float = 250.0
@export var destroy_on_wall_hit: bool = true # Уничтожать пулю при попадании в стену/платформу

var direction: Vector2 = Vector2.RIGHT
var is_active: bool = true

@onready var lifetime_timer: Timer = Timer.new()

func _ready():
	collision_layer = 0
	collision_mask = 1 | 2
	
	body_entered.connect(_on_body_entered)
	
	add_to_group("enemy_attack")
	
	add_child(lifetime_timer)
	lifetime_timer.wait_time = lifetime
	lifetime_timer.one_shot = true
	lifetime_timer.timeout.connect(_on_lifetime_timeout)
	lifetime_timer.start()

func _physics_process(delta):
	if not is_active:
		return
	position += direction * speed * delta

# Вызывается врагом (у него уже есть проверка has_method("set_direction"))
func set_direction(new_direction: Vector2):
	if new_direction == Vector2.ZERO:
		return
	direction = new_direction.normalized()
	rotation = direction.angle()
	
	if has_node("Sprite2D"):
		$Sprite2D.rotation = 0.0 # спрайт не крутим отдельно, крутится весь узел через rotation

func _on_body_entered(body: Node):
	if not is_active:
		return
	
	# Попадание в игрока
	if body.is_in_group("player") and body.has_method("take_hit"):
		is_active = false
		
		# Передаем сам урон (damage) первым аргументом!
		body.take_hit(damage, global_position)
		
		if body.has_method("apply_knockback"):
			body.apply_knockback(direction * knockback_force)
		
		_create_hit_effect()
		queue_free()
		return

func _on_lifetime_timeout():
	if is_instance_valid(self):
		queue_free()

func _create_hit_effect():
	# Сюда можно заспавнить сцену искры/попадания об стену или тело, если понадобится
	pass
