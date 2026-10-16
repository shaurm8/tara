extends CharacterBody2D

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D

var current_health: int = 1
var is_dead: bool = false

func _ready() -> void:
	if animated_sprite and animated_sprite.sprite_frames and animated_sprite.sprite_frames.has_animation("idle"):
		animated_sprite.play("idle")

func take_damage(damage: int = 35) -> void:
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

	queue_free()
