class_name FactionLedger
extends RefCounted
## What the fleet remembers of the player this run (LORE.md §1: "the sector is
## watching"). Plain data with no game systems behind it, so it can be built,
## queried and saved anywhere; FactionStanding keeps the run's copy current.
##
## It remembers three things, each keyed by a FactionIdentity.id or a deed:
##   - standing: how each faction feels about the player, a number that only
##     authored deeds move (FactionDeed). Read it through regard().
##   - deeds: how often each named thing was done ("caravan_shop_attacked"),
##     whichever faction it touched. For gossip and one-off consequences.
##   - kills: ships of each faction the player destroyed, counted
##     automatically. Ordinary fights move no standing (most of the game is
##     shooting the Undertow), but an encounter can still ask how many.

## How a faction regards the player: standing read in bands, so content asks
## "do they like me?" rather than pinning a number a tuning pass will move.
enum Regard { HATED, DISLIKED, NEUTRAL, LIKED, TRUSTED }

## Standing is held within this far either side of zero, so one long streak of
## kindness or cruelty can't bank more than the bands can show, and a turn
## around later in the run is always possible.
const STANDING_LIMIT: int = 10
## The standing at which a faction LIKES the player; the mirror below zero
## DISLIKES them.
const LIKED_AT: int = 2
## The standing at which a faction TRUSTS the player; the mirror below zero
## HATES them.
const TRUSTED_AT: int = 6

## What a faction's traders charge the player, by regard. Shops and repair
## docks read it for their keeper's faction (the Caravan Compact runs both).
const PRICE_MULTIPLIERS: Dictionary[Regard, float] = {
	Regard.HATED: 1.5,
	Regard.DISLIKED: 1.25,
	Regard.NEUTRAL: 1.0,
	Regard.LIKED: 0.9,
	Regard.TRUSTED: 0.8,
}

var _standing: Dictionary[StringName, int] = {}
var _deeds: Dictionary[StringName, int] = {}
var _kills: Dictionary[StringName, int] = {}


func standing(faction_id: StringName) -> int:
	return _standing.get(faction_id, 0)


func regard(faction_id: StringName) -> Regard:
	return regard_for(standing(faction_id))


static func regard_for(value: int) -> Regard:
	if value >= TRUSTED_AT:
		return Regard.TRUSTED
	if value >= LIKED_AT:
		return Regard.LIKED
	if value <= -TRUSTED_AT:
		return Regard.HATED
	if value <= -LIKED_AT:
		return Regard.DISLIKED
	return Regard.NEUTRAL


## Moves [param faction_id]'s standing by [param delta], held within
## STANDING_LIMIT. Returns the new standing.
func change_standing(faction_id: StringName, delta: int) -> int:
	if faction_id.is_empty():
		return 0
	var value: int = clampi(standing(faction_id) + delta, -STANDING_LIMIT, STANDING_LIMIT)
	_standing[faction_id] = value
	return value


func note_deed(deed: StringName) -> void:
	if deed.is_empty():
		return
	_deeds[deed] = deed_count(deed) + 1


func deed_count(deed: StringName) -> int:
	return _deeds.get(deed, 0)


func note_kill(faction_id: StringName) -> void:
	if faction_id.is_empty():
		return
	_kills[faction_id] = kills(faction_id) + 1


func kills(faction_id: StringName) -> int:
	return _kills.get(faction_id, 0)


## What [param faction_id]'s traders charge, as a multiple of the list price.
func price_multiplier(faction_id: StringName) -> float:
	return PRICE_MULTIPLIERS[regard(faction_id)]


## Plain JSON-able data for the save: {"standing": {...}, "deeds": {...},
## "kills": {...}}, each a map of name to count.
func get_state() -> Dictionary:
	return {
		"standing": _plain(_standing),
		"deeds": _plain(_deeds),
		"kills": _plain(_kills),
	}


## Inverse of get_state(). Anything missing (a save from before the ledger)
## starts at zero: a fleet that remembers nothing.
func load_state(state: Dictionary) -> void:
	_standing = _counts(state.get("standing", {}))
	_deeds = _counts(state.get("deeds", {}))
	_kills = _counts(state.get("kills", {}))


func clear() -> void:
	load_state({})


static func _plain(counts: Dictionary[StringName, int]) -> Dictionary:
	var out: Dictionary = {}
	for key: StringName in counts:
		out[String(key)] = counts[key]
	return out


## JSON gives keys back as Strings and every number as a float.
static func _counts(data: Variant) -> Dictionary[StringName, int]:
	var out: Dictionary[StringName, int] = {}
	if data is Dictionary:
		for key: Variant in data:
			out[StringName(str(key))] = int(data[key])
	return out
