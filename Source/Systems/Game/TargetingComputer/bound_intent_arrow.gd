class_name BoundIntentArrow
extends Node2D
## A crisp directional arc from the targeted ship to a ship some of its slots are bound
## to ("on a 1, the Tender repairs *that* one"), backed by a subtle dark plate so it
## stands out against the background and ship hull art.
##
## The badge riding the arc organizes bound die faces, action icons, and their amounts.
## Multiple bound arrows in the formation are dynamically separated by TargetingComputer
## so their paths, arrowheads, and badges never overlap.
##
## Drawn in world pixels on whole-pixel positions, out of axis-aligned 1px
## rects only, so it stays on the art's pixel grid under the 6x camera.
## Redrawn every frame: ships and their idle bobs move smoothly.

const _DIE_FACES_LIT: Texture2D = preload(
	"res://Assets/Textures/TargetingComputer/intent_dice_indicator_held-Sheet.png"
)
const _DIE_FACES_DIM: Texture2D = preload(
	"res://Assets/Textures/TargetingComputer/intent_dice_indicator_default-Sheet.png"
)

## Approved palette: the bright colour and its dark shade, per binding.
const _ALLY_LIT: Color = Color("#7abd33")
const _ALLY_DIM: Color = Color("#4c7520")
const _HOSTILE_LIT: Color = Color("#d03656")
const _HOSTILE_DIM: Color = Color("#90263c")
const _PLATE: Color = Color("#0f0c2e")
const _PLATE_SHADOW: Color = Color(0.02, 0.01, 0.06, 0.6)

## Die faces and intent icons are both this square.
const _ICON: int = 7
## Spacing between directional chevrons along the arc, and how fast they march while live.
const _CHEVRON_SPACING: float = 16.0
const _MARCH_SPEED: float = 12.0
## How high the arc rises over the straight line between the ships, as a
## share of their distance, within these bounds.
const _LIFT_SHARE: float = 0.4
const _LIFT_RANGE: Vector2 = Vector2(18.0, 34.0)
## The arc's top never rises above this, so the badge stays on screen. High,
## to clear the hull and shield badges each ship carries on its upper left.
const _MIN_APEX_Y: float = 8.0
## Clearance between the arc's ends and the ships' art.
const _END_GAP: float = 3.0
## Default badge position share along the arc from its left end.
const _BADGE_ALONG: float = 0.4
## Points sampled along the curve to calculate length and path points.
const _SAMPLES: int = 48

var source: Enemy
var target: Enemy
var hostile: bool = false
## Slot indices (die face - 1) of source's actions bound to target.
var slots: Array[int] = []
## Answers whether one of source's slots is live. Bound by the targeting
## computer, which knows which slot a ship is playing right now.
var is_live: Callable

## Dynamic layout offsets set by TargetingComputer._layout_bound_arrows to avoid overlaps.
var arc_lift_offset: float = 0.0
var source_offset_x: float = 0.0
var badge_along: float = _BADGE_ALONG
var badge_offset_y: float = 0.0

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
		_march = fposmod(_march + delta * _MARCH_SPEED, _CHEVRON_SPACING)
	queue_redraw()


func _draw() -> void:
	if not _ships_present():
		return
	var live: bool = _any_live()
	var color: Color = _line_color(live)
	var from: Vector2 = _anchor(source) + Vector2(source_offset_x, 0.0)
	var to: Vector2 = _anchor(target)
	var control: Vector2 = control_point(from, to, arc_lift_offset)

	var path: PackedVector2Array = _sample(from, control, to)
	var length: float = _length(path)

	_draw_arrow_body(path, length, color, live)
	_draw_head(to, color)

	var effective_t: float = badge_along if from.x <= to.x else 1.0 - badge_along
	_draw_badge(_point_on(from, control, to, effective_t), live)


