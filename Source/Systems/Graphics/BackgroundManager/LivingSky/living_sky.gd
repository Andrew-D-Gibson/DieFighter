class_name LivingSky
extends Node2D
## Keeps a settled sky from reading as a still image. A jump in is all motion
## (the stars stream, the planet slides into place), then the stars hold
## still, so on its own the sky would snap to a picture. Once it has settled:
## - the main menu's space dust drifts in over it, and
## - every few tens of seconds something happens far off: a small ship of the
##   sector's fleet drifts in from the edge and jumps away, or a comet streaks
##   past.
## A jump fades the dust out again (dust that ignores the streaming stars
## would look pinned to the glass) and any ship still drifting jumps with it.
##
## Everything stays in [member zones], the open sky either side of the fight,
## so nothing crosses behind the enemies or the cockpit's panels.
##
## Cosmetic only: nothing here touches the board, and every roll comes from
## the COSMETIC stream, so a run's seed plays out the same with or without
## it. Drawn in art pixels with its origin at the screen's top-left.

@export_group("Dust")
@export var dust: CPUParticles2D
## In place of the dust scene's own colour: the menu's grey vanishes against
## a battle sky, which is lighter than the menu's near-black.
@export var dust_color: Color = Color("#63605C")
## How visible the dust is once it has faded in. Kept low: it sits behind play.
@export_range(0.0, 1.0) var dust_opacity: float = 0.6
@export var dust_fade_in_seconds: float = 2.5
@export var dust_fade_out_seconds: float = 0.3

@export_group("Ambient Events")
## Seconds from the sky settling to its first event, picked from this range.
@export var first_event_delay: Vector2 = Vector2(8.0, 20.0)
## Seconds between one event ending and the next starting.
@export var event_interval: Vector2 = Vector2(25.0, 50.0)
## How many events are comets rather than ships.
@export_range(0.0, 1.0) var comet_share: float = 0.35
## Where events may play, in art pixels: the sky beside the fight. A ship
## enters a zone from the screen edge it touches; a comet heads for that edge.
@export var zones: Array[Rect2] = [Rect2(4, 40, 72, 54), Rect2(248, 40, 68, 54)]

@export_group("Ships")
## Who flies past in each sector, picked evenly; list a kind twice to see it
## more. The Tail is what the fleet left behind: stragglers, wake pirates and
## the odd honest Picket. Any sector past the Spine uses the Spine's.
@export var tail_kinds: Array[CaravanShipKind] = []
@export var belly_kinds: Array[CaravanShipKind] = []
@export var spine_kinds: Array[CaravanShipKind] = []
## How wide a ship is drawn, in art pixels, before turning it side-on.
@export var ship_width: Vector2i = Vector2i(7, 10)
## Art pixels per second.
@export var ship_speed: Vector2 = Vector2(3.0, 5.0)
## Far ships fade toward this, the colour of the space around them.
@export var haze_color: Color = Color("#191347")
@export_range(0.0, 1.0) var ship_haze: float = 0.5
## Seconds the drive spools (the engines flicker) before the jump.
@export var charge_seconds: float = 0.9
## How long the jump's wake is, in art pixels.
@export var streak_length: Vector2i = Vector2i(14, 20)

@export_group("Comets")
## Art pixels per second.
@export var comet_speed: Vector2 = Vector2(45.0, 70.0)
## How far a comet is seen to travel, in art pixels.
@export var comet_distance: Vector2 = Vector2(30.0, 46.0)
## Pixels of tail behind the head.
@export var comet_tail: Vector2i = Vector2i(5, 9)
@export var comet_head_color: Color = Color("#CEF0F1")
## The tail runs from the first colour behind the head to the last at its tip.
@export var comet_tail_colors: PackedColorArray = PackedColorArray([
	Color("#8DF1F4"), Color("#43A6FC"), Color("#2C71AA")])

