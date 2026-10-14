class_name EnvironmentMonitor
extends Node2D
## A small hinged monitor that swings up out of the targeting computer to
## announce what governs the background the player just arrived in: a
## permanent rule (BackgroundModifierResource), or a timed hazard
## (BackgroundHazardResource) with its countdown beside its icon.
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

## The same chime an upgrade tile makes when it fires: the rule paying off is
## the same kind of moment, just working against the player as often as for.
const _TRIGGER_SFX: SoundEffectResource = preload(
	"res://Source/Resources/SoundEffectResources/SoundEffects/upgrade_trigger.tres"
)

## Matches Tile's callout cooldown, so a burst of trips reads as one beat.
const _TRIGGER_COOLDOWN_MSEC: int = 150

## How far over-bright the unit flares when the rule bites.
const _FLARE_BRIGHTNESS: float = 2.2

## Where the callout starts, from the centre of the screen glyph: just above the
## housing, so it rises clear of the monitor.
const _CALLOUT_OFFSET: Vector2 = Vector2(0, -12)

const _COUNTDOWN_FONT: Font = preload("res://Assets/Fonts/m5x7/m5x7.ttf")

## Where the glyph sits on the screen, alone or sharing it with a countdown.
const _GLYPH_CENTRED: Vector2 = Vector2(0, -22)
const _GLYPH_BESIDE_COUNTDOWN: Vector2 = Vector2(-4, -22)
const _COUNTDOWN_POSITION: Vector2 = Vector2(4, -22)

## The countdown ticking down. The last tick before it fires is a heavier one.
const _TICK_SFX: SoundEffectResource = preload(
	"res://Source/Resources/SoundEffectResources/SoundEffects/dice_reroll_blip.tres"
)
const _URGENT_TICK_SFX: SoundEffectResource = preload(
	"res://Source/Resources/SoundEffectResources/SoundEffects/die_dread_thunk.tres"
)

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

## The permanent rule in force right now, or null.
var _modifier: BackgroundModifierResource = null

## The hazard counting down this fight, or null. Shown in preference to a
## rule, though a background only ever carries one of the two.
var _hazard: BackgroundHazardResource = null
var _turns_remaining: int = 0

var _countdown: Label

var _deployed: bool = false

var _motion_tween: Tween
var _blink_tween: Tween
var _kick_tween: Tween
var _flare_tween: Tween
var _countdown_tween: Tween

var _last_trigger_msec: int = -_TRIGGER_COOLDOWN_MSEC


func _ready() -> void:
	_build_countdown()
	_stow_instantly()
	_clickable.clicked.connect(_on_clicked)
	Events.background_modifier_applied.connect(_on_modifier_applied)
	Events.modifier_triggered.connect(_on_modifier_triggered)
	Events.hazard_armed.connect(_on_hazard_armed)
	Events.hazard_countdown_changed.connect(_on_hazard_countdown_changed)
	Events.hazard_triggered.connect(_on_hazard_triggered)
	Events.jump.connect(_on_jump)


func _on_modifier_applied(modifier: BackgroundModifierResource) -> void:
	_modifier = modifier
	_present()


func _on_hazard_armed(hazard: BackgroundHazardResource, turns_remaining: int) -> void:
	_hazard = hazard
	_turns_remaining = turns_remaining
	_present()


## The number going down is the moment the player should look up, so every
## tick flashes the whole unit and pops the digit. The reset after a hazard
## fires counts up, and the firing itself already made the noise.
func _on_hazard_countdown_changed(hazard: BackgroundHazardResource, turns_remaining: int) -> void:
	if hazard != _hazard or not _deployed:
		return
	var ticked_down: bool = turns_remaining < _turns_remaining
	_turns_remaining = turns_remaining
	_update_countdown()
	if not ticked_down:
		# Reset after firing: no longer imminent, so the red alarm blink ends.
		_stop_blinking()
		return

	var color: Color = _current_color()
	Juice.bump(_arm, 0.25, 0.3)
	_kick()
	_flare(color)
	_pop_countdown()
	Events.play_sound.emit(_URGENT_TICK_SFX if _is_urgent() else _TICK_SFX)
	if _is_urgent():
		Juice.ring(self, _glyph.global_position, color, 22.0, 0.4, 8.0)
		_start_blinking()


func _on_hazard_triggered(hazard: BackgroundHazardResource) -> void:
	if hazard != _hazard or not _deployed:
		return
	_play_trigger_feedback(hazard.hazard_name.to_upper(), hazard.color)


