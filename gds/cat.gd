extends CharacterBody2D

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D

var current_health: int = 1
var is_dead: bool = false

# === РАЗЛЁТ НА КРОВАВЫЕ КУСКИ ===
@export_group("Разлёт при смерти")
@export var gib_chunk_count: int = 12          # на сколько кусков рвётся враг
@export var gib_chunk_size_variation: float = 1.0   # 0 = одинаковые, 1+ = крупные куски и мелкие ошмётки
@export var gib_edge_roughness: float = 2.5    # рваность границ между кусками
@export var gib_speed_min: float = 150.0
@export var gib_speed_max: float = 450.0
@export var gib_gravity: float = 700.0         # 0 — если игра с видом сверху
@export var gib_drag: float = 1.5              # в виде сверху лучше 3–5
@export var gib_spin: float = 14.0
@export var gib_upward_bias: float = 120.0
@export var gib_hit_dir_strength: float = 0.6  # насколько куски и кровь летят по направлению удара
@export_group("Свои кусочки")
@export var gib_textures: Array[Texture2D] = []   # сюда перетащи свои нарисованные кусочки
@export var gib_textures_copies: int = 1          # сколько раз повторить каждый (2 = по два каждого)
@export var gib_generated_pieces: int = 3         # сколько сгенерированных ошмётков добавить к нарисованным (0 = только твои)
@export_group("Пол и стены")
@export_flags_2d_physics var gib_world_mask: int = 1   # ТОЛЬКО слои пола и стен (не враги и не игрок!)
@export var gib_bounce: float = 0.35
@export var gib_rest_speed: float = 45.0
@export var gib_lie_time: float = 0.0          # сколько лежат (0 = навсегда)
@export_group("Кровь (твоя сцена)")
@export var blood_drop_scene: PackedScene      # перетащи сюда свою сцену крови, как в огнемёте
@export var blood_drop_scene_count: int = 80   # сколько капель вылетает при взрыве
@export var blood_land_count: int = 30         # залп крови, когда кусок приземлился
@export var blood_impact_count: int = 10        # поменьше — при каждом отскоке
@export var blood_trail_rate: float = 200.0    # капель в секунду с каждого летящего куска (больше = гуще)
@export var blood_trail_inherit: float = 0.9   # доля скорости куска, которую наследуют капли
@export var blood_trail_spread: float = 25.0   # разброс капель: меньше = ближе к куску
@export var blood_trail_per_piece: int = 400          # сколько капель накапают летящие куски (0 = выкл)
@export var blood_speed_min: float = 100.0
@export var blood_speed_max: float = 400.0
@export_group("Вид кусков")
@export_range(0.0, 1.0) var gib_blood_tint: float = 0.45   # насколько куски пропитаны красным
@export var gib_blood_color: Color = Color(0.6, 0.02, 0.04)
@export var gib_edge_color: Color = Color(0.35, 0.0, 0.02)  # кромка в местах разрыва

@export_group("Смерть от огня")
@export var fire_death_anim: StringName = &"Fdeath"   # твоя анимация сгорания (проигрывается один раз, остаётся последний кадр)
@export var fire_hit_window: float = 0.3       # огонь считается убийцей, если попал не раньше чем за столько секунд до смерти
@export var smoke_scene: PackedScene          # твоя сцена дыма (сама исчезает после анимации)
@export var smoke_interval: float = 0.06       # как часто выходит клуб дыма, пока он горит
@export var smoke_duration: float = 6.0        # сколько секунд после конца анимации труп ещё тлеет (0 = не тлеет)
@export var smoke_offset: Vector2 = Vector2(0, -10)   # смещение точки дыма от центра спрайта
@export var smoke_spread: float = 14.0          # разброс точки дыма

@export var smoke_per_puff: int = 2            # сколько клубов дыма за раз (больше = гуще)
@export var smoke_side_drift: float = 30.0     # на сколько пикселей дым может снести в сторону
@export var smoke_rise: float = 20.0           # и на сколько приподнять (0 = только в стороны)
@export var smoke_drift_time: float = 1.2      # за сколько секунд дым проходит этот путь
@export var fire_scene: PackedScene            # сцена огня: первое время он «выходит» из тела, как дым
@export var fire_duration: float = 1.5         # сколько секунд с начала смерти идёт огонь
@export var fire_interval: float = 0.04        # как часто появляется язычок огня
@export var fire_spread: float = 10.0          # разброс точки появления огня
@export var fire_rise_speed: float = 90.0      # скорость подъёма огня вверх
@export var fire_side_speed: float = 40.0      # скорость разлёта огня в стороны

var _fire_age: float = 999.0
var _fire_timer: float = 0.0
var _smoke_mode: int = 0      # 0 — нет, 1 — горит (идёт анимация), 2 — тлеет (после анимации)
var _smoke_timer: float = 0.0
var _smoke_age: float = 0.0

func _ready() -> void:
	set_process(false)
	if animated_sprite and animated_sprite.sprite_frames and animated_sprite.sprite_frames.has_animation("idle"):
		animated_sprite.play("idle")

## hit_dir (необязательно) — направление удара, куски и кровь полетят в эту сторону
func take_damage(damage: int = 35, hit_dir: Vector2 = Vector2.ZERO) -> void:
	if is_dead:
		return

	current_health -= damage
	if current_health > 0:
		return

	is_dead = true

	# Регистрируем убийство, если нужно
	var player_node = get_tree().get_first_node_in_group("player")
	if player_node and player_node.has_method("register_enemy_kill"):
		player_node.register_enemy_kill()

	# Убит огнём: сгорает на месте и остаётся обугленным трупом (без кусков и крови)
	var fire_age := Time.get_ticks_msec() / 1000.0 - float(get_meta("fire_last_hit", -100.0))
	if fire_age <= fire_hit_window and _start_fire_death():
		return

	_explode(hit_dir)
	queue_free()

