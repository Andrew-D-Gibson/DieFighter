class_name IonStorm
extends HazardTelegraph
## The Ion Storm Front's weather: lightning inside the charged nebula.
## Sometimes a bolt cracks through the cloud in view; sometimes the strike is
## just off screen and all that shows is the near cloud lighting up. Either
## way the light comes from where the lightning is: every strike writes its
## position, reach and brightness to the global ion_flash, which
## ion_nebula.gdshader reads to light the cloud around it.
##
## It strikes more often once the storm's discharge is a turn away, and when
## the discharge fires a close bolt and a broad flash go off together, then a
## second bolt.
##
## Photosensitivity: strikes start at least MIN_GAP seconds apart (the hazard
## firing aside), the light fades rather than strobes, the void behind the
## cloud only lifts a little, and the one full-screen wash (a bolt's) is
## faint. The game has no reduced-flashing option yet; if one is added, this
## is where to honour it.
##
## Draws one screen of art pixels from its own origin, so place it at (0, 0).
## It sits above the nebula and below the scrolling pieces, so the motes stay
## in front of the lightning.

enum Kind { FLASH, BOLT }

## Seconds between strikes, picked fresh each time: at rest, and while the
## discharge is a turn away.
@export var calm_gap: Vector2 = Vector2(2.4, 5.5)
@export var urgent_gap: Vector2 = Vector2(1.0, 2.0)
## Odds that a strike shows its bolt rather than lighting the cloud from off
## screen.
@export_range(0.0, 1.0) var bolt_chance: float = 0.45
## How strongly a bolt's faint wash reaches the whole screen, cockpit and UI
## included. 0 keeps the storm inside the viewer.
@export_range(0.0, 0.1) var screen_wash: float = 0.03
## False leaves strikes to flash_offscreen() and strike_bolt() alone, for a
## scene that times its own lightning.
@export var autonomous: bool = true

## The shortest time between two strikes starting.
const MIN_GAP: float = 1.0

## Approved palette.
const _CORE: Color = Color("#cef0f1")
const _HOT: Color = Color("#8df1f4")
const _GLOW: Color = Color("#43a6fc")
const _SKY: Color = Color("#251c6b")

## How long each kind of strike lights the cloud, in seconds.
const _LIFETIMES: Dictionary[Kind, float] = {Kind.FLASH: 0.9, Kind.BOLT: 0.75}
## A bolt's dimmed blink between its two strikes, in seconds from its start,
## and when its second strike starts to fade.
const _BOLT_BLINK: Vector2 = Vector2(0.06, 0.11)
const _BOLT_HOLD: float = 0.24
## How bright the bolt's light stays through its blink. Lightning flickers;
## this keeps the flicker from becoming a full on-off strobe.
const _BOLT_BLINK_LEVEL: float = 0.6
## How far outside the screen an unseen strike sits, in art pixels.
const _OFFSCREEN_DEPTH: Vector2 = Vector2(14.0, 40.0)
## How much the dark sky behind the cloud lifts at full light.
const _SKY_LIFT: float = 0.15

class Strike:
	var kind: Kind
	var age: float = 0.0
	var strength: float = 1.0
	## Where the light comes from, in this node's space, and how far it reaches.
	var centre: Vector2
	var radius: float
	## BOLT only.
	var bolt: LightningBolt = null

var _strikes: Array[Strike] = []
var _countdown: float = 0.0
var _since_last_strike: float = MIN_GAP

@onready var _sky: ColorRect = $Sky


func _ready() -> void:
	super()
	_countdown = _next_gap()


func _exit_tree() -> void:
	RenderingServer.global_shader_parameter_set(&"ion_flash", Vector4(0.0, 0.0, 0.0, 1.0))


func _process(delta: float) -> void:
	for active: Strike in _strikes:
		active.age += delta
	_strikes = _strikes.filter(func(s: Strike) -> bool: return s.age < _LIFETIMES[s.kind])

	_since_last_strike += delta
	if autonomous:
		_countdown -= delta
		if _countdown <= 0.0 and _since_last_strike >= MIN_GAP:
			_countdown = _next_gap()
			_strike_random()
	_show()


## A strike just off screen: no bolt, only the near cloud lighting up from
## one edge.
func flash_offscreen(strength: float = 1.0) -> void:
	var new_strike: Strike = Strike.new()
	new_strike.kind = Kind.FLASH
	new_strike.strength = strength
	var depth: float = _randf(_OFFSCREEN_DEPTH.x, _OFFSCREEN_DEPTH.y)
	var size: Vector2 = Globals.SCREEN_SIZE
	match RNGManager.randi_range(RNGManager.Bucket.COSMETIC, 0, 2):
		0:
			new_strike.centre = Vector2(-depth, _randf(10.0, size.y - 30.0))
		1:
			new_strike.centre = Vector2(size.x + depth, _randf(10.0, size.y - 30.0))
		_:
			new_strike.centre = Vector2(_randf(20.0, size.x - 20.0), -depth)
	new_strike.radius = _randf(120.0, 180.0)
	_begin(new_strike)


