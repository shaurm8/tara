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
@export_subgroup("Откуда идут огонь и дым")
@export var emit_width_fraction: float = 0.6   # по какой части ширины трупа они появляются (1 = по всей ширине)
@export var emit_height_spread: float = 6.0    # разброс вверх от нижней точки трупа (px)
@export var emit_offset: Vector2 = Vector2.ZERO   # ручная подгонка относительно нижней точки (минус по Y = выше)
@export_subgroup("Дым")
@export var smoke_scene: PackedScene           # твоя сцена дыма (сама исчезает после анимации)
@export var smoke_total_time: float = 14.0     # сколько секунд от смерти дым постепенно затухает до нуля
@export var smoke_rate: float = 40.0           # сколько клубов в секунду в самом начале
@export var smoke_fade_curve: float = 1.6      # 1 = линейное затухание, больше = быстрее спад и долгий тонкий «хвост»
@export_range(0.0, 1.0) var smoke_end_alpha: float = 0.45   # прозрачность дыма к концу (1 = не меняется)
@export var smoke_side_drift: float = 30.0     # на сколько пикселей дым может снести в сторону
@export var smoke_rise: float = 120.0          # и на сколько приподнять (0 = только в стороны)
@export var smoke_drift_time: float = 1.2      # за сколько секунд дым проходит этот путь
@export_subgroup("Огонь")
@export var fire_scene: PackedScene            # сцена огня: идёт из тела, пока труп горит
@export var fire_total_time: float = 6.0       # сколько секунд огонь постепенно затухает до нуля
@export var fire_rate: float = 25.0            # сколько язычков в секунду в самом начале
@export var fire_fade_curve: float = 1.4       # 1 = линейно, больше = быстрее спад и долгий слабый «хвост»
@export var fire_rise_speed: float = 90.0      # скорость подъёма огня вверх (к концу снижается)
@export var fire_side_speed: float = 40.0      # скорость разлёта огня в стороны
@export_subgroup("Пепел")
@export var ash_enabled: bool = true           # выключатель пепла
@export var ash_total_time: float = 24.0       # сколько секунд пепел постепенно затухает (самый долгий: огонь → дым → пепел)
@export var ash_rate: float = 20.0             # пикселей пепла в секунду в самом начале
@export var ash_fade_curve: float = 1.3        # 1 = линейно, больше = быстрее спад и долгий редкий «хвост»
@export var ash_life_min: float = 1.5          # сколько живёт один пиксель пепла (сек)
@export var ash_life_max: float = 3.5
@export var ash_rise_speed: float = 60.0       # начальная скорость вверх
@export var ash_side_speed: float = 18.0       # начальный разброс в стороны (меньше = ближе к вертикали)
@export var ash_buoyancy: float = 55.0         # сила подъёма: чем больше, тем выше поднимается
@export var ash_turbulence: float = 100.0      # хаотичность (случайные толчки): больше = беспорядочнее
@export var ash_curl: float = 3.0              # закрученность: траектория качается влево-вправо; больше = круче петли (общий ход при этом остаётся вверх)
@export var ash_size_min: float = 1.0          # размер пикселя пепла
@export var ash_size_max: float = 2.0
@export var ash_color_start: Color = Color(0.25, 0.25, 0.25)   # тёмный край перелива (не чёрный, чтобы пепел не пропадал на тёмном фоне)
@export var ash_color_end: Color = Color(0.8, 0.8, 0.8)         # светлый край перелива (не белый); пиксель в полёте случайно переливается между ними
@export var ash_shimmer_speed_min: float = 1.0   # скорость перелива (рад/с): у каждого пикселя своя случайная, между min и max
@export var ash_shimmer_speed_max: float = 2.5   # меньше = медленнее; 2.0 ≈ одна смена чёрный→белый→чёрный за 3 секунды
@export var ash_trail_enabled: bool = true     # незаметный шлейф за пеплом (выключатель)
@export_range(0.0, 1.0) var ash_trail_alpha: float = 0.25   # яркость шлейфа относительно самого пикселя
@export var ash_trail_length: int = 5          # сколько точек в шлейфе (длиннее = длиннее след)
@export var ash_trail_step: float = 0.03       # как часто ставится точка шлейфа, сек (больше = шлейф длиннее и реже)
@export var ash_z_offset: int = -2             # относительно огня и дыма: -2 = позади них и позади шлейфа дыма (шлейф дыма лежит на -1)

