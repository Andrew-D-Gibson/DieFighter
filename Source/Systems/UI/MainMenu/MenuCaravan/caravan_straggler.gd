class_name CaravanStraggler
extends Node
## Every so often a ship in the menu's caravan breaks down and drops out of
## the column, and the Undertow, who live in the fleet's wake picking off the
## slow, come for it: a raider climbs out of the wake, shoots out its lights,
## hooks it and drags it back down toward Fate.

@export var caravan: MenuCaravan
@export var raider: CaravanShipKind
## The kinds that can break down. Escorts and pilgrims don't.
@export var breakdown_kinds: Array[CaravanShipKind]
## Only ships this big break down, which keeps it to the open middle of the
## screen.
@export var breakdown_depths: Vector2 = Vector2(0.36, 0.52)
## Seconds after the menu opens before the first breakdown, picked from this
## range.
@export var first_delay: Vector2 = Vector2(12.0, 20.0)
## Seconds between breakdowns after that.
@export var repeat_delay: Vector2 = Vector2(50.0, 100.0)
## How far a broken-down ship drifts out of the column, in pixels: into the
## open space beside it, where it can be seen.
@export var drift: Vector2 = Vector2(-22.0, 14.0)
## How much bigger it gets as it drifts: everyone else, the player included,
## is still flying, so it falls back toward them.
@export var drift_growth: float = 1.1
## The fleet's wake, where the raider comes from and drags its prize: off the
## bottom of the screen, toward Fate. In the caravan's space.
@export var wake: Vector2 = Vector2(80.0, 228.0)
@export var wake_depth: float = 0.7

@export_group("Look")
@export var bolt_color: Color = Color("#D03656")
@export var flash_color: Color = Color("#CEF0F1")
@export var spark_color: Color = Color("#F29C5D")
@export var tether_color: Color = Color("#8E8B85")

## The Gaff's crane hook and its gun, on its combat sprite.
const _HOOK_POINT: Vector2 = Vector2(19, 21)
const _GUN_POINT: Vector2 = Vector2(12, 24)
## Where the raider holds station to shoot, below and just behind its prize,
## in pixels at the prize's combat size.
const _STATION: Vector2 = Vector2(-8.0, 28.0)
const _BOLT_SPEED: float = 55.0
const _SHOTS: int = 3
const _SHOT_GAP: float = 0.45
const _FLASH_SECONDS: float = 0.35
## How fast a towed ship catches up with the end of its tether.
const _TOW_STIFFNESS: float = 1.6


## A shot on its way.
class Bolt:
	var from: Vector2
	var to: Vector2
	var travelled: float = 0.0


## Where a shot landed.
class Flash:
	var at: Vector2
	var age: float = 0.0


var _overlay: Node2D = Node2D.new()
var _bolts: Array[Bolt] = []
var _flashes: Array[Flash] = []
## The broken-down ship and the raider taking it, while it's happening.
var _prize: MenuCaravan.Ship
var _captor: MenuCaravan.Ship
## How far the hook has reached, 0 to 1.
var _tether: float = 0.0
var _towing: bool = false
## Where the prize hangs from the captor while it's towed.
var _tow_offset: Vector2
var _tow_depth_offset: float


func _ready() -> void:
	# The overlay has to go in after the caravan's own layers to draw over them.
	if not caravan.is_node_ready():
		await caravan.ready
	caravan.add_overlay(_overlay)
	_overlay.draw.connect(_draw_overlay)
	_run()


func _process(delta: float) -> void:
	_advance_bolts(delta)
	for flash: Flash in _flashes:
		flash.age += delta
	_flashes = _flashes.filter(func(flash: Flash) -> bool: return flash.age < _FLASH_SECONDS)
	if _towing:
		_follow_tow(delta)
	_overlay.queue_redraw()


func _run() -> void:
	await _wait(_roll(first_delay))
	while true:
		if await play():
			await _wait(_roll(repeat_delay))
		else:
			await _wait(2.0)


## One breakdown, start to finish. False, straight away, if no ship was in the
## right place to break down.
func play() -> bool:
	var prize: MenuCaravan.Ship = _pick_straggler()
	if prize == null:
		return false
	_prize = prize
	caravan.take_off_route(prize)
	prize.beacon = MenuCaravan.Beacon.DISTRESS
	await _break_down(prize)

	_captor = caravan.add_ship(raider, wake, wake_depth)
	await _close_in(prize, _captor)
	await _open_fire(prize, _captor)
	await _hook()
	await _tow_away(prize, _captor)

	caravan.remove_ship(prize)
	caravan.remove_ship(_captor)
	_prize = null
	_captor = null
	_tether = 0.0
	_towing = false
	return true


func _pick_straggler() -> MenuCaravan.Ship:
	var candidates: Array[MenuCaravan.Ship] = caravan.ships_on_route().filter(
		func(ship: MenuCaravan.Ship) -> bool:
			return ship.kind in breakdown_kinds and ship.direction > 0.0 \
				and ship.depth >= breakdown_depths.x and ship.depth <= breakdown_depths.y)
	if candidates.is_empty():
		return null
	return RNGManager.pick_random(RNGManager.Bucket.COSMETIC, candidates)


## The engines cough and die and the ship drifts out of the column, calling
## Mayday while the caravan passes it by.
func _break_down(prize: MenuCaravan.Ship) -> void:
	var tween: Tween = create_tween().set_parallel().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(prize, "position", prize.position + drift, 8.0)
	tween.tween_property(prize, "depth", prize.depth * drift_growth, 8.0)
	tween.tween_method(_sputter.bind(prize), 1.0, 0.0, 3.5)
	await tween.finished
	await _wait(3.0)


