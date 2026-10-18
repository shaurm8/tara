class_name Weapon
extends Node
## Базовый класс оружия. Живёт дочерним узлом PlayerHands.
## Общее состояние (патроны, прицел, твины, хитбокс) лежит в PlayerHands и доступно через `hands`.

var hands: PlayerHands
var type: int = 0
var anim_prefix: String = ""

var player:
	get:
		return hands.player

func setup(p_hands: PlayerHands, p_type: int) -> void:
	hands = p_hands
	type = p_type

## Вызывается каждый физ-кадр у ВСЕХ оружий (регенерация, остывание и т.п.)
func always_update(_delta: float) -> void:
	pass

## Вызывается каждый физ-кадр только у текущего оружия (ввод)
func physics_update(_delta: float) -> void:
	pass

## Поза рук, когда оружие не атакует. Вызывается только у текущего оружия.
func update_pose(delta: float) -> void:
	var aim := hands.get_aim_angle_local()
	var pos := hands.origin_position + Vector2.from_angle(aim) * PlayerHands.AIM_FORWARD_OFFSET
	hands.position = hands.position.lerp(pos, delta * 45.0)
	hands.rotation = lerp_angle(hands.rotation, aim, delta * 50.0)

func has_ammo() -> bool:
	return hands.ammo[type] > 0.0

func is_active() -> bool:
	return hands.is_attacking or (hands.is_attack_pressed() and has_ammo())

## Какую анимацию играть сейчас. Оружие может переопределить (например, передёргивание цевья).
func get_animation_name() -> String:
	return anim_prefix + ("attack" if is_active() else "normal")

func enter() -> void:
	pass

func exit() -> void:
	pass

func on_player_died() -> void:
	pass

func on_hitbox_body_entered(_body: Node2D) -> void:
	pass
