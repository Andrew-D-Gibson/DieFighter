class_name BoundIntentArrow
extends Node2D
## A dotted arc from the targeted ship to a ship some of its slots are bound
## to ("on a 1, the Tender repairs *that* one"), with one badge riding the
## arc: the die faces that act there and an icon for each kind of thing they
## do. The amount only shows when every face shares it; otherwise the
## targeting computer's row of intents, right below, has each face's own.
## A badge per amount used to put three plates on one arc for a ship that
## shields an escort for 2, 3 and 4.
##
## Escorts often share a name, so the intent text alone can't say which ship
## a slot means. A marker on the far ship said which, but not who it came
## from or what it would do; the arc reads as "this ship -> that one, on a 1,
## shields 3". Green for help to an ally, red for a raid on another ship.
##
## A slot the ship holds the die for (or is playing now) is live: its face
## lights and the dots march toward the target. With none live the arc sits
## dim and still, like the targeting computer's unlit intents.
##
## Drawn in world pixels on whole-pixel positions, out of axis-aligned 1px
## rects only, so it stays on the art's pixel grid under the 6x camera.
## Redrawn every frame: the dots move, and so do ships closing up a gap.

const _DIE_FACES_LIT: Texture2D = preload(
	"res://Assets/Textures/TargetingComputer/intent_dice_indicator_held-Sheet.png"
)
const _DIE_FACES_DIM: Texture2D = preload(
	"res://Assets/Textures/TargetingComputer/intent_dice_indicator_default-Sheet.png"
)
const _FONT: Font = preload("res://Assets/Fonts/m5x7/m5x7_ui.tres")
const _FONT_SIZE: int = 16

## Approved palette: the bright colour and its dark shade, per binding.
const _ALLY_LIT: Color = Color("#7abd33")
const _ALLY_DIM: Color = Color("#4c7520")
const _HOSTILE_LIT: Color = Color("#d03656")
const _HOSTILE_DIM: Color = Color("#90263c")
const _PLATE: Color = Color("#0f0c2e")

## Die faces and intent icons are both this square.
const _ICON: int = 7
## Pixels between dots along the arc, and how fast they march while live.
const _DOT_SPACING: float = 3.0
const _MARCH_SPEED: float = 9.0
## How high the arc rises over the straight line between the ships, as a
## share of their distance, within these bounds.
const _LIFT_SHARE: float = 0.4
const _LIFT_RANGE: Vector2 = Vector2(18.0, 34.0)
## The arc's top never rises above this, so the badge stays on screen. High,
## to clear the hull and shield badges each ship carries on its upper left.
const _MIN_APEX_Y: float = 8.0
## Clearance between the arc's ends and the ships' art.
const _END_GAP: float = 3.0
## How far along the arc, from its left end, the badge sits. Short of the
## middle: every ship carries its hull and shield badges on its upper left,
## so the right-hand end of an arc is the crowded one.
const _BADGE_ALONG: float = 0.4
## Points sampled along the curve to space the dots evenly.
const _SAMPLES: int = 48

var source: Enemy
var target: Enemy
var hostile: bool = false
## Slot indices (die face - 1) of source's actions bound to target.
var slots: Array[int] = []
## Answers whether one of source's slots is live. Bound by the targeting
## computer, which knows which slot a ship is playing right now.
var is_live: Callable

var _march: float = 0.0


func _ready() -> void:
	top_level = true
	global_position = Vector2.ZERO


func _process(delta: float) -> void:
	if not _ships_present():
		hide()
		return
	show()
	if _any_live():
		_march = fposmod(_march + delta * _MARCH_SPEED, _DOT_SPACING)
	queue_redraw()


func _draw() -> void:
	if not _ships_present():
		return
	var live: bool = _any_live()
	var color: Color = _line_color(live)
	var from: Vector2 = _anchor(source)
	var to: Vector2 = _anchor(target)
	var control: Vector2 = control_point(from, to)

	var path: PackedVector2Array = _sample(from, control, to)
	var length: float = _length(path)
	# The dots stop short of the head, which carries on the line itself.
	var offset: float = _march if live else 0.0
	var along: float = offset
	while along < length - 3.0:
		_pixel(_point_at(path, along), color)
		along += _DOT_SPACING
	_draw_head(to, color)
	var badge_t: float = _BADGE_ALONG if from.x <= to.x else 1.0 - _BADGE_ALONG
	_draw_badge(_point_on(from, control, to, badge_t), live)


## The arc's control point: lifted over the midpoint of [param from] and
## [param to] by a share of their distance, held below the screen's top.
static func control_point(from: Vector2, to: Vector2) -> Vector2:
	var lift: float = clampf(from.distance_to(to) * _LIFT_SHARE, _LIFT_RANGE.x, _LIFT_RANGE.y)
	var control: Vector2 = (from + to) * 0.5 - Vector2(0, lift)
	# The apex sits halfway between the ends' midpoint and the control point.
	var apex_y: float = ((from.y + to.y) * 0.5 + control.y) * 0.5
	if apex_y < _MIN_APEX_Y:
		control.y += (_MIN_APEX_Y - apex_y) * 2.0
	return control


func _ships_present() -> bool:
	return _alive(source) and _alive(target)


## Untyped on purpose: a freed ship passed into an Enemy-typed parameter is a
## script error, not false, and the arrow can outlive either end for a frame.
static func _alive(ship: Variant) -> bool:
	if not is_instance_valid(ship):
		return false
	var enemy: Enemy = ship as Enemy
	return enemy != null and enemy.health != null and enemy.health.health > 0