## Engines that cut out and catch again, a few times a second, weaker each time.
func _sputter(power: float, ship: MenuCaravan.Ship) -> void:
	ship.engine_power = power if fposmod(power * 13.0, 1.0) > 0.35 else 0.0


## The raider climbs out of the wake to just behind its prize.
func _close_in(prize: MenuCaravan.Ship, captor: MenuCaravan.Ship) -> void:
	var tween: Tween = create_tween().set_parallel().set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	tween.tween_property(captor, "position", prize.position + _STATION * prize.depth, 6.0)
	tween.tween_property(captor, "depth", prize.depth + 0.12, 6.0)
	await tween.finished
	await _wait(0.5)


func _open_fire(prize: MenuCaravan.Ship, captor: MenuCaravan.Ship) -> void:
	for i: int in _SHOTS:
		var bolt: Bolt = Bolt.new()
		bolt.from = caravan.pixel_on(captor, _GUN_POINT)
		bolt.to = prize.position + Vector2(
			RNGManager.randf_range(RNGManager.Bucket.COSMETIC, -3.0, 3.0),
			RNGManager.randf_range(RNGManager.Bucket.COSMETIC, -1.0, 2.0)).round()
		_bolts.append(bolt)
		await _wait(_SHOT_GAP)
	await _wait(1.2)


func _hook() -> void:
	var tween: Tween = create_tween()
	tween.tween_property(self, "_tether", 1.0, 0.6)
	await tween.finished
	await _wait(0.8)


## The raider backs off into the wake with its prize swinging after it.
func _tow_away(prize: MenuCaravan.Ship, captor: MenuCaravan.Ship) -> void:
	_tow_offset = (prize.position - captor.position) / captor.depth
	_tow_depth_offset = prize.depth - captor.depth
	_towing = true
	var tween: Tween = create_tween().set_parallel().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tween.tween_property(captor, "position", wake, 11.0)
	tween.tween_property(captor, "depth", wake_depth, 11.0)
	tween.tween_property(captor, "engine_power", 0.3, 2.0)
	await tween.finished


func _follow_tow(delta: float) -> void:
	var catch_up: float = 1.0 - exp(-_TOW_STIFFNESS * delta)
	_prize.position = _prize.position.lerp(_captor.position + _tow_offset * _captor.depth, catch_up)
	_prize.depth = lerpf(_prize.depth, _captor.depth + _tow_depth_offset, catch_up)


func _advance_bolts(delta: float) -> void:
	for bolt: Bolt in _bolts:
		bolt.travelled += _BOLT_SPEED * delta
		if bolt.travelled >= bolt.from.distance_to(bolt.to):
			var flash: Flash = Flash.new()
			flash.at = bolt.to
			_flashes.append(flash)
			# The first hit puts its lights out.
			if _prize != null:
				_prize.beacon = MenuCaravan.Beacon.DARK
				_prize.engine_power = 0.0
	_bolts = _bolts.filter(func(bolt: Bolt) -> bool: return bolt.travelled < bolt.from.distance_to(bolt.to))


func _draw_overlay() -> void:
	if _tether > 0.0 and _prize != null and _captor != null:
		var from: Vector2 = caravan.pixel_on(_captor, _HOOK_POINT)
		var to: Vector2 = from.lerp(_tether_point_on(_prize), _tether).round()
		_overlay.draw_line(from + Vector2(0.5, 0.5), to + Vector2(0.5, 0.5), tether_color, -1.0)

	for bolt: Bolt in _bolts:
		var heading: Vector2 = bolt.from.direction_to(bolt.to)
		var head: Vector2 = (bolt.from + heading * bolt.travelled).floor()
		for trail: int in [2, 1]:
			var behind: Vector2 = (bolt.from + heading * maxf(bolt.travelled - trail, 0.0)).floor()
			_overlay.draw_rect(Rect2(behind, Vector2.ONE), Color(bolt_color, 1.0 - trail * 0.3))
		_overlay.draw_rect(Rect2(head, Vector2.ONE), bolt_color)

	for flash: Flash in _flashes:
		if flash.age < _FLASH_SECONDS * 0.3:
			for offset: Vector2 in [Vector2.ZERO, Vector2.LEFT, Vector2.RIGHT, Vector2.UP, Vector2.DOWN]:
				_overlay.draw_rect(Rect2(flash.at + offset, Vector2.ONE), flash_color)
		else:
			var spark: Color = Color(spark_color, 1.0 - flash.age / _FLASH_SECONDS)
			for offset: Vector2 in [Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 1), Vector2(1, 1)]:
				_overlay.draw_rect(Rect2(flash.at + offset * 1.5, Vector2.ONE), spark)


## Where the hook bites: between the prize's engines.
func _tether_point_on(ship: MenuCaravan.Ship) -> Vector2:
	var sum: Vector2 = Vector2.ZERO
	for engine: Vector2 in ship.kind.engine_points:
		sum += engine
	return caravan.pixel_on(ship, sum / maxi(ship.kind.engine_points.size(), 1))


func _wait(seconds: float) -> void:
	# A timer of our own rather than the tree's, so that if the menu closes
	# mid-wait this coroutine is dropped instead of resumed on a freed node.
	var timer: Timer = Timer.new()
	timer.one_shot = true
	add_child(timer)
	timer.start(seconds)
	await timer.timeout
	timer.queue_free()


func _roll(range_seconds: Vector2) -> float:
	return RNGManager.randf_range(RNGManager.Bucket.COSMETIC, range_seconds.x, range_seconds.y)