const _FLASH_SECONDS: float = 0.35
const _STREAK_GROW_SECONDS: float = 0.08
const _STREAK_PINCH_SECONDS: float = 0.35
const _COMET_FADE_SECONDS: float = 0.25
## Narrower than this (side-on height), a ship's engines merge into one light.
const _SEPARATE_ENGINES_HEIGHT: int = 9


class AmbientShip:
	var texture: ImageTexture
	## Top-left, in art pixels; drawn rounded.
	var position: Vector2
	## +1 flying right, -1 flying left.
	var heading: float
	var speed: float
	## Where the engines sit on [member texture].
	var engines: PackedVector2Array
	var engine_color: Color
	## Starts spooling once the nose gets this far across.
	var jump_x: float
	## Seconds the drive has been spooling, or -1 while it hasn't started.
	var charge: float = -1.0
	var phase: float

	func nose() -> Vector2:
		var size: Vector2 = texture.get_size()
		var x: float = position.x + (size.x - 1.0 if heading > 0.0 else 0.0)
		return (Vector2(x, position.y + floorf(size.y / 2.0))).round()


class Wake:
	var from: Vector2
	var heading: float
	var length: int
	var color: Color
	var age: float = 0.0


class Comet:
	var position: Vector2
	var velocity: Vector2
	var travelled: float = 0.0
	var distance: float
	var tail: int


var _settled: bool = false
var _events_allowed: bool = true
var _dust_tween: Tween
var _countdown: float = 0.0
var _time: float = 0.0
var _ships: Array[AmbientShip] = []
var _wakes: Array[Wake] = []
var _comets: Array[Comet] = []
## Side-on ship sprites by kind, width and heading.
var _sprites: Dictionary[String, ImageTexture] = {}
var _events_layer: Node2D = Node2D.new()


func _ready() -> void:
	dust.color = dust_color
	dust.modulate.a = 0.0
	# Above the stars (and the set pieces level with them): a ship passing
	# should cover the stars behind it.
	_events_layer.z_index = 1
	_events_layer.draw.connect(_draw_events)
	add_child(_events_layer)


## Called by BackgroundManager whenever the sky starts or stops holding still.
func set_settled(settled: bool) -> void:
	if settled == _settled:
		return
	_settled = settled
	_fade_dust(dust_opacity if settled else 0.0,
		dust_fade_in_seconds if settled else dust_fade_out_seconds)
	if settled:
		_countdown = _roll(first_event_delay)
	else:
		# Our jump drags theirs: anyone still drifting goes now.
		for ship: AmbientShip in _ships:
			if ship.charge < 0.0:
				ship.charge = charge_seconds


func is_settled() -> bool:
	return _settled


## Whether fly-bys and comets may play over the current sky. BackgroundManager
## turns them off for Fate's skies (BackgroundResource.fate_themed), where they
## would break the story. Turning them off also removes any already in
## progress, wake and all, so nothing carries over from the previous sky.
func set_events_allowed(allowed: bool) -> void:
	_events_allowed = allowed
	if allowed:
		return
	_ships.clear()
	_wakes.clear()
	_comets.clear()
	_events_layer.queue_redraw()


func _process(delta: float) -> void:
	_time += delta
	if _settled and _events_allowed and _is_idle():
		_countdown -= delta
		if _countdown <= 0.0:
			_start_event()
			_countdown = _roll(event_interval)
	_advance_ships(delta)
	_advance_wakes(delta)
	_advance_comets(delta)
	_events_layer.queue_redraw()


func _is_idle() -> bool:
	return _ships.is_empty() and _wakes.is_empty() and _comets.is_empty()


func _fade_dust(to_alpha: float, seconds: float) -> void:
	if _dust_tween:
		_dust_tween.kill()
	_dust_tween = create_tween()
	_dust_tween.tween_property(dust, "modulate:a", to_alpha, seconds)


