class_name FateLedger
extends Node
## The run's memory of what the player did, for Fate (LORE.md §5-§8): Fate's
## Die and its carvings, every ship the player destroyed (the Tally replays
## them), the ships they saved (who comes back to help), and a count of deeds
## that set hidden conditions (tithes paid or refused).
##
## Saved with the run (GameSaveResource.fate_state) at every checkpoint. The
## knowledge that unlocks the secret fight outlives the run, and lives in
## CollectionManager instead.

## How many of the most recent kills the Tally replays at most, besides the
## very first kill, which always closes it (LORE.md §7).
const TALLY_MAX_WAVES: int = 6
const TALLY_SHIPS_PER_WAVE: int = 3

## Deed ids recorded by RECORD_DEED steps. Free-form, but the ones code reads
## are named here.
const DEED_TITHE_PAID: String = "tithe_paid"
const DEED_TITHE_REFUSED: String = "tithe_refused"

## What REMEMBER_SHIP files a ship under: a ship the player saved, who flies
## into the Reckoning as an ally tile, or one they spared, who owes a Debt.
const KIND_ALLY: String = "ally"
const KIND_DEBT: String = "debt"

## Whether the player has been handed the die yet (the Inbound pilgrim).
## Nothing carves before then: Fate only notices people holding its die.
var has_die: bool = false
var die: FateDie = FateDie.new()
## Faces carved while the die was full, waiting for the player to pick which
## old face each goes over (FateCarveChoice). Oldest first.
var pending: Array[FateDie.Face] = []
## Every ship the player destroyed, in order: {"enemy": id, "faction": the
## FactionIdentity's file id, "sector": int}. Mounted boss parts are left out.
var kills: Array[Dictionary] = []
## Ships saved or spared, in order: {"enemy": id, "kind": KIND_*}.
var allies: Array[Dictionary] = []
## Deed id -> how many times.
var deeds: Dictionary[String, int] = {}
## Sectors in which flying into Fate has already carved Hunger, so camping a
## Fate tile doesn't carve it every visit.
var _hunger_sectors: Array[int] = []
## True while the run is in the Reckoning, so a Continue goes back into it.
var in_reckoning: bool = false
## The Reckoning's scenario seed, so a Continue replays the same fight.
var reckoning_seed: int = 0
## Whether the player already knew the secret when this run began (Gate 1 is
## knowledge from an earlier run). Fixed for the run, and saved with it, so
## learning the secret at this run's end doesn't open its own way back.
var knew_secret: bool = false


func _ready() -> void:
	Globals.fate_ledger = self
	Events.load_game_save.connect(_load_game_save)
	Events.enemy_destroyed.connect(_on_enemy_destroyed)
	Events.start_scenario.connect(_on_start_scenario)


# ── The die ──────────────────────────────────────────────────────────────────

## The pilgrim hands the player Fate's Die. Once a run.
func give_die() -> void:
	if has_die:
		return
	has_die = true
	Events.fate_die_received.emit()


## A choice carves [param face]. Into a blank face while there is one;
## otherwise it waits (pending) for the player to choose which face to carve
## over. Ignored until the player holds the die.
func request_carve(face: FateDie.Face) -> void:
	if not has_die or face == FateDie.Face.BLANK:
		return
	var slot: int = die.carve(face)
	if slot >= 0:
		Events.fate_face_carved.emit(slot, face, FateDie.Face.BLANK)
		return
	pending.append(face)
	Events.fate_carve_pending.emit(face)


func has_pending() -> bool:
	return not pending.is_empty()


## The oldest carving still waiting for a face to go over.
func next_pending() -> FateDie.Face:
	return pending[0] if has_pending() else FateDie.Face.BLANK


## Carves the oldest pending face over [param slot]. A slot of -1 lets the
## carving go: the die stays as it was (the choice is the player's).
func resolve_pending(slot: int) -> void:
	if not has_pending():
		return
	var face: FateDie.Face = pending.pop_front()
	if slot < 0:
		return
	var old: FateDie.Face = die.carve_over(slot, face)
	Events.fate_face_carved.emit(slot, face, old)


# ── Deeds and the ships that remember ────────────────────────────────────────

func record_deed(id: String) -> void:
	if id.is_empty():
		return
	deeds[id] = deeds.get(id, 0) + 1


func deed_count(id: String) -> int:
	return deeds.get(id, 0)


## The hidden condition of LORE.md §6: a player who never paid a tithe, and
## turned at least one down, never paid into the Vanguard's deal.
func refused_every_tithe() -> bool:
	return deed_count(DEED_TITHE_PAID) == 0 and deed_count(DEED_TITHE_REFUSED) > 0


func remember_ship(ship: Enemy, kind: String) -> void:
	var id: String = _enemy_id(ship)
	if id.is_empty():
		return
	allies.append({"enemy": id, "kind": kind})


func allies_of_kind(kind: String) -> Array[String]:
	var ids: Array[String] = []
	for entry: Dictionary in allies:
		if entry.get("kind", "") == kind:
			ids.append(str(entry.get("enemy", "")))
	return ids


# ── The gates to the secret fight (LORE.md §6) ───────────────────────────────

## Gate 1: the player had seen the front before this run began.
func knows_the_secret() -> bool:
	return knew_secret


## Gate 2: every face carved. Fate only notices people who make choices.
func die_is_full() -> bool:
	return has_die and die.is_full()