static var _ash_layers: Dictionary = {}

var _death_age: float = 0.0
var _fire_acc: float = 0.0
var _smoke_acc: float = 0.0
var _ash_acc: float = 0.0
var _fx_ref_z: int = 2147483647               # самый низкий z среди созданных огня и дыма (от него считается z пепла)
var _emit_local: Vector2 = Vector2.ZERO        # нижняя точка трупа в координатах спрайта
var _emit_half_w: float = 0.0                  # половина ширины трупа (px спрайта)

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

	# Направление удара можно передать аргументом или положить в метаданные врага (так делает пуля)
	if hit_dir == Vector2.ZERO and has_meta("last_hit_dir"):
		hit_dir = get_meta("last_hit_dir")

	# Убираем тело врага из физики сразу, чтобы вылетающие куски не врезались в него
	_disable_collision()

	# Взрыв откладываем на конец кадра: пуля вызывает take_damage прямо из физического сигнала,
	# а создавать ноды и запускать физику внутри такого сигнала небезопасно
	call_deferred("_explode_and_free", hit_dir)

func _explode_and_free(hit_dir: Vector2) -> void:
	_explode(hit_dir)
	queue_free()

## Тела, которые куски не должны задевать: сам враг и игрок (при ударе топором они рядом)
func _gib_exclude() -> Array:
	var ex: Array = [get_rid()]
	var pl = get_tree().get_first_node_in_group("player")
	if pl is CollisionObject2D:
		ex.append(pl.get_rid())
	return ex

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
		"exclude_rids": _gib_exclude(),
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
	var frames := animated_sprite.sprite_frames
	if not frames.has_animation(fire_death_anim):
		return false   # анимации нет — умрёт обычным разлётом
	_disable_collision()
	_compute_emit_point(frames)
	# Без цикла: после последнего кадра спрайт так и остаётся на нём
	frames.set_animation_loop(fire_death_anim, false)
	animated_sprite.play(fire_death_anim)
	_death_age = 0.0
	_fire_acc = 0.0
	_smoke_acc = 0.0
	_ash_acc = 0.0
	set_process(true)
	return true

## Находит самую нижнюю видимую точку ПОСЛЕДНЕГО кадра сгорания (там, где труп и останется лежать)
func _compute_emit_point(frames: SpriteFrames) -> void:
	var count := frames.get_frame_count(fire_death_anim)
	var tex: Texture2D = frames.get_frame_texture(fire_death_anim, maxi(count - 1, 0))
	var sp := animated_sprite
	if tex == null:
		_emit_local = sp.offset
		_emit_half_w = 0.0
		return
	var size := tex.get_size()
	var origin := sp.offset
	if sp.centered:
		origin -= size * 0.5
	var rect := Rect2i(0, 0, int(size.x), int(size.y))
	var img := tex.get_image()
	if img != null:
		if img.is_compressed():
			img.decompress()
		var used := img.get_used_rect()
		if used.size.x > 0 and used.size.y > 0:
			rect = used
	var cx := rect.position.x + rect.size.x * 0.5
	var bottom := float(rect.position.y + rect.size.y)
	if sp.flip_h:
		cx = size.x - cx
	if sp.flip_v:
		bottom = size.y - float(rect.position.y)
	_emit_local = origin + Vector2(cx, bottom)
	_emit_half_w = rect.size.x * 0.5