func _start_event() -> void:
	if zones.is_empty():
		return
	var zone: Rect2 = zones[RNGManager.randi_range(RNGManager.Bucket.COSMETIC, 0, zones.size() - 1)]
	var kinds: Array[CaravanShipKind] = _sector_kinds()
	if kinds.is_empty() or RNGManager.randf(RNGManager.Bucket.COSMETIC) < comet_share:
		_spawn_comet(zone)
	else:
		_spawn_ship(zone, kinds[RNGManager.randi_range(RNGManager.Bucket.COSMETIC, 0, kinds.size() - 1)])


## Which side of the screen [param zone] opens onto: -1 left, +1 right.
func _edge_of(zone: Rect2) -> float:
	return -1.0 if zone.get_center().x < Globals.SCREEN_SIZE.x / 2.0 else 1.0


func _sector_kinds() -> Array[CaravanShipKind]:
	var sector: int = 0
	if Globals.state_manager != null and Globals.state_manager.current_game_save != null:
		sector = Globals.state_manager.current_game_save.sector_index
	match sector:
		0:
			return tail_kinds
		1:
			return belly_kinds
		_:
			return spine_kinds


# --- Ships ---

## Flies in from the zone's screen edge toward the fight, and jumps out before
## its wake would leave the zone.
func _spawn_ship(zone: Rect2, kind: CaravanShipKind) -> void:
	var ship: AmbientShip = AmbientShip.new()
	ship.heading = -_edge_of(zone)
	var width: int = RNGManager.randi_range(RNGManager.Bucket.COSMETIC, ship_width.x, ship_width.y)
	ship.texture = _sprite_for(kind, width, ship.heading)
	ship.engines = _engines_on(kind, width, ship.heading)
	ship.engine_color = kind.engine_color
	ship.speed = _roll(ship_speed)
	ship.phase = _roll(Vector2(0.0, TAU))
	var size: Vector2 = ship.texture.get_size()
	var y: float = roundf(_roll(Vector2(zone.position.y, zone.end.y - size.y)))
	var wake: int = streak_length.y
	if ship.heading > 0.0:
		ship.position = Vector2(-size.x, y)
		ship.jump_x = _roll(Vector2(zone.position.x + zone.size.x * 0.4, zone.end.x - wake))
	else:
		ship.position = Vector2(Globals.SCREEN_SIZE.x, y)
		ship.jump_x = _roll(Vector2(zone.position.x + wake, zone.end.x - zone.size.x * 0.4))
	_ships.append(ship)


func _advance_ships(delta: float) -> void:
	for ship: AmbientShip in _ships:
		if ship.charge >= 0.0:
			ship.charge += delta
			# The drive takes over: it eases to a stop as it spools.
			ship.position.x += ship.heading * ship.speed * delta * maxf(0.0, 1.0 - ship.charge / charge_seconds)
			if ship.charge >= charge_seconds:
				_jump(ship)
			continue
		ship.position.x += ship.heading * ship.speed * delta
		var nose_x: float = ship.nose().x
		if (ship.heading > 0.0 and nose_x >= ship.jump_x) or (ship.heading < 0.0 and nose_x <= ship.jump_x):
			ship.charge = 0.0
	_ships = _ships.filter(func(ship: AmbientShip) -> bool: return ship.charge < charge_seconds)


func _jump(ship: AmbientShip) -> void:
	var wake: Wake = Wake.new()
	wake.from = ship.nose()
	wake.heading = ship.heading
	wake.length = RNGManager.randi_range(RNGManager.Bucket.COSMETIC, streak_length.x, streak_length.y)
	wake.color = ship.engine_color
	_wakes.append(wake)


func _advance_wakes(delta: float) -> void:
	for wake: Wake in _wakes:
		wake.age += delta
	_wakes = _wakes.filter(func(wake: Wake) -> bool:
		return wake.age < _STREAK_GROW_SECONDS + _STREAK_PINCH_SECONDS)


