extends Area2D

var velocity: Vector2 = Vector2.ZERO
var lifetime: float = 0.0

# === НАСТРОЙКИ ОГНЯ ===
@export var anim_name: StringName = &"fly"
@export var max_lifetime: float = 0.65
@export var lifetime_variation: float = 0.2
@export var drag: float = 1.8
@export var buoyancy: float = 140.0
@export var spin_speed: float = 2.0
@export var start_scale: float = 1.0
@export var end_scale: float = 1.0
@export var fade_start: float = 0.55

# === НАСТРОЙКИ СВЕТА ===
@export_range(0.0, 1.0) var light_chance: float = 0.3
@export var light_color: Color = Color(1.0, 0.5, 0.15)
@export var max_light_energy: float = 1
@export var light_fade_in_ratio: float = 0.15
@export var guaranteed_light_count: int = 1
@export var new_stream_gap: float = 0.3

static var _last_spawn_sec: float = -100.0
static var _stream_count: int = 0
# Одна общая текстура света на все частицы (раньше создавалась заново каждой)
static var _light_tex: GradientTexture2D = null

# === УРОН ===
@export var tick_damage: float = 20.0
@export var tick_interval: float = 0.1
@export var scan_interval: float = 0.05       # как часто частица проверяет, кого она касается (раньше каждый кадр)
@export var fade_frames: int = 2
@export_range(0.0, 1.0) var fade_damage_mult: float = 0.5
@export var wall_slow: float = 0.15

# === ШЛЕЙФ (рисуется одним нодом на всех, от FPS не зависит) ===
@export var trail_enabled: bool = true
@export var trail_ghosts_per_second: float = 120.0   # раньше было 3 за кадр (= 180/с при 60 fps). Хочешь как раньше — 180
@export_range(0.0, 1.0) var trail_start_alpha: float = 0.3
@export var trail_z_index: int = 0
@export_group("Обычный шлейф (как у топора)")
@export var classic_trail_enabled: bool = true
@export var classic_trail_lifetime: float = 0.1
@export_range(0.0, 1.0) var classic_trail_alpha: float = 0.3
@export_group("Рваность шлейфа")
@export var ragged_trail_enabled: bool = true
@export var trail_lifetime: float = 0.2
@export_range(0.0, 1.0) var trail_spawn_chance: float = 0.75
@export_range(0.0, 1.0) var trail_lifetime_variation: float = 0.5
@export var trail_jitter: float = 3.0
@export var trail_drift_up: float = 10.0
@export var trail_drift_side: float = 6.0
@export var trail_spin: float = 2.0
@export var trail_end_scale_min: float = 0.35
@export var trail_end_scale_max: float = 0.9
@export var trail_end_color: Color = Color(1.0, 0.45, 0.2)

# === КРОВЬ ===
@export var blood_drop_scene: PackedScene
@export var blood_back_count: int = 6
@export var blood_front_count: int = 2

const _RAD50 := 0.8726646
const _RAD70 := 1.2217305

var sprite: AnimatedSprite2D
var _life_total: float = 0.65
var _rot_direction: float = 1.0
var _light: PointLight2D = null
var _trail_prev_xform: Transform2D
var _trail_has_prev: bool = false
var _trail_acc: float = 0.0
var _trail_layer: FireTrailLayer = null
var _scan_timer: float = 0.0

# Кэш «игнорировать эту цель» (раньше на каждый тик делались to_lower() и поиск по группам)
static var _ignore_cache: Dictionary = {}

func _ready() -> void:
	_life_total = max_lifetime * randf_range(1.0 - lifetime_variation, 1.0 + lifetime_variation)
	scale = Vector2.ONE * start_scale

	rotation += randf_range(-0.4, 0.4)
	_rot_direction = -1.0 if randf() < 0.5 else 1.0

	var now := Time.get_ticks_msec() / 1000.0
	if now - _last_spawn_sec > new_stream_gap:
		_stream_count = 0
	_last_spawn_sec = now
	var force_light := _stream_count < guaranteed_light_count
	_stream_count += 1

	if force_light or randf() < light_chance:
		_setup_light()

	# Фаза скана урона у каждой частицы своя, чтобы они не проверялись все в один кадр
	_scan_timer = randf() * scan_interval

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
	if _light_tex == null:
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
		_light_tex = grad_tex

	_light = PointLight2D.new()
	_light.name = "FireLight"
	_light.texture = _light_tex
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

	velocity *= exp(-drag * delta)
	velocity.y -= buoyancy * delta
	position += velocity * delta

	if velocity != Vector2.ZERO:
		rotation = lerp_angle(rotation, velocity.angle(), 10.0 * delta)
	rotation += spin_speed * _rot_direction * delta

	scale = Vector2.ONE * lerp(start_scale, end_scale, t)
	var alpha := 1.0
	if t > fade_start:
		alpha = 1.0 - (t - fade_start) / (1.0 - fade_start)
	modulate.a = alpha

	if trail_enabled:
		_update_trail(delta)

	if _light:
		var light_factor := 1.0
		if t < light_fade_in_ratio:
			light_factor = t / light_fade_in_ratio
		elif t > fade_start:
			light_factor = 1.0 - (t - fade_start) / (1.0 - fade_start)
		_light.energy = max_light_energy * clamp(light_factor, 0.0, 1.0)

	_scan_timer -= delta
	if _scan_timer <= 0.0:
		_scan_timer = scan_interval
		_apply_damage_ticks()

	if lifetime >= _life_total:
		queue_free()

