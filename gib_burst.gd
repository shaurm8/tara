class_name GibBurst
extends Node2D
## Рвёт кадр спрайта на неровные кровавые куски (по пикселям).
## Куски летят, отскакивают от пола/стен и ОСТАЮТСЯ лежать.
## Саму кровь (брызги, следы, пятна на стенах) делает ТВОЯ сцена blood_scene — своей крови тут нет.
##
## Использование: GibBurst.spawn(animated_sprite, hit_dir, {"blood_scene": preload("res://blood_drop.tscn")})

# === ОШМЁТКИ ===
var chunk_count: int = 12
var chunk_size_variation: float = 1.0  # 0 = куски примерно равные, 1+ = и крупные, и мелкие ошмётки
var edge_roughness: float = 2.5        # рваность границы между кусками (в пикселях спрайта)
var generated_pieces: int = -1         # сколько сгенерированных кусков оставить (-1 = все, 0 = ни одного)
var custom_textures: Array = []        # твои нарисованные кусочки (Texture2D): каждый вылетает отдельным куском
var custom_copies: int = 1             # сколько раз повторить каждый нарисованный кусочек
var variants_per_frame: int = 4        # сколько вариантов нарезки кэшируется на кадр
var speed_min: float = 150.0
var speed_max: float = 450.0
var gravity: float = 700.0             # 0 = вид сверху
var drag: float = 1.5                  # в виде сверху поставь 3–5
var spin_max: float = 14.0
var upward_bias: float = 120.0
var hit_dir_strength: float = 0.6

# === ПОЛ / СТЕНЫ ===
var world_mask: int = 1                # слои физики, от которых отскакивают куски (только пол и стены!)
var bounce: float = 0.35
var surface_friction: float = 0.4
var rest_speed: float = 45.0
var max_flight_time: float = 3.0       # не упал за это время (улетел в пустоту) — пропадает
var lie_time: float = 0.0              # сколько лежат (0 = навсегда)

# === КРОВЬ (твоя сцена) ===
var blood_scene: PackedScene = null    # твоя сцена капли: ей выставляются global_position и velocity
var blood_scene_count: int = 80        # сколько капель вылетает при взрыве
var blood_land_count: int = 30         # залп крови при первом приземлении куска
var blood_impact_count: int = 10        # поменьше — при последующих отскоках (зависит от силы удара)
var blood_trail_rate: float = 200.0    # капель в секунду с КАЖДОГО летящего куска (больше = гуще, след непрерывный)
var blood_trail_inherit: float = 0.9   # какую долю скорости куска наследуют капли (чтобы летели вместе с ним)
var blood_trail_spread: float = 25.0   # разброс скорости капель: меньше = держатся ближе к куску
var blood_trail_per_piece: int = 400          # сколько капель всего могут «накапать» летящие куски (0 = выкл)
var blood_speed_min: float = 100.0
var blood_speed_max: float = 400.0

# === ВИД КУСКОВ ===
var blood_tint: float = 0.45           # насколько куски пропитаны красным
var blood_color: Color = Color(0.6, 0.02, 0.04)
var edge_color: Color = Color(0.35, 0.0, 0.02)   # тёмно-красная кромка в местах разрыва

static var max_total_pieces: int = 500
static var _bursts: Array = []
static var _cache: Dictionary = {}

class ChunkData:
	var tex: Texture2D
	var center: Vector2   # центр куска в координатах спрайта (px)
	var size: Vector2
	var pixels: int = 0
	var flip: Vector2 = Vector2.ONE

class Piece:
	var tex: Texture2D
	var size: Vector2
	var pos: Vector2
	var vel: Vector2
	var rot: float
	var spin: float
	var scl: Vector2
	var age: float = 0.0
	var settled: bool = false
	var landed: bool = false
	var trail_left: int = 0
	var rad: float = 3.0
	var trail_t: float = 0.0

var _tint: Color = Color.WHITE
var _pieces: Array[Piece] = []
var _trail_left: int = 0
var _fading: bool = false

static func spawn(source: AnimatedSprite2D, hit_dir: Vector2 = Vector2.ZERO, config: Dictionary = {}) -> GibBurst:
	var scene := source.get_tree().current_scene
	if scene == null:
		return null
	var burst := GibBurst.new()
	for key in config:
		burst.set(key, config[key])
	scene.add_child(burst)
	burst._launch(source, hit_dir)
	_enforce_cap()
	return burst