func _any_live() -> bool:
	for slot: int in slots:
		if _slot_live(slot):
			return true
	return false


func _slot_live(slot: int) -> bool:
	return is_live.is_valid() and is_live.call(source, slot)


func _line_color(live: bool) -> Color:
	if hostile:
		return _HOSTILE_LIT if live else _HOSTILE_DIM
	return _ALLY_LIT if live else _ALLY_DIM


## Just over the top-middle of [param ship]'s art.
static func _anchor(ship: Enemy) -> Vector2:
	var art: Node2D = ship.graphics_manager.ship_graphics if ship.graphics_manager else null
	var top: float = -16.0
	var at: Vector2 = ship.global_position
	if art is Sprite2D:
		var sprite: Sprite2D = art
		var rect: Rect2 = sprite.get_rect()
		at = sprite.global_transform * Vector2(rect.get_center().x, rect.position.y)
		top = 0.0
	return (at + Vector2(0, top - _END_GAP)).round()


static func _point_on(from: Vector2, control: Vector2, to: Vector2, t: float) -> Vector2:
	var u: float = 1.0 - t
	return from * u * u + control * 2.0 * u * t + to * t * t


static func _sample(from: Vector2, control: Vector2, to: Vector2) -> PackedVector2Array:
	var points: PackedVector2Array = PackedVector2Array()
	for i: int in _SAMPLES + 1:
		points.append(_point_on(from, control, to, float(i) / _SAMPLES))
	return points


static func _length(path: PackedVector2Array) -> float:
	var total: float = 0.0
	for i: int in range(1, path.size()):
		total += path[i - 1].distance_to(path[i])
	return total


## The point [param distance] along [param path].
static func _point_at(path: PackedVector2Array, distance: float) -> Vector2:
	for i: int in range(1, path.size()):
		var step: float = path[i - 1].distance_to(path[i])
		if distance <= step:
			return path[i - 1].lerp(path[i], distance / step if step > 0.0 else 0.0)
		distance -= step
	return path[path.size() - 1]


func _pixel(at: Vector2, color: Color) -> void:
	draw_rect(Rect2(at.floor(), Vector2.ONE), color)


## A small chevron pointing down onto the target: the arc always comes down
## onto its top.
func _draw_head(tip: Vector2, color: Color) -> void:
	var at: Vector2 = tip.floor()
	draw_rect(Rect2(at + Vector2(-2, -2), Vector2(5, 1)), color)
	draw_rect(Rect2(at + Vector2(-1, -1), Vector2(3, 1)), color)
	draw_rect(Rect2(at, Vector2.ONE), color)


## The arc's plate, centred across [param on] and sat on top of it, so it
## stays clear of the hull badges the arc passes over.
func _draw_badge(on: Vector2, live: bool) -> void:
	var icons: Array[Texture2D] = _icons()
	var amount: String = _shared_amount()
	var size: Vector2 = Vector2(_badge_width(icons.size(), amount), _ICON + 2)
	var at: Vector2 = Vector2(roundf(on.x - size.x * 0.5), roundf(on.y) - (_ICON + 1))
	draw_rect(Rect2(at, size), _PLATE)
	draw_rect(Rect2(at, size), _line_color(live), false, 1.0)

	var x: float = at.x + 1
	for slot: int in slots:
		var faces: Texture2D = _DIE_FACES_LIT if _slot_live(slot) else _DIE_FACES_DIM
		draw_texture_rect_region(faces, Rect2(Vector2(x, at.y + 1), Vector2(_ICON, _ICON)),
			Rect2(slot * _ICON, 0, _ICON, _ICON))
		x += _ICON + 1
	for icon: Texture2D in icons:
		draw_texture(icon, Vector2(x, at.y + 1))
		x += _ICON + 1
	if not amount.is_empty():
		draw_string(_FONT, Vector2(x, at.y + _ICON + 1), amount, HORIZONTAL_ALIGNMENT_LEFT, -1,
			_FONT_SIZE, Globals.white)


## Border, a face per slot, an icon per kind, the amount, border; a pixel
## apart.
func _badge_width(icon_count: int, amount: String) -> int:
	var width: int = 1 + (slots.size() + icon_count) * (_ICON + 1)
	if not amount.is_empty():
		width += 1 + ceili(_FONT.get_string_size(amount, HORIZONTAL_ALIGNMENT_LEFT, -1, _FONT_SIZE).x)
	return width


## The bound slots' intent icons, each once, in table order.
func _icons() -> Array[Texture2D]:
	var icons: Array[Texture2D] = []
	for slot: int in slots:
		var action: EnemyActionResource = _action(slot)
		if action and action.indicator_texture and action.indicator_texture not in icons:
			icons.append(action.indicator_texture)
	return icons


## The amount every bound slot shares, or "" when they differ or do
## different things.
func _shared_amount() -> String:
	if slots.is_empty() or _icons().size() > 1:
		return ""
	var amount: String = _amount_text(slots[0])
	for slot: int in slots:
		if _amount_text(slot) != amount:
			return ""
	return amount


func _action(slot: int) -> EnemyActionResource:
	if slot < 0 or slot >= source.turn_actions.size():
		return null
	return source.turn_actions[slot]


func _amount_text(slot: int) -> String:
	var action: EnemyActionResource = _action(slot)
	return action.get_intent_amount_text() if action else ""
