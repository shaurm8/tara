class_name PlayerHands
extends AnimatedSprite2D

const MIN_AIM_DISTANCE: float = 20.0
const AIM_LIMIT: float = deg_to_rad(85.0)
const AIM_FORWARD_OFFSET: float = 3.0

const SHOTGUN_FIRE_RATE: float = 0.55
const PELLET_COUNT: int = 7
const SPREAD_ANGLE: float = deg_to_rad(18.0)
const AK_FIRE_RATE: float = 0.09
const AK_SPREAD_ANGLE: float = deg_to_rad(4.0)

const SLASH_ARC_HALF: float = deg_to_rad(58.0)
const SLASH_DURATION: float = 0.20
const SLASH_WINDUP_TIME: float = 0.03
const SLASH_ARC_RADIUS: float = 11.0
const SLASH_DASH_FORCE: float = 260.0
const SLASH_COOLDOWN_PADDING: float = 0.8
const SLASH_HIT_DAMAGE: float = 24.0
const SLASH_HIT_SHAKE_INTENSITY: float = 2.4
const SLASH_HIT_SHAKE_DURATION: float = 0.85
const BLOOD_BURST_COUNT: int = 20
const BLOOD_DROPS_PER_BURST_MIN: int = 70
const BLOOD_DROPS_PER_BURST_MAX: int = 80
const HITSTOP_DURATION: float = 0.3

const SAW_TAP_MAX_TIME: float = 0.15
const SAW_CHARGE_TIME: float = 1.0
const SAW_ULT_DAMAGE_MULT: float = 3.0
const SAW_ULT_ARC_MULT: float = 1.3
const SAW_ULT_RADIUS_MULT: float = 1.15
const SAW_ULT_DASH_MULT: float = 1.15
const SAW_ULT_HITBOX_SCALE: float = 1.2
const SAW_ULT_HITSTOP_DURATION: float = 0.5

const SAW_PUSH_HAND_OFFSET: float = 5.0
const SAW_PUSH_MOVE_SPEED: float = 18.0
const SAW_PUSH_DAMAGE_PER_TICK: float = 6.0
const SAW_PUSH_TICK_INTERVAL: float = 0.006
const SAW_PUSH_BLOOD_DROPS_MIN: int = 35
const SAW_PUSH_BLOOD_DROPS_MAX: int = 40
const SAW_PUSH_SHAKE_INTENSITY: float = 0.5
const SAW_PUSH_SHAKE_DURATION: float = 0.08
const SAW_PUSH_STUCK_TURN_SPEED: float = deg_to_rad(85.0)
const SAW_PUSH_FREE_TURN_SPEED: float = deg_to_rad(1000.0)

const FLAME_FIRE_RATE: float = 0.018
const FLAME_PARTICLES_PER_TICK: int = 2
const FLAME_SPREAD_ANGLE: float = deg_to_rad(13.0)
const FLAME_SPEED_MIN: float = 400.0
const FLAME_SPEED_MAX: float = 650.0
const FLAME_RAMP_UP_TIME: float = 0.12
const FLAME_RAMP_DOWN_TIME: float = 0.15

const AXE_ARC_HALF: float = deg_to_rad(60.0)
const AXE_ARC_RADIUS: float = 16.0
const AXE_WINDUP_EXTRA: float = 0.35
const AXE_TIME_FRACTION: float = 0.85
const AXE_TIME_MIN: float = 0.07
const AXE_TIME_MAX: float = 0.30
const AXE_WINDUP_SHARE: float = 0.2
const AXE_DASH_FORCE: float = 22.0
const AXE_HIT_DAMAGE: float = 24.0
const AXE_STAMINA_COST: float = 4.0
const AXE_COMBO_RESET_TIME: float = 0.4
const AXE_INTERVAL_FULL: float = 0.10
const AXE_INTERVAL_MID: float = 0.18
const AXE_INTERVAL_LOW: float = 0.45
const AXE_INTERVAL_EMPTY: float = 0.9
const AXE_FRAC_MID: float = 0.6
const AXE_FRAC_LOW: float = 0.2
const AXE_REGEN_DELAY: float = 0.5
const AXE_REGEN_DELAY_EMPTY: float = 1.0
const AXE_REGEN_RATE_MIN: float = 4.0
const AXE_REGEN_RATE_MAX: float = 24.0
const AXE_REGEN_RAMP_TIME: float = 3.0
const AXE_SWING_SHAKE_INTENSITY: float = 1.6
const AXE_SWING_SHAKE_DURATION: float = 0.08
const AXE_HIT_SHAKE_INTENSITY: float = 2.0
const AXE_HIT_SHAKE_DURATION: float = 0.15
const AXE_BLOOD_DROPS_MIN: int = 500
const AXE_BLOOD_DROPS_MAX: int = 600

const AXE_THROW_COST: float = 40.0
const AXE_THROW_SPEED: float = 750.0

const TRAIL_SPAWN_INTERVAL: float = 0.0
const TRAIL_LIFETIME: float = 0.1
const TRAIL_START_ALPHA: float = 0.3
const TRAIL_GHOSTS_PER_FRAME: int = 3
const TRAIL_Z_INDEX: int = 0

