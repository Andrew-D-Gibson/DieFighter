class_name EnemyFormation
extends RefCounted
## Works out where ships stand along the enemy spawning path.
##
## Scenarios used to author a hard-coded spot for every ship they spawned. That
## only ever produced one correct layout: the roster the scenario happened to
## start with, on a screen with nothing else on it. A ship dying left a gap, the
## shop panel opened on top of whoever was standing there, and the tutorial's
## popups covered the one enemy they were talking about.
##
## So position is derived instead. A scenario says who shows up and in what
## order; this decides where they go, from how wide they are and how much of
## the screen is currently free. One ship centres itself, a wing spreads evenly,
## and the survivors close ranks when one of them dies. "How wide" means the
## whole footprint a ship draws, not just its hull: a health bar hanging off
## one ship's side must not land on the hull beside it.
##
## Space is taken away by reservations — a screen-space x span claimed by
## something else on screen (the shop panel, the tutorial's popups, a ship that
## a scenario effect deliberately parked somewhere). Each is keyed by its owner
## so it can be dropped again, and the formation re-expands when it is.
##
## Everything here is in screen-space x. Turning that back into a position along
## the curve is [EnemyManager]'s job.


## The full stretch of screen the formation may use, before reservations.
var usable_span: Vector2 = Vector2(40.0, 280.0)

## Narrowest gap allowed between two ships' footprints. When the free space can't
## give everyone this much, the formation overflows its free span rather than
## stacking ships on top of each other — a ship half-behind the shop panel is
## bad, two ships in the same pixel is worse.
var min_ship_gap: float = 8.0

## The stretch of screen a ship's speech box may use. Wider than
## [member usable_span]: a ship has to stand clear of the screen edge so its
## health bar stays visible, but its speech can run right up to it.
var speech_span: Vector2 = Vector2(0.0, 320.0)

## How much more room the left side needs before a speech box moves there. The
## box is drawn pointing right, so that side wins a near-tie.
const _SPEECH_SIDE_BIAS: float = 1.0

var _reservations: Dictionary[StringName, Vector2] = {}


## Claims [param span] for [param key], replacing any span that key already
## held. Returns whether this actually changed the layout, so callers can skip
## a pointless reflow.
func reserve(key: StringName, span: Vector2) -> bool:
	var ordered: Vector2 = Vector2(minf(span.x, span.y), maxf(span.x, span.y))
	if _reservations.get(key, Vector2.INF) == ordered:
		return false
	_reservations[key] = ordered
	return true


## The reservation key for space a particular ship holds (a pinned spot, a
## seat on a hull).
static func ship_key(ship: Node) -> StringName:
	return StringName("ship_%d" % ship.get_instance_id())


## Gives [param key]'s claimed space back. Returns whether anything was held.
func clear_reservation(key: StringName) -> bool:
	return _reservations.erase(key)


func has_reservation(key: StringName) -> bool:
	return _reservations.has(key)


## The span [param key] holds, or [constant Vector2.ZERO] if it holds none.
func get_reservation(key: StringName) -> Vector2:
	return _reservations.get(key, Vector2.ZERO)


## Where ships with hulls [param widths] wide should stand, left to right.
## Each ship's footprint is just its hull. See [method solve_footprints].
func solve(widths: PackedFloat32Array) -> PackedFloat32Array:
	return solve_footprints(symmetric_footprints(widths))