## [param kind]'s combat sprite (nose down) shrunk to [param width] and
## turned side-on, nose toward [param heading], and hazed into the distance.
func _sprite_for(kind: CaravanShipKind, width: int, heading: float) -> ImageTexture:
	var key: String = "%d:%d:%d" % [kind.get_instance_id(), width, int(heading)]
	if _sprites.has(key):
		return _sprites[key]
	var image: Image = PixelArtShrinker.shrink(kind.texture.get_image(), width)
	# Down to right is a quarter turn anticlockwise.
	image.rotate_90(COUNTERCLOCKWISE if heading > 0.0 else CLOCKWISE)
	for y: int in image.get_height():
		for x: int in image.get_width():
			var c: Color = image.get_pixel(x, y)
			if c.a > 0.0:
				var hazed: Color = c.lerp(haze_color, ship_haze)
				hazed.a = c.a
				image.set_pixel(x, y, hazed)
	_sprites[key] = ImageTexture.create_from_image(image)
	return _sprites[key]


## Where [param kind]'s engines land on the side-on sprite from _sprite_for(),
## merged into one light once the ship is too small to tell them apart.
func _engines_on(kind: CaravanShipKind, width: int, heading: float) -> PackedVector2Array:
	var full: Vector2 = kind.texture.get_size()
	var factor: float = float(width) / full.x
	var shrunk: Vector2 = (full * factor).round().max(Vector2.ONE)
	var points: PackedVector2Array = kind.engine_points.duplicate()
	if points.is_empty():
		# Nothing marked (a ship drawn coming back): light the middle of its tail.
		points.append(Vector2(full.x / 2.0, 0.0))
	var placed: PackedVector2Array = []
	for point: Vector2 in points:
		var p: Vector2 = (point * factor).floor()
		# Matches the turn in _sprite_for().
		if heading > 0.0:
			placed.append(Vector2(p.y, shrunk.x - 1.0 - p.x))
		else:
			placed.append(Vector2(shrunk.y - 1.0 - p.y, p.x))
	if shrunk.x < _SEPARATE_ENGINES_HEIGHT and placed.size() > 1:
		var sum: Vector2 = Vector2.ZERO
		for p: Vector2 in placed:
			sum += p
		placed = PackedVector2Array([(sum / placed.size()).floor()])
	return placed


# --- Comets ---

## Starts high in the zone and dives toward its screen edge.
func _spawn_comet(zone: Rect2) -> void:
	var comet: Comet = Comet.new()
	var edge: float = _edge_of(zone)
	comet.position = Vector2(
		_roll(Vector2(zone.position.x + zone.size.x * 0.3, zone.end.x - zone.size.x * 0.1)) if edge < 0.0
			else _roll(Vector2(zone.position.x + zone.size.x * 0.1, zone.end.x - zone.size.x * 0.3)),
		_roll(Vector2(zone.position.y, zone.get_center().y)))
	var angle: float = deg_to_rad(_roll(Vector2(15.0, 40.0)))
	comet.velocity = Vector2(edge * cos(angle), sin(angle)) * _roll(comet_speed)
	comet.distance = _roll(comet_distance)
	comet.tail = RNGManager.randi_range(RNGManager.Bucket.COSMETIC, comet_tail.x, comet_tail.y)
	_comets.append(comet)


func _advance_comets(delta: float) -> void:
	for comet: Comet in _comets:
		comet.position += comet.velocity * delta
		comet.travelled += comet.velocity.length() * delta
	_comets = _comets.filter(func(comet: Comet) -> bool: return comet.travelled < comet.distance)


# --- Drawing ---

func _draw_events() -> void:
	for comet: Comet in _comets:
		_draw_comet(comet)
	for ship: AmbientShip in _ships:
		_draw_ship(ship)
	for wake: Wake in _wakes:
		_draw_wake(wake)


