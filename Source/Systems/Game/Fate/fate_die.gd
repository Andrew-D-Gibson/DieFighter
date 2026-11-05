class_name FateDie
extends RefCounted
## Fate's Die (LORE.md §5): the seventh die, which sits in the cockpit all run
## and never goes into the hand. Its six faces start blank, and choices with
## moral weight carve them. In the Reckoning (§7) Fate rolls it at the start of
## every round, so the die is both a record of the run and Fate's intent table
## for the secret fight.
##
## Pure state, no nodes: FateLedger owns the run's die and does the telling.

## What a face can hold. Stored in saves by id (face_id()), never by ordinal,
## so this enum may be reordered safely.
enum Face { BLANK, MERCY, PLUNDER, DUTY, RUIN, HUNGER, STRANGE }

const FACE_COUNT: int = 6

const _IDS: Dictionary[Face, String] = {
	Face.BLANK: "blank",
	Face.MERCY: "mercy",
	Face.PLUNDER: "plunder",
	Face.DUTY: "duty",
	Face.RUIN: "ruin",
	Face.HUNGER: "hunger",
	Face.STRANGE: "strange",
}

## Slot by slot, what each face shows.
var faces: Array[Face] = []


func _init() -> void:
	faces.resize(FACE_COUNT)
	faces.fill(Face.BLANK)


## The id a face is saved and authored by ("mercy").
static func face_id(face: Face) -> String:
	return _IDS.get(face, "blank")


## The face an id names, or -1 for an id that isn't one. Authored carvings
## (CarveFateFaceEvent) name their face this way.
static func face_from_id(id: String) -> int:
	var key: Variant = _IDS.find_key(id.strip_edges().to_lower())
	return -1 if key == null else int(key)


## Every face a choice can carve, in the order the codex and popups list them.
static func carvable_faces() -> Array[Face]:
	return [Face.MERCY, Face.PLUNDER, Face.DUTY, Face.RUIN, Face.HUNGER, Face.STRANGE]


func is_full() -> bool:
	return blank_count() == 0


func is_blank() -> bool:
	return blank_count() == FACE_COUNT


func blank_count() -> int:
	return count(Face.BLANK)


func count(face: Face) -> int:
	return faces.count(face)


func face_at(slot: int) -> Face:
	if slot < 0 or slot >= faces.size():
		return Face.BLANK
	return faces[slot]


## Carves [param face] into the first blank slot and returns it. Returns -1
## once the die is full: from then on a carving goes over an old face, and
## which one is the player's choice (carve_over()).
func carve(face: Face) -> int:
	if face == Face.BLANK:
		return -1
	var slot: int = faces.find(Face.BLANK)
	if slot >= 0:
		faces[slot] = face
	return slot


## Carves [param face] over whatever [param slot] holds, and returns what was
## there. A bad slot changes nothing and returns BLANK.
func carve_over(slot: int, face: Face) -> Face:
	if slot < 0 or slot >= faces.size() or face == Face.BLANK:
		return Face.BLANK
	var old: Face = faces[slot]
	faces[slot] = face
	return old


## The slot that comes up when the die is thrown. A thrown die is uniform over
## its slots, so two Mercy faces come up twice as often as one.
func roll(rng: RandomNumberGenerator) -> int:
	return rng.randi_range(0, faces.size() - 1)


## The faces by id, for a save.
func to_data() -> Array[String]:
	var data: Array[String] = []
	for face: Face in faces:
		data.append(face_id(face))
	return data


## A die from to_data(). Unknown ids, and a short or missing list, read as
## blank faces rather than failing the save.
static func from_data(data: Variant) -> FateDie:
	var die: FateDie = FateDie.new()
	if not data is Array:
		return die
	for slot: int in mini((data as Array).size(), FACE_COUNT):
		var face: int = face_from_id(str(data[slot]))
		die.faces[slot] = Face.BLANK if face < 0 else face as Face
	return die
