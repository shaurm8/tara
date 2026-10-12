extends Camera2D

@export var zoom_speed: float = 2.0
@export var min_zoom: Vector2 = Vector2(0.2, 0.2)
@export var max_zoom: Vector2 = Vector2(10.0, 10.0)

func _process(delta: float) -> void:
	var zoom_change: float = 0.0
	if Input.is_key_pressed(KEY_MINUS) or Input.is_key_pressed(KEY_KP_SUBTRACT):
		zoom_change -= 1.0
	if Input.is_key_pressed(KEY_EQUAL) or Input.is_key_pressed(KEY_PLUS) or Input.is_key_pressed(KEY_KP_ADD):
		zoom_change += 1.0

	if zoom_change != 0.0:
		zoom = (zoom + Vector2.ONE * zoom_change * zoom_speed * delta).clamp(min_zoom, max_zoom)
