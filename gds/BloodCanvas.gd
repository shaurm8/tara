extends Node2D

const PIXEL: float = 1.06
const CHUNK_PIXELS: int = 128
const CHUNK_SIZE_WORLD: float = CHUNK_PIXELS * PIXEL

enum BloodType { DOT, STREAK, BLOB, DRIP, SPLASH, DROPLET, SPLATTER }

class ChunkData:
	var image: Image
	var texture: ImageTexture
	var sprite: Sprite2D
	var counts: PackedByteArray
	var dirty: bool = false

var chunks: Dictionary = {} # Vector2i -> ChunkData

# Перевод мировой позиции в целочисленные координаты сетки
func _world_to_grid(pos: Vector2) -> Vector2i:
	return Vector2i(int(round(pos.x / PIXEL)), int(round(pos.y / PIXEL)))

# Координаты чанка по целочисленной сетке
func _grid_to_chunk(grid_pos: Vector2i) -> Vector2i:
	return Vector2i(
		int(floor(float(grid_pos.x) / CHUNK_PIXELS)),
		int(floor(float(grid_pos.y) / CHUNK_PIXELS))
	)

# Точный локальный пиксель внутри чанка (0..127) без погрешностей float
func _grid_to_local_px(grid_pos: Vector2i) -> Vector2i:
	return Vector2i(
		posmod(grid_pos.x, CHUNK_PIXELS),
		posmod(grid_pos.y, CHUNK_PIXELS)
	)

func _get_chunk(coord: Vector2i) -> ChunkData:
	if chunks.has(coord):
		return chunks[coord]

	var cd := ChunkData.new()
	cd.image = Image.create(CHUNK_PIXELS, CHUNK_PIXELS, false, Image.FORMAT_RGBA8)
	cd.image.fill(Color(0, 0, 0, 0))
	cd.texture = ImageTexture.create_from_image(cd.image)
	cd.counts = PackedByteArray()
	cd.counts.resize(CHUNK_PIXELS * CHUNK_PIXELS)

	var spr := Sprite2D.new()
	spr.texture = cd.texture
	spr.centered = false
	# Фильтр убирает щели и размытие на стыках чанков ✨
	spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	spr.position = Vector2(coord.x * CHUNK_SIZE_WORLD, coord.y * CHUNK_SIZE_WORLD)
	spr.scale = Vector2(PIXEL, PIXEL)
	spr.z_index = -1
	add_child(spr)
	cd.sprite = spr

	chunks[coord] = cd
	return cd

func register_overlap(world_pos: Vector2) -> Color:
	var grid_pos = _world_to_grid(world_pos)
	var chunk_coord = _grid_to_chunk(grid_pos)
	var cd = _get_chunk(chunk_coord)

	var local = _grid_to_local_px(grid_pos)
	var idx = local.y * CHUNK_PIXELS + local.x

	var overlap = cd.counts[idx]
	if overlap < 255:
		cd.counts[idx] = overlap + 1

	if overlap == 0:
		return Color(0.669, 0.032, 0.033, 0.7)
	elif overlap == 1:
		return Color(0.669, 0.032, 0.033, 1.0)
	else:
		return Color(0.42, 0.015, 0.015, 1.0)

# Запекаем пиксель и сразу обновляем его наслоение в массиве counts ✨
func _bake_pixel_grid(grid_pos: Vector2i) -> int:
	var chunk_coord = _grid_to_chunk(grid_pos)
	var cd = _get_chunk(chunk_coord)
	var local = _grid_to_local_px(grid_pos)
	var idx = local.y * CHUNK_PIXELS + local.x

	var overlap = cd.counts[idx]
	if overlap < 255:
		overlap += 1
		cd.counts[idx] = overlap

	var color: Color
	if overlap == 1:
		color = Color(0.669, 0.032, 0.033, 0.7)
	elif overlap == 2:
		color = Color(0.669, 0.032, 0.033, 1.0)
	else:
		color = Color(0.42, 0.015, 0.015, 1.0) # Самый густой бордовый цвет! ❤️

	cd.image.set_pixel(local.x, local.y, color)
	cd.dirty = true
	return overlap

