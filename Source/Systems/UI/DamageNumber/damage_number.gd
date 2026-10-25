## DamageNumber
## A floating number that pops off a ship when it takes damage.
##
## Spawned by DamageEvent rather than authored per tile, so every hit in the
## game shows one, and the number is the damage that actually landed after
## modifiers — not a guess made earlier in the chain.
class_name DamageNumber
extends Node2D

const _FONT: Font = preload("res://Assets/Fonts/m5x7/m5x7.ttf")

## m5x7 is drawn at 16 so one font pixel is one world pixel; larger hits scale
## the whole node by whole numbers to stay crisp.
const _FONT_SIZE: int = 16

## Hits at or above this read as big and get the doubled number.
const _BIG_HIT: int = 6

const _RISE_PIXELS: float = 10.0
const _LIFETIME_SECONDS: float = 0.8
## Words take longer to read than a number: a callout ("RELAY", "+2 BURN",
## "NO SHIELDS") holds this long, plus a little per letter.
const _TEXT_LIFETIME_SECONDS: float = 1.4
const _TEXT_SECONDS_PER_LETTER: float = 0.05
const _MAX_TEXT_LIFETIME_SECONDS: float = 2.2

## Repeated hits on the same ship scatter sideways instead of stacking into
## one unreadable pile.
const _SCATTER_PIXELS: float = 6.0

## Damage numbers fly off sideways and fall, while callouts (status names,
## heals) rise from the middle, so a hit never lands on top of the text that
## explains it.
const _DAMAGE_SIDE_PIXELS: float = 16.0
const _DAMAGE_DRIFT: Vector2 = Vector2(10.0, 8.0)

## Callouts landing on one ship inside this window stack upward instead of
## printing over each other.
const _STACK_WINDOW_MSEC: int = 900
const _STACK_STEP_PIXELS: float = 9.0

## Ship instance id -> {"msec": last callout time, "count": stacked so far}.
static var _recent_callouts: Dictionary = {}

## How much bigger the numbers for hits on the player print, in whole steps.
const _PLAYER_EXTRA_SCALE: float = 1.0

## Where a hit on the player starts, relative to their hull bar, and how far it
## drifts. Both lean right: there is more open space on that side of the bar.
const _PLAYER_SPAWN_AREA: Rect2 = Rect2(-16.0, -20.0, 52.0, 18.0)
const _PLAYER_DRIFT_RANGE: Rect2 = Rect2(-6.0, -24.0, 20.0, 10.0)

## Room kept between a label and the edge of the screen.
const _SCREEN_MARGIN_PIXELS: float = 2.0

## How far past full size the label overshoots as it pops in.
const _POP_SCALE: float = 1.4

var _drift: Vector2 = Vector2(0.0, -_RISE_PIXELS)
var _rest_scale: Vector2 = Vector2.ONE
var _label: Label
var _lifetime: float = _LIFETIME_SECONDS


## Spawns a number for `amount` beside `target`. Parented beside the target
## rather than under it, so a killing blow's number outlives the ship.
static func spawn(target: Node2D, amount: int, color: Color) -> void:
	if amount <= 0 or not is_instance_valid(target) or target.get_parent() == null:
		return
	# Hits on the player land down in the cockpit corner while their eyes are on
	# the enemy that fired, so they print a size up to still catch the eye.
	var size: float = 1.0 + (_PLAYER_EXTRA_SCALE if target is Player else 0.0)
	# A random side, so back-to-back hits usually don't share a spot.
	var side: float = -1.0 if RNGManager.randf_range(RNGManager.Bucket.COSMETIC, 0.0, 1.0) < 0.5 else 1.0
	var origin: Vector2 = Juice.anchor_of(target) + Vector2(side * _DAMAGE_SIDE_PIXELS * size, 0.0)
	var drift: Vector2 = Vector2(side * _DAMAGE_DRIFT.x, _DAMAGE_DRIFT.y) * size
	# The player's bar sits in the bottom-left corner, so a sideways fall
	# carries their numbers straight out of frame, and a left-hand spot is
	# always pushed back to the same place against the edge. They start
	# anywhere over the bar and rise into the open starfield above it instead.
	if target is Player:
		origin = Juice.anchor_of(target) + _random_in(_PLAYER_SPAWN_AREA)
		drift = _random_in(_PLAYER_DRIFT_RANGE)
	_spawn_label(target.get_parent(), origin, str(amount), color, amount >= _BIG_HIT, drift, size, _LIFETIME_SECONDS)


static func _random_in(area: Rect2) -> Vector2:
	return Vector2(
		RNGManager.randf_range(RNGManager.Bucket.COSMETIC, area.position.x, area.end.x),
		RNGManager.randf_range(RNGManager.Bucket.COSMETIC, area.position.y, area.end.y)
	)