## Where ships taking up [param footprints] should stand, left to right. Each
## footprint is how far the ship reaches to the left (x) and right (y) of its
## centre — its hull, plus whatever hangs off it, like a health bar. Returns
## centres.
##
## Every ship gets the same gap to its neighbours and half that gap to the ends
## of the free span. Measuring gaps between footprints rather than between
## centres keeps a capital ship from parking on top of its escorts, and keeps
## one ship's health bar off the hull beside it; giving the ends only half a
## gap spreads a pair out across the screen rather than bunching them in the
## middle, which leaves room between them for their dice and their speech.
##
## A reservation in the middle of the screen (salvage floating where the wreck
## was) leaves free space on both sides of it. The wing then splits across
## them, keeping its left-to-right order, whichever way gives the most crowded
## ship the most room — rather than crushing everyone into the wider half.
##
## A ship alone in its stretch centres its hull rather than its footprint, as
## long as the footprint still fits: one lopsided ship has nobody to crowd,
## and an off-centre lone ship just looks misplaced.
func solve_footprints(footprints: PackedVector2Array) -> PackedFloat32Array:
	var positions: PackedFloat32Array = PackedFloat32Array()
	var count: int = footprints.size()
	if count == 0:
		return positions

	var widths: PackedFloat32Array = _footprint_widths(footprints)
	var stretches: Array[Vector2] = get_free_stretches()
	var groups: PackedInt32Array = _best_split(widths, stretches)
	if count > 1 and _split_gap(widths, stretches, groups) < min_ship_gap:
		return _overflow_positions(footprints, get_free_span())

	var first: int = 0
	for i: int in range(stretches.size()):
		var group: PackedVector2Array = footprints.slice(first, first + groups[i])
		first += groups[i]
		if group.is_empty():
			continue
		var span: Vector2 = stretches[i]
		if group.size() == 1:
			var reach: Vector2 = group[0]
			positions.append(clampf(
				(span.x + span.y) * 0.5,
				span.x + reach.x,
				maxf(span.x + reach.x, span.y - reach.y)
			))
			continue
		var gap: float = (span.y - span.x - _total(_footprint_widths(group))) / float(group.size())
		var edge: float = span.x + gap * 0.5
		for reach: Vector2 in group:
			positions.append(edge + reach.x)
			edge += reach.x + reach.y + gap
	return positions


## Whether ships taking up [param footprints] fit the free space with at least
## [member min_ship_gap] between them. When they don't, [method solve_footprints]
## overflows; a caller with a slimmer way to draw its ships can try that first.
func fits(footprints: PackedVector2Array) -> bool:
	if footprints.size() <= 1:
		return true
	var widths: PackedFloat32Array = _footprint_widths(footprints)
	var stretches: Array[Vector2] = get_free_stretches()
	return _split_gap(widths, stretches, _best_split(widths, stretches)) >= min_ship_gap


## Footprints for ships that are nothing but their hulls.
static func symmetric_footprints(widths: PackedFloat32Array) -> PackedVector2Array:
	var footprints: PackedVector2Array = PackedVector2Array()
	for width: float in widths:
		footprints.append(Vector2(width * 0.5, width * 0.5))
	return footprints


## Whether a ship standing at [param x] should put its speech box on its left
## rather than its right. The box goes to whichever side has more room before
## it runs into another ship's half of the gap between them, reserved space, or
## the edge of the screen. Two ships side by side end up talking outward, away
## from each other, instead of one talking over the other.
func speech_points_left(x: float, other_ships: PackedFloat32Array) -> bool:
	var room: Vector2 = speech_room(x, other_ships)
	return room.x > room.y + _SPEECH_SIDE_BIAS


## How far a speech box from a ship at [param x] can reach to its left (x) and
## right (y) before running into anything. See [method speech_points_left].
func speech_room(x: float, other_ships: PackedFloat32Array) -> Vector2:
	var left_limit: float = speech_span.x
	var right_limit: float = speech_span.y

	for other: float in other_ships:
		var halfway: float = (x + other) * 0.5
		if other < x:
			left_limit = maxf(left_limit, halfway)
		elif other > x:
			right_limit = minf(right_limit, halfway)

	for reserved: Vector2 in _reservations.values():
		# Space reserved around the ship itself is its own pin, or somewhere it
		# overflowed into. Either way it says nothing about which side is clear.
		if reserved.x <= x and x <= reserved.y:
			continue
		if reserved.y <= x:
			left_limit = maxf(left_limit, reserved.y)
		else:
			right_limit = minf(right_limit, reserved.x)

	return Vector2(x - left_limit, right_limit - x)


## The widest unreserved stretch of [member usable_span]. Falls back to the
## whole span when reservations have swallowed all of it, so a ship always has
## somewhere to be.
func get_free_span() -> Vector2:
	var widest: Vector2 = usable_span
	var widest_width: float = -1.0
	for stretch: Vector2 in get_free_stretches():
		var width: float = stretch.y - stretch.x
		if width > widest_width:
			widest_width = width
			widest = stretch
	return widest


