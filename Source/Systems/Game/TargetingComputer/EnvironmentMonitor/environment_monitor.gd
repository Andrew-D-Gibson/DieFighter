class_name EnvironmentMonitor
extends Node2D
## A small hinged monitor that swings up out of the targeting computer to
## announce the permanent rule of the background the player just arrived in.
##
## Backgrounds are drawn from a random pool, so the player does not pick their
## rule — which means the rule has to announce itself, or "shields do nothing
## here" reads as a bug rather than as the terrain. Rather than a UI badge
## floating in the sky, the warning is a piece of cockpit hardware: it lives
## folded away behind the targeting computer in plain space, so the monitor
## deploying at all is itself information. Its lamp blinks until the rule has
## been read, then stays lit as a reminder the rule is still in force.
##
## Clicking it opens the ordinary InfoShower panel, the same one tiles and
## enemy intents use, so the rule is presented in the vocabulary the player
## already reads everything else in.
##
## The node's origin is the hinge. Everything that moves hangs off %Arm, which
## rises from behind the targeting computer and swings upright about that hinge.

## Shown on the screen when a rule ships no art of its own. White, so it can
## take the rule's colour.
const _DEFAULT_GLYPH: Texture2D = preload(
	"res://Assets/Textures/TargetingComputer/environment_monitor_glyph.png"
)

## Shown on the info panel when a rule ships no art of its own. The panel sits
## on white, so this one carries its own colours instead of being tinted.
const _DEFAULT_INFO_ICON: Texture2D = preload(
	"res://Assets/Textures/TargetingComputer/environment_rule_icon.png"
)

## The unlit lamp: dark glass, not a colour of its own, so the lit state reads
## as the rule's colour switching on.
const _LAMP_OFF: Color = Color(0.22, 0.16, 0.38)

## How far below the hinge the arm sits when stowed — far enough that the whole
## monitor hides behind the targeting computer's body.
@export var stowed_drop: float = 40.0

## The tilt the arm starts its swing from, in degrees. It rises leaning over,
## then swings upright, so it reads as unfolding rather than sliding.
@export var swing_from_degrees: float = -24.0

## One full lamp on/off cycle while the rule is unread, in seconds.
@export var blink_period: float = 0.8

@onready var _arm: Node2D = %Arm
@onready var _lamp: Sprite2D = %Lamp
@onready var _glyph: Sprite2D = %Glyph
@onready var _clickable: Clickable = %Clickable

## The rule on screen right now, or null in plain space.
var _modifier: BackgroundModifierResource = null

var _deployed: bool = false

var _motion_tween: Tween
var _blink_tween: Tween
var _kick_tween: Tween


func _ready() -> void:
	_stow_instantly()
	_clickable.clicked.connect(_on_clicked)
	Events.background_modifier_applied.connect(_on_modifier_applied)
	Events.modifier_triggered.connect(_on_modifier_triggered)


func _on_modifier_applied(modifier: BackgroundModifierResource) -> void:
	_modifier = modifier
	_stop_blinking()

	if modifier == null:
		if _deployed:
			_stow()
		return

	if modifier.icon:
		# Authored art has colours of its own; modulate multiplies, so tinting
		# it would just muddy both.
		_glyph.texture = modifier.icon
		_glyph.modulate = Color.WHITE
	else:
		_glyph.texture = _DEFAULT_GLYPH
		_glyph.modulate = modifier.color

	if _deployed:
		# Already up from the last region: a fresh swing says "new rule"
		# without folding away and back.
		_kick()
	else:
		_deploy()

	# Every arrival is a fresh rule to read, even when the region repeats one
	# the player has seen before, so the monitor always starts unread.
	_start_blinking()


## The rule just bit — a shield gain cancelled, a big hit capped. Jolting the
## monitor then ties the surprise to its cause. An unread monitor is already
## blinking for attention, so it's left to do that.
func _on_modifier_triggered(mod: Modifier) -> void:
	var manager: BackgroundModifierManager = Globals.background_modifier_manager
	if not is_instance_valid(manager) or mod != manager.get_active_modifier():
		return
	if not _deployed or _is_blinking():
		return
	_kick()


