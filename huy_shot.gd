extends CharacterBody2D

# === НАСТРОЙКИ (Экспортируемые переменные для настройки в инспекторе Godot) ===
@export_enum("Вправо:1", "Влево:-1") var initial_direction: int = 1 # Выбор начального направления
@export var patrol_enabled: bool = true       # Если выключено - враг стоит на месте
@export var walk_speed: float = 30.0          # Скорость движения врага при патрулировании (10 * 3)
@export var chase_speed: float = 87.0         # Скорость бега врага во время преследования (29 * 3)
@export var patrol_distance: float = 150.0    # Дистанция патрулирования (50 * 3)
@export var patrol_pause_time: float = 4.5    # Время паузы (1.5 * 3)
@export var gravity: float = 480.0            # Сила гравитации (160 * 3)
@export var spotted_delay: float = 0.5        # Время замирания врага (0.5 * 3)
@export var lose_target_distance: float = 600.0 # Дистанция потери игрока (200 * 3)
@export var detection_distance: float = 450.0 # ОГРАНИЧЕНИЕ ЗРЕНИЯ: как далеко видит враг (150 * 3)

# === ЗДОРОВЬЕ ===
@export var max_health: int = 300             # (100 * 3)
var current_health: int = 300

# === НАСТРОЙКИ СТРЕЛЬБЫ (ДРОБОВИК) ===
@export var bullet_scene: PackedScene         # Сцена пули (снаряда)
@export var bullet_speed: float = 1500.0       # Базовая скорость полета пули (240 * 3)
@export var bullet_speed_variance: float = 0.35 # Разброс скорости картечин
@export var muzzle_offset: float = 9.0        # Смещение точки спавна пули (3 * 3)
@export var pellet_count: int = 6             # Сколько пуль вылетает за один выстрел
@export var spread_angle_degrees: float = 10.0 # Общий угол разброса картечи
@export var attack_cooldown: float = 2      # Базовое время перезарядки (1.2 * 3)
@export var min_attack_cooldown: float = 1.05 # Минимальный кулдаун стрельбы (0.35 * 3)
@export var attack_range: float = 120.0       # Дистанция выстрела (40 * 3)
@export var attack_windup: float = 0.15       # Время перед выстрелом (0.05 * 3)
@export var attack_active_duration: float = 0.15 # Длительность "момента выстрела" (0.05 * 3)
@export var attack_recovery: float = 1.5      # Пауза после залпа (0.5 * 3)
@export var gun_aim_speed: float = 21.0       # Скорость поворота дробовика (7 * 3)
@export var attack_entry_delay: float = 0.999 # Пауза перед первым выстрелом (~0.333 * 3)
@export var retreat_distance: float = 99.0    # Дистанция начала отступления (33 * 3)
@export var retreat_speed: float = 48.0       # Начальная скорость отступления (16 * 3)
@export var max_retreat_speed: float = 126.0  # Максимальная скорость убегания (42 * 3)

# === НАСТРОЙКИ ОТДАЧИ (RECOIL) ===
@export var recoil_kick_distance: float = 2.7       # Насколько ствол дергается назад (0.9 * 3)
@export var recoil_rotation_kick_degrees: float = 16.0 # На сколько градусов ствол "прогибается"
@export var recoil_recovery_speed: float = 27.0     # Как быстро отдача гасится (9 * 3)
@export var enemy_recoil_force: float = 66.0        # Толкание самого врага назад (22 * 3)

# === КОМПОНЕНТЫ (Ссылки на узлы) ===
@onready var raycast: RayCast2D = $RayCast2D                  
@onready var collision_shape: CollisionShape2D = $CollisionShape2D 
@onready var hands_sprite: AnimatedSprite2D = $TELO/HandsAnimatedSprite 

# === СОСТОЯНИЕ (Конечный автомат врага) ===
enum EnemyState { PATROL, SPOTTED, CHASE, ATTACK, DEAD } 
var current_state: EnemyState = EnemyState.PATROL        
var facing: int = 1                                      
var patrol_traveled: float = 0.0              
var patrol_waiting: bool = false              
var patrol_wait_timer: float = 0.0            
var player: Node2D = null                     
var spotted_timer: float = 0.0                
var is_dead: bool = false                     
var death_rotation_speed: float = 0.0         