static func _enforce_cap() -> void:
	var alive: Array = []
	var total := 0
	for b in _bursts:
		if is_instance_valid(b) and not b._fading:
			alive.append(b)
			total += b._pieces.size()
	_bursts = alive
	while total > max_total_pieces and _bursts.size() > 1:
		var oldest: GibBurst = _bursts.pop_front()
		total -= oldest._pieces.size()
		oldest.fade_out()

# ---------- Нарезка спрайта на куски ----------

func _get_chunks(src_tex: Texture2D, flip_h: bool, flip_v: bool) -> Array:
	var key := "%s|%s%s|%s|%s|%s|%s|%s|%s" % [src_tex.get_instance_id(), flip_h, flip_v, chunk_count, blood_tint, blood_color.to_html(), edge_color.to_html(), edge_roughness, chunk_size_variation]
	var variants: Array = _cache.get(key, [])
	if variants.size() >= variants_per_frame:
		return variants.pick_random()
	var chunks := _build_chunks(src_tex, flip_h, flip_v)
	if chunks.is_empty():
		return chunks
	if _cache.size() > 48:
		_cache.clear()
	variants.append(chunks)
	_cache[key] = variants
	return chunks

func _build_chunks(src_tex: Texture2D, flip_h: bool, flip_v: bool) -> Array:
	var img := src_tex.get_image()
	if img == null:
		return []
	img = img.duplicate()
	if img.is_compressed():
		img.decompress()
	if img.get_format() != Image.FORMAT_RGBA8:
		img.convert(Image.FORMAT_RGBA8)
	if flip_h: img.flip_x()
	if flip_v: img.flip_y()

	var w := img.get_width()
	var h := img.get_height()
	var opaque := PackedInt32Array()
	for y in h:
		for x in w:
			if img.get_pixel(x, y).a > 0.05:
				opaque.append(y * w + x)
	if opaque.size() < 6:
		return []

	# Центры кусков + «вес» каждого (больше вес = крупнее кусок)
	var n := mini(chunk_count, opaque.size() / 3)
	var seeds := PackedVector2Array()
	var weights := PackedFloat32Array()
	for i in n:
		var idx := opaque[randi() % opaque.size()]
		seeds.append(Vector2(idx % w, idx / w))
		weights.append(maxf(0.4, 1.0 + chunk_size_variation * randf_range(-0.5, 1.5)))

	# Каждый непрозрачный пиксель достаётся ближайшему центру; шум в расстоянии даёт рваную границу
	var ids := PackedInt32Array()
	ids.resize(w * h)
	ids.fill(-1)
	var minx := PackedInt32Array(); minx.resize(n); minx.fill(w)
	var miny := PackedInt32Array(); miny.resize(n); miny.fill(h)
	var maxx := PackedInt32Array(); maxx.resize(n); maxx.fill(-1)
	var maxy := PackedInt32Array(); maxy.resize(n); maxy.fill(-1)
	var counts := PackedInt32Array(); counts.resize(n); counts.fill(0)

	for idx in opaque:
		var px := idx % w
		var py := idx / w
		var p := Vector2(px, py)
		var best := 0
		var best_d := INF
		for i in n:
			var d := p.distance_to(seeds[i]) / weights[i] + randf() * edge_roughness
			if d < best_d:
				best_d = d
				best = i
		ids[idx] = best
		counts[best] += 1
		minx[best] = mini(minx[best], px)
		miny[best] = mini(miny[best], py)
		maxx[best] = maxi(maxx[best], px)
		maxy[best] = maxi(maxy[best], py)

	var blotch := Color(minf(blood_color.r * 1.3, 1.0), minf(blood_color.g * 1.5 + 0.02, 1.0), minf(blood_color.b * 1.5 + 0.02, 1.0))
	var result: Array = []
	for i in n:
		if counts[i] < 2:
			continue
		var cw := maxx[i] - minx[i] + 1
		var ch := maxy[i] - miny[i] + 1
		var cimg := Image.create(cw, ch, false, Image.FORMAT_RGBA8)
		for y in range(miny[i], maxy[i] + 1):
			for x in range(minx[i], maxx[i] + 1):
				if ids[y * w + x] != i:
					continue
				var col := img.get_pixel(x, y)
				var a := col.a
				col = col.lerp(blood_color, blood_tint * 0.6)
				# Кромка там, где кусок оторван от соседнего куска
				var torn := false
				for off in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
					var nx: int = x + off.x
					var ny: int = y + off.y
					if nx >= 0 and ny >= 0 and nx < w and ny < h:
						var nid := ids[ny * w + nx]
						if nid >= 0 and nid != i:
							torn = true
							break
				if torn:
					col = col.lerp(edge_color, 0.7)
				elif randf() < 0.15:
					col = col.lerp(blotch, 0.6)   # пятна свежей крови
				col.a = a
				cimg.set_pixel(x - minx[i], y - miny[i], col)
		var cd := ChunkData.new()
		cd.tex = ImageTexture.create_from_image(cimg)
		cd.size = Vector2(cw, ch)
		cd.center = Vector2(minx[i] + cw * 0.5, miny[i] + ch * 0.5)
		cd.pixels = counts[i]
		result.append(cd)
	return result