## Draws the solid continuous arc with a subtle dark backing plate, plus
## directional chevrons showing the flow toward the target ship.
func _draw_arrow_body(path: PackedVector2Array, length: float, color: Color, live: bool) -> void:
	if length <= 5.0:
		return

	# Collect integer pixels along the curve, stopping short of the arrowhead.
	var line_pixels: Dictionary = {}
	var step_dist: float = 0.0
	var end_dist: float = maxf(0.0, length - 4.0)
	while step_dist <= end_dist:
		var pt: Vector2i = Vector2i(_point_at(path, step_dist).round())
		line_pixels[pt] = true
		step_dist += 0.8

	# Generate subtle dark backing plate around the line pixels
	var plate_pixels: Dictionary = {}
	var offsets: Array[Vector2i] = [
		Vector2i(-1, 0), Vector2i(1, 0),
		Vector2i(0, -1), Vector2i(0, 1),
	]
	for pt: Vector2i in line_pixels.keys():
		for off: Vector2i in offsets:
			var n: Vector2i = pt + off
			if not line_pixels.has(n):
				plate_pixels[n] = true

	# 1. Subtle dark background plate
	for pt: Vector2i in plate_pixels.keys():
		draw_rect(Rect2(Vector2(pt), Vector2.ONE), _PLATE)

	# 2. Solid crisp line
	for pt: Vector2i in line_pixels.keys():
		draw_rect(Rect2(Vector2(pt), Vector2.ONE), color)

	# 3. Directional chevrons along the line pointing toward target
	var chevron_start: float = _march if live else 8.0
	var cur: float = chevron_start
	var chevron_col: Color = Globals.white if live else color
	while cur < end_dist - 3.0:
		if cur >= 3.0:
			_draw_chevron(_point_at(path, cur), _point_at(path, cur + 2.0), chevron_col)
		cur += _CHEVRON_SPACING


## A small 3-pixel directional chevron pointing forward along the arc.
func _draw_chevron(at: Vector2, next_pt: Vector2, col: Color) -> void:
	var dir: Vector2 = (next_pt - at).normalized()
	var center: Vector2i = Vector2i(at.round())
	var dx: int = 1 if dir.x >= 0.0 else -1
	var dy: int = 1 if dir.y >= 0.0 else -1

	# Plate backing for the chevron wings
	draw_rect(Rect2(Vector2(center + Vector2i(-dx * 2, -dy)), Vector2.ONE), _PLATE)
	draw_rect(Rect2(Vector2(center + Vector2i(-dx * 2, dy)), Vector2.ONE), _PLATE)

	# Crisp colored chevron
	draw_rect(Rect2(Vector2(center), Vector2.ONE), col)
	if absf(dir.x) >= absf(dir.y):
		draw_rect(Rect2(Vector2(center + Vector2i(-dx, -1)), Vector2.ONE), col)
		draw_rect(Rect2(Vector2(center + Vector2i(-dx, 1)), Vector2.ONE), col)
	else:
		draw_rect(Rect2(Vector2(center + Vector2i(-1, -dy)), Vector2.ONE), col)
		draw_rect(Rect2(Vector2(center + Vector2i(1, -dy)), Vector2.ONE), col)


## A crisp directional arrowhead with a dark backing plate, pointing down
## onto the target ship's anchor.
func _draw_head(tip: Vector2, color: Color) -> void:
	var at: Vector2i = Vector2i(tip.floor())

	# Subtle dark backing plate for the arrowhead
	draw_rect(Rect2(Vector2(at.x - 4, at.y - 4), Vector2(9, 1)), _PLATE)
	draw_rect(Rect2(Vector2(at.x - 4, at.y - 3), Vector2(9, 1)), _PLATE)
	draw_rect(Rect2(Vector2(at.x - 3, at.y - 2), Vector2(7, 1)), _PLATE)
	draw_rect(Rect2(Vector2(at.x - 2, at.y - 1), Vector2(5, 1)), _PLATE)
	draw_rect(Rect2(Vector2(at.x - 1, at.y), Vector2(3, 1)), _PLATE)
	draw_rect(Rect2(Vector2(at.x, at.y + 1), Vector2.ONE), _PLATE)

	# Crisp colored arrowhead pointing into the ship
	draw_rect(Rect2(Vector2(at.x - 3, at.y - 3), Vector2(7, 1)), color)
	draw_rect(Rect2(Vector2(at.x - 2, at.y - 2), Vector2(5, 1)), color)
	draw_rect(Rect2(Vector2(at.x - 1, at.y - 1), Vector2(3, 1)), color)
	draw_rect(Rect2(Vector2(at.x, at.y), Vector2.ONE), color)


