class_name PlayerHands
extends AnimatedSprite2D
## Руки игрока: прицел, поза, патроны, HUD, трейл, эффекты крови.
## Логика каждого оружия лежит в отдельных скриптах (Weapon и наследники).

const MIN_AIM_DISTANCE: float = 20.0
const AIM_LIMIT: float = deg_to_rad(85.0)
const AIM_FORWARD_OFFSET: float = 3.0

const BLOOD_BURST_COUNT: int = 20
const BLOOD_DROPS_PER_BURST_MIN: int = 70
const BLOOD_DROPS_PER_BURST_MAX: int = 80
const AXE_BLOOD_DROPS_MIN: int = 500
const AXE_BLOOD_DROPS_MAX: int = 600
const HITSTOP_DURATION: float = 0.3

const TRAIL_SPAWN_INTERVAL: float = 0.0
const TRAIL_LIFETIME: float = 0.1
const TRAIL_START_ALPHA: float = 0.3
const TRAIL_GHOSTS_PER_FRAME: int = 3
const TRAIL_Z_INDEX: int = 0

# Порядок в enum должен совпадать с порядком в WEAPON_SCRIPTS (см. _create_weapons)
enum WeaponType { AXE, SAW, SHOTGUN, AK, FLAMETHROWER }

const AMMO_MAX: Dictionary = {
	WeaponType.AXE: 100.0,
	WeaponType.SAW: 100.0,
	WeaponType.SHOTGUN: 24.0,
	WeaponType.AK: 120.0,
	WeaponType.FLAMETHROWER: 100.0,
}

const HUD_MARGIN: int = 8
const HUD_COLOR_NORMAL: Color = Color(1.0, 0.9, 0.2)
const HUD_COLOR_EMPTY: Color = Color(1.0, 0.25, 0.25)
const HUD_OUTLINE_COLOR: Color = Color(0.45, 0.35, 0.0)

@export var bullet_scene: PackedScene
@export var flame_bullet_scene: PackedScene
@export var blood_drop_scene: PackedScene
@export var smoke_scene: PackedScene
@export var thrown_axe_scene: PackedScene
@export var shell_scene: PackedScene   ## сцена гильзы, вылетает при передёргивании дробовика

@export_group("HUD")
@export var hud_panels: Array[Texture2D] = []
@export var hud_font: Font
@export var hud_font_size: int = 16
@export var hud_outline_size: int = 0
@export var hud_scale: float = 1.0
@export var hud_number_rect: Rect2 = Rect2(0, 0, 64, 32)
@export var hud_debug: bool = true
@export_enum("Правый нижний", "Левый нижний", "Правый верхний", "Левый верхний") var hud_corner: int = 0
@export var hud_offset: Vector2 = Vector2(8, 8)
@export_range(0.0, 1.0) var hud_shadow_alpha: float = 0.4
@export var hud_shadow_offset: Vector2 = Vector2(1, 1)
@export_range(0.0, 0.5) var hud_pop_strength: float = 0.18
@export_range(0.0, 1.0) var hud_low_ammo_fraction: float = 0.25

@onready var sprite: AnimatedSprite2D = self
@onready var chainsaw_hitbox: Area2D = get_node_or_null("Hitbox")
@onready var blood_marker: Marker2D = get_node_or_null("BloodMarker")
@onready var muzzle_marker: Marker2D = get_node_or_null("MuzzleMarker")
@onready var eject_marker: Marker2D = get_node_or_null("EjectMarker")

var player
var weapons: Array[Weapon] = []
## При смене оружия вызывает exit() у старого и enter() у нового
var current_weapon: WeaponType = WeaponType.AXE:
	set(value):
		if value == current_weapon: return
		if not weapons.is_empty(): weapons[current_weapon].exit()
		current_weapon = value
		if not weapons.is_empty(): weapons[current_weapon].enter()
var is_axe_thrown: bool = false

var ammo: Dictionary = {}
var _hud_layer: CanvasLayer
var _hud_root: Control
var _hud_panel: TextureRect
var _hud_label: Label
var _hud_debug_rect: ColorRect
var _hud_shadow: TextureRect
var _hud_pop_tween: Tween
var _hud_slide_tween: Tween
var _hud_slide: float = 1.0
var _hud_last_shown: int = -1
var _hud_time: float = 0.0
var _hud_weapon: int = -1

var shoot_cooldown: float = 0.0
var attack_cooldown_timer: float = 0.0