# ---------- Запуск ----------

func _launch(source: AnimatedSprite2D, hit_dir: Vector2) -> void:
	top_level = true
	z_as_relative = false
	z_index = source.z_index
	material = source.material
	texture_filter = source.texture_filter
	_bursts.append(self)

	if not source.sprite_frames:
		queue_free()
		return
	var src_tex := source.sprite_frames.get_frame_texture(source.animation, source.frame)
	if src_tex == null:
		queue_free()
		return
	var tex_size := src_tex.get_size()
	var chunks: Array = []
	if generated_pieces != 0:
		# duplicate(), чтобы не портить кэшированный набор
		chunks = _get_chunks(src_tex, source.flip_h, source.flip_v).duplicate()
		if generated_pieces > 0 and chunks.size() > generated_pieces:
			chunks.shuffle()
			chunks.resize(generated_pieces)

	# Нарисованные кусочки: стартуют рядом с центром тела, дальше летят как все
	var body_flip := Vector2(-1.0 if source.flip_h else 1.0, -1.0 if source.flip_v else 1.0)
	for t in custom_textures:
		if t == null:
			continue
		for k in custom_copies:
			var cd := ChunkData.new()
			cd.tex = t
			cd.size = t.get_size()
			cd.center = tex_size * 0.5 + Vector2(randf_range(-0.25, 0.25) * tex_size.x, randf_range(-0.3, 0.3) * tex_size.y)
			cd.pixels = int(cd.size.x * cd.size.y * 0.6)
			cd.flip = body_flip
			chunks.append(cd)

	if chunks.is_empty():
		queue_free()
		return
	_tint = source.modulate * source.self_modulate

	var origin := source.offset
	if source.centered:
		origin -= tex_size * 0.5
	var xf := source.global_transform
	var center := xf * (origin + tex_size * 0.5)
	var piece_scale := xf.get_scale()
	var piece_rot := xf.get_rotation()
	var hd := hit_dir.normalized() if hit_dir != Vector2.ZERO else Vector2.ZERO

	var max_px := 1
	for c in chunks:
		max_px = maxi(max_px, c.pixels)

	for c in chunks:
		var p := Piece.new()
		p.tex = c.tex
		p.size = c.size
		p.scl = piece_scale * c.flip
		p.rot = piece_rot
		p.pos = xf * (origin + c.center)
		var dir := p.pos - center
		if dir.length_squared() < 0.001:
			dir = Vector2.from_angle(randf() * TAU)
		dir = dir.normalized()
		# Крупные куски тяжелее и летят медленнее, мелкие ошмётки — дальше
		var mult := lerpf(1.25, 0.65, float(c.pixels) / float(max_px))
		p.vel = dir * randf_range(speed_min, speed_max) * mult
		p.vel += hd * randf_range(speed_min, speed_max) * hit_dir_strength
		p.vel.y -= randf() * upward_bias
		p.spin = randf_range(-spin_max, spin_max) * mult
		p.trail_t = randf()
		p.trail_left = blood_trail_per_piece
		p.rad = c.size.length() * 0.2 * maxf(piece_scale.x, piece_scale.y)
		_pieces.append(p)

	# Взрыв крови — целиком твоей сценой
	for i in blood_scene_count:
		var v := Vector2.from_angle(randf() * TAU) * randf_range(blood_speed_min, blood_speed_max)
		v += hd * randf_range(blood_speed_min, blood_speed_max) * hit_dir_strength
		_spawn_blood(center + Vector2(randf_range(-0.25, 0.25), randf_range(-0.25, 0.25)) * tex_size, v)