# Быстрая проверка перекрытия без изменения данных
func get_overlap(world_pos: Vector2) -> int:
	var grid_pos = _world_to_grid(world_pos)
	var chunk_coord = _grid_to_chunk(grid_pos)
	var cd = _get_chunk(chunk_coord)
	var local = _grid_to_local_px(grid_pos)
	return cd.counts[local.y * CHUNK_PIXELS + local.x]

# Теперь bake_rect сам определяет цвет каждого пикселя
func bake_rect(world_pos: Vector2, rect_offset: Vector2, size: Vector2, _dummy_color: Color = Color.WHITE) -> void:
	var start_grid = _world_to_grid(world_pos + rect_offset)
	var w = maxi(1, int(round(size.x / PIXEL)))
	var h = maxi(1, int(round(size.y / PIXEL)))
	for yy in range(h):
		for xx in range(w):
			_bake_pixel_grid(start_grid + Vector2i(xx, yy))

func bake_shape(world_pos: Vector2, blood_type: int, color: Color, dir_x: int, dir_y: int, stripe_length: int, is_diagonal: bool, vel: Vector2) -> void:
	match blood_type:
		BloodType.DOT:
			bake_rect(world_pos, Vector2(0, 0), Vector2(PIXEL, PIXEL), color)
			if randf() > 0.5:
				bake_rect(world_pos, Vector2(dir_x * PIXEL, 0), Vector2(PIXEL, PIXEL), color)

		BloodType.STREAK:
			for i in range(stripe_length):
				var offset_x := 0.0
				var offset_y := 0.0
				if is_diagonal:
					offset_x = i * PIXEL * dir_x
					offset_y = i * PIXEL * dir_y
				else:
					if abs(vel.x) > abs(vel.y):
						offset_x = i * PIXEL * dir_x
					else:
						offset_y = i * PIXEL * dir_y
				bake_rect(world_pos, Vector2(offset_x, offset_y), Vector2(PIXEL, PIXEL), color)

		BloodType.BLOB:
			bake_rect(world_pos, Vector2(0, 0), Vector2(PIXEL * 2, PIXEL), color)
			bake_rect(world_pos, Vector2(PIXEL, -PIXEL), Vector2(PIXEL * 2, PIXEL * 2), color)

		BloodType.DRIP:
			bake_rect(world_pos, Vector2(0, 0), Vector2(PIXEL, PIXEL), color)
			var drip_height = randi_range(1, 2) * PIXEL
			bake_rect(world_pos, Vector2(0, PIXEL), Vector2(PIXEL, drip_height), color)

		BloodType.SPLASH:
			bake_rect(world_pos, Vector2(0, 0), Vector2(PIXEL, PIXEL), color)
			bake_rect(world_pos, Vector2(PIXEL * dir_x, 0), Vector2(PIXEL, PIXEL), color)
			bake_rect(world_pos, Vector2(0, PIXEL * dir_y), Vector2(PIXEL, PIXEL), color)
			if randf() > 0.5:
				bake_rect(world_pos, Vector2(-PIXEL * dir_x, -PIXEL * dir_y), Vector2(PIXEL, PIXEL), color)

		BloodType.DROPLET:
			bake_rect(world_pos, Vector2(0, 0), Vector2(PIXEL, PIXEL), color)
			bake_rect(world_pos, Vector2(PIXEL * 2 * dir_x, PIXEL * dir_y), Vector2(PIXEL, PIXEL), color)

		BloodType.SPLATTER:
			bake_rect(world_pos, Vector2(0, 0), Vector2(PIXEL * 2, PIXEL * 2), color)
			bake_rect(world_pos, Vector2(-PIXEL, PIXEL), Vector2(PIXEL, PIXEL), color)
			bake_rect(world_pos, Vector2(PIXEL * 2, -PIXEL), Vector2(PIXEL, PIXEL), color)
			bake_rect(world_pos, Vector2(PIXEL, PIXEL * 2), Vector2(PIXEL, PIXEL), color)

func _process(_delta: float) -> void:
	for cd in chunks.values():
		if cd.dirty:
			cd.texture.update(cd.image)
			cd.dirty = false