## Случайная точка у нижнего края трупа (в мировых координатах)
func _emit_point() -> Vector2:
	var hw := _emit_half_w * emit_width_fraction
	var local := _emit_local + Vector2(randf_range(-hw, hw), -randf_range(0.0, emit_height_spread))
	return animated_sprite.global_transform * local + emit_offset

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
	_death_age += delta
	var active := false

	# Огонь и дым не обрываются, а плавно слабеют: частота спавна падает от 100% до 0 по кривой
	if fire_scene and _death_age < fire_total_time:
		active = true
		var k := _death_age / fire_total_time
		_fire_acc += fire_rate * pow(1.0 - k, fire_fade_curve) * delta
		var n := mini(int(_fire_acc), 20)
		_fire_acc -= int(_fire_acc)
		for i in n:
			_spawn_fire(k)

	if smoke_scene and _death_age < smoke_total_time:
		active = true
		var k := _death_age / smoke_total_time
		_smoke_acc += smoke_rate * pow(1.0 - k, smoke_fade_curve) * delta
		var n := mini(int(_smoke_acc), 30)
		_smoke_acc -= int(_smoke_acc)
		for i in n:
			_spawn_smoke(k)

	if ash_enabled and _death_age < ash_total_time:
		active = true
		var k := _death_age / ash_total_time
		_ash_acc += ash_rate * pow(1.0 - k, ash_fade_curve) * delta
		var n := mini(int(_ash_acc), 40)
		_ash_acc -= int(_ash_acc)
		for i in n:
			_spawn_ash()

	if not active:
		set_process(false)

func _get_ash_layer() -> AshLayer:
	var base_z := _fx_ref_z if _fx_ref_z != 2147483647 else animated_sprite.z_index
	var z := base_z + ash_z_offset
	var layer = _ash_layers.get(z)
	if layer == null or not is_instance_valid(layer) or not layer.is_inside_tree():
		var scene := get_tree().current_scene
		if scene == null:
			return null
		layer = AshLayer.new()
		layer.z_index = z
		scene.add_child(layer)
		_ash_layers[z] = layer
	return layer

func _spawn_ash() -> void:
	if animated_sprite == null:
		return
	var layer := _get_ash_layer()
	if layer == null:
		return
	var p := AshParticle.new()
	p.pos = _emit_point()
	var side := (randf_range(-1.0, 1.0) + randf_range(-1.0, 1.0)) * 0.5 * ash_side_speed   # чаще около нуля, реже по краям
	p.vel = Vector2(side, -ash_rise_speed * randf_range(0.6, 1.2))
	p.life = randf_range(ash_life_min, ash_life_max)
	p.size = randf_range(ash_size_min, ash_size_max)
	p.c0 = ash_color_start
	p.c1 = ash_color_end
	p.sh_speed = randf_range(ash_shimmer_speed_min, ash_shimmer_speed_max)
	p.sh_phase1 = randf() * TAU
	p.sh_phase2 = randf() * TAU
	p.curl = ash_curl * randf_range(0.4, 1.0)
	p.buoy = ash_buoyancy
	p.turb = ash_turbulence
	if ash_trail_enabled and ash_trail_length > 0:
		p.trail_max = ash_trail_length
		p.trail_alpha = ash_trail_alpha
		p.trail_step = maxf(ash_trail_step, 0.005)
	layer.add_particle(p)

func _spawn_smoke(k: float) -> void:
	if smoke_scene == null or animated_sprite == null:
		return
	var s = smoke_scene.instantiate()
	get_tree().current_scene.add_child(s)
	var p := _emit_point()
	s.global_position = p
	# Чем дальше, тем дым прозрачнее
	if s is CanvasItem:
		_fx_ref_z = mini(_fx_ref_z, s.z_index)
		s.modulate.a = lerpf(1.0, smoke_end_alpha, k)
	# Дым сносит немного вбок (и приподнимает) за время жизни
	if smoke_side_drift > 0.0 or smoke_rise > 0.0:
		var target := p + Vector2(randf_range(-smoke_side_drift, smoke_side_drift), -smoke_rise * randf_range(0.5, 1.0))
		var tw := s.create_tween()
		tw.tween_property(s, "global_position", target, smoke_drift_time).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