func _spawn_blood(pos: Vector2, vel: Vector2) -> void:
	if blood_scene == null:
		return
	var drop = blood_scene.instantiate()
	get_parent().add_child(drop)
	drop.global_position = pos
	if "velocity" in drop:
		drop.velocity = vel

# ---------- Физика ----------

func _ray(space: PhysicsDirectSpaceState2D, from: Vector2, to: Vector2) -> Dictionary:
	var q := PhysicsRayQueryParameters2D.create(from, to, world_mask)
	q.hit_from_inside = true
	return space.intersect_ray(q)

## Первое приземление куска: залп крови
func _land(p: Piece, n: Vector2) -> void:
	p.landed = true
	_blood_burst(p.pos, n, p.vel, blood_land_count)

## Веер капель от точки удара: от поверхности (по нормали) или во все стороны, если нормали нет (вид сверху)
func _blood_burst(pos: Vector2, n: Vector2, inc_vel: Vector2, count: int) -> void:
	for i in count:
		var dir: Vector2
		if n != Vector2.ZERO:
			dir = n.rotated(randf_range(-1.2, 1.2))
		else:
			dir = Vector2.from_angle(randf() * TAU)
		var spd := randf_range(blood_speed_min, blood_speed_max * 1.2)
		_spawn_blood(pos + n * 2.0, dir * spd + inc_vel * 0.2)

func _settle(p: Piece) -> void:
	p.settled = true
	p.vel = Vector2.ZERO
	p.spin = 0.0

func _physics_process(delta: float) -> void:
	var space := get_world_2d().direct_space_state
	var drag_k := exp(-drag * delta)
	var moving := 0

	var w := 0
	for r in _pieces.size():
		var p := _pieces[r]
		if not p.settled:
			p.age += delta
			if p.age > max_flight_time:
				continue   # улетел в пустоту
			p.vel.y += gravity * delta
			p.vel *= drag_k
			var old_pos := p.pos
			var to := p.pos + p.vel * delta
			var hit := _ray(space, p.pos, to)
			if hit.is_empty():
				p.pos = to
				p.rot += p.spin * delta
			else:
				var n: Vector2 = hit["normal"]
				p.pos = hit["position"] + n
				if n == Vector2.ZERO:
					_land(p, n)
					_settle(p)
				else:
					var impact := absf(p.vel.dot(n))
					var vn := n * p.vel.dot(n)
					var vt := p.vel - vn
					p.vel = vt * (1.0 - surface_friction) - vn * bounce
					p.spin *= 0.5
					if not p.landed:
						_land(p, n)
					elif impact > 120.0:
						_blood_burst(p.pos, n, p.vel, int(blood_impact_count * clampf(impact / 400.0, 0.3, 1.5)))
					if p.vel.length() < rest_speed:
						_settle(p)
			if not p.settled and gravity < 1.0 and p.vel.length() < rest_speed:
				if not p.landed:
					_land(p, Vector2.ZERO)
				_settle(p)

			# Летящий кусок капает кровью (твоей сценой), общий бюджет ограничен
			if not p.settled and p.trail_left > 0:
				# Капли по времени, но раскладываются вдоль пройденного пути — след непрерывный при любой скорости
				p.trail_t += blood_trail_rate * delta
				var cnt := mini(int(p.trail_t), p.trail_left)
				if cnt > 0:
					p.trail_t -= cnt
					p.trail_left -= cnt
					for k in cnt:
						var at := old_pos.lerp(p.pos, float(k + 1) / float(cnt))
						at += Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * p.rad
						var v := p.vel * blood_trail_inherit + Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * blood_trail_spread
						_spawn_blood(at, v)
			if not p.settled:
				moving += 1
		_pieces[w] = p
		w += 1
	_pieces.resize(w)

	queue_redraw()

	if moving == 0:
		set_physics_process(false)
		_on_finished()

func _on_finished() -> void:
	if _pieces.is_empty():
		queue_free()
		return
	if lie_time > 0.0 and not _fading:
		var tw := create_tween()
		tw.tween_interval(lie_time)
		tw.tween_callback(fade_out)

func fade_out(duration: float = 1.0) -> void:
	if _fading:
		return
	_fading = true
	set_physics_process(false)
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 0.0, duration)
	tw.tween_callback(queue_free)

func _exit_tree() -> void:
	_bursts.erase(self)

func _draw() -> void:
	for p in _pieces:
		draw_set_transform(p.pos, p.rot, p.scl)
		draw_texture(p.tex, -p.size * 0.5, _tint)