## The arc's plate, centred across [param on] and sat on top of it, so it
## stays clear of the hull badges the arc passes over.
func _draw_badge(on: Vector2, live: bool) -> void:
	var groups: Array = _group_slots()
	var total_width: int = _badge_width_for_groups(groups)
	var size: Vector2 = Vector2(total_width, _ICON + 3)
	var at: Vector2 = Vector2(roundf(on.x - total_width * 0.5), roundf(on.y) - (_ICON + 2) + badge_offset_y)
	if at.y < 2.0:
		at.y = 2.0

	# 1. Subtle dark drop shadow
	draw_rect(Rect2(at + Vector2(1, 1), size), _PLATE_SHADOW)
	# 2. Subtle dark background plate
	draw_rect(Rect2(at, size), _PLATE)
	# 3. Crisp border
	draw_rect(Rect2(at, size), _line_color(live), false, 1.0)

	var x: float = at.x + 2
	for g_idx: int in range(groups.size()):
		var group: Dictionary = groups[g_idx]
		var group_slots: Array = group.get("slots", [])
		for slot_val: Variant in group_slots:
			var slot: int = int(slot_val)
			var faces: Texture2D = _DIE_FACES_LIT if _slot_live(slot) else _DIE_FACES_DIM
			draw_texture_rect_region(faces, Rect2(Vector2(x, at.y + 1), Vector2(_ICON, _ICON)),
				Rect2(slot * _ICON, 0, _ICON, _ICON))
			x += _ICON + 1
		var icon: Texture2D = group.get("icon", null)
		if icon:
			draw_texture(icon, Vector2(x, at.y + 1))
			x += _ICON + 1
		var amount: String = group.get("amount", "")
		if not amount.is_empty():
			draw_string(FontRoles.font(FontRoles.BODY), Vector2(x, at.y + _ICON + 1), amount,
				HORIZONTAL_ALIGNMENT_LEFT, -1, FontRoles.size(FontRoles.BODY), Globals.white)
			x += ceili(FontRoles.font(FontRoles.BODY).get_string_size(amount,
				HORIZONTAL_ALIGNMENT_LEFT, -1, FontRoles.size(FontRoles.BODY)).x) + 1
		if g_idx < groups.size() - 1:
			# Subtle 1px vertical divider line between distinct assist actions
			draw_line(Vector2(roundf(x + 1), at.y + 2), Vector2(roundf(x + 1), at.y + _ICON + 1),
				_line_color(live).darkened(0.4), 1.0)
			x += 4


## Calculates the bounding rect for this arrow's badge.
func get_badge_rect() -> Rect2:
	if not _ships_present():
		return Rect2()
	var from: Vector2 = _anchor(source) + Vector2(source_offset_x, 0.0)
	var to: Vector2 = _anchor(target)
	var control: Vector2 = control_point(from, to, arc_lift_offset)
	var effective_t: float = badge_along if from.x <= to.x else 1.0 - badge_along
	var on: Vector2 = _point_on(from, control, to, effective_t)
	var total_width: int = _badge_width_for_groups(_group_slots())
	var at: Vector2 = Vector2(roundf(on.x - total_width * 0.5), roundf(on.y) - (_ICON + 2) + badge_offset_y)
	if at.y < 2.0:
		at.y = 2.0
	return Rect2(at, Vector2(total_width, _ICON + 3))


## Groups slots by distinct action so each assist displays its own die faces,
## icon, and amount cleanly.
func _group_slots() -> Array[Dictionary]:
	var groups: Array[Dictionary] = []
	for slot: int in slots:
		var action: EnemyActionResource = _action(slot)
		var found: Dictionary = {}
		for g: Dictionary in groups:
			if g.get("action", null) == action:
				found = g
				break
		if found.is_empty():
			var new_g: Dictionary = {
				"action": action,
				"slots": [slot],
				"icon": action.indicator_texture if action else null,
				"amount": action.get_landing_amount_text(source) if action else ""
			}
			groups.append(new_g)
		else:
			found["slots"].append(slot)
	return groups


## Width of the badge containing the given slot groups.
func _badge_width_for_groups(groups: Array[Dictionary]) -> int:
	if groups.is_empty():
		return 8
	var w: int = 3
	for i: int in range(groups.size()):
		var g: Dictionary = groups[i]
		var group_slots: Array = g.get("slots", [])
		w += group_slots.size() * (_ICON + 1)
		if g.get("icon", null) != null:
			w += _ICON + 1
		var amount: String = g.get("amount", "")
		if not amount.is_empty():
			w += ceili(FontRoles.font(FontRoles.BODY).get_string_size(amount,
				HORIZONTAL_ALIGNMENT_LEFT, -1, FontRoles.size(FontRoles.BODY)).x) + 1
		if i < groups.size() - 1:
			w += 4
	return w


## The arc's control point: lifted over the midpoint of [param from] and
## [param to] by a share of their distance, held below the screen's top.
static func control_point(from: Vector2, to: Vector2, lift_offset: float = 0.0) -> Vector2:
	var lift: float = clampf(from.distance_to(to) * _LIFT_SHARE + lift_offset, _LIFT_RANGE.x, _LIFT_RANGE.y + lift_offset)
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
	return action.get_landing_amount_text(source) if action else ""