# === ПЕРЕМЕННЫЕ АТАКИ (СТРЕЛЬБЫ) ===
var attack_timer: float = 0.0                 
var attack_phase: String = "idle"             
var can_attack: bool = true                   
var is_attacking: bool = false                

# === ПЕРЕМЕННЫЕ ОТДАЧИ СТВОЛА ===
var hands_base_position: Vector2 = Vector2.ZERO  
var current_aim_rotation: float = 0.0            
var recoil_rotation_offset: float = 0.0          
var recoil_position_offset: Vector2 = Vector2.ZERO 

var was_in_range: bool = false                
var range_entry_timer: float = 0.0            

func _ready():
	current_health = max_health
	_set_facing(initial_direction)
	
	add_to_group("enemy")
	
	attack_timer = attack_cooldown
	
	if hands_sprite and hands_sprite.sprite_frames.has_animation("idle"):
		hands_sprite.play("idle")
	
	if hands_sprite:
		hands_base_position = hands_sprite.position

func _physics_process(delta):
	if is_dead:
		velocity.y += gravity * delta
		if velocity.y > 360.0: # (120 * 3)
			velocity.y = 360.0
			
		$TELO.rotation += death_rotation_speed * delta
		
		move_and_slide()
		
		if is_on_floor():
			velocity.x = move_toward(velocity.x, 0.0, 900.0 * delta) # (300 * 3)
			death_rotation_speed = 0.0
			$TELO.rotation = lerp_angle($TELO.rotation, sign(facing) * deg_to_rad(85.0), delta * 12.0)
		return
	
	if not can_attack:
		attack_timer -= delta
		if attack_timer <= 0:
			can_attack = true
	
	if not is_on_floor():
		velocity.y += gravity * delta
		if velocity.y > 270.0: # (90 * 3)
			velocity.y = 270.0
	
	match current_state:
		EnemyState.PATROL:
			_check_player_detection() 
			_patrol_state(delta)
		EnemyState.SPOTTED:
			_spotted_state(delta)
		EnemyState.CHASE:
			_chase_state(delta)
		EnemyState.ATTACK:
			_attack_state(delta)
		EnemyState.DEAD:
			_dead_state(delta)
	
	move_and_slide()

func _get_panic_factor(distance: float) -> float:
	if retreat_distance <= 0:
		return 0.0
	return clamp(1.0 - (distance / retreat_distance), 0.0, 1.0)

# === ОБНАРУЖЕНИЕ (RayCast2D) ===
func _check_player_detection():
	raycast.target_position = Vector2(facing * detection_distance, 0)
	
	if raycast.is_colliding():
		var collider = raycast.get_collider()
		if collider and collider.is_in_group("player"):
			player = collider
			current_state = EnemyState.SPOTTED
			spotted_timer = spotted_delay
			patrol_waiting = false
			_look_at_player()

# === ПАТРУЛЬ ===
func _patrol_state(delta):
	if not patrol_enabled:
		velocity.x = 0.0
		return
	
	if patrol_waiting:
		velocity.x = 0.0
		patrol_wait_timer -= delta
		if patrol_wait_timer <= 0:
			patrol_waiting = false
			_flip_direction()
		return
	
	velocity.x = facing * walk_speed
	
	patrol_traveled += abs(velocity.x * delta)
	if patrol_traveled >= patrol_distance:
		patrol_traveled = 0.0
		patrol_waiting = true
		patrol_wait_timer = patrol_pause_time
		velocity.x = 0.0
		return
	
	for i in range(get_slide_collision_count()):
		var collision = get_slide_collision(i)
		var normal = collision.get_normal()
		if normal.x * facing < -0.5:
			patrol_traveled = 0.0
			patrol_waiting = true
			patrol_wait_timer = patrol_pause_time
			velocity.x = 0.0
			break

# === ЗАМИРАНИЕ ===
func _spotted_state(delta):
	velocity.x = 0
	
	if player:
		_look_at_player()
	
	spotted_timer -= delta
	if spotted_timer <= 0:
		current_state = EnemyState.CHASE