## Hands the rule to the shared info panel, which zooms its art up to the
## middle of the screen and dims everything behind it.
func _on_clicked() -> void:
	if _modifier == null:
		return

	_stop_blinking()

	var info: InfoResource = InfoResource.new()
	info.title_label_text = "[color=%s]%s[/color]" % [
		_modifier.color.to_html(false), _modifier.modifier_name.to_upper()
	]
	info.bottom_label_text = _modifier.description
	info.texture = _modifier.icon if _modifier.icon else _DEFAULT_INFO_ICON
	Events.show_info.emit(info)


## Rises out from behind the targeting computer leaning over, then swings
## upright on the hinge and settles with a wobble.
func _deploy() -> void:
	_deployed = true
	show()
	_kill_motion()

	_motion_tween = create_tween().set_parallel()
	_motion_tween.tween_property(_arm, "position:y", 0.0, 0.45) \
		.from(stowed_drop).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_motion_tween.tween_property(_arm, "rotation", 0.0, 0.9) \
		.from(deg_to_rad(swing_from_degrees)).set_delay(0.2) \
		.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	# Not clickable until it has finished arriving, so a click aimed at the
	# targeting computer never lands on a monitor still in transit.
	_motion_tween.chain().tween_callback(_set_clickable.bind(true))


## Leans back over and drops out of sight behind the targeting computer.
func _stow() -> void:
	_deployed = false
	_set_clickable(false)
	_kill_motion()

	_motion_tween = create_tween().set_parallel()
	_motion_tween.tween_property(
		_arm, "rotation", deg_to_rad(swing_from_degrees * 0.6), 0.15
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_motion_tween.tween_property(_arm, "position:y", stowed_drop, 0.3) \
		.set_delay(0.1).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	_motion_tween.chain().tween_callback(hide)


func _stow_instantly() -> void:
	_deployed = false
	_set_clickable(false)
	_arm.position.y = stowed_drop
	_arm.rotation = deg_to_rad(swing_from_degrees)
	hide()


## A knock on the hinge and a flare of the screen.
func _kick() -> void:
	if _kick_tween and _kick_tween.is_valid():
		_kick_tween.kill()
	_kick_tween = create_tween().set_parallel()
	_kick_tween.tween_property(_arm, "rotation", 0.0, 0.6) \
		.from(deg_to_rad(10.0)).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	_kick_tween.tween_property(_glyph, "self_modulate", Color.WHITE, 0.35) \
		.from(Color(2.5, 2.5, 2.5)).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


func _start_blinking() -> void:
	var lit: Color = _modifier.color
	_blink_tween = create_tween().set_loops()
	_blink_tween.tween_callback(_set_lit.bind(lit, true))
	_blink_tween.tween_interval(blink_period * 0.5)
	_blink_tween.tween_callback(_set_lit.bind(lit, false))
	_blink_tween.tween_interval(blink_period * 0.5)


## Leaves the lamp lit and steady: read, but still in force.
func _stop_blinking() -> void:
	if _blink_tween:
		_blink_tween.kill()
		_blink_tween = null
	if _modifier:
		_set_lit(_modifier.color, true)


func _is_blinking() -> bool:
	return _blink_tween != null and _blink_tween.is_valid()


## The screen dims with the lamp so the whole unit reads as flashing, without
## the glyph ever disappearing outright.
func _set_lit(lit_color: Color, lit: bool) -> void:
	_lamp.modulate = lit_color if lit else _LAMP_OFF
	_glyph.self_modulate.a = 1.0 if lit else 0.45


func _set_clickable(clickable: bool) -> void:
	_clickable.input_pickable = clickable
	if not clickable and _clickable.hovered:
		_clickable.reset_hover_state()


func _kill_motion() -> void:
	if _motion_tween and _motion_tween.is_valid():
		_motion_tween.kill()