var is_attacking: bool = false
var is_saw_pushing: bool = false

var last_aim_angle: float = 0.0
var attack_swing_rotation: float = 0.0
var chainsaw_shake_time: float = 0.0

var trail_timer: float = 0.0
var trail_prev_xform: Transform2D
var trail_has_prev: bool = false

var origin_position: Vector2 = Vector2.ZERO
var origin_rotation: float = 0.0
var hands_tween: Tween

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	refill_all()
	_build_hud()
	player = _find_player()
	origin_position = position
	origin_rotation = rotation
	_create_weapons()
	if sprite:
		sprite.play(get_weapon().anim_prefix + "normal")
		sprite.speed_scale = 1.0
	if chainsaw_hitbox:
		chainsaw_hitbox.monitoring = false
		chainsaw_hitbox.monitorable = false
		if not chainsaw_hitbox.body_entered.is_connected(_on_chainsaw_body_entered):
			chainsaw_hitbox.body_entered.connect(_on_chainsaw_body_entered)

func _create_weapons() -> void:
	# Порядок строго как в enum WeaponType
	var scripts: Array = [AxeWeapon, SawWeapon, ShotgunWeapon, AkWeapon, FlamethrowerWeapon]
	for i in scripts.size():
		var w: Weapon = scripts[i].new()
		w.name = "Weapon" + str(i)
		add_child(w)
		w.setup(self, i)
		weapons.append(w)

func get_weapon() -> Weapon:
	return weapons[current_weapon]

func _process(delta: float) -> void:
	_update_hud(delta)

func _find_player():
	var n = get_parent()
	while n and not n is CharacterBody2D:
		n = n.get_parent()
	return n

func is_busy() -> bool: return is_attacking or is_saw_pushing

# ---------- Патроны ----------

func refill_all() -> void:
	for w in AMMO_MAX: ammo[w] = AMMO_MAX[w]

func add_ammo(weapon: int, amount: float) -> void:
	ammo[weapon] = minf(AMMO_MAX[weapon], ammo[weapon] + amount)

func spend(weapon: int, cost: float) -> bool:
	if ammo[weapon] < cost: return false
	ammo[weapon] -= cost
	return true

func drain(weapon: int, amount: float) -> void:
	ammo[weapon] = maxf(0.0, ammo[weapon] - amount)

func pick_up_axe() -> void:
	is_axe_thrown = false
	refill_all()
	if current_weapon == WeaponType.AXE and sprite: sprite.play("axe_normal")

# ---------- HUD ----------

func _setup_hud_texture_rect(tr: TextureRect) -> void:
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_SCALE

func _build_hud() -> void:
	_hud_layer = CanvasLayer.new()
	_hud_layer.layer = 100
	_hud_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	_hud_layer.name = "AmmoHudLayer"
	add_child(_hud_layer)

	_hud_root = Control.new()
	_hud_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hud_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_hud_layer.add_child(_hud_root)

	_hud_shadow = TextureRect.new()
	_setup_hud_texture_rect(_hud_shadow)
	_hud_root.add_child(_hud_shadow)

	_hud_panel = TextureRect.new()
	_setup_hud_texture_rect(_hud_panel)
	_hud_root.add_child(_hud_panel)

	_hud_label = Label.new()
	_hud_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hud_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hud_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	if hud_font: _hud_label.add_theme_font_override("font", hud_font)
	_hud_label.add_theme_font_size_override("font_size", int(hud_font_size * hud_scale))
	if hud_outline_size > 0:
		_hud_label.add_theme_constant_override("outline_size", int(hud_outline_size * hud_scale))
		_hud_label.add_theme_color_override("font_outline_color", HUD_OUTLINE_COLOR)
	_hud_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.65))
	_hud_label.add_theme_constant_override("shadow_offset_x", maxi(1, int(round(hud_scale / 2.0))))
	_hud_label.add_theme_constant_override("shadow_offset_y", maxi(1, int(round(hud_scale / 2.0))))
	_hud_panel.add_child(_hud_label)

	_hud_debug_rect = ColorRect.new()
	_hud_debug_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hud_debug_rect.color = Color(1.0, 0.0, 1.0)
	_hud_debug_rect.size = Vector2(40, 40)
	_hud_debug_rect.visible = hud_debug
	_hud_root.add_child(_hud_debug_rect)
	_apply_hud_weapon()

