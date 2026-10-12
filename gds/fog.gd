extends AnimatedSprite2D

@export var float_speed: float = 500.0

func _ready() -> void:
	play("fog")
	animation_finished.connect(_on_animation_finished)

func _process(delta: float) -> void:
	position.y -= float_speed * delta

func _on_animation_finished() -> void:
	queue_free()