## Every unreserved stretch of [member usable_span], left to right. Just the
## whole span when reservations have swallowed all of it.
func get_free_stretches() -> Array[Vector2]:
	var free: Array[Vector2] = [usable_span]

	for reserved: Vector2 in _reservations.values():
		var remaining: Array[Vector2] = []
		for stretch: Vector2 in free:
			remaining.append_array(_subtract(stretch, reserved))
		free = remaining

	if free.is_empty():
		return [usable_span]
	free.sort_custom(func(a: Vector2, b: Vector2) -> bool: return a.x < b.x)
	return free


## How many ships, taken in order, go in each of [param stretches]: the split
## whose tightest gap is widest. Ties go to the split found first, which puts
## ships further left.
func _best_split(widths: PackedFloat32Array, stretches: Array[Vector2]) -> PackedInt32Array:
	var best: PackedInt32Array = PackedInt32Array()
	var best_gap: float = -INF
	for split: PackedInt32Array in _splits(widths.size(), stretches.size()):
		var gap: float = _split_gap(widths, stretches, split)
		if gap > best_gap:
			best_gap = gap
			best = split
	return best


## The tightest gap any ship gets under [param split]. See [method solve].
func _split_gap(widths: PackedFloat32Array, stretches: Array[Vector2], split: PackedInt32Array) -> float:
	var tightest: float = INF
	var first: int = 0
	for i: int in range(stretches.size()):
		if split[i] == 0:
			continue
		var group: PackedFloat32Array = widths.slice(first, first + split[i])
		first += split[i]
		var room: float = stretches[i].y - stretches[i].x - _total(group)
		tightest = minf(tightest, room / float(split[i]))
	return tightest


## Every way of dealing [param count] ships out, in order, across [param parts]
## stretches, empty stretches allowed. A handful of ships over a handful of
## stretches is at most a few hundred splits.
static func _splits(count: int, parts: int) -> Array[PackedInt32Array]:
	var out: Array[PackedInt32Array] = []
	if parts == 1:
		out.append(PackedInt32Array([count]))
		return out
	# Most-in-the-first-stretch first, so ties settle leftward.
	for here: int in range(count, -1, -1):
		for rest: PackedInt32Array in _splits(count - here, parts - 1):
			var split: PackedInt32Array = PackedInt32Array([here])
			split.append_array(rest)
			out.append(split)
	return out


## [param stretch] minus [param reserved]: nothing, one side, or both sides.
func _subtract(stretch: Vector2, reserved: Vector2) -> Array[Vector2]:
	if reserved.y <= stretch.x or reserved.x >= stretch.y:
		return [stretch]

	var remainder: Array[Vector2] = []
	if reserved.x > stretch.x:
		remainder.append(Vector2(stretch.x, reserved.x))
	if reserved.y < stretch.y:
		remainder.append(Vector2(reserved.y, stretch.y))
	return remainder


## Too many ships for the free span: line them up at the minimum gap, centred
## on the free space, and slide the whole line back inside the usable span if
## that pushed anyone off the edge of the screen.
func _overflow_positions(footprints: PackedVector2Array, span: Vector2) -> PackedFloat32Array:
	var line_width: float = _total(_footprint_widths(footprints)) \
		+ min_ship_gap * float(footprints.size() - 1)
	var start: float = (span.x + span.y) * 0.5 - line_width * 0.5
	start = clampf(
		start,
		usable_span.x,
		maxf(usable_span.x, usable_span.y - line_width)
	)

	var positions: PackedFloat32Array = PackedFloat32Array()
	var edge: float = start
	for reach: Vector2 in footprints:
		positions.append(edge + reach.x)
		edge += reach.x + reach.y + min_ship_gap
	return positions


static func _footprint_widths(footprints: PackedVector2Array) -> PackedFloat32Array:
	var widths: PackedFloat32Array = PackedFloat32Array()
	for reach: Vector2 in footprints:
		widths.append(reach.x + reach.y)
	return widths


static func _total(values: PackedFloat32Array) -> float:
	var total: float = 0.0
	for value: float in values:
		total += value
	return total
