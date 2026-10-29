class_name TargetShiftButton
extends Node2D
## One of the two arrow buttons on the targeting computer's flanks that step
## the target to the next ship. They only make sense with a choice to make, so
## the computer keeps them folded away behind its body until a second ship is
## on the roster.
##
## Like the EnvironmentMonitor, they arrive in motion: each slides out from
## behind the body with its tip drooping, then swings level on the hinge where
## its shaft meets the body. They travel pushed in and unlit, a button that
## isn't live yet; once both are out the computer pops them up together (see
## pop_up). Hovering a live button sinks it a pixel and brightens it, and a
## push (click or the target keys) bottoms it out and lets it spring back.
##
## The node's origin is the hinge; everything that moves hangs off %Arm. The
## art faces left; a right-hand button mirrors it.

## Clicked while live. Fired on the press rather than the release, so the
## target changes the moment the cap bottoms out.
signal pushed

## The slide-out has finished, so the button is waiting, still pushed in, to
## be popped up.
signal extended

## Which way the arrow points: -1 for left, 1 for right.
@export_enum("Left:-1", "Right:1") var facing: int = -1

## How far in towards the computer's centre the button sits when stowed: its
## full width, so it hides completely behind the body.
@export var stowed_inset: float = 14.0

## The tilt the arm starts its swing from, in degrees, tip down.
@export var swing_from_degrees: float = 22.0

## How far the cap travels, in pixels: proud of the face when live, flush
## when pushed.
const _TRAVEL: float = 2.0
## A hovered cap gives a little under the finger.
const _HOVER_DEPTH: float = 1.0

## Unlit while it travels: pushed in and dark reads as "not live yet".
const _UNLIT: Color = Color(0.68, 0.68, 0.68)
const _HOVER_LIT: Color = Color(1.18, 1.18, 1.18)

const _HOVER_SFX: SoundEffectResource = preload(
	"res://Source/Resources/SoundEffectResources/SoundEffects/hover_thump.tres"
)
## The same clack as the menu buttons.
const _PUSH_SFX: SoundEffectResource = preload(
	"res://Source/Resources/SoundEffectResources/SoundEffects/tile_dropped.tres"
)

enum State {
	STOWED,
	## Sliding out, or out and pushed in, waiting for pop_up.
	EXTENDING,
	EXTENDED,
	LIVE,
	STOWING,
}

@onready var _arm: Node2D = %Arm
@onready var _visual: Node2D = %Visual
@onready var _cap: Sprite2D = %Cap
@onready var _clickable: Clickable = %Clickable
@onready var _hitbox: CollisionPolygon2D = %Hitbox

var _state: State = State.STOWED

## How far the cap is pushed in: 0 is proud, _TRAVEL is flush. Drawn on whole
## pixels so the cap never smears between rows.
var _depth: float = _TRAVEL:
	set(value):
		_depth = value
		if _cap:
			_cap.position.y = roundf(value)

var _motion_tween: Tween
var _cap_tween: Tween


func _ready() -> void:
	_visual.scale.x = -facing
	# The hitbox is authored for the left-facing art and mirrored here rather
	# than flipped by a negative scale, which physics shapes don't take to.
	if facing > 0:
		var mirrored: PackedVector2Array = PackedVector2Array()
		for point: Vector2 in _hitbox.polygon:
			mirrored.append(Vector2(-point.x, point.y))
		_hitbox.polygon = mirrored
	_clickable.is_hovered.connect(_on_hovered)
	_clickable.input_event.connect(_on_input_event)
	stow_instantly()


func is_out() -> bool:
	return _state == State.EXTENDING or _state == State.EXTENDED or _state == State.LIVE


func is_extended() -> bool:
	return _state == State.EXTENDED or _state == State.LIVE


func is_live() -> bool:
	return _state == State.LIVE


## Slides out from behind the body, pushed in and unlit, then swings level
## and settles with a wobble.
func deploy() -> void:
	if is_out():
		return
	_state = State.EXTENDING
	show()
	_kill_tweens()
	_set_depth(_TRAVEL, _UNLIT)

	var out_x: float = 0.0
	var in_x: float = -facing * stowed_inset
	_motion_tween = create_tween().set_parallel()
	_motion_tween.tween_property(_arm, "position:x", out_x, 0.45) \
		.from(in_x).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_motion_tween.tween_property(_arm, "rotation", 0.0, 0.9) \
		.from(_droop()).set_delay(0.2) \
		.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	_motion_tween.chain().tween_callback(_on_extended)