## A bolt cracking through the cloud in view: down one flank, or in across
## the top from one side, keeping clear of the middle where the ships fight.
func strike_bolt(strength: float = 1.0) -> void:
	var new_strike: Strike = Strike.new()
	new_strike.kind = Kind.BOLT
	new_strike.strength = strength
	var from_left: bool = _randf(0.0, 1.0) < 0.5
	var size: Vector2 = Globals.SCREEN_SIZE
	var start: Vector2
	var angle: float
	var length: float
	if _randf(0.0, 1.0) < 0.6:
		start = Vector2(_randf(12.0, 90.0) if from_left else _randf(size.x - 90.0, size.x - 12.0), _randf(-2.0, 40.0))
		# Down, leaning away from the middle rather than into it.
		var lean: float = _randf(-0.15, 0.5)
		angle = PI / 2.0 + (lean if from_left else -lean)
		length = _randf(50.0, 110.0)
	else:
		start = Vector2(_randf(-4.0, 40.0) if from_left else _randf(size.x - 40.0, size.x + 4.0), _randf(8.0, 50.0))
		angle = _randf(-0.3, 0.45) if from_left else PI + _randf(-0.45, 0.3)
		length = _randf(60.0, 100.0)
	new_strike.bolt = LightningBolt.grow(start, angle, length, 2)
	new_strike.centre = start + Vector2.from_angle(angle) * length * 0.45
	new_strike.radius = _randf(80.0, 120.0)
	_begin(new_strike)
	if screen_wash > 0.0:
		Juice.screen_flash(self, _HOT, screen_wash * strength, 0.2)


func _urgency_changed() -> void:
	# Don't make an imminent storm sit out the rest of a long calm wait.
	_countdown = minf(_countdown, _next_gap())


## The discharge: a close bolt with a broad flash behind it, then a second
## bolt once the first has faded.
func _fired() -> void:
	strike_bolt(1.0)
	flash_offscreen(0.8)
	await get_tree().create_timer(MIN_GAP).timeout
	if is_inside_tree():
		strike_bolt(0.8)


func _strike_random() -> void:
	if _randf(0.0, 1.0) < bolt_chance:
		strike_bolt(_randf(0.7, 1.0))
	else:
		flash_offscreen(_randf(0.5, 1.0))


func _begin(new_strike: Strike) -> void:
	_strikes.append(new_strike)
	_since_last_strike = 0.0


func _next_gap() -> float:
	var gap: Vector2 = urgent_gap if urgent else calm_gap
	return _randf(gap.x, gap.y)


# --- Light ------------------------------------------------------------------

## How lit the cloud is by [param strike_now], 0 to 1. A bolt strikes twice:
## a flash, a dim blink, a second flash that holds, then a fade. An unseen
## strike rolls in two humps, like light behind cloud.
func _light(strike_now: Strike) -> float:
	var t: float = strike_now.age
	var level: float = 0.0
	match strike_now.kind:
		Kind.BOLT:
			if t < _BOLT_BLINK.x:
				level = 1.0
			elif t < _BOLT_BLINK.y:
				level = _BOLT_BLINK_LEVEL
			elif t < _BOLT_HOLD:
				level = 1.0
			else:
				level = exp(-(t - _BOLT_HOLD) / 0.15)
		Kind.FLASH:
			if t < 0.05:
				level = 0.6 * t / 0.05
			else:
				level = 0.6 * exp(-(t - 0.05) / 0.1)
			if t > 0.18:
				level = maxf(level, exp(-(t - 0.18) / 0.22))
	return clampf(level * strike_now.strength, 0.0, 1.0)


func _show() -> void:
	var brightest: Strike = null
	var brightest_level: float = 0.0
	for strike_now: Strike in _strikes:
		var level: float = _light(strike_now)
		if level > brightest_level:
			brightest = strike_now
			brightest_level = level

	var flash: Vector4 = Vector4(0.0, 0.0, 0.0, 1.0)
	if brightest:
		var centre: Vector2 = global_transform * brightest.centre
		flash = Vector4(centre.x, centre.y, brightest_level, brightest.radius)
	RenderingServer.global_shader_parameter_set(&"ion_flash", flash)
	# The sky rect blends additively, so its alpha is how much light it adds.
	_sky.color = Color(_SKY, brightest_level * _SKY_LIFT)
	queue_redraw()


func _draw() -> void:
	for strike_now: Strike in _strikes:
		if strike_now.kind != Kind.BOLT:
			continue
		var level: float = _light(strike_now)
		if level <= 0.05:
			continue
		# White-hot only while each strike lands, then the storm's cyan.
		var age: float = strike_now.age
		var landing: bool = age < _BOLT_BLINK.x or (age > _BOLT_BLINK.y and age < _BOLT_BLINK.y + 0.05)
		var core: Color = _CORE if landing else _HOT
		strike_now.bolt.draw_on(self, Color(core, minf(1.0, level * 1.5)), Color(_GLOW, level * 0.7))


func _randf(from: float, to: float) -> float:
	return RNGManager.randf_range(RNGManager.Bucket.COSMETIC, from, to)
