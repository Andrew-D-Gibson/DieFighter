class_name ArrivalFormation
extends RefCounted
## The Caravan's travelling formation (RECKONING_ENDINGS.md §6, The
## formation): a broad chevron flying right, one slot for every ship the run
## could have saved, so a missing ship reads as a gap.
##
## The chevron's point is the player's place. It's never a slot: the player
## takes it in the perfect Convoy, and it's the gap kept open in the Last Die.
## Until then the player flies at the rear (see rear()). Slots run back from
## the point in pairs, one on each arm, nearest the front first.

enum Kind {
	## Jumped out of the Reckoning with a die: arrives.
	OUT,
	## Still on the board or still queued when the fight ended: a jump that
	## tries to follow and never arrives.
	LEFT_BEHIND,
	## Lost in the fight, or a chance missed during the run: simply empty.
	EMPTY,
}

## One place in the chevron.
class Slot:
	var kind: Kind
	## Enemy id of the ship that fills it or failed to; "" for an empty slot
	## nobody was ever named for.
	var enemy_id: String = ""
	## Its place in the chevron, 0 nearest the front.
	var index: int = 0

## Where the chevron's point is, in art pixels.
var apex: Vector2 = Vector2(220, 90)
## How far each pair of slots sits behind the one before (x) and out from the
## centre line (y), in art pixels.
var spacing: Vector2 = Vector2(20, 12)
var slots: Array[Slot] = []


## The formation [param ending] calls for: the ships that got out at the
## front in the order they left, then those left behind, then the slots of
## ships lost in the fight and chances missed during the run.
static func plan(ending: ReckoningEnding, cap: int = 12) -> ArrivalFormation:
	var formation: ArrivalFormation = ArrivalFormation.new()
	var size: int = ending.formation_size(cap)
	var entries: Array[Array] = []
	for id: String in ending.saved_out:
		entries.append([Kind.OUT, id])
	for id: String in ending.left_behind:
		entries.append([Kind.LEFT_BEHIND, id])
	for id: String in ending.lost:
		entries.append([Kind.EMPTY, id])
	for missed: Dictionary in ending.missed:
		entries.append([Kind.EMPTY, str(missed.get("enemy", ""))])
	for i: int in mini(size, entries.size()):
		var slot: Slot = Slot.new()
		slot.kind = entries[i][0]
		slot.enemy_id = entries[i][1]
		slot.index = i
		formation.slots.append(slot)
	# A short chevron opens wider, or a handful of ships reads as a huddle
	# rather than a shape; a long one packs in to fit the frame.
	var rows: int = formation.rows()
	if rows <= 3:
		formation.spacing = Vector2(26, 16)
	elif rows == 4:
		formation.spacing = Vector2(23, 14)
	return formation


## Pairs of slots behind the point.
func rows() -> int:
	return ceili(slots.size() / 2.0)


## Where slot [param index] sits: upper arm for even, lower for odd.
func position_of(index: int) -> Vector2:
	var row: int = index / 2 + 1
	var side: float = -1.0 if index % 2 == 0 else 1.0
	return apex + Vector2(-row * spacing.x, side * row * spacing.y)


## Where the player holds station while not leading: on the centre line,
## behind the last pair, watching the way they came. Taking the point means
## flying up through the whole formation.
func rear() -> Vector2:
	return (apex - Vector2((maxi(rows(), 1) + 0.6) * spacing.x, 0.0)).round()


## How far the chevron reaches back from its point, in art pixels.
func depth() -> float:
	return maxi(rows(), 1) * spacing.x


func slots_of(kind: Kind) -> Array[Slot]:
	var matching: Array[Slot] = []
	for slot: Slot in slots:
		if slot.kind == kind:
			matching.append(slot)
	return matching