func _explode(hit_dir: Vector2) -> void:
	if animated_sprite == null:
		return
	GibBurst.spawn(animated_sprite, hit_dir, {
		"chunk_count": gib_chunk_count,
		"chunk_size_variation": gib_chunk_size_variation,
		"edge_roughness": gib_edge_roughness,
		"custom_textures": gib_textures,
		"custom_copies": gib_textures_copies,
		"generated_pieces": gib_generated_pieces if not gib_textures.is_empty() else -1,
		"speed_min": gib_speed_min,
		"speed_max": gib_speed_max,
		"gravity": gib_gravity,
		"drag": gib_drag,
		"spin_max": gib_spin,
		"upward_bias": gib_upward_bias,
		"hit_dir_strength": gib_hit_dir_strength,
		"world_mask": gib_world_mask,
		"bounce": gib_bounce,
		"rest_speed": gib_rest_speed,
		"lie_time": gib_lie_time,
		"blood_scene": blood_drop_scene,
		"blood_scene_count": blood_drop_scene_count,
		"blood_trail_per_piece": blood_trail_per_piece,
		"blood_land_count": blood_land_count,
		"blood_impact_count": blood_impact_count,
		"blood_trail_rate": blood_trail_rate,
		"blood_trail_inherit": blood_trail_inherit,
		"blood_trail_spread": blood_trail_spread,
		"blood_speed_min": blood_speed_min,
		"blood_speed_max": blood_speed_max,
		"blood_tint": gib_blood_tint,
		"blood_color": gib_blood_color,
		"edge_color": gib_edge_color,
	})

# ---------- Смерть от огня ----------

func _start_fire_death() -> bool:
	if animated_sprite == null or animated_sprite.sprite_frames == null:
		return false
	if not animated_sprite.sprite_frames.has_animation(fire_death_anim):
		return false   # анимации нет — умрёт обычным разлётом
	_disable_collision()
	# Без цикла: после последнего кадра спрайт так и остаётся на нём
	animated_sprite.sprite_frames.set_animation_loop(fire_death_anim, false)
	animated_sprite.play(fire_death_anim)
	animated_sprite.animation_finished.connect(_on_fire_death_finished, CONNECT_ONE_SHOT)
	_smoke_mode = 1
	_smoke_timer = 0.0
	_fire_age = 0.0
	_fire_timer = 0.0
	_smoke_age = 0.0
	set_process(true)
	return true

func _on_fire_death_finished() -> void:
	_smoke_mode = 2   # анимация доиграла, труп остаётся лежать и тлеет
	_smoke_age = 0.0

## Труп не должен ловить удары: огонь, пули и т.д. проходят сквозь него
func _disable_collision() -> void:
	set_deferred("collision_layer", 0)
	set_deferred("collision_mask", 0)
	for n in find_children("*", "CollisionShape2D", true, false):
		n.set_deferred("disabled", true)
	for n in find_children("*", "CollisionPolygon2D", true, false):
		n.set_deferred("disabled", true)
	for n in find_children("*", "CollisionObject2D", true, false):
		n.set_deferred("collision_layer", 0)
		n.set_deferred("collision_mask", 0)

func _process(delta: float) -> void:
	var active := false

	# Огонь: первое время «выходит» из тела, как дым
	if fire_scene and _fire_age < fire_duration:
		active = true
		_fire_age += delta
		_fire_timer -= delta
		if _fire_timer <= 0.0:
			_fire_timer = fire_interval * randf_range(0.7, 1.3)
			_spawn_fire()

	# Дым: густой, пока горит, потом тлеет и редеет
	if _smoke_mode != 0:
		active = true
		var k := 0.0
		if _smoke_mode == 2:
			_smoke_age += delta
			if smoke_duration <= 0.0 or _smoke_age >= smoke_duration:
				_smoke_mode = 0
			else:
				k = _smoke_age / smoke_duration
		if _smoke_mode != 0:
			_smoke_timer -= delta
			if _smoke_timer <= 0.0:
				_smoke_timer = smoke_interval * lerpf(1.0, 3.0, k) * randf_range(0.7, 1.3)
				for i in smoke_per_puff:
					_spawn_smoke()

	if not active:
		set_process(false)

func _spawn_smoke() -> void:
	if smoke_scene == null or animated_sprite == null:
		return
	var s = smoke_scene.instantiate()
	get_tree().current_scene.add_child(s)
	var p := animated_sprite.global_position + smoke_offset + Vector2(randf_range(-smoke_spread, smoke_spread), randf_range(-smoke_spread, smoke_spread) * 0.5)
	s.global_position = p
	# Дым сносит немного вбок (и приподнимает) за время жизни
	if smoke_side_drift > 0.0 or smoke_rise > 0.0:
		var target := p + Vector2(randf_range(-smoke_side_drift, smoke_side_drift), -smoke_rise * randf_range(0.5, 1.0))
		var tw := s.create_tween()
		tw.tween_property(s, "global_position", target, smoke_drift_time).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

func _spawn_fire() -> void:
	if fire_scene == null or animated_sprite == null:
		return
	var f = fire_scene.instantiate()
	get_tree().current_scene.add_child(f)
	f.global_position = animated_sprite.global_position + smoke_offset + Vector2(randf_range(-fire_spread, fire_spread), randf_range(-fire_spread, fire_spread) * 0.5)
	if "velocity" in f:
		f.velocity = Vector2(randf_range(-fire_side_speed, fire_side_speed), -fire_rise_speed * randf_range(0.6, 1.2))