func _draw_ship(ship: AmbientShip) -> void:
	var top_left: Vector2 = ship.position.round()
	_events_layer.draw_texture(ship.texture, top_left)
	var strength: float = 0.75 + 0.25 * sin(_time * 3.0 + ship.phase)
	var color: Color = ship.engine_color
	if ship.charge >= 0.0:
		# Spooling: the engines flicker faster and brighter, whiter at the end.
		var spool: float = ship.charge / charge_seconds
		strength = 1.0 if fmod(_time * lerpf(6.0, 20.0, spool), 1.0) < 0.6 else 0.4
		color = color.lerp(comet_head_color, spool * 0.6)
	color.a *= strength
	for engine: Vector2 in ship.engines:
		_events_layer.draw_rect(Rect2(top_left + engine, Vector2.ONE), color)


## The jump: a flash at the nose, and a wake that shoots ahead, then pinches
## shut from behind as it fades from white to the drive's colour.
func _draw_wake(wake: Wake) -> void:
	var flash_strength: float = Juice.soften_flash(1.0)
	if wake.age < _FLASH_SECONDS * 0.3:
		for offset: Vector2 in [Vector2.ZERO, Vector2.LEFT, Vector2.RIGHT, Vector2.UP, Vector2.DOWN]:
			_events_layer.draw_rect(Rect2(wake.from + offset, Vector2.ONE),
				Color(comet_head_color, flash_strength))
	elif wake.age < _FLASH_SECONDS:
		var spark: Color = Color(wake.color, 1.0 - wake.age / _FLASH_SECONDS)
		for offset: Vector2 in [Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 1), Vector2(1, 1)]:
			_events_layer.draw_rect(Rect2(wake.from + offset, Vector2.ONE), spark)

	var grown: float = clampf(wake.age / _STREAK_GROW_SECONDS, 0.0, 1.0)
	var pinched: float = clampf((wake.age - _STREAK_GROW_SECONDS) / _STREAK_PINCH_SECONDS, 0.0, 1.0)
	var start: int = roundi(wake.length * pinched)
	var end: int = roundi(wake.length * grown)
	if end <= start:
		return
	var color: Color = comet_head_color.lerp(wake.color, clampf(wake.age / 0.15, 0.0, 1.0))
	color.a = 1.0 - pinched * 0.5
	var x: float = wake.from.x + wake.heading * start
	var length: float = float(end - start)
	var left: float = x if wake.heading > 0.0 else x - length + 1.0
	_events_layer.draw_rect(Rect2(Vector2(left, wake.from.y), Vector2(length, 1.0)), color)


func _draw_comet(comet: Comet) -> void:
	var fade_in: float = clampf(comet.travelled / (comet.velocity.length() * _COMET_FADE_SECONDS), 0.0, 1.0)
	var fade_out: float = clampf((comet.distance - comet.travelled) / (comet.velocity.length() * _COMET_FADE_SECONDS), 0.0, 1.0)
	var alpha: float = minf(fade_in, fade_out)
	var head: Vector2 = comet.position.round()
	var back: Vector2 = -comet.velocity.normalized()
	var last: Vector2 = head
	for i: int in range(1, comet.tail + 1):
		var at: Vector2 = (comet.position + back * i).round()
		if at == last:
			continue
		last = at
		var t: float = float(i) / comet.tail
		var color: Color = _tail_color(t)
		color.a = alpha * (1.0 - t * 0.8)
		_events_layer.draw_rect(Rect2(at, Vector2.ONE), color)
	_events_layer.draw_rect(Rect2(head, Vector2.ONE), Color(comet_head_color, alpha))


## The tail colour [param t] of the way from head (0) to tip (1).
func _tail_color(t: float) -> Color:
	if comet_tail_colors.is_empty():
		return comet_head_color
	var scaled: float = t * (comet_tail_colors.size() - 1)
	var i: int = mini(floori(scaled), comet_tail_colors.size() - 1)
	return comet_tail_colors[i].lerp(comet_tail_colors[mini(i + 1, comet_tail_colors.size() - 1)], scaled - i)


func _roll(range_values: Vector2) -> float:
	return RNGManager.randf_range(RNGManager.Bucket.COSMETIC, range_values.x, range_values.y)
