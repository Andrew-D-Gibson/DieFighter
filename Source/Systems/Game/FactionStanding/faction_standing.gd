class_name FactionStanding
extends Node
## Keeps the run's FactionLedger: records what the player does to each
## faction as it happens, and hands it to the save at every checkpoint.
##
## It writes from two sources. Authored deeds arrive with the ship state that
## stands for them (Events.ship_deeds_done, from ScenarioShipState.deeds).
## Kills are counted on their own, by the same rule as RunStats: a ship the
## player destroyed, not one another ship finished off.
##
## Readers that aren't in the main scene (a resource resolving a branch, a
## static price helper) go through ledger_now(), which stands in an empty
## ledger, a fleet that remembers nothing, when no run is live.

var ledger: FactionLedger = FactionLedger.new()


func _ready() -> void:
	Globals.faction_standing = self
	Events.load_game_save.connect(_load_game_save)
	Events.ship_deeds_done.connect(_on_ship_deeds_done)
	Events.enemy_left.connect(_on_enemy_left)


## The live run's ledger, or an empty one outside a run (a test, a menu).
static func ledger_now() -> FactionLedger:
	if is_instance_valid(Globals.faction_standing):
		return Globals.faction_standing.ledger
	return FactionLedger.new()


## What [param ship]'s faction charges the player, as a multiple of the list
## price: 1.0 for a ship with no faction, or none at all.
static func price_multiplier_for(ship: Enemy) -> float:
	var faction: FactionIdentity = faction_of(ship)
	if faction == null:
		return 1.0
	return ledger_now().price_multiplier(faction.id)


static func faction_of(ship: Enemy) -> FactionIdentity:
	if not is_instance_valid(ship) or ship.enemy_resource == null:
		return null
	return ship.enemy_resource.faction


## Records [param deed], felt by its own faction or else [param ship_faction].
func record(deed: FactionDeed, ship_faction: FactionIdentity) -> void:
	if deed == null:
		return
	ledger.note_deed(deed.deed)
	var faction: FactionIdentity = deed.faction_for(ship_faction)
	if faction == null or faction.id.is_empty() or deed.standing == 0:
		return
	var value: int = ledger.change_standing(faction.id, deed.standing)
	Events.faction_standing_changed.emit(faction, value, deed.deed)


func get_state() -> Dictionary:
	return ledger.get_state()


func _load_game_save(game_save: GameSaveResource) -> void:
	ledger.load_state(game_save.faction_standing)


func _on_ship_deeds_done(ship: Enemy, deeds: Array[FactionDeed]) -> void:
	var ship_faction: FactionIdentity = faction_of(ship)
	for deed: FactionDeed in deeds:
		record(deed, ship_faction)


func _on_enemy_left(ship: Enemy, _faction: ScenarioManager.Faction) -> void:
	if not is_instance_valid(ship) or ship.health.health > 0 or ship.was_killed_by_ship():
		return
	var faction: FactionIdentity = faction_of(ship)
	if faction:
		ledger.note_kill(faction.id)