## Puts whatever governs this place on the screen — the hazard and its
## countdown, else the permanent rule — or folds away when neither does.
func _present() -> void:
	_stop_blinking()

	if _hazard == null and _modifier == null:
		_countdown.hide()
		if _deployed:
			_stow()
		return

	var icon: Texture2D = _hazard.icon if _hazard else _modifier.icon
	if icon:
		# Authored art has colours of its own; modulate multiplies, so tinting
		# it would just muddy both.
		_glyph.texture = icon
		_glyph.modulate = Color.WHITE
	else:
		_glyph.texture = _DEFAULT_GLYPH
		_glyph.modulate = _hazard.color if _hazard else _modifier.color

	_glyph.position = _GLYPH_BESIDE_COUNTDOWN if _hazard else _GLYPH_CENTRED
	_countdown.visible = _hazard != null
	_update_countdown()

	if _deployed:
		# Already up from the last region: a fresh swing says "new rule"
		# without folding away and back.
		_kick()
	else:
		_deploy()

	# Every arrival is a fresh rule to read, even when the region repeats one
	# the player has seen before, so the monitor always starts unread.
	_start_blinking()


## The old region's rule is meaningless mid-hyperspace, and a lamp blinking
## over the jump reads as a warning about nothing. Stow now; the next
## start_scenario re-announces whatever rule the new region carries, so the
## monitor only comes back when one is actually in force.
func _on_jump() -> void:
	_modifier = null
	_hazard = null
	_present()


## The rule just bit — a shield gain cancelled, damage doubled, a big hit
## capped. The monitor goes off the way an upgrade tile does when it fires, so
## the surprise is tied to its cause. It does so even while still blinking
## unread: the rule biting is exactly when the player most needs to look.
func _on_modifier_triggered(mod: Modifier) -> void:
	var manager: BackgroundModifierManager = Globals.background_modifier_manager
	if not is_instance_valid(manager) or mod != manager.get_active_modifier():
		return
	if not _deployed or _modifier == null:
		return
	_play_trigger_feedback(mod.get_trigger_text(), _modifier.color)


## Squashes on the hinge, flares in the rule's colour and floats a callout
## ("x2", "NO SHIELDS", "SOLAR FLARE") off the top. One chain can trip a rule
## several times over, so the ring, callout and sound are rate-limited; the
## squash and flare still answer every trip.
func _play_trigger_feedback(callout_text: String, color: Color) -> void:
	Juice.bump(_arm, 0.3, 0.35)
	# Mid-deploy the arm's swing belongs to the motion tween.
	if not (_motion_tween and _motion_tween.is_running()):
		_kick()
	_flare(color)

	var now: int = Time.get_ticks_msec()
	if now - _last_trigger_msec < _TRIGGER_COOLDOWN_MSEC:
		return
	_last_trigger_msec = now

	var screen: Vector2 = _glyph.global_position
	Juice.ring(self, screen, color, 22.0, 0.4, 8.0)
	Juice.sparkle(self, screen, color, 10, 45.0)
	if not callout_text.is_empty():
		Juice.callout_at(get_parent(), screen + _CALLOUT_OFFSET, callout_text, color)
	Events.play_sound.emit(_TRIGGER_SFX)


## Floods the whole unit with a bright wash of the rule's colour and lets it
## fade. Snapped on rather than eased in, so it still reads inside a hitstop.
func _flare(color: Color) -> void:
	if _flare_tween and _flare_tween.is_valid():
		_flare_tween.kill()
	var hot: Color = Color.WHITE.lerp(color, 0.4) * _FLARE_BRIGHTNESS
	hot.a = 1.0
	_arm.modulate = hot
	_flare_tween = create_tween()
	_flare_tween.tween_property(_arm, "modulate", Color.WHITE, 0.35) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)


## Hands the rule to the shared info panel, which zooms its art up to the
## middle of the screen and dims everything behind it.
func _on_clicked() -> void:
	if _hazard == null and _modifier == null:
		return

	_stop_blinking()

	var info: InfoResource = InfoResource.new()
	if _hazard:
		info.title_label_text = "[color=%s]%s[/color]" % [
			_hazard.color.to_html(false), _hazard.hazard_name.to_upper()
		]
		info.bottom_label_text = "%s\n%s" % [_hazard.description, _hazard_timing_text()]
		info.texture = _hazard.icon if _hazard.icon else _DEFAULT_INFO_ICON
	else:
		info.title_label_text = "[color=%s]%s[/color]" % [
			_modifier.color.to_html(false), _modifier.modifier_name.to_upper()
		]
		info.bottom_label_text = _modifier.description
		info.texture = _modifier.icon if _modifier.icon else _DEFAULT_INFO_ICON
	Events.show_info.emit(info)