# === ПОГОНЯ ===
func _chase_state(delta):
	if not player:
		current_state = EnemyState.PATROL
		patrol_traveled = 0.0
		patrol_waiting = false
		was_in_range = false
		return
	
	var distance_to_player = global_position.distance_to(player.global_position)
	
	if distance_to_player > lose_target_distance:
		current_state = EnemyState.PATROL
		patrol_traveled = 0.0
		patrol_waiting = false
		player = null
		was_in_range = false
		return
	
	_look_at_player()
	_aim_gun(delta)
	
	var in_combat_range = distance_to_player <= attack_range
	
	if in_combat_range and not was_in_range:
		was_in_range = true
		range_entry_timer = attack_entry_delay
	elif not in_combat_range:
		was_in_range = false
	
	if distance_to_player < retreat_distance:
		var panic_factor = _get_panic_factor(distance_to_player)
		var dynamic_retreat_speed = lerp(retreat_speed, max_retreat_speed, panic_factor)
		var away_direction = (global_position - player.global_position).normalized()
		velocity.x = away_direction.x * dynamic_retreat_speed
	elif in_combat_range:
		velocity.x = 0
	else:
		var direction = (player.global_position - global_position).normalized()
		velocity.x = direction.x * chase_speed
		return
	
	if in_combat_range:
		if range_entry_timer > 0:
			range_entry_timer -= delta
			return
		
		if can_attack and not is_attacking:
			current_state = EnemyState.ATTACK
			is_attacking = true
			attack_phase = "windup"
			attack_timer = attack_windup
			_start_hands_attack_animation()

# === АТАКА (СТРЕЛЬБА) ===
func _attack_state(delta):
	if not player:
		current_state = EnemyState.PATROL
		patrol_traveled = 0.0
		patrol_waiting = false
		is_attacking = false
		return
	
	if not is_on_floor():
		var air_dir = sign(player.global_position.x - global_position.x)
		if air_dir != 0:
			velocity.x = move_toward(velocity.x, air_dir * (chase_speed * 1.2), 600.0 * delta) # (200 * 3)
	else:
		var distance_to_player = global_position.distance_to(player.global_position)
		if distance_to_player < retreat_distance:
			var panic_factor = _get_panic_factor(distance_to_player)
			var dynamic_retreat_speed = lerp(retreat_speed, max_retreat_speed, panic_factor)
			var away_direction = (global_position - player.global_position).normalized()
			velocity.x = move_toward(velocity.x, away_direction.x * dynamic_retreat_speed, 900.0 * delta) # (300 * 3)
		else:
			velocity.x = move_toward(velocity.x, 0.0, 900.0 * delta) # (300 * 3)
		
	_look_at_player()
	_aim_gun(delta)
	
	match attack_phase:
		"windup":
			_look_at_player()
			attack_timer -= delta
			if attack_timer <= 0:
				attack_phase = "active"
				attack_timer = attack_active_duration
				_perform_attack()
		
		"active":
			attack_timer -= delta
			if attack_timer <= 0:
				attack_phase = "recovery"
				attack_timer = attack_recovery
		
		"recovery":
			attack_timer -= delta
			if attack_timer <= 0:
				is_attacking = false
				can_attack = false
				
				var dist = global_position.distance_to(player.global_position)
				var panic_factor = _get_panic_factor(dist)
				attack_timer = lerp(attack_cooldown, min_attack_cooldown, panic_factor)
				
				current_state = EnemyState.CHASE
				_reset_hands_animation()
		
		_:
			current_state = EnemyState.CHASE
			is_attacking = false

func _start_hands_attack_animation():
	if hands_sprite and hands_sprite.sprite_frames.has_animation("attack"):
		hands_sprite.play("attack")

func _reset_hands_animation():
	if hands_sprite:
		if hands_sprite.sprite_frames.has_animation("idle"):
			hands_sprite.play("idle")
		else:
			hands_sprite.stop()

