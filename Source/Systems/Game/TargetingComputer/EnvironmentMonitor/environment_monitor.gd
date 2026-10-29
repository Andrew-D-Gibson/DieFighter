class_name EnvironmentMonitor
extends Node2D
## A hinged monitor that swings up out of the targeting computer when the
## player arrives in a region whose background has a rule
## (BackgroundModifierResource) or a timed hazard (BackgroundHazardResource).
## Backgrounds are random, so the rule has to announce itself or it reads as a
## bug. It stays folded away in plain space, its lamp blinks until clicked
## (which opens the usual InfoShower panel), then stays lit while the player is
## in the region. Unless the player turned them off, a RegionAlert card spells
## the rule out on arrival: it unfolds out of the screen once the monitor is
## up, ahead of the ships (the first beat of the ArrivalIntro), and folds back
## in, which counts as read. A hazard only counts down during a fight, so its
## countdown shows only while one is on.
##
## The node's origin is the hinge; everything that moves hangs off %Arm.

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

const _COUNTDOWN_FONT: Font = preload("res://Assets/Fonts/m5x7/m5x7_ui.tres")

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

## The region's timed hazard, or null. Shown in preference to a rule, though a
## background only ever carries one of the two.
var _hazard: BackgroundHazardResource = null
## True while a fight has the hazard counting down. Outside one it is shown
## without a number: a warning of what a fight here will bring.
var _armed: bool = false
var _turns_remaining: int = 0

## Between arriving in a region and jumping out of it. A background swapped in
## hyperspace waits for the arrival to be announced.
var _in_region: bool = false

## What the screen is showing, so a fight starting or ending in the same region
## updates the countdown instead of announcing the rule all over again.
var _shown: Resource = null
var _shown_armed: bool = false
## The lamp blinks until the player clicks to read what's shown.
var _unread: bool = false
## Arrival fires several signals in one go (the rule applied, the region
## entered, a fight starting); they're answered as one present.
var _present_queued: bool = false

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
	ArrivalIntro.shared()
	_clickable.clicked.connect(_on_clicked)
	Events.background_modifier_applied.connect(_on_modifier_applied)
	Events.modifier_triggered.connect(_on_modifier_triggered)
	Events.hazard_armed.connect(_on_hazard_armed)
	Events.hazard_countdown_changed.connect(_on_hazard_countdown_changed)
	Events.hazard_triggered.connect(_on_hazard_triggered)
	Events.start_scenario.connect(_on_arrival)
	Events.background_changed.connect(_on_background_changed)
	Events.jump.connect(_on_jump)


func _on_modifier_applied(modifier: BackgroundModifierResource) -> void:
	_modifier = modifier
	_queue_present()


## The hazard is the region's, not the fight's, so it goes up as the player
## arrives, whether or not anyone is shooting yet.
func _on_arrival() -> void:
	_in_region = true
	_hazard = _region_hazard()
	_queue_present()


## A background swapped in place (dev console, scripted sequences) brings its
## own hazard. HazardManager re-arms a live fight for it, so only a change of
## hazard drops the countdown here.
func _on_background_changed(background: BackgroundResource) -> void:
	if not _in_region:
		return
	var hazard: BackgroundHazardResource = background.hazard if background else null
	if hazard != _hazard:
		_hazard = hazard
		_armed = false
	_queue_present()


## A null hazard is the fight ending (or never arming): the countdown goes, but
## the region's hazard stays on show until the player leaves.
func _on_hazard_armed(hazard: BackgroundHazardResource, turns_remaining: int) -> void:
	_armed = hazard != null
	if hazard:
		_hazard = hazard
		_turns_remaining = turns_remaining
	_queue_present()


func _region_hazard() -> BackgroundHazardResource:
	var manager: BackgroundManager = Globals.background_manager
	if not is_instance_valid(manager) or manager.current_background == null:
		return null
	return manager.current_background.hazard


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
		_refresh_blink()
		return

	var color: Color = _current_color()
	Juice.bump(_arm, 0.25, 0.3)
	_kick()
	_flare(color)
	_pop_countdown()
	Events.play_sound.emit(_URGENT_TICK_SFX if _is_urgent() else _TICK_SFX)
	if _is_urgent():
		Juice.ring(self, _glyph.global_position, color, 22.0, 0.4, 8.0)
		_refresh_blink()


