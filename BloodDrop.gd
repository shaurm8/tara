extends Node2D

const GRAVITY: float = 422.5

var velocity: Vector2 = Vector2.ZERO
var lifetime: float = 0.0

var is_stuck: bool = false
var timer: float = 0.0

var trail_points: Array = []
const MAX_TRAIL_POINTS: int = 5

enum BloodType { DOT, STREAK, BLOB, DRIP, SPLASH, DROPLET, SPLATTER }
var blood_type: BloodType = BloodType.DOT

var stripe_length: int = 1
var dir_x: int = 1
var dir_y: int = 1
var is_diagonal: bool = false

# Вытянутая ли капля в полете ✨
var is_stretched: bool = false

# Цвет капли во время полета
var flight_color: Color = Color(0.669, 0.032, 0.033, 1.0)

# Финальный цвет капли на стене
var blood_color: Color = Color(0.669, 0.032, 0.033, 1.0)

const SHAPE_TEX_SIZE: int = 8
const SHAPE_ANCHOR: int = 3
var stuck_sprite: Sprite2D = null

func _ready():
	z_index = 10
	
	if randf() < 0.4:
		is_stretched = true
	
	flight_color = Color(randf_range(0.55, 0.8), randf_range(0.01, 0.05), randf_range(0.01, 0.04), 1.0)
	
	if lifetime <= 0.0:
		var min_l = 0.01
		var max_l = 0.15
		lifetime = min_l + (max_l - min_l) * pow(randf(), 2.8)

func _process(delta: float) -> void:
	if is_stuck:
		return

	velocity.y += GRAVITY * delta
	position += velocity * delta

	if trail_points.is_empty() or trail_points.back().distance_to(position) >= 1.06:
		trail_points.append(position)
		if trail_points.size() > MAX_TRAIL_POINTS:
			trail_points.pop_front()

	flight_color = Color(randf_range(0.5, 0.95), randf_range(0.0, 0.08), randf_range(0.0, 0.08), 1.0)

	timer += delta
	queue_redraw()

	if timer >= lifetime:
		stick_to_wall()

func stick_to_wall() -> void:
	is_stuck = true
	trail_points.clear()
	
	if is_stretched:
		blood_type = BloodType.STREAK
		stripe_length = 2
		dir_x = 1 if velocity.x >= 0 else -1
		dir_y = 1 if velocity.y >= 0 else -1
	
	z_index = -1
	
	global_position.x = round(global_position.x / 1.06) * 1.06
	global_position.y = round(global_position.y / 1.06) * 1.06
	
	blood_color = BloodCanvas.register_overlap(global_position)
	
	set_process(false)
	queue_redraw()

	if randf() < 0.25:
		_build_stuck_visual()
		_start_drip_sequence()
	else:
		BloodCanvas.bake_shape(global_position, blood_type, blood_color, dir_x, dir_y, stripe_length, is_diagonal, velocity)
		queue_free()

func _start_drip_sequence() -> void:
	# Пауза перед тем, как капля вообще начнет сползать вниз стала больше ✨
	await get_tree().create_timer(randf_range(2.0, 5.0)).timeout
	
	var steps = randi_range(1, 4)
	for i in range(steps):
		# Медленные задержки между каждым шагом на пиксель вниз, чтобы кровь текла лениво и красиво ❤️
		await get_tree().create_timer(randf_range(3.0, 7.0)).timeout
		
		global_position.y += 1.06

	BloodCanvas.bake_shape(global_position, blood_type, blood_color, dir_x, dir_y, stripe_length, is_diagonal, velocity)
	queue_free()

func _build_stuck_visual() -> void:
	var img := Image.create(SHAPE_TEX_SIZE, SHAPE_TEX_SIZE, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))

	var put := func(offset_x: float, offset_y: float, w: float, h: float) -> void:
		var tx0 := SHAPE_ANCHOR + int(round(offset_x / 1.06))
		var ty0 := SHAPE_ANCHOR + int(round(offset_y / 1.06))
		var tw := maxi(1, int(round(w / 1.06)))
		var th := maxi(1, int(round(h / 1.06)))
		for yy in range(th):
			for xx in range(tw):
				var tx = tx0 + xx
				var ty = ty0 + yy
				if tx >= 0 and ty >= 0 and tx < SHAPE_TEX_SIZE and ty < SHAPE_TEX_SIZE:
					img.set_pixel(tx, ty, blood_color)

	match blood_type:
		BloodType.DOT:
			put.call(0, 0, 1.06, 1.06)
			if randf() > 0.5:
				put.call(dir_x * 1.06, 0, 1.06, 1.06)

		BloodType.STREAK:
			for i in range(stripe_length):
				var offset_x := 0.0
				var offset_y := 0.0
				if is_diagonal:
					offset_x = i * 1.06 * dir_x
					offset_y = i * 1.06 * dir_y
				else:
					if abs(velocity.x) > abs(velocity.y):
						offset_x = i * 1.06 * dir_x
					else:
						offset_y = i * 1.06 * dir_y
				put.call(offset_x, offset_y, 1.06, 1.06)

		BloodType.BLOB:
			put.call(0, 0, 2.11, 1.06)
			put.call(1.06, -1.06, 2.11, 2.11)

		BloodType.DRIP:
			put.call(0, 0, 1.06, 1.06)
			var drip_height = randi_range(1, 2) * 1.06
			put.call(0, 1.06, 1.06, drip_height)

		BloodType.SPLASH:
			put.call(0, 0, 1.06, 1.06)
			put.call(1.06 * dir_x, 0, 1.06, 1.06)
			put.call(0, 1.06 * dir_y, 1.06, 1.06)
			if randf() > 0.5:
				put.call(-1.06 * dir_x, -1.06 * dir_y, 1.06, 1.06)

		BloodType.DROPLET:
			put.call(0, 0, 1.06, 1.06)
			put.call(2.11 * dir_x, 1.06 * dir_y, 1.06, 1.06)

		BloodType.SPLATTER:
			put.call(0, 0, 2.11, 2.11)
			put.call(-1.06, 1.06, 1.06, 1.06)
			put.call(2.11, -1.06, 1.06, 1.06)
			put.call(1.06, 2.11, 1.06, 1.06)

	var tex := ImageTexture.create_from_image(img)

	stuck_sprite = Sprite2D.new()
	stuck_sprite.texture = tex
	stuck_sprite.centered = false
	stuck_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	stuck_sprite.position = Vector2(-SHAPE_ANCHOR * 1.06, -SHAPE_ANCHOR * 1.06)
	stuck_sprite.scale = Vector2(1.06, 1.06)
	add_child(stuck_sprite)

func _draw() -> void:
	if not is_stuck:
		for i in range(trail_points.size()):
			var pt = trail_points[i] - position
			var snap_x = round(pt.x / 1.06) * 1.06
			var snap_y = round(pt.y / 1.06) * 1.06
			draw_rect(Rect2(snap_x, snap_y, 1.06, 1.06), flight_color)
			
			if is_stretched:
				var off_x = 0.0
				var off_y = 0.0
				if abs(velocity.x) >= abs(velocity.y):
					off_x = -1.06 if velocity.x >= 0 else 1.06
				else:
					off_y = -1.06 if velocity.y >= 0 else 1.06
				draw_rect(Rect2(snap_x + off_x, snap_y + off_y, 1.06, 1.06), flight_color)