const WEAPON_PREFIX: Array[String] = ["axe_", "saw_", "shotgun_", "ak_", "flame_"]
enum WeaponType { AXE, SAW, SHOTGUN, AK, FLAMETHROWER }

const AMMO_MAX: Dictionary = {
	WeaponType.AXE: 100.0,
	WeaponType.SAW: 100.0,
	WeaponType.SHOTGUN: 24.0,
	WeaponType.AK: 120.0,
	WeaponType.FLAMETHROWER: 100.0,
}
const SAW_PUSH_COST_PER_SEC: float = 6.0
const SAW_SLASH_COST: float = 8.0
const AK_SHOT_COST: float = 1.0
const SHOTGUN_SHOT_COST: float = 1.0
const FLAME_COST_PER_SEC: float = 10.0

const HUD_MARGIN: int = 8
const HUD_COLOR_NORMAL: Color = Color(1.0, 0.9, 0.2)
const HUD_COLOR_EMPTY: Color = Color(1.0, 0.25, 0.25)
const HUD_OUTLINE_COLOR: Color = Color(0.45, 0.35, 0.0)

@export var bullet_scene: PackedScene
@export var flame_bullet_scene: PackedScene
@export var blood_drop_scene: PackedScene
@export var smoke_scene: PackedScene
@export var thrown_axe_scene: PackedScene

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

var player
var current_weapon: WeaponType = WeaponType.AXE
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
var is_saw_charging: bool = false

var saw_push_damage_timer: float = 0.0
var saw_push_aim_angle: float = 0.0
var saw_charge_time: float = 0.0
var saw_rmb_hold: float = 0.0
var current_attack_is_ult: bool = false
var current_attack_is_axe: bool = false
var flame_heat: float = 0.0

var axe_cooldown_timer: float = 0.0
var axe_time_since_swing: float = 999.0
var axe_next_down: bool = true
var axe_regen_delay_timer: float = 0.0
var axe_regen_time: float = 0.0
var _axe_sweep_prev_t: float = 0.0
var _hitbox_shape_node: CollisionShape2D

var last_aim_angle: float = 0.0
var attack_swing_rotation: float = 0.0
var chainsaw_shake_time: float = 0.0

var trail_timer: float = 0.0
var trail_prev_xform: Transform2D
var trail_has_prev: bool = false

var _hit_bodies_this_attack: Array = []

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
	if sprite:
		sprite.play(WEAPON_PREFIX[current_weapon] + "normal")
		sprite.speed_scale = 1.0
	if chainsaw_hitbox:
		chainsaw_hitbox.monitoring = false
		chainsaw_hitbox.monitorable = false
		if not chainsaw_hitbox.body_entered.is_connected(_on_chainsaw_body_entered):
			chainsaw_hitbox.body_entered.connect(_on_chainsaw_body_entered)

func _process(delta: float) -> void:
	_update_hud(delta)

func _find_player():
	var n = get_parent()
	while n and not n is CharacterBody2D:
		n = n.get_parent()
	return n

func is_busy() -> bool: return is_attacking or is_saw_pushing

func refill_all() -> void:
	for w in AMMO_MAX: ammo[w] = AMMO_MAX[w]

func add_ammo(weapon: int, amount: float) -> void:
	ammo[weapon] = minf(AMMO_MAX[weapon], ammo[weapon] + amount)

func _spend(weapon: int, cost: float) -> bool:
	if ammo[weapon] < cost: return false
	ammo[weapon] -= cost
	return true

func _drain(weapon: int, amount: float) -> void:
	ammo[weapon] = maxf(0.0, ammo[weapon] - amount)

func _has_ammo_for_current() -> bool:
	match current_weapon:
		WeaponType.AXE: return not is_axe_thrown
		WeaponType.SAW: return ammo[WeaponType.SAW] >= SAW_SLASH_COST
		WeaponType.SHOTGUN: return ammo[WeaponType.SHOTGUN] >= SHOTGUN_SHOT_COST
		WeaponType.AK: return ammo[WeaponType.AK] >= AK_SHOT_COST
		_: return ammo[WeaponType.FLAMETHROWER] > 0.0

func pick_up_axe() -> void:
	is_axe_thrown = false
	refill_all()
	if current_weapon == WeaponType.AXE and sprite: sprite.play("axe_normal")

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
	_kill_tween(_hud_slide_tween)
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
	_kill_tween(_hud_pop_tween)
	_hud_label.scale = Vector2.ONE * (1.0 + hud_pop_strength)
	_hud_pop_tween = _hud_label.create_tween()
	_hud_pop_tween.tween_property(_hud_label, "scale", Vector2.ONE, 0.14).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

func has_saw_targets() -> bool: return not _saw_targets().is_empty()
func on_player_died() -> void: _stop_saw_push(); _cancel_saw_charge()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_T: refill_all()
	if not player or player.is_dead or get_tree().paused or not (event is InputEventMouseButton and event.pressed): return
	match event.button_index:
		MOUSE_BUTTON_WHEEL_UP: switch_weapon(1)
		MOUSE_BUTTON_WHEEL_DOWN: switch_weapon(-1)