func _spawn_fire(k: float) -> void:
	if fire_scene == null or animated_sprite == null:
		return
	var f = fire_scene.instantiate()
	get_tree().current_scene.add_child(f)
	f.global_position = _emit_point()
	if f is CanvasItem:
		_fx_ref_z = mini(_fx_ref_z, f.z_index)
	if "velocity" in f:
		# К концу огонь не только реже, но и ниже: взлетает слабее
		var rise := fire_rise_speed * lerpf(1.0, 0.35, k)
		f.velocity = Vector2(randf_range(-fire_side_speed, fire_side_speed), -rise * randf_range(0.6, 1.2))

## Один слой на все пиксели пепла всех трупов (z-индекс общий): рисует всё одним нодом, без отдельных нод на пиксель
class AshParticle:
	var pos: Vector2
	var vel: Vector2
	var age: float = 0.0
	var life: float = 2.0
	var size: float = 1.0
	var c0: Color = Color.BLACK       # один край перелива
	var c1: Color = Color.WHITE       # другой край перелива
	var sh_speed: float = 1.5         # личная скорость перелива
	var sh_phase1: float = 0.0        # случайные фазы двух волн: вместе дают неровное, «случайное» мерцание
	var sh_phase2: float = 0.0
	var curl: float = 0.0
	var buoy: float = 50.0
	var turb: float = 100.0
	var phase: float = 0.0
	var freq: float = 2.0
	var trail: PackedVector2Array = PackedVector2Array()
	var trail_max: int = 0
	var trail_alpha: float = 0.25
	var trail_step: float = 0.03
	var trail_t: float = 0.0

class AshLayer extends Node2D:
	const MAX_PARTICLES := 3000   # аварийный предохранитель, в обычной игре не достигается
	const DRAG := 0.9
	var items: Array[AshParticle] = []

	func _init() -> void:
		top_level = true          # координаты глобальные
		z_as_relative = false
		set_process(false)

	func add_particle(p: AshParticle) -> void:
		if items.size() >= MAX_PARTICLES:
			return
		p.phase = randf() * TAU
		p.freq = randf_range(1.5, 3.5)
		items.append(p)
		set_process(true)

	func _process(delta: float) -> void:
		var drag_k := exp(-DRAG * delta)
		var w := 0
		for r in items.size():
			var p := items[r]
			p.age += delta
			if p.age >= p.life:
				continue
			p.vel.y -= p.buoy * delta
			p.vel += Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * p.turb * delta
			# Поворот скорости то в одну, то в другую сторону: траектория вьётся и петляет, но в среднем идёт вверх
			p.vel = p.vel.rotated(p.curl * sin(p.age * p.freq + p.phase) * delta)
			p.vel *= drag_k
			p.pos += p.vel * delta
			# Шлейф: точки ставятся по времени, а не по кадрам — длина не зависит от FPS
			if p.trail_max > 0:
				p.trail_t += delta
				if p.trail_t >= p.trail_step:
					p.trail_t -= p.trail_step
					p.trail.append(p.pos)
					if p.trail.size() > p.trail_max:
						p.trail.remove_at(0)
			items[w] = p
			w += 1
		items.resize(w)
		queue_redraw()
		if w == 0:
			set_process(false)

	func _draw() -> void:
		for p in items:
			var t := p.age / p.life
			# Быстро проявляется и плавно исчезает во второй половине жизни
			var a := minf(p.age / 0.15, 1.0) * (1.0 - smoothstep(0.5, 1.0, t))
			# Цвет переливается между c0 и c1 туда-сюда: две волны с разной частотой дают неровное случайное мерцание
			var v := 0.5 + 0.25 * sin(p.age * p.sh_speed + p.sh_phase1) + 0.25 * sin(p.age * p.sh_speed * 1.7 + p.sh_phase2)
			var col := p.c0.lerp(p.c1, v)
			var sz := Vector2(p.size, p.size)
			var n := p.trail.size()
			for i in n:
				var f := float(i + 1) / float(n + 1)   # старые точки шлейфа бледнее
				draw_rect(Rect2(p.trail[i].round(), sz), Color(col.r, col.g, col.b, col.a * a * p.trail_alpha * f))
			draw_rect(Rect2(p.pos.round(), sz), Color(col.r, col.g, col.b, col.a * a))