func _on_hazard_triggered(hazard: BackgroundHazardResource) -> void:
	if hazard != _hazard or not _deployed:
		return
	_play_trigger_feedback(hazard.hazard_name.to_upper(), hazard.color)


func _queue_present() -> void:
	if _present_queued:
		return
	_present_queued = true
	_present.call_deferred()


## Puts whatever governs this place on the screen — the hazard (and its
## countdown, during a fight), else the permanent rule — or folds away when
## neither does.
func _present() -> void:
	_present_queued = false
	# A rule can be applied while still in hyperspace (the engine for the new
	# region exists before the jump out finishes); it waits for the arrival.
	var shown: Resource = null
	if _in_region:
		shown = _hazard if _hazard else _modifier

	if shown == null:
		_shown = null
		_shown_armed = false
		_unread = false
		_refresh_blink()
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

	var counting: bool = _hazard != null and _armed
	_glyph.position = _GLYPH_BESIDE_COUNTDOWN if counting else _GLYPH_CENTRED
	_countdown.visible = counting
	_update_countdown()

	# The jump clears what was shown, so every arrival is a fresh rule to
	# read, even when the region repeats one the player has seen before.
	var is_new: bool = shown != _shown
	var countdown_appeared: bool = counting and not _shown_armed
	_shown = shown
	_shown_armed = counting

	if not _deployed:
		_deploy()
	elif is_new or countdown_appeared:
		# Already up: a fresh swing says "new rule" (or "it's counting now")
		# without folding away and back.
		_kick()

	if is_new:
		_unread = true
		if Globals.show_region_alerts and _arrival_announces_region():
			var intro: ArrivalIntro = ArrivalIntro.shared()
			if intro.is_collecting():
				intro.add(ArrivalIntro.Beat.REGION_RULE, _announce.bind(shown))
			else:
				_announce(shown)
	_refresh_blink()


## False at a stop whose own panel opens on arrival (ScenarioResource.
## announce_region): the card would only cover it.
func _arrival_announces_region() -> bool:
	var manager: ScenarioManager = Globals.scenario_manager
	if manager == null or manager.current_scenario == null:
		return true
	return manager.current_scenario.announce_region


## Spells the new rule out in a card that unfolds out of the screen and
## later shrinks back into it, returning once it has. See RegionAlert.
func _announce(shown: Resource) -> void:
	# Out of the screen, so the monitor has to be up first. Killed (a jump
	# stowing it) ends the wait as well as finishing does.
	while _motion_tween and _motion_tween.is_valid() and _motion_tween.is_running():
		await get_tree().process_frame
	if shown != _shown or not _deployed:
		return

	var alert: RegionAlert = RegionAlert.new()
	if shown is BackgroundHazardResource:
		var hazard: BackgroundHazardResource = shown
		alert.title = tr(hazard.hazard_name).to_upper()
		alert.color = hazard.color
		alert.description = tr(hazard.description)
		# Word for word what the monitor's info panel says, so the card and
		# the monitor read as one instrument.
		alert.footnote = hazard_timing_text(hazard, _armed, _turns_remaining)
	else:
		var modifier: BackgroundModifierResource = shown
		alert.title = tr(modifier.modifier_name).to_upper()
		alert.color = modifier.color
		alert.description = tr(modifier.description)
	alert.landing_point = func() -> Vector2: return _glyph.global_position
	# The first sighting waits to be closed. Only the player's own runs count:
	# a bot or the Scenario Lab would wait on it forever.
	var id: String = region_id(shown)
	alert.wait_for_close = CollectionManager.is_recording() and not CollectionManager.has_read_region(id)
	alert.landed.connect(_on_alert_landed.bind(shown))
	alert.landed.connect(_record_read.bind(id))
	# Beside the monitor rather than on it: the monitor hides itself while
	# stowed, and would take the card with it.
	get_parent().add_child(alert)
	await alert.tree_exited


## How CollectionManager remembers a rule or hazard the player has read: its
## file name, under a prefix so a rule and a hazard can share one.
static func region_id(shown: Resource) -> String:
	var prefix: String = "hazard:" if shown is BackgroundHazardResource else "rule:"
	var key: String = shown.resource_path.get_file().get_basename()
	if key.is_empty():
		key = (shown as BackgroundHazardResource).hazard_name if shown is BackgroundHazardResource \
			else (shown as BackgroundModifierResource).modifier_name
	return prefix + key