## The same pop-and-drift for any short label: a heal's "+3", a status name,
## an upgrade tile's "x2".
static func spawn_text(target: Node2D, text: String, color: Color, big: bool = false) -> void:
	if not is_instance_valid(target) or target.get_parent() == null:
		return
	var origin: Vector2 = Juice.anchor_of(target)
	spawn_text_at(target.get_parent(), origin + Vector2(0.0, _stack_offset(target)), text, color, big)


## A label at `global_pos`, parented to `parent`.
static func spawn_text_at(parent: Node, global_pos: Vector2, text: String, color: Color, big: bool = false) -> void:
	var lifetime: float = minf(_TEXT_LIFETIME_SECONDS + text.length() * _TEXT_SECONDS_PER_LETTER,
		_MAX_TEXT_LIFETIME_SECONDS)
	_spawn_label(parent, global_pos, text, color, big, Vector2(0.0, -_RISE_PIXELS), 1.0, lifetime)


static func _stack_offset(target: Node2D) -> float:
	var now: int = Time.get_ticks_msec()
	var id: int = target.get_instance_id()
	var entry: Dictionary = _recent_callouts.get(id, {"msec": -_STACK_WINDOW_MSEC, "count": 0})
	var count: int = (entry["count"] as int) + 1 if now - (entry["msec"] as int) < _STACK_WINDOW_MSEC else 0
	# Keyed by instance id, so drop expired ships rather than grow all run.
	for stale: int in _recent_callouts.keys():
		if now - (_recent_callouts[stale]["msec"] as int) >= _STACK_WINDOW_MSEC:
			_recent_callouts.erase(stale)
	_recent_callouts[id] = {"msec": now, "count": count}
	return -_STACK_STEP_PIXELS * count


## [param size] is a whole-number scale on top of the big-hit doubling, so the
## pixel font stays crisp.
static func _spawn_label(parent: Node, global_pos: Vector2, text: String, color: Color,
		big: bool, drift: Vector2, size: float = 1.0, lifetime: float = _LIFETIME_SECONDS) -> void:
	if text.is_empty() or not is_instance_valid(parent):
		return

	var number: DamageNumber = DamageNumber.new()
	number._build(text, color)
	number._drift = drift
	number._lifetime = lifetime
	number._rest_scale = Vector2.ONE * ((2.0 if big else 1.0) + size - 1.0)
	parent.add_child(number)
	number.global_position = global_pos + Vector2(
		RNGManager.randf_range(RNGManager.Bucket.COSMETIC, -_SCATTER_PIXELS, _SCATTER_PIXELS),
		-10.0
	)
	number._keep_on_screen()
	number._animate()


## Keeps the whole flight on screen: slides the start in from the edge if it
## would begin half off it (callouts off hardware at the edge of the cockpit, a
## wide word on a ship at the end of the formation), then shortens the drift
## so the label never carries itself out of frame before it has faded.
func _keep_on_screen() -> void:
	var screen: Rect2 = get_canvas_transform().affine_inverse() * get_viewport_rect()
	var half_size: Vector2 = _label.size * 0.5 * _rest_scale * _POP_SCALE + Vector2.ONE * _SCREEN_MARGIN_PIXELS
	var safe: Rect2 = screen.grow_individual(-half_size.x, -half_size.y, -half_size.x, -half_size.y)
	if safe.size.x <= 0.0 or safe.size.y <= 0.0:
		return
	global_position = global_position.clamp(safe.position, safe.end)
	var end: Vector2 = (global_position + _drift).clamp(safe.position, safe.end)
	_drift = end - global_position


func _build(text: String, color: Color) -> void:
	# Above ships, particles and the cockpit frame.
	z_index = 100

	_label = Label.new()
	_label.text = text
	_label.add_theme_font_override("font", _FONT)
	_label.add_theme_font_size_override("font_size", _FONT_SIZE)
	_label.add_theme_color_override("font_color", color)
	_label.add_theme_color_override("font_outline_color", Globals.dark_gray)
	_label.add_theme_constant_override("outline_size", 4)
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	add_child(_label)
	# Centre the label on this node so scaling pops from the middle.
	_label.reset_size()
	_label.position = -_label.size / 2.0


## Pops in past full size, drifts up, and fades out on the way.
func _animate() -> void:
	var rest_scale: Vector2 = _rest_scale
	scale = rest_scale * 0.4

	var tween: Tween = create_tween()
	tween.tween_property(self, "scale", rest_scale * _POP_SCALE, 0.08) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "scale", rest_scale, 0.12) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(self, "position", position + _drift, _lifetime) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	# Fades over a fixed stretch at the end, so a longer life is all reading time.
	var fade: float = _LIFETIME_SECONDS * 0.4
	tween.parallel().tween_property(self, "modulate:a", 0.0, fade) \
		.set_delay(_lifetime - fade)
	tween.finished.connect(queue_free)