func _apply_hud_weapon() -> void:
	_hud_weapon = int(current_weapon)
	var tex: Texture2D = hud_panels[_hud_weapon] if _hud_weapon < hud_panels.size() else null
	var base_size: Vector2 = tex.get_size() if tex and (tex.get_size().x >= 1.0 and tex.get_size().y >= 1.0) else Vector2(64, 32)
	_hud_panel.texture = tex
	_hud_panel.size = base_size * hud_scale
	_hud_shadow.texture = tex
	_hud_shadow.size = _hud_panel.size
	_hud_label.position = hud_number_rect.position * hud_scale
	_hud_label.size = hud_number_rect.size * hud_scale
	_hud_label.pivot_offset = _hud_label.size / 2.0
	_hud_last_shown = -1
	_hud_slide = 0.0
	kill_tween(_hud_slide_tween)
	_hud_slide_tween = create_tween()
	_hud_slide_tween.tween_property(self, "_hud_slide", 1.0, 0.28).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _update_hud(delta: float) -> void:
	_hud_time += delta
	if not _hud_panel: return
	if _hud_weapon != int(current_weapon): _apply_hud_weapon()

	var vp: Vector2 = get_viewport().get_visible_rect().size
	var right_x: float = vp.x - _hud_panel.size.x - hud_offset.x
	var bottom_y: float = vp.y - _hud_panel.size.y - hud_offset.y
	match hud_corner:
		0: _hud_panel.position = Vector2(right_x, bottom_y)
		1: _hud_panel.position = Vector2(hud_offset.x, bottom_y)
		2: _hud_panel.position = Vector2(right_x, hud_offset.y)
		_: _hud_panel.position = hud_offset
	if _hud_debug_rect:
		_hud_debug_rect.visible = hud_debug
		_hud_debug_rect.position = vp - _hud_debug_rect.size - Vector2.ONE * 2.0

	var slide_dir: float = 1.0 if (hud_corner == 0 or hud_corner == 2) else -1.0
	_hud_panel.position.x += slide_dir * (1.0 - _hud_slide) * _hud_panel.size.x * 0.5
	_hud_panel.modulate.a = clampf(_hud_slide, 0.0, 1.0)
	if _hud_shadow:
		_hud_shadow.size = _hud_panel.size
		_hud_shadow.position = _hud_panel.position + hud_shadow_offset * hud_scale
		_hud_shadow.modulate = Color(0, 0, 0, hud_shadow_alpha * clampf(_hud_slide, 0.0, 1.0))

	var weapon_id: int = int(current_weapon)
	var amount: float = ammo[weapon_id]
	var shown: int = ceili(amount)
	_hud_label.text = str(shown)
	if shown != _hud_last_shown:
		if _hud_last_shown != -1: _hud_pop()
		_hud_last_shown = shown

	var color: Color = HUD_COLOR_NORMAL
	if amount <= 0.0: color = HUD_COLOR_EMPTY
	elif amount <= float(AMMO_MAX[weapon_id]) * hud_low_ammo_fraction:
		color = HUD_COLOR_NORMAL.lerp(HUD_COLOR_EMPTY, 0.5 + 0.5 * sin(_hud_time * 12.0))
	_hud_label.add_theme_color_override("font_color", color)

func _hud_pop() -> void:
	if hud_pop_strength <= 0.0: return
	kill_tween(_hud_pop_tween)
	_hud_label.scale = Vector2.ONE * (1.0 + hud_pop_strength)
	_hud_pop_tween = _hud_label.create_tween()
	_hud_pop_tween.tween_property(_hud_label, "scale", Vector2.ONE, 0.14).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

# ---------- Публичный API ----------

func has_saw_targets() -> bool: return not saw_targets().is_empty()

func on_player_died() -> void:
	for w in weapons: w.on_player_died()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_T: refill_all()
	if not player or player.is_dead or get_tree().paused or not (event is InputEventMouseButton and event.pressed): return
	match event.button_index:
		MOUSE_BUTTON_WHEEL_UP: switch_weapon(1)
		MOUSE_BUTTON_WHEEL_DOWN: switch_weapon(-1)

func is_attack_pressed(just: bool = false) -> bool:
	var saw := current_weapon == WeaponType.SAW
	var action := "pkm" if saw else "lkm"
	var mouse := Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT if saw else MOUSE_BUTTON_LEFT)
	return mouse or (Input.is_action_just_pressed(action) if just else Input.is_action_pressed(action))