## Read once is read for good: later cards fold away on their own.
func _record_read(id: String) -> void:
	if CollectionManager.is_recording():
		CollectionManager.record_region(id)


## The card has delivered the rule: the screen takes it in with a knock and a
## flare, and the lamp stops asking to be read.
func _on_alert_landed(shown: Resource) -> void:
	if shown != _shown or not _deployed:
		return
	_unread = false
	_refresh_blink()
	_kick()
	_flare(_current_color())


## The old region's rule is meaningless mid-hyperspace, and a lamp blinking
## over the jump reads as a warning about nothing. Stow now; the next arrival
## re-announces whatever rule the new region carries, so the monitor only comes
## back when there is one.
func _on_jump() -> void:
	_in_region = false
	_modifier = null
	_hazard = null
	_armed = false
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
	if _shown == null:
		return

	_unread = false
	_refresh_blink()

	var info: InfoResource = InfoResource.new()
	if _hazard:
		info.title_label_text = "[color=%s]%s[/color]" % [
			_hazard.color.to_html(false), _hazard.hazard_name.to_upper()
		]
		info.bottom_label_text = "%s\n%s" % [
			_hazard.description, hazard_timing_text(_hazard, _armed, _turns_remaining)
		]
		info.texture = _hazard.icon if _hazard.icon else _DEFAULT_INFO_ICON
	else:
		info.title_label_text = "[color=%s]%s[/color]" % [
			_modifier.color.to_html(false), _modifier.modifier_name.to_upper()
		]
		info.bottom_label_text = _modifier.description
		info.texture = _modifier.icon if _modifier.icon else _DEFAULT_INFO_ICON
	Events.show_info.emit(info)


## When [param hazard] next hits: [param turns_remaining] on a fight's
## countdown while [param armed], else how far into a fight it first does.
## The last turn is spelled out, because "in 1 turn" can't say whether that
## means as this turn ends or as the next one starts. Every line is kept under
## the ~27 characters the info panel fits on one line.
static func hazard_timing_text(
	hazard: BackgroundHazardResource, armed: bool, turns_remaining: int
) -> String:
	if not armed:
		var first: int = maxi(1, hazard.turns_until_first)
		if first == 1:
			return TranslationServer.translate("HAZARD_FIRST_ONE_TURN_INTO_FIGHT")
		return TranslationServer.translate("HAZARD_FIRST_TURNS_INTO_FIGHT").format({"turns": first})
	if turns_remaining <= 1:
		if hazard.timing == BackgroundHazardResource.Timing.YOUR_TURN_ENDS:
			return TranslationServer.translate("HAZARD_HITS_AS_THIS_TURN_ENDS")
		return TranslationServer.translate("HAZARD_HITS_AS_NEXT_TURN_STARTS")
	return TranslationServer.translate("HAZARD_NEXT_IN_TURNS").format({"turns": turns_remaining})


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


## Blinks while what's shown is unread, else stays lit and steady: read, but
## still in force. A hazard about to go off blinks regardless — reading it
## doesn't make it less imminent. Restarted on every change, so the blink
## picks up the current colour (red once imminent).
func _refresh_blink() -> void:
	if _is_blinking():
		_blink_tween.kill()
	_blink_tween = null
	if _shown == null:
		return

	var lit: Color = _current_color()
	if not (_unread or _is_urgent()):
		_set_lit(lit, true)
		return

	_blink_tween = create_tween().set_loops()
	_blink_tween.tween_callback(_set_lit.bind(lit, true))
	_blink_tween.tween_interval(blink_period * 0.5)
	_blink_tween.tween_callback(_set_lit.bind(lit, false))
	_blink_tween.tween_interval(blink_period * 0.5)


## The lamp and countdown colour: the hazard's own, red once it is imminent,
## else the rule's.
func _current_color() -> Color:
	if _hazard:
		return Globals.red if _is_urgent() else _hazard.color
	return _modifier.color if _modifier else Color.WHITE


## Imminent hazards turn the countdown red and keep the lamp blinking even once
## read. Only a fight's countdown can be imminent.
func _is_urgent() -> bool:
	return _hazard != null and _armed and _turns_remaining <= HazardManager.URGENT_AT


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