## Whether the way back toward Fate opens when the last boss falls.
func fate_route_open() -> bool:
	return knows_the_secret() and die_is_full()


# ── The Tally ────────────────────────────────────────────────────────────────

## The Reckoning's waves: the player's kills played backwards, most recent
## first, with the very first kill always on its own as the last wave. Long
## runs keep only the most recent kills (see TALLY_MAX_WAVES). [param skip]
## drops kills of those faction ids (the Rearguard, for a player who never
## paid their tithe). Each wave is a list of enemy ids.
static func tally_waves(kill_log: Array[Dictionary], skip: Array[String] = [],
		max_waves: int = TALLY_MAX_WAVES, per_wave: int = TALLY_SHIPS_PER_WAVE) -> Array[Array]:
	var ids: Array[String] = []
	for entry: Dictionary in kill_log:
		if str(entry.get("faction", "")) in skip:
			continue
		var id: String = str(entry.get("enemy", ""))
		if not id.is_empty():
			ids.append(id)
	var waves: Array[Array] = []
	if ids.is_empty() or max_waves <= 0 or per_wave <= 0:
		return waves

	var first: String = ids[0]
	var rest: Array[String] = ids.slice(1)
	rest.reverse()
	rest = rest.slice(0, (max_waves - 1) * per_wave)
	for start: int in range(0, rest.size(), per_wave):
		waves.append(rest.slice(start, start + per_wave))
	waves.append([first])
	return waves


# ── Run hooks ────────────────────────────────────────────────────────────────

func _on_enemy_destroyed(ship: Enemy) -> void:
	if in_reckoning or not is_instance_valid(ship) or ship.was_killed_by_ship() or ship.is_mounted:
		return
	var id: String = _enemy_id(ship)
	if id.is_empty():
		return
	var faction_id: String = ""
	if ship.enemy_resource.faction:
		faction_id = ship.enemy_resource.faction.resource_path.get_file().get_basename()
	var sector: int = 0
	if Globals.state_manager and Globals.state_manager.current_game_save:
		sector = Globals.state_manager.current_game_save.sector_index
	kills.append({"enemy": id, "faction": faction_id, "sector": sector})


## Flying into one of Fate's tiles rather than away carves Hunger, once a
## sector. Connected before GameStateManager's arrival checkpoint, so the
## carving is in the save that checkpoint writes.
func _on_start_scenario() -> void:
	if in_reckoning or not Globals.map or not Globals.state_manager:
		return
	if not Globals.state_manager.get_restore().is_empty():
		return
	var scenario: ScenarioResource = Globals.map.scenario_list[Globals.map.current_scenario_index]
	if not Globals.map.is_fate_scenario(scenario):
		return
	var sector: int = Globals.state_manager.current_game_save.sector_index
	if sector in _hunger_sectors:
		return
	_hunger_sectors.append(sector)
	request_carve(FateDie.Face.HUNGER)


static func _enemy_id(ship: Enemy) -> String:
	if not is_instance_valid(ship) or not ship.enemy_resource:
		return ""
	return ContentRegistry.get_enemy_id(ship.enemy_resource.resource_path)


# ── Save ─────────────────────────────────────────────────────────────────────

func get_state() -> Dictionary:
	var pending_ids: Array[String] = []
	for face: FateDie.Face in pending:
		pending_ids.append(FateDie.face_id(face))
	return {
		"has_die": has_die,
		"faces": die.to_data(),
		"pending": pending_ids,
		"kills": kills.duplicate(true),
		"allies": allies.duplicate(true),
		"deeds": deeds.duplicate(),
		"hunger_sectors": _hunger_sectors.duplicate(),
		"in_reckoning": in_reckoning,
		"reckoning_seed": reckoning_seed,
		"knew_secret": knew_secret,
	}


## Restores from get_state() as it comes back from JSON (every number a
## float). An empty state, a new run or a save from before Fate's Die, is a
## run with no die yet.
func load_state(state: Dictionary) -> void:
	has_die = bool(state.get("has_die", false))
	die = FateDie.from_data(state.get("faces", []))
	pending.clear()
	for id: Variant in state.get("pending", []):
		var face: int = FateDie.face_from_id(str(id))
		if face > 0:
			pending.append(face as FateDie.Face)
	kills.clear()
	for entry: Variant in state.get("kills", []):
		if entry is Dictionary:
			kills.append({
				"enemy": str(entry.get("enemy", "")),
				"faction": str(entry.get("faction", "")),
				"sector": int(entry.get("sector", 0)),
			})
	allies.clear()
	for entry: Variant in state.get("allies", []):
		if entry is Dictionary:
			allies.append({"enemy": str(entry.get("enemy", "")), "kind": str(entry.get("kind", KIND_ALLY))})
	deeds.clear()
	var saved_deeds: Variant = state.get("deeds", {})
	if saved_deeds is Dictionary:
		for id: Variant in saved_deeds:
			deeds[str(id)] = int(saved_deeds[id])
	_hunger_sectors.clear()
	for sector: Variant in state.get("hunger_sectors", []):
		_hunger_sectors.append(int(sector))
	in_reckoning = bool(state.get("in_reckoning", false))
	reckoning_seed = int(state.get("reckoning_seed", 0))
	# A new run (or a save from before Fate's Die) reads the knowledge now.
	knew_secret = bool(state.get("knew_secret", CollectionManager.has_fate_knowledge()))


func _load_game_save(game_save: GameSaveResource) -> void:
	load_state(game_save.fate_state)