func switch_weapon(dir: int = 1) -> void:
	if not is_busy(): current_weapon = posmod(current_weapon + dir, WeaponType.size()) as WeaponType

# ---------- Прицел ----------

func get_aim_angle_local() -> float:
	var parent := get_parent() as Node2D
	if not parent: return 0.0
	var diff = parent.to_local(get_global_mouse_position()) - origin_position
	var target = clampf(diff.angle(), -AIM_LIMIT, AIM_LIMIT)
	last_aim_angle = lerp_angle(last_aim_angle, target, get_physics_process_delta_time() * 25.0) if diff.length() < MIN_AIM_DISTANCE else target
	return last_aim_angle

func local_angle_to_world(local_angle: float) -> float:
	return atan2(sin(local_angle), player.facing * cos(local_angle))

func get_muzzle_position() -> Vector2: return (muzzle_marker if muzzle_marker else self).global_position
## Окно выброса гильз. Если EjectMarker нет в сцене, берём дуло
func get_eject_position() -> Vector2: return (eject_marker if eject_marker else (muzzle_marker if muzzle_marker else self)).global_position
func get_blood_pos(_body: Node2D) -> Vector2: return (blood_marker if blood_marker else self).global_position
func aim_world() -> float: return local_angle_to_world(rotation)

# ---------- Хелперы ----------

func spawn(scene: PackedScene, pos: Vector2):
	var n = scene.instantiate()
	get_tree().current_scene.add_child(n)
	n.global_position = pos
	return n

func saw_targets() -> Array:
	return chainsaw_hitbox.get_overlapping_bodies().filter(func(b): return b != player and b.has_method("take_damage")) if chainsaw_hitbox else []

func shake_offset(amp: float) -> Vector2: return Vector2(sin(chainsaw_shake_time * 1.7), cos(chainsaw_shake_time * 2.3)) * amp
func kill_tween(tween: Tween) -> void: if tween and tween.is_valid(): tween.kill()
func new_tween(old: Tween = null) -> Tween: kill_tween(old); return create_tween().set_pause_mode(Tween.TWEEN_PAUSE_STOP)

func hit_stop(_target: Node = null, duration: float = HITSTOP_DURATION) -> void:
	if _target and (_target.is_in_group("wall") or _target.is_in_group("destructible")): return
	get_tree().paused = true
	await get_tree().create_timer(duration, true, false, true).timeout
	get_tree().paused = false

# ---------- Главный цикл ----------

func _physics_process(delta: float) -> void:
	if get_tree().paused or not player or player.is_dead: return
	_decrement_timers(delta)
	_handle_weapon_inputs(delta)
	_update_animation()
	_update_hands_position(delta)
	_update_trail(delta)

func _decrement_timers(delta: float) -> void:
	shoot_cooldown = maxf(0.0, shoot_cooldown - delta)
	attack_cooldown_timer = maxf(0.0, attack_cooldown_timer - delta)

func _is_active() -> bool: return get_weapon().is_active()

func _handle_weapon_inputs(delta: float) -> void:
	for w in weapons: w.always_update(delta)
	get_weapon().physics_update(delta)

func _update_animation() -> void:
	if not sprite: return
	if current_weapon == WeaponType.AXE and is_axe_thrown:
		if sprite.animation != "axe_empty": sprite.play("axe_empty")
		return
	var anim: String = get_weapon().get_animation_name()
	if sprite.animation != anim: sprite.play(anim)

func _update_hands_position(delta: float) -> void:
	var active := _is_active()
	chainsaw_shake_time += delta * (25.0 if active else 10.0)
	if is_attacking or is_saw_pushing: return
	get_weapon().update_pose(delta)

func reset_hands_position() -> void:
	hands_tween = new_tween(hands_tween)
	hands_tween.tween_property(self, "position", origin_position, 0.1)
	hands_tween.parallel().tween_property(self, "rotation", origin_rotation, 0.1)

func apply_slash_pose(t: float, start_angle: float, end_angle: float, radius: float) -> void:
	attack_swing_rotation = lerp_angle(start_angle, end_angle, t)
	rotation = attack_swing_rotation
	position = origin_position + Vector2.from_angle(attack_swing_rotation) * radius

func _on_chainsaw_body_entered(body: Node2D) -> void:
	if is_saw_pushing or not body.has_method("take_damage"): return
	get_weapon().on_hitbox_body_entered(body)

# ---------- Трейл ----------