## Pops the cap up proud and lights it: the button is live. Called once both
## buttons are out, so they come alive together.
func pop_up() -> void:
	if _state != State.EXTENDED:
		return
	_state = State.LIVE
	_kill_cap_tween()
	_cap.modulate = Color.WHITE
	# Springs a pixel past proud before it settles, and flashes as it lights.
	_cap.self_modulate = Color(1.8, 1.8, 1.8)
	_cap_tween = create_tween().set_parallel()
	_cap_tween.tween_property(self, "_depth", -1.0, 0.09) \
		.from(_TRAVEL).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_cap_tween.tween_property(self, "_depth", _rest_depth(), 0.12) \
		.set_delay(0.09).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	_cap_tween.tween_property(_cap, "self_modulate", Color.WHITE, 0.25)
	Events.play_sound.emit(_HOVER_SFX)
	_set_clickable(true)


## Sinks back in, leans over and slides away behind the body.
func stow() -> void:
	if not is_out():
		return
	_state = State.STOWING
	_set_clickable(false)
	_kill_tweens()

	_cap_tween = create_tween().set_parallel()
	_cap_tween.tween_property(self, "_depth", _TRAVEL, 0.08)
	_cap_tween.tween_property(_cap, "modulate", _UNLIT, 0.12)

	_motion_tween = create_tween().set_parallel()
	_motion_tween.tween_property(_arm, "rotation", _droop() * 0.6, 0.15) \
		.set_delay(0.08).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_motion_tween.tween_property(_arm, "position:x", -facing * stowed_inset, 0.3) \
		.set_delay(0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	_motion_tween.chain().tween_callback(_on_stowed)


func stow_instantly() -> void:
	_state = State.STOWED
	_kill_tweens()
	_set_clickable(false)
	_arm.position.x = -facing * stowed_inset
	_arm.rotation = _droop()
	_set_depth(_TRAVEL, _UNLIT)
	hide()


## Bottoms the cap out and lets it spring back: a click, or the target keys
## doing what a click would. Only a live button moves.
func press() -> void:
	if not is_live():
		return
	_kill_cap_tween()
	_depth = _TRAVEL
	_cap.self_modulate = Color.WHITE
	Events.play_sound.emit(_PUSH_SFX)
	_cap_tween = create_tween()
	_cap_tween.tween_interval(0.07)
	_cap_tween.tween_property(self, "_depth", _rest_depth(), 0.16) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _on_input_event(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	if not is_live():
		return
	var click: InputEventMouseButton = event as InputEventMouseButton
	if click and click.pressed and click.button_index == MOUSE_BUTTON_LEFT:
		press()
		pushed.emit()


func _on_hovered(hovered: bool) -> void:
	if not is_live():
		return
	if hovered:
		Events.play_sound.emit(_HOVER_SFX)
	_cap.modulate = _HOVER_LIT if hovered else Color.WHITE
	# A push in progress finishes at the new resting depth on its own.
	if _cap_tween and _cap_tween.is_running():
		return
	_cap_tween = create_tween()
	_cap_tween.tween_property(self, "_depth", _rest_depth(), 0.06)


func _on_extended() -> void:
	_state = State.EXTENDED
	extended.emit()


func _on_stowed() -> void:
	_state = State.STOWED
	hide()


## Where the cap sits when nothing is pushing it.
func _rest_depth() -> float:
	return _HOVER_DEPTH if _clickable.hovered else 0.0


## Tip down, whichever side the button is on.
func _droop() -> float:
	return deg_to_rad(swing_from_degrees) * facing


func _set_depth(depth: float, tint: Color) -> void:
	_depth = depth
	_cap.modulate = tint
	_cap.self_modulate = Color.WHITE


func _set_clickable(clickable: bool) -> void:
	_clickable.input_pickable = clickable
	if not clickable and _clickable.hovered:
		_clickable.reset_hover_state()


func _kill_tweens() -> void:
	if _motion_tween and _motion_tween.is_valid():
		_motion_tween.kill()
	_kill_cap_tween()


func _kill_cap_tween() -> void:
	if _cap_tween and _cap_tween.is_valid():
		_cap_tween.kill()