func _is_attack_pressed(just: bool = false) -> bool:
	var saw := current_weapon == WeaponType.SAW
	var action := "pkm" if saw else "lkm"
	var mouse := Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT if saw else MOUSE_BUTTON_LEFT)
	return mouse or (Input.is_action_just_pressed(action) if just else Input.is_action_pressed(action))

func _is_saw_push_pressed() -> bool:
	return Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) or Input.is_action_pressed("lkm")

func switch_weapon(dir: int = 1) -> void:
	if not is_busy(): current_weapon = posmod(current_weapon + dir, WeaponType.size()) as WeaponType

func get_aim_angle_local() -> float:
	var parent := get_parent() as Node2D
	if not parent: return 0.0
	var diff = parent.to_local(get_global_mouse_position()) - origin_position
	var target = clampf(diff.angle(), -AIM_LIMIT, AIM_LIMIT)
	last_aim_angle = lerp_angle(last_aim_angle, target, get_physics_process_delta_time() * 25.0) if diff.length() < MIN_AIM_DISTANCE else target
	return last_aim_angle

func _local_angle_to_world(local_angle: float) -> float:
	return atan2(sin(local_angle), player.facing * cos(local_angle))

func _get_muzzle_position() -> Vector2: return (muzzle_marker if muzzle_marker else self).global_position
func _get_saw_blood_pos(_body: Node2D) -> Vector2: return (blood_marker if blood_marker else self).global_position
func _aim_world() -> float: return _local_angle_to_world(rotation)

func _spawn(scene: PackedScene, pos: Vector2):
	var n = scene.instantiate()
	get_tree().current_scene.add_child(n)
	n.global_position = pos
	return n

func _saw_targets() -> Array:
	return chainsaw_hitbox.get_overlapping_bodies().filter(func(b): return b != player and b.has_method("take_damage")) if chainsaw_hitbox else []

func _shake_offset(amp: float) -> Vector2: return Vector2(sin(chainsaw_shake_time * 1.7), cos(chainsaw_shake_time * 2.3)) * amp
func _kill_tween(tween: Tween) -> void: if tween and tween.is_valid(): tween.kill()
func _new_tween(old: Tween = null) -> Tween: _kill_tween(old); return create_tween().set_pause_mode(Tween.TWEEN_PAUSE_STOP)

func hit_stop(_target: Node = null, duration: float = HITSTOP_DURATION) -> void:
	if _target and (_target.is_in_group("wall") or _target.is_in_group("destructible")): return
	get_tree().paused = true
	await get_tree().create_timer(duration, true, false, true).timeout
	get_tree().paused = false

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
	axe_cooldown_timer = maxf(0.0, axe_cooldown_timer - delta)
	axe_time_since_swing += delta

func _is_active() -> bool: return is_attacking or is_saw_pushing or (_is_attack_pressed() and _has_ammo_for_current())

func _handle_weapon_inputs(delta: float) -> void:
	_update_axe_stamina(delta)
	_update_flamethrower(delta)

	if current_weapon == WeaponType.SAW:
		_handle_saw_inputs(delta)
		return

	if is_saw_pushing: _stop_saw_push()
	if is_saw_charging: _cancel_saw_charge()

	if current_weapon == WeaponType.AXE:
		if is_axe_thrown: return
		if (Input.is_action_just_pressed("pkm") or Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT)) and ammo[WeaponType.AXE] >= AXE_THROW_COST:
			if _spend(WeaponType.AXE, AXE_THROW_COST):
				_throw_axe()
				return
		if _is_attack_pressed() and axe_cooldown_timer <= 0.0 and not is_attacking: perform_axe_attack()
		return

	if current_weapon == WeaponType.AK and _is_attack_pressed() and shoot_cooldown <= 0.0:
		shoot_ak()
	elif current_weapon == WeaponType.SHOTGUN and _is_attack_pressed(true) and shoot_cooldown <= 0.0 and attack_cooldown_timer <= 0.0:
		shoot_shotgun()

