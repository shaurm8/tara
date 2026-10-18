class_name Shell
extends RigidBody2D
## Гильза: падает, крутится, отскакивает от пола и остаётся лежать на карте.
## Скорость и вращение при вылете задаёт дробовик (linear_velocity / angular_velocity).

@export_group("Физика")
@export_range(0.0, 1.0) var bounce_amount: float = 0.45   ## насколько отскакивает (0 = не отскакивает)
@export_range(0.0, 1.0) var friction_amount: float = 0.6  ## трение о пол (больше = быстрее останавливается)
@export var air_spin_damp: float = 0.3                    ## затухание вращения в воздухе (меньше = дольше крутится)

@export_group("Жизнь на карте")
@export var lifetime: float = 0.0       ## 0 = лежит вечно; иначе исчезает через N секунд после вылета
@export var fade_time: float = 0.5      ## плавное исчезновение
@export var max_shells: int = 150       ## если гильз на карте больше, самые старые удаляются

const GROUP: String = "shells"

# Шлейф в полёте (как у топора, но короче)
const TRAIL_SPAWN_INTERVAL: float = 0.0
const TRAIL_LIFETIME: float = 0.06      # у топора 0.1
const TRAIL_START_ALPHA: float = 0.3
const TRAIL_GHOSTS_PER_FRAME: int = 3
const TRAIL_Z_INDEX: int = 0
const TRAIL_MIN_SPEED: float = 80.0     # шлейф только пока гильза реально летит, лежащая и затихающая без него

var sprite: Sprite2D
var trail_timer: float = 0.0
var trail_prev_xform: Transform2D
var trail_has_prev: bool = false

func _ready() -> void:
	add_to_group(GROUP)

	# Спрайт гильзы: ищем первого Sprite2D среди детей (имя не важно)
	for c in get_children():
		if c is Sprite2D:
			sprite = c
			break

	var mat := PhysicsMaterial.new()
	mat.bounce = bounce_amount
	mat.friction = friction_amount
	physics_material_override = mat

	angular_damp = air_spin_damp
	contact_monitor = true
	max_contacts_reported = 4
	body_entered.connect(_on_body_entered)

	_limit_shell_count()
	if lifetime > 0.0:
		await get_tree().create_timer(lifetime).timeout
		_fade_out()

func _physics_process(delta: float) -> void:
	if linear_velocity.length() >= TRAIL_MIN_SPEED:
		_update_trail(delta)
	else:
		trail_has_prev = false

# ---------- Шлейф ----------

func _update_trail(delta: float) -> void:
	if not sprite: return

	var current: Transform2D = sprite.global_transform
	if not trail_has_prev:
		trail_prev_xform = current
		trail_has_prev = true

	trail_timer -= delta
	if trail_timer > 0.0: return
	trail_timer = TRAIL_SPAWN_INTERVAL

	for i in TRAIL_GHOSTS_PER_FRAME:
		var w := float(i + 1) / float(TRAIL_GHOSTS_PER_FRAME)
		_spawn_trail_ghost(trail_prev_xform.interpolate_with(current, w))
	trail_prev_xform = current

func _spawn_trail_ghost(xform: Transform2D) -> void:
	if not sprite.texture: return

	var ghost := Sprite2D.new()
	ghost.process_mode = Node.PROCESS_MODE_ALWAYS
	ghost.texture = sprite.texture
	ghost.centered = sprite.centered
	ghost.offset = sprite.offset
	ghost.flip_h = sprite.flip_h
	ghost.flip_v = sprite.flip_v
	ghost.hframes = sprite.hframes
	ghost.vframes = sprite.vframes
	ghost.frame = sprite.frame
	ghost.region_enabled = sprite.region_enabled
	ghost.region_rect = sprite.region_rect
	ghost.material = sprite.material
	ghost.texture_filter = sprite.texture_filter
	ghost.z_as_relative = false
	ghost.z_index = TRAIL_Z_INDEX
	ghost.modulate = Color(1.0, 1.0, 1.0, TRAIL_START_ALPHA)

	get_tree().current_scene.add_child(ghost)
	ghost.global_transform = xform

	var tween := ghost.create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.tween_property(ghost, "modulate:a", 0.0, TRAIL_LIFETIME)
	tween.tween_callback(ghost.queue_free)

## Не даём карте захламиться: удаляем самые старые гильзы сверх лимита
func _limit_shell_count() -> void:
	var shells := get_tree().get_nodes_in_group(GROUP)
	var extra := shells.size() - max_shells
	for i in extra:
		if is_instance_valid(shells[i]): shells[i].queue_free()

func _fade_out() -> void:
	if not is_inside_tree(): return
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 0.0, fade_time)
	tween.tween_callback(queue_free)

## Сюда потом можно добавить звук падения гильзы на пол
func _on_body_entered(_body: Node) -> void:
	# Пропускаем тихие касания, чтобы звук не срабатывал на каждое дрожание
	if linear_velocity.length() < 40.0: return
	# TODO: проиграть звук