func _perform_attack():
	if not bullet_scene or not player:
		return
	
	var base_direction = (player.global_position - global_position).normalized()
	if base_direction == Vector2.ZERO:
		base_direction = Vector2(facing, 0)
	
	_trigger_gun_recoil()
	velocity -= base_direction * enemy_recoil_force 
	
	var base_angle = base_direction.angle()
	var spread_rad = deg_to_rad(spread_angle_degrees)
	
	for i in range(pellet_count):
		var pellet_angle = base_angle + randf_range(-spread_rad * 0.5, spread_rad * 0.5)
		var pellet_direction = Vector2.RIGHT.rotated(pellet_angle)
		var pellet_speed = bullet_speed * randf_range(1.0 - bullet_speed_variance, 1.0 + bullet_speed_variance)
		
		var bullet_instance = bullet_scene.instantiate()
		get_tree().current_scene.add_child(bullet_instance)
		
		var spawn_offset = pellet_direction * muzzle_offset
		bullet_instance.global_position = global_position + spawn_offset
		bullet_instance.rotation = pellet_angle
		
		if "direction" in bullet_instance:
			bullet_instance.direction = pellet_direction
		if "speed" in bullet_instance:
			bullet_instance.speed = pellet_speed
		if bullet_instance.has_method("set_direction"):
			bullet_instance.set_direction(pellet_direction)

# === СМЕРТЬ ===
func take_damage(damage: int = 35):
	if is_dead:
		return
	
	current_health -= damage
	if current_health > 0:
		return
	
	is_dead = true
	current_state = EnemyState.DEAD

	var player_node = get_tree().get_first_node_in_group("player")
	if player_node:
		if player_node.has_method("register_enemy_kill"):
			player_node.register_enemy_kill()
			
		if "dash_timer" in player_node and player_node.dash_timer > 0:
			player_node.can_dash = true
			player_node.dash_cooldown_timer = 0.0
	
	collision_layer = 0
	collision_mask = 1
	
	var push_dir = -facing
	if player_node:
		push_dir = sign(global_position.x - player_node.global_position.x)
		if push_dir == 0:
			push_dir = -facing
			
	velocity = Vector2(push_dir * 105.0, -120.0) # (35*3, -40*3)
	death_rotation_speed = randf_range(12.0, 18.0) * push_dir
	
	await get_tree().create_timer(7.0).timeout
	
	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 1.5)
	await tween.finished
	queue_free()

func _dead_state(delta):
	pass

# === ВСПОМОГАТЕЛЬНЫЕ ФУНКЦИИ ===

func _set_facing(new_facing: int):
	if new_facing != 0 and facing != new_facing:
		facing = new_facing
		if has_node("TELO"):
			$TELO.scale.x = abs($TELO.scale.x) * facing

func _look_at_player():
	if not player:
		return
	var direction = (player.global_position - global_position).normalized()
	if direction.x != 0:
		_set_facing(sign(direction.x))

func _aim_gun(delta):
	if not hands_sprite or is_dead:
		return
	
	if player:
		var telo = $TELO
		var local_target = telo.to_local(player.global_position)
		var local_diff = local_target - hands_base_position
		if local_diff != Vector2.ZERO:
			var target_rotation = local_diff.angle()
			current_aim_rotation = lerp_angle(current_aim_rotation, target_rotation, delta * gun_aim_speed)
	
	recoil_rotation_offset = lerp_angle(recoil_rotation_offset, 0.0, delta * recoil_recovery_speed)
	recoil_position_offset = recoil_position_offset.lerp(Vector2.ZERO, delta * recoil_recovery_speed)
	
	hands_sprite.rotation = current_aim_rotation + recoil_rotation_offset
	hands_sprite.position = hands_base_position + recoil_position_offset

func _trigger_gun_recoil():
	if not hands_sprite:
		return
	
	var kick_local = Vector2(-recoil_kick_distance, -recoil_kick_distance * 0.5).rotated(current_aim_rotation)
	recoil_position_offset += kick_local
	recoil_rotation_offset -= deg_to_rad(recoil_rotation_kick_degrees)

func _flip_direction():
	_set_facing(-facing)

func reset_attack_cooldown():
	can_attack = true
	attack_timer = 0.0