func _throw_axe() -> void:
	is_attacking = true
	var windup_time := 0.08
	var windup_angle := get_aim_angle_local() - AXE_ARC_HALF * (1.0 + AXE_WINDUP_EXTRA)

	hands_tween = _new_tween(hands_tween).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	hands_tween.tween_method(_apply_slash_pose.bind(rotation, windup_angle, AXE_ARC_RADIUS), 0.0, 1.0, windup_time)
	player.body_lean(-0.1 * player.facing, windup_time)
	await hands_tween.finished

	var fresh_aim_local := get_aim_angle_local()
	rotation = fresh_aim_local
	position = origin_position + Vector2.from_angle(fresh_aim_local) * AXE_ARC_RADIUS

	is_axe_thrown = true
	if sprite: sprite.play("axe_empty")

	if thrown_axe_scene:
		var axe_node = _spawn(thrown_axe_scene, _get_muzzle_position())
		if axe_node.has_method("setup"):
			axe_node.setup(player, self, _local_angle_to_world(fresh_aim_local), AXE_THROW_SPEED)

	const FOLLOW_THROUGH_TIME: float = 0.12
	const EXTENDED_RADIUS: float = 35.0
	player.start_shake(6.0, 0.15)
	player.body_lean_strike(0.35 * player.facing, FOLLOW_THROUGH_TIME)

	var throw_pose_angle := fresh_aim_local + AXE_ARC_HALF * 0.4
	hands_tween = _new_tween().set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT).set_parallel(true)
	hands_tween.tween_property(self, "rotation", throw_pose_angle, FOLLOW_THROUGH_TIME)
	hands_tween.tween_property(self, "position", origin_position + Vector2.from_angle(throw_pose_angle) * EXTENDED_RADIUS, FOLLOW_THROUGH_TIME)

	await get_tree().create_timer(FOLLOW_THROUGH_TIME).timeout
	is_attacking = false
	reset_hands_position()

func _handle_saw_inputs(delta: float) -> void:
	var lmb_held: bool = _is_saw_push_pressed() and ammo[WeaponType.SAW] > 0.0
	var rmb_held: bool = _is_attack_pressed() and ammo[WeaponType.SAW] >= SAW_SLASH_COST

	if rmb_held or is_saw_charging or saw_rmb_hold > 0.0:
		if is_saw_pushing: _stop_saw_push()
		if not is_attacking: _handle_saw_charge(delta, rmb_held)
		return

	if lmb_held and not is_attacking: _handle_saw_push(delta)
	elif is_saw_pushing: _stop_saw_push()

func _handle_saw_charge(delta: float, rmb_held: bool) -> void:
	if not is_saw_charging and attack_cooldown_timer > 0.0:
		saw_rmb_hold = 0.0
		return

	if rmb_held:
		saw_rmb_hold += delta
		if saw_rmb_hold >= SAW_TAP_MAX_TIME and not is_saw_charging:
			is_saw_charging = true
			saw_charge_time = 0.0
		if is_saw_charging: saw_charge_time = minf(saw_charge_time + delta, SAW_CHARGE_TIME)
		return

	if is_saw_charging:
		var was_full := saw_charge_time >= SAW_CHARGE_TIME
		is_saw_charging = false
		saw_charge_time = 0.0
		saw_rmb_hold = 0.0
		if was_full: perform_chainsaw_attack_visual(true)
	elif saw_rmb_hold > 0.0 and saw_rmb_hold < SAW_TAP_MAX_TIME:
		saw_rmb_hold = 0.0
		perform_chainsaw_attack_visual(false)
	else:
		saw_rmb_hold = 0.0

func _cancel_saw_charge() -> void:
	is_saw_charging = false; saw_charge_time = 0.0; saw_rmb_hold = 0.0

func _update_animation() -> void:
	if not sprite: return
	if current_weapon == WeaponType.AXE and is_axe_thrown:
		if sprite.animation != "axe_empty": sprite.play("axe_empty")
		return
	var anim: String = WEAPON_PREFIX[current_weapon] + ("attack" if _is_active() else "normal")
	if sprite.animation != anim: sprite.play(anim)

func _update_hands_position(delta: float) -> void:
	var active := _is_active()
	chainsaw_shake_time += delta * (25.0 if active else 10.0)
	if is_attacking or is_saw_pushing: return
	if is_saw_charging:
		_update_charge_pose(delta)
		return

	var aim = get_aim_angle_local()
	var pos = origin_position
	var rot = aim
	if current_weapon == WeaponType.SAW:
		pos += _shake_offset(1.23 if active else 0.35)
		rot += sin(chainsaw_shake_time * 3.1) * deg_to_rad((3.5 if active else 1.0) * 0.8) * 0.3
	else:
		pos += Vector2.from_angle(aim) * AIM_FORWARD_OFFSET

	position = position.lerp(pos, delta * 45.0)
	rotation = lerp_angle(rotation, rot, delta * 50.0)

func _update_charge_pose(delta: float) -> void:
	var t := saw_charge_time / SAW_CHARGE_TIME
	var windup_angle := get_aim_angle_local() - SLASH_ARC_HALF * t
	var target_pos := origin_position + _shake_offset(lerpf(0.35, 3.0, t)) + Vector2.from_angle(windup_angle) * SLASH_ARC_RADIUS * t
	var target_rot := windup_angle + sin(chainsaw_shake_time * 3.1) * deg_to_rad(2.0) * t
	position = position.lerp(target_pos, delta * 15.0)
	rotation = lerp_angle(rotation, target_rot, delta * 18.0)

func reset_hands_position() -> void:
	hands_tween = _new_tween(hands_tween)
	hands_tween.tween_property(self, "position", origin_position, 0.1)
	hands_tween.parallel().tween_property(self, "rotation", origin_rotation, 0.1)

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

func shoot_ak() -> void:
	if _spend(WeaponType.AK, AK_SHOT_COST):
		_fire_weapon(AK_FIRE_RATE, AK_SPREAD_ANGLE, 1, 8.0, 1350.0, 300.0, 2.2, 0.03, 0.06, 0.4, 0.08, 3)