# ---------- Шлейф ----------

func _update_trail(delta: float) -> void:
	if not sprite or not sprite.sprite_frames: return

	var current: Transform2D = sprite.global_transform
	if not _trail_has_prev:
		_trail_prev_xform = current
		_trail_has_prev = true

	# Призраки спавнятся по ВРЕМЕНИ, а не по кадрам: плотность шлейфа одинакова при любом FPS
	_trail_acc += delta * trail_ghosts_per_second
	var n := int(_trail_acc)
	if n <= 0: return
	_trail_acc -= n

	var tex := sprite.sprite_frames.get_frame_texture(sprite.animation, sprite.frame)
	if not tex: return
	var layer := _get_layer()
	if layer == null: return

	# Прямоугольник отрисовки с учётом centered / offset / flip (одинаков для всех призраков кадра)
	var size := tex.get_size()
	var rect := Rect2(sprite.offset, size)
	if sprite.centered:
		rect.position -= size * 0.5
	if sprite.flip_h:
		rect.position.x += rect.size.x
		rect.size.x = -rect.size.x
	if sprite.flip_v:
		rect.position.y += rect.size.y
		rect.size.y = -rect.size.y

	for i in n:
		var w := float(i + 1) / float(n)
		var xform := _trail_prev_xform.interpolate_with(current, w)
		if classic_trail_enabled:
			var g := layer.take()
			g.tex = tex
			g.rect = rect
			g.ax = xform.x
			g.ay = xform.y
			g.origin = xform.origin
			g.life = classic_trail_lifetime
			g.a0 = classic_trail_alpha * modulate.a
			g.ragged = false
			layer.add(g)
		if ragged_trail_enabled and randf() <= trail_spawn_chance:
			var g := layer.take()
			g.tex = tex
			g.rect = rect
			g.ax = xform.x
			g.ay = xform.y
			g.origin = xform.origin + Vector2(randf_range(-trail_jitter, trail_jitter), randf_range(-trail_jitter, trail_jitter))
			g.life = trail_lifetime * randf_range(1.0 - trail_lifetime_variation, 1.0 + trail_lifetime_variation)
			g.a0 = trail_start_alpha * modulate.a * randf_range(0.6, 1.2)
			g.ragged = true
			g.drift = Vector2(randf_range(-trail_drift_side, trail_drift_side), -trail_drift_up * randf_range(0.4, 1.0))
			g.rot = randf_range(-trail_spin, trail_spin)
			g.end_scale = randf_range(trail_end_scale_min, trail_end_scale_max)
			g.end_color = Color(trail_end_color.r, trail_end_color.g, trail_end_color.b, 0.0)
			layer.add(g)
	_trail_prev_xform = current

## Один слой на материал: рисует ВСЕХ призраков ВСЕХ частиц за один нод
static var _layers: Dictionary = {}

func _get_layer() -> FireTrailLayer:
	if _trail_layer and is_instance_valid(_trail_layer) and _trail_layer.is_inside_tree():
		return _trail_layer
	var key: Variant = sprite.material if sprite.material else &"none"
	var layer = _layers.get(key)
	if layer == null or not is_instance_valid(layer) or not layer.is_inside_tree():
		var scene := get_tree().current_scene
		if scene == null: return null
		layer = FireTrailLayer.new()
		layer.z_index = trail_z_index
		layer.material = sprite.material
		layer.texture_filter = sprite.texture_filter
		scene.add_child(layer)
		_layers[key] = layer
	_trail_layer = layer
	return layer

class TrailGhost:
	var tex: Texture2D
	var rect: Rect2
	var ax: Vector2
	var ay: Vector2
	var origin: Vector2
	var born: float = 0.0
	var life: float = 0.1
	var a0: float = 0.3
	var ragged: bool = false
	var drift: Vector2
	var rot: float = 0.0
	var end_scale: float = 1.0
	var end_color: Color

