extends AnimatedSprite2D

@export var float_speed: float = 500.0

# === ШЛЕЙФ (рисуется одним нодом на всех, от FPS не зависит) ===
@export_group("Шлейф")
@export var trail_enabled: bool = true                # общий выключатель: false = шлейфа нет вообще
@export var trail_ghosts_per_second: float = 60.0     # плотность шлейфа (больше = гуще, но дороже)
@export_range(0.0, 1.0) var trail_start_alpha: float = 0.3
@export var trail_z_offset: int = -1                  # -1 = шлейф лежит чуть позади самого дыма

@export_group("Обычный шлейф (как у топора)")
@export var classic_trail_enabled: bool = true        # ровный шлейф: копия на месте, просто тает
@export var classic_trail_lifetime: float = 0.5
@export_range(0.0, 1.0) var classic_trail_alpha: float = 0.3

@export_group("Рваный шлейф")
@export var ragged_trail_enabled: bool = true         # рваный: призраки всплывают, крутятся, сжимаются
@export var trail_lifetime: float = 0.25
@export_range(0.0, 1.0) var trail_spawn_chance: float = 0.75
@export_range(0.0, 1.0) var trail_lifetime_variation: float = 0.5
@export var trail_jitter: float = 3.0
@export var trail_drift_up: float = 10.0
@export var trail_drift_side: float = 6.0
@export var trail_spin: float = 2.0
@export var trail_end_scale_min: float = 0.35
@export var trail_end_scale_max: float = 0.9
@export var trail_end_color: Color = Color(0.55, 0.55, 0.55)   # к чему темнеет шлейф при угасании (у огня был оранжевый)

var _trail_prev_xform: Transform2D
var _trail_has_prev: bool = false
var _trail_acc: float = 0.0
var _trail_layer: SmokeTrailLayer = null

# Один слой на материал и z-индекс: рисует ВСЕХ призраков ВСЕХ клубов дыма за один нод
static var _layers: Dictionary = {}

func _ready() -> void:
	play("fog")
	animation_finished.connect(_on_animation_finished)

func _process(delta: float) -> void:
	position.y -= float_speed * delta
	if trail_enabled and (classic_trail_enabled or ragged_trail_enabled):
		_update_trail(delta)

func _on_animation_finished() -> void:
	queue_free()

# ---------- Шлейф ----------

func _update_trail(delta: float) -> void:
	if sprite_frames == null:
		return

	var current: Transform2D = global_transform
	if not _trail_has_prev:
		_trail_prev_xform = current
		_trail_has_prev = true

	# Призраки спавнятся по ВРЕМЕНИ, а не по кадрам: плотность шлейфа одинакова при любом FPS
	_trail_acc += delta * trail_ghosts_per_second
	var n := int(_trail_acc)
	if n <= 0:
		return
	_trail_acc -= n

	var tex := sprite_frames.get_frame_texture(animation, frame)
	if tex == null:
		return
	var layer := _get_layer()
	if layer == null:
		return

	# Прямоугольник отрисовки с учётом centered / offset / flip (одинаков для всех призраков кадра)
	var size := tex.get_size()
	var rect := Rect2(offset, size)
	if centered:
		rect.position -= size * 0.5
	if flip_h:
		rect.position.x += rect.size.x
		rect.size.x = -rect.size.x
	if flip_v:
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

func _get_layer() -> SmokeTrailLayer:
	if _trail_layer and is_instance_valid(_trail_layer) and _trail_layer.is_inside_tree():
		return _trail_layer
	var z := z_index + trail_z_offset
	var key := "%s_%s" % [material.get_instance_id() if material else 0, z]
	var layer = _layers.get(key)
	if layer == null or not is_instance_valid(layer) or not layer.is_inside_tree():
		var scene := get_tree().current_scene
		if scene == null:
			return null
		layer = SmokeTrailLayer.new()
		layer.z_index = z
		layer.material = material
		layer.texture_filter = texture_filter
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

class SmokeTrailLayer extends Node2D:
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
				# Рваный: всплывает/крутится/сжимается (ease-out quad), темнеет и гаснет (ease-in quad)
				var eo := 1.0 - (1.0 - p) * (1.0 - p)
				var ei := p * p
				var f := lerpf(1.0, g.end_scale, eo)
				var t := Transform2D(g.ax, g.ay, Vector2.ZERO).rotated(g.rot * p).scaled(Vector2(f, f))
				t.origin = g.origin + g.drift * eo
				draw_set_transform_matrix(t)
				var c := Color(1.0, 1.0, 1.0, g.a0).lerp(g.end_color, ei)
				draw_texture_rect(g.tex, g.rect, false, c)