## When the hazard next hits. How often it repeats is left out: once it has
## hit, the reset countdown says that. The last turn is spelled out, because
## "in 1 turn" can't say whether that means as this turn ends or as the next
## one starts.
func _hazard_timing_text() -> String:
	if _turns_remaining <= 1:
		var ends_turn: bool = _hazard.timing == BackgroundHazardResource.Timing.YOUR_TURN_ENDS
		# Both kept under the ~27 characters the panel fits on one line.
		return "Hits as you [color=yellow]end this turn[/color]" if ends_turn \
			else "Hits at [color=yellow]start of next turn[/color]"
	return "Next in [color=yellow]%s[/color]" % _turns_text(_turns_remaining)


static func _turns_text(turns: int) -> String:
	return "1 turn" if turns == 1 else "%d turns" % turns


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
	if _is_blinking():
		_blink_tween.kill()
	var lit: Color = _current_color()
	_blink_tween = create_tween().set_loops()
	_blink_tween.tween_callback(_set_lit.bind(lit, true))
	_blink_tween.tween_interval(blink_period * 0.5)
	_blink_tween.tween_callback(_set_lit.bind(lit, false))
	_blink_tween.tween_interval(blink_period * 0.5)


## Leaves the lamp lit and steady: read, but still in force. A hazard about to
## go off keeps blinking regardless — reading it doesn't make it less imminent.
func _stop_blinking() -> void:
	if _hazard and _is_urgent() and _deployed:
		return
	if _blink_tween:
		_blink_tween.kill()
		_blink_tween = null
	if _hazard or _modifier:
		_set_lit(_current_color(), true)


## The lamp and countdown colour: the hazard's own, red once it is imminent,
## else the rule's.
func _current_color() -> Color:
	if _hazard:
		return Globals.red if _is_urgent() else _hazard.color
	return _modifier.color if _modifier else Color.WHITE


## Imminent hazards turn the countdown red and keep the lamp blinking even once
## read.
func _is_urgent() -> bool:
	return _hazard != null and _turns_remaining <= HazardManager.URGENT_AT


## Built in code like DamageNumber's label, so it can be centred on its own
## measured size and stay on whole pixels.
func _build_countdown() -> void:
	_countdown = Label.new()
	_countdown.add_theme_font_override("font", _COUNTDOWN_FONT)
	_countdown.add_theme_font_size_override("font_size", 16)
	_countdown.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_countdown.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_countdown.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_countdown.text = "0"
	_arm.add_child(_countdown)
	_countdown.reset_size()
	_countdown.pivot_offset = (_countdown.size / 2.0).round()
	_countdown.position = (_COUNTDOWN_POSITION - _countdown.size / 2.0).round()
	_countdown.hide()


func _update_countdown() -> void:
	if _hazard == null:
		return
	# One digit is all the screen has room for, and no authored hazard waits
	# longer than nine turns.
	_countdown.text = str(clampi(_turns_remaining, 0, 9))
	_countdown.add_theme_color_override("font_color", _current_color())


func _pop_countdown() -> void:
	if _countdown_tween and _countdown_tween.is_valid():
		_countdown_tween.kill()
	_countdown.scale = Vector2.ONE * 2.0
	_countdown_tween = create_tween()
	_countdown_tween.tween_property(_countdown, "scale", Vector2.ONE, 0.3) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _is_blinking() -> bool:
	return _blink_tween != null and _blink_tween.is_valid()


## The screen dims with the lamp so the whole unit reads as flashing, without
## the glyph ever disappearing outright.
func _set_lit(lit_color: Color, lit: bool) -> void:
	_lamp.modulate = lit_color if lit else _LAMP_OFF
	_glyph.self_modulate.a = 1.0 if lit else 0.45
	_countdown.self_modulate.a = 1.0 if lit else 0.45


func _set_clickable(clickable: bool) -> void:
	_clickable.input_pickable = clickable
	if not clickable and _clickable.hovered:
		_clickable.reset_hover_state()


func _kill_motion() -> void:
	if _motion_tween and _motion_tween.is_valid():
		_motion_tween.kill()