class FireTrailLayer extends Node2D:
	const MAX_GHOSTS := 6000   # только аварийный предохранитель, в обычной игре не достигается
	var ghosts: Array[TrailGhost] = []
	var pool: Array[TrailGhost] = []
	var time: float = 0.0
	var _had_ghosts: bool = false

	func _init() -> void:
		top_level = true                       # координаты глобальные, не зависят от родителя
		z_as_relative = false
		process_mode = Node.PROCESS_MODE_ALWAYS

	func take() -> TrailGhost:
		return pool.pop_back() if not pool.is_empty() else TrailGhost.new()

	func add(g: TrailGhost) -> void:
		if ghosts.size() >= MAX_GHOSTS:
			pool.append(g)
			return
		g.born = time
		ghosts.append(g)

	func _process(delta: float) -> void:
		time += delta
		var w := 0
		for r in ghosts.size():
			var g := ghosts[r]
			if time - g.born >= g.life:
				if pool.size() < MAX_GHOSTS:
					pool.append(g)
			else:
				ghosts[w] = g
				w += 1
		ghosts.resize(w)
		if w > 0 or _had_ghosts:
			queue_redraw()
		_had_ghosts = w > 0

	func _draw() -> void:
		for g in ghosts:
			var p: float = clampf((time - g.born) / g.life, 0.0, 1.0)
			if not g.ragged:
				# Ровный шлейф: просто линейно тает
				draw_set_transform_matrix(Transform2D(g.ax, g.ay, g.origin))
				draw_texture_rect(g.tex, g.rect, false, Color(1.0, 1.0, 1.0, g.a0 * (1.0 - p)))
			else:
				# Рваный: всплывает/крутится/сжимается (ease-out quad), краснеет и гаснет (ease-in quad)
				var eo := 1.0 - (1.0 - p) * (1.0 - p)
				var ei := p * p
				var f := lerpf(1.0, g.end_scale, eo)
				var t := Transform2D(g.ax, g.ay, Vector2.ZERO).rotated(g.rot * p).scaled(Vector2(f, f))
				t.origin = g.origin + g.drift * eo
				draw_set_transform_matrix(t)
				var c := Color(1.0, 1.0, 1.0, g.a0).lerp(g.end_color, ei)
				draw_texture_rect(g.tex, g.rect, false, c)

# ---------- Урон ----------

func _apply_damage_ticks() -> void:
	if has_overlapping_bodies():
		for body in get_overlapping_bodies():
			_try_burn(body)
	if has_overlapping_areas():
		for area in get_overlapping_areas():
			_try_burn(area)

func _is_ignored(target: Node) -> bool:
	var id := target.get_instance_id()
	if _ignore_cache.has(id):
		return _ignore_cache[id]
	var result := false
	var parent = target.get_parent()
	var lname := target.name.to_lower()
	if target.is_in_group("player") or (parent and parent.is_in_group("player")):
		result = true
	elif "player" in lname:
		result = true
	elif target.is_in_group("bullet") or "bullet" in lname:
		result = true
	if _ignore_cache.size() > 512:
		_ignore_cache.clear()
	_ignore_cache[id] = result
	return result

func _try_burn(target: Node2D) -> void:
	if not target.has_method("take_damage"):
		return
	# Мёртвых (трупы) не жжём: без новых ударов и крови
	if "is_dead" in target and target.is_dead:
		return

	var now := Time.get_ticks_msec() / 1000.0
	var next_tick: float = target.get_meta("fire_next_tick", 0.0)
	if now < next_tick:
		return
	if _is_ignored(target):
		return
	target.set_meta("fire_next_tick", now + tick_interval)

	# Пометка «последний урон был огнём»: враг по ней понимает, что умер от огня
	target.set_meta("fire_last_hit", now)
	target.take_damage(tick_damage * _damage_multiplier())
	if target.has_method("set_on_fire"):
		target.set_on_fire()

	spawn_hit_blood(global_position, velocity.normalized())

func _damage_multiplier() -> float:
	if not sprite or not sprite.sprite_frames or sprite.animation != anim_name:
		return 1.0
	var total := sprite.sprite_frames.get_frame_count(anim_name)
	if sprite.frame >= total - fade_frames:
		return fade_damage_mult
	return 1.0

func _on_body_entered(body: Node2D) -> void:
	if body.has_method("take_damage") or _is_ignored(body):
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

	var scene := get_tree().current_scene
	var back_angle := hit_dir.angle()
	for i in range(blood_back_count):
		var drop = blood_drop_scene.instantiate()
		scene.add_child(drop)
		drop.global_position = hit_pos + hit_dir * randf_range(0.0, 10.0)
		var a := back_angle + randf_range(-_RAD50, _RAD50)
		drop.velocity = Vector2(cos(a), sin(a)) * randf_range(100.0, 400.0)

	var front_angle := back_angle + PI
	for i in range(blood_front_count):
		var drop = blood_drop_scene.instantiate()
		scene.add_child(drop)
		drop.global_position = hit_pos
		var a := front_angle + randf_range(-_RAD70, _RAD70)
		drop.velocity = Vector2(cos(a), sin(a)) * randf_range(50.0, 150.0)