func shoot_shotgun() -> void:
	if _spend(WeaponType.SHOTGUN, SHOTGUN_SHOT_COST):
		_fire_weapon(SHOTGUN_FIRE_RATE, SPREAD_ANGLE, PELLET_COUNT, 12.0, 1232.4, 264.1, 4.93, 0.04, 0.18, 1.2, 0.18, 12)

func _fire_weapon(rate: float, spread: float, pellets: int, damage: float, bullet_speed: float, ray_len: float, recoil: float, out_t: float, back_t: float, shake_i: float, shake_d: float, smoke_count: int) -> void:
	shoot_cooldown = rate
	player.start_shake(shake_i, shake_d)
	var muzzle = _get_muzzle_position()
	var base = _aim_world()

	if smoke_scene:
		var base_dir = Vector2.from_angle(base)
		for j in smoke_count:
			var smoke_pos = muzzle + Vector2(randf_range(-2.0, 3.0), randf_range(5.0, 6.0))
			var smoke = _spawn(smoke_scene, smoke_pos)
			smoke.rotation = randf_range(0.0, TAU)
			smoke.scale = Vector2.ONE
			var final_pos = smoke_pos + base_dir * randf_range(16.0, 42.0) + base_dir.rotated(PI / 2.0) * randf_range(-14.0, 14.0) + Vector2(0.0, -randf_range(14.0, 26.0))
			var duration = randf_range(0.38, 0.65)
			var stween = smoke.create_tween().set_parallel(true)
			stween.tween_property(smoke, "position", final_pos, duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
			stween.tween_property(smoke, "rotation", smoke.rotation + randf_range(-PI, PI), duration)
			stween.tween_property(smoke, "modulate:a", 0.0, duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)

	hands_tween = _new_tween(hands_tween)
	hands_tween.tween_property(self, "position", origin_position - Vector2.from_angle(base) * recoil, out_t).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	hands_tween.tween_property(self, "position", origin_position, back_t).set_trans(Tween.TRANS_SPRING)

	var space = get_world_2d().direct_space_state
	for i in pellets:
		var angle = base + randf_range(-spread / 2.0, spread / 2.0)
		var dir = Vector2.from_angle(angle)
		var pos = muzzle + dir * randf_range(-10.0, 14.0)
		if bullet_scene:
			var bullet = _spawn(bullet_scene, pos)
			bullet.rotation = angle
			if "velocity" in bullet: bullet.velocity = dir * bullet_speed * randf_range(0.88, 1.12)
		else:
			var query = PhysicsRayQueryParameters2D.create(pos, pos + dir * ray_len)
			query.exclude = [player.get_rid()]
			var hit = space.intersect_ray(query)
			if hit and hit.collider.has_method("take_damage"):
				hit.collider.take_damage(damage)
				spawn_shotgun_hit_blood(hit.position, dir)

func spawn_shotgun_hit_blood(hit_pos: Vector2, hit_dir: Vector2) -> void:
	if blood_drop_scene:
		for i in 6: _blood_drop(hit_pos, hit_dir.angle(), 0.0, 0.0, 28.0, randf_range(88.0, 246.5))

func _update_flamethrower(delta: float) -> void:
	var fire: bool = current_weapon == WeaponType.FLAMETHROWER and _is_attack_pressed() and ammo[WeaponType.FLAMETHROWER] > 0.0
	if fire: _drain(WeaponType.FLAMETHROWER, FLAME_COST_PER_SEC * delta)
	flame_heat = clampf(flame_heat + delta / (FLAME_RAMP_UP_TIME if fire else -FLAME_RAMP_DOWN_TIME), 0.0, 1.0)
	if fire and shoot_cooldown <= 0.0: _spawn_flame_burst()

func _spawn_flame_burst() -> void:
	shoot_cooldown = FLAME_FIRE_RATE
	player.start_shake(0.35, 0.06)
	if not flame_bullet_scene: return
	var muzzle = _get_muzzle_position()
	var base = _aim_world()
	var spread = FLAME_SPREAD_ANGLE * lerpf(0.5, 1.0, flame_heat)
	var speed_mult = lerpf(0.4, 1.0, flame_heat)
	var target_scale = Vector2.ONE * lerpf(0.5, 1.0, flame_heat)

	for i in FLAME_PARTICLES_PER_TICK:
		var angle = base + randf_range(-spread / 2.0, spread / 2.0)
		var dir = Vector2.from_angle(angle)
		var bullet = _spawn(flame_bullet_scene, muzzle + dir * randf_range(0.0, 8.0))
		bullet.rotation = angle
		if "velocity" in bullet: bullet.velocity = dir * randf_range(FLAME_SPEED_MIN, FLAME_SPEED_MAX) * speed_mult
		bullet.scale = Vector2.ZERO
		bullet.modulate.a = 0.0
		var tween = bullet.create_tween().set_parallel(true)
		tween.tween_property(bullet, "scale", target_scale, 0.05).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tween.tween_property(bullet, "modulate:a", 1.0, 0.04)

func _axe_interval() -> float:
	var stamina: float = ammo[WeaponType.AXE]
	if stamina <= 0.0: return AXE_INTERVAL_EMPTY
	var f: float = stamina / float(AMMO_MAX[WeaponType.AXE])
	if f >= AXE_FRAC_MID: return lerpf(AXE_INTERVAL_MID, AXE_INTERVAL_FULL, (f - AXE_FRAC_MID) / (1.0 - AXE_FRAC_MID))
	if f >= AXE_FRAC_LOW: return lerpf(AXE_INTERVAL_LOW, AXE_INTERVAL_MID, (f - AXE_FRAC_LOW) / (AXE_FRAC_MID - AXE_FRAC_LOW))
	return AXE_INTERVAL_LOW

func _update_axe_stamina(delta: float) -> void:
	axe_regen_delay_timer = maxf(0.0, axe_regen_delay_timer - delta)
	if axe_regen_delay_timer > 0.0 or ammo[WeaponType.AXE] >= AMMO_MAX[WeaponType.AXE]:
		axe_regen_time = 0.0; return
	axe_regen_time += delta
	add_ammo(WeaponType.AXE, lerpf(AXE_REGEN_RATE_MIN, AXE_REGEN_RATE_MAX, clampf(axe_regen_time / AXE_REGEN_RAMP_TIME, 0.0, 1.0)) * delta)

func perform_axe_attack() -> void:
	is_attacking = true; current_attack_is_axe = true; current_attack_is_ult = false
	_hit_bodies_this_attack.clear()
	var was_empty: bool = ammo[WeaponType.AXE] <= 0.0
	_drain(WeaponType.AXE, AXE_STAMINA_COST)
	axe_regen_delay_timer = AXE_REGEN_DELAY_EMPTY if (was_empty or ammo[WeaponType.AXE] <= 0.0) else AXE_REGEN_DELAY
	axe_regen_time = 0.0; axe_cooldown_timer = _axe_interval()

	if axe_time_since_swing > AXE_COMBO_RESET_TIME: axe_next_down = true
	var is_down: bool = axe_next_down
	axe_next_down = not axe_next_down
	axe_time_since_swing = 0.0

	if chainsaw_hitbox: chainsaw_hitbox.scale = Vector2.ONE
	player.face_mouse()
	var base_angle = get_aim_angle_local()
	attack_swing_rotation = base_angle
	await _perform_axe_slash(base_angle, is_down)

	for b in _saw_targets(): _axe_hit(b)
	if chainsaw_hitbox: chainsaw_hitbox.monitoring = false
	is_attacking = false; current_attack_is_axe = false
	if sprite: sprite.flip_v = false
	reset_hands_position()

func _perform_axe_slash(base_angle: float, is_downward: bool) -> void:
	var total: float = clampf(_axe_interval() * AXE_TIME_FRACTION, AXE_TIME_MIN, AXE_TIME_MAX)
	var windup_time: float = total * AXE_WINDUP_SHARE
	var swing_time: float = total - windup_time
	var arc := AXE_ARC_HALF if is_downward else -AXE_ARC_HALF
	var windup_angle = base_angle - arc * (1.0 + AXE_WINDUP_EXTRA)
	var end_angle = base_angle + arc
	var lean = (0.08 if is_downward else -0.08) * player.facing

	_kill_tween(hands_tween)
	if sprite: sprite.flip_v = not is_downward

	var windup_tween = _new_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	windup_tween.tween_method(_apply_slash_pose.bind(rotation, windup_angle, AXE_ARC_RADIUS), 0.0, 1.0, windup_time)
	player.body_lean(-lean, windup_time)
	await windup_tween.finished

	if chainsaw_hitbox: chainsaw_hitbox.monitoring = true
	player.add_dash(AXE_DASH_FORCE)
	player.start_shake(AXE_SWING_SHAKE_INTENSITY, swing_time)
	player.body_lean_strike(lean, swing_time)

	_axe_sweep_prev_t = 0.0
	var swing_tween = _new_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	swing_tween.tween_method(_axe_swing_step.bind(windup_angle, end_angle, AXE_ARC_RADIUS), 0.0, 1.0, swing_time)
	await swing_tween.finished

func _axe_swing_step(t: float, start_angle: float, end_angle: float, radius: float) -> void:
	var prev_t: float = _axe_sweep_prev_t
	_axe_sweep_prev_t = t
	_apply_slash_pose(t, start_angle, end_angle, radius)
	_axe_sweep(prev_t, t, start_angle, end_angle, radius)

func _get_hitbox_shape_node() -> CollisionShape2D:
	if is_instance_valid(_hitbox_shape_node): return _hitbox_shape_node
	if not chainsaw_hitbox: return null
	for c in chainsaw_hitbox.get_children():
		if c is CollisionShape2D and c.shape:
			_hitbox_shape_node = c
			return c
	return null

func _axe_sweep(t0: float, t1: float, start_angle: float, end_angle: float, radius: float) -> void:
	if not chainsaw_hitbox or not chainsaw_hitbox.monitoring: return
	var shape_node := _get_hitbox_shape_node()
	var parent := get_parent() as Node2D
	if not shape_node or not parent or not player: return

	var params := PhysicsShapeQueryParameters2D.new()
	params.shape = shape_node.shape
	params.collision_mask = chainsaw_hitbox.collision_mask
	params.collide_with_bodies = true
	params.exclude = [player.get_rid()]

	var shape_in_hands: Transform2D = chainsaw_hitbox.transform * shape_node.transform
	var space := get_world_2d().direct_space_state
	for i in range(1, 6):
		var ang: float = lerp_angle(start_angle, end_angle, lerpf(t0, t1, float(i) / 5.0))
		params.transform = parent.global_transform * Transform2D(ang, scale, 0.0, origin_position + Vector2.from_angle(ang) * radius) * shape_in_hands
		for r in space.intersect_shape(params, 16):
			var col = r.get("collider")
			if col is Node2D: _axe_hit(col)

func _axe_hit(body: Node2D) -> void:
	if not is_instance_valid(body) or body == player or not body.has_method("take_damage") or body in _hit_bodies_this_attack: return
	_hit_bodies_this_attack.append(body)
	body.take_damage(AXE_HIT_DAMAGE)
	player.start_shake(AXE_HIT_SHAKE_INTENSITY, AXE_HIT_SHAKE_DURATION)
	spawn_axe_blood(_get_saw_blood_pos(body), _local_angle_to_world(attack_swing_rotation))

func spawn_axe_blood(spawn_pos: Vector2, cut_angle: float) -> void:
	if not blood_drop_scene: return
	for i in randi_range(AXE_BLOOD_DROPS_MIN, AXE_BLOOD_DROPS_MAX):
		var roll = randf()
		var speed = randf_range(28.2, 211.3) if roll < 0.25 else (randf_range(211.3, 528.2) if roll < 0.75 else randf_range(528.2, 845.1))
		var dir_roll = randf()
		if dir_roll < 0.55: _blood_drop(spawn_pos, cut_angle, 21.1, 1.76, 50.0, speed)
		elif dir_roll < 0.85: _blood_drop(spawn_pos, randf() * TAU, 10.0, 1.76, 0.0, speed * 0.6)
		else: _blood_drop(spawn_pos, cut_angle + PI, 21.1, 1.76, 35.0, speed * 0.7)

func perform_chainsaw_attack_visual(is_ult: bool = false) -> void:
	if not _spend(WeaponType.SAW, SAW_SLASH_COST): return
	is_attacking = true; current_attack_is_ult = is_ult
	_hit_bodies_this_attack.clear()
	if chainsaw_hitbox and is_ult: chainsaw_hitbox.scale = Vector2.ONE * SAW_ULT_HITBOX_SCALE
	player.face_mouse()
	var base_angle = get_aim_angle_local()
	attack_swing_rotation = base_angle
	await _perform_slash_attack(base_angle, true, is_ult)

	if chainsaw_hitbox:
		chainsaw_hitbox.monitoring = false
		chainsaw_hitbox.scale = Vector2.ONE
	is_attacking = false; current_attack_is_ult = false
	reset_hands_position()

func _perform_slash_attack(base_angle: float, is_downward: bool, is_ult: bool = false) -> void:
	attack_cooldown_timer = SLASH_DURATION + SLASH_WINDUP_TIME + SLASH_COOLDOWN_PADDING
	var arc_half := SLASH_ARC_HALF * (SAW_ULT_ARC_MULT if is_ult else 1.0)
	var arc := arc_half if is_downward else -arc_half
	var arc_radius := SLASH_ARC_RADIUS * (SAW_ULT_RADIUS_MULT if is_ult else 1.0)
	var lean = (0.12 if is_downward else -0.12) * player.facing

	hands_tween = _new_tween(hands_tween).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	hands_tween.tween_method(_apply_slash_pose.bind(rotation, base_angle - arc, arc_radius), 0.0, 1.0, SLASH_WINDUP_TIME)
	player.body_lean(-lean, SLASH_WINDUP_TIME)
	player.start_shake(1.4, 0.12)
	await get_tree().create_timer(SLASH_WINDUP_TIME, false).timeout

	if chainsaw_hitbox: chainsaw_hitbox.monitoring = true
	player.add_dash(SLASH_DASH_FORCE * (SAW_ULT_DASH_MULT if is_ult else 1.0))
	var swing_tween = _new_tween().set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	swing_tween.tween_method(_apply_slash_pose.bind(base_angle - arc, base_angle + arc, arc_radius), 0.0, 1.0, SLASH_DURATION)
	player.start_shake(4.0 * (1.5 if is_ult else 1.0), SLASH_DURATION)
	player.body_lean_strike(lean, SLASH_DURATION)
	await swing_tween.finished

func _apply_slash_pose(t: float, start_angle: float, end_angle: float, radius: float = SLASH_ARC_RADIUS) -> void:
	attack_swing_rotation = lerp_angle(start_angle, end_angle, t)
	rotation = attack_swing_rotation
	position = origin_position + Vector2.from_angle(attack_swing_rotation) * radius

func _on_chainsaw_body_entered(body: Node2D) -> void:
	if is_saw_pushing or not body.has_method("take_damage"): return
	if current_attack_is_axe:
		_axe_hit(body)
		return
	if body in _hit_bodies_this_attack: return
	_hit_bodies_this_attack.append(body)

	body.take_damage(SLASH_HIT_DAMAGE * (SAW_ULT_DAMAGE_MULT if current_attack_is_ult else 1.0))
	player.start_shake(SLASH_HIT_SHAKE_INTENSITY, SLASH_HIT_SHAKE_DURATION)
	_kill_tween(hands_tween)
	position = origin_position + Vector2.from_angle(attack_swing_rotation) * (SLASH_ARC_RADIUS * (SAW_ULT_RADIUS_MULT if current_attack_is_ult else 1.0))

	var stop_time := SAW_ULT_HITSTOP_DURATION if current_attack_is_ult else HITSTOP_DURATION
	spawn_chainsaw_blood(_get_saw_blood_pos(body), _local_angle_to_world(attack_swing_rotation), stop_time)
	hit_stop(null, stop_time)

func _blood_drop(pos: Vector2, center: float, off: float, jit: float, spread_deg: float, speed: float) -> void:
	var drop = _spawn(blood_drop_scene, pos + Vector2.from_angle(center) * randf_range(0.0, off) + Vector2(randf_range(-jit, jit), randf_range(-jit, jit)))
	drop.process_mode = Node.PROCESS_MODE_ALWAYS
	drop.velocity = Vector2.from_angle(center + deg_to_rad(randf_range(-spread_deg, spread_deg))) * speed

func spawn_chainsaw_blood(spawn_pos: Vector2, cut_angle: float, hitstop_duration: float = HITSTOP_DURATION) -> void:
	if not blood_drop_scene: return
	var center = cut_angle + PI
	var interval = hitstop_duration / float(BLOOD_BURST_COUNT)
	for burst in BLOOD_BURST_COUNT:
		for i in randi_range(BLOOD_DROPS_PER_BURST_MIN, BLOOD_DROPS_PER_BURST_MAX):
			var roll = randf()
			_blood_drop(spawn_pos, center, 21.1, 1.76, 30.0, randf_range(28.2, 211.3) if roll < 0.25 else (randf_range(211.3, 528.2) if roll < 0.75 else randf_range(528.2, 845.1)))
		if burst < BLOOD_BURST_COUNT - 1: await get_tree().create_timer(interval, true, false, true).timeout

func _handle_saw_push(delta: float) -> void:
	if not is_saw_pushing:
		is_saw_pushing = true
		saw_push_damage_timer = 0.0
		saw_push_aim_angle = get_aim_angle_local()
		if chainsaw_hitbox: chainsaw_hitbox.monitoring = true; chainsaw_hitbox.monitorable = true

	_drain(WeaponType.SAW, SAW_PUSH_COST_PER_SEC * delta)
	var stuck = not _saw_targets().is_empty()
	if not stuck: player.face_mouse()

	saw_push_aim_angle = move_toward(saw_push_aim_angle, get_aim_angle_local(), (SAW_PUSH_STUCK_TURN_SPEED if stuck else SAW_PUSH_FREE_TURN_SPEED) * delta)
	if stuck: saw_push_aim_angle += randf_range(-deg_to_rad(4.5), deg_to_rad(4.5))

	chainsaw_shake_time += delta * 25.0
	position = position.lerp(origin_position + _shake_offset(1.23) + Vector2.from_angle(saw_push_aim_angle) * SAW_PUSH_HAND_OFFSET, delta * SAW_PUSH_MOVE_SPEED)
	rotation = lerp_angle(rotation, saw_push_aim_angle + sin(chainsaw_shake_time * 3.1) * deg_to_rad(2.8), delta * SAW_PUSH_MOVE_SPEED)

	saw_push_damage_timer -= delta
	if saw_push_damage_timer <= 0.0:
		saw_push_damage_timer = SAW_PUSH_TICK_INTERVAL
		_apply_saw_push_damage()

func _stop_saw_push() -> void:
	is_saw_pushing = false
	if chainsaw_hitbox: chainsaw_hitbox.monitoring = false
	reset_hands_position()

func _apply_saw_push_damage() -> void:
	for body in _saw_targets():
		body.take_damage(SAW_PUSH_DAMAGE_PER_TICK)
		player.start_shake(SAW_PUSH_SHAKE_INTENSITY, SAW_PUSH_SHAKE_DURATION)
		if blood_drop_scene:
			var center = _local_angle_to_world(saw_push_aim_angle) + PI
			for i in randi_range(SAW_PUSH_BLOOD_DROPS_MIN, SAW_PUSH_BLOOD_DROPS_MAX):
				_blood_drop(_get_saw_blood_pos(body), center, 14.0, 1.5, 32.0, randf_range(120.0, 420.0))