func _update_trail(delta: float) -> void:
	var parent := get_parent() as Node2D
	if not sprite or not parent or not (is_attacking or is_saw_pushing):
		trail_timer = 0.0; trail_has_prev = false; return

	var current: Transform2D = parent.global_transform.affine_inverse() * sprite.global_transform
	if not trail_has_prev:
		trail_prev_xform = current
		trail_has_prev = true

	trail_timer -= delta
	if trail_timer > 0.0: return
	trail_timer = TRAIL_SPAWN_INTERVAL

	for i in TRAIL_GHOSTS_PER_FRAME:
		_spawn_trail_ghost(parent, trail_prev_xform.interpolate_with(current, float(i + 1) / float(TRAIL_GHOSTS_PER_FRAME)))
	trail_prev_xform = current

func _spawn_trail_ghost(parent: Node2D, local_xform: Transform2D) -> void:
	if not sprite.sprite_frames: return
	var tex := sprite.sprite_frames.get_frame_texture(sprite.animation, sprite.frame)
	if not tex: return

	var ghost := Sprite2D.new()
	ghost.process_mode = Node.PROCESS_MODE_ALWAYS
	ghost.texture = tex
	ghost.centered = sprite.centered
	ghost.offset = sprite.offset
	ghost.flip_h = sprite.flip_h
	ghost.flip_v = sprite.flip_v
	ghost.material = sprite.material
	ghost.texture_filter = sprite.texture_filter
	ghost.z_as_relative = false
	ghost.z_index = TRAIL_Z_INDEX
	ghost.modulate = Color(1.0, 1.0, 1.0, TRAIL_START_ALPHA)

	parent.add_child(ghost)
	ghost.transform = local_xform

	var tween := ghost.create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.tween_property(ghost, "modulate:a", 0.0, TRAIL_LIFETIME)
	tween.tween_callback(ghost.queue_free)

# ---------- Кровь ----------

func blood_drop(pos: Vector2, center: float, off: float, jit: float, spread_deg: float, speed: float) -> void:
	var drop = spawn(blood_drop_scene, pos + Vector2.from_angle(center) * randf_range(0.0, off) + Vector2(randf_range(-jit, jit), randf_range(-jit, jit)))
	drop.process_mode = Node.PROCESS_MODE_ALWAYS
	drop.velocity = Vector2.from_angle(center + deg_to_rad(randf_range(-spread_deg, spread_deg))) * speed

func spawn_shotgun_hit_blood(hit_pos: Vector2, hit_dir: Vector2) -> void:
	if blood_drop_scene:
		for i in 6: blood_drop(hit_pos, hit_dir.angle(), 0.0, 0.0, 28.0, randf_range(88.0, 246.5))

func spawn_axe_blood(spawn_pos: Vector2, cut_angle: float) -> void:
	if not blood_drop_scene: return
	for i in randi_range(AXE_BLOOD_DROPS_MIN, AXE_BLOOD_DROPS_MAX):
		var roll = randf()
		var speed = randf_range(28.2, 211.3) if roll < 0.25 else (randf_range(211.3, 528.2) if roll < 0.75 else randf_range(528.2, 845.1))
		var dir_roll = randf()
		if dir_roll < 0.55: blood_drop(spawn_pos, cut_angle, 21.1, 1.76, 50.0, speed)
		elif dir_roll < 0.85: blood_drop(spawn_pos, randf() * TAU, 10.0, 1.76, 0.0, speed * 0.6)
		else: blood_drop(spawn_pos, cut_angle + PI, 21.1, 1.76, 35.0, speed * 0.7)

func spawn_chainsaw_blood(spawn_pos: Vector2, cut_angle: float, hitstop_duration: float = HITSTOP_DURATION) -> void:
	if not blood_drop_scene: return
	var center = cut_angle + PI
	var interval = hitstop_duration / float(BLOOD_BURST_COUNT)
	for burst in BLOOD_BURST_COUNT:
		for i in randi_range(BLOOD_DROPS_PER_BURST_MIN, BLOOD_DROPS_PER_BURST_MAX):
			var roll = randf()
			blood_drop(spawn_pos, center, 21.1, 1.76, 30.0, randf_range(28.2, 211.3) if roll < 0.25 else (randf_range(211.3, 528.2) if roll < 0.75 else randf_range(528.2, 845.1)))
		if burst < BLOOD_BURST_COUNT - 1: await get_tree().create_timer(interval, true, false, true).timeout
