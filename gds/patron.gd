class_name AmmoPickup
extends Area2D

## Какому оружию добавляются патроны
@export var weapon: PlayerHands.WeaponType = PlayerHands.WeaponType.AK
## Сколько добавляется (в тех же единицах, что и AMMO_MAX: патроны / «бензин» пилы / топливо огнемёта)
@export var amount: float = 30.0
## Если false, пикап не подбирается, пока боезапас этого оружия полон
@export var pickup_when_full: bool = false

func _physics_process(_delta: float) -> void:
	# Проверяем перекрытие каждый кадр, а не по body_entered:
	# так пикап можно подобрать позже, когда боезапас перестанет быть полным.
	for body in get_overlapping_bodies():
		if _try_pickup(body):
			return

func _try_pickup(body: Node2D) -> bool:
	if not body is Player:
		return false
	var player := body as Player
	if player.is_dead or not player.hands:
		return false
	var hands: PlayerHands = player.hands
	if not pickup_when_full and hands.ammo[weapon] >= PlayerHands.AMMO_MAX[weapon]:
		return false
	hands.add_ammo(weapon, amount)
	queue_free()
	return true
