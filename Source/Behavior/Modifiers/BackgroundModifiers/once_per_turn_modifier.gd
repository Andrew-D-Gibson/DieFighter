class_name OncePerTurnModifier
extends Modifier
## Every ship system activates at most once a turn: a tile with three uses
## gets one, a tile with no limit gets one, and nothing makes it fire twice
## (no x2 repetitions, no uses topped back up). The Engine Charger and the
## map's jump tiles aren't systems (JammedStatus.is_ship_system), so they are
## immune, and the player's spare dice go into the engine.
##
## The cap itself lives on the tile's use budget (Tile.max_uses_per_turn()
## asks every modifier's get_tile_use_cap()), so the indicator lights, the
## gray-out and the "no uses" refusal all read it the way they read a tile's
## own limit. This modifier only says which tiles it caps, and stops the two
## ways round a budget: repetitions and refunds.


func _init() -> void:
	modifier_name = "Once Per Turn"
	priority = 75   # clamping; must run after the x2 multipliers at 50


func get_tile_use_cap(tile: Tile) -> int:
	return 1 if JammedStatus.is_ship_system(tile) else -1


func get_rule_info_text(tile: Tile) -> String:
	if get_tile_use_cap(tile) < 0:
		return ""
	return tr("TILE_INFO_ONCE_PER_TURN").format({"rule": tr(modifier_name)})


func on_before_event(event: EffectEvent, _engine: ScenarioEngine) -> void:
	if event is TileActivationEvent:
		var activation: TileActivationEvent = event as TileActivationEvent
		if activation.activation_repetitions > 1 and get_tile_use_cap(activation.tile) >= 0:
			activation.activation_repetitions = 1
			announce_triggered()
	elif event is AddUsesRemainingEvent and event.amount > 0:
		_refuse_refunds(event)


## A use given back would be a second activation. Drains still land.
func _refuse_refunds(event: EffectEvent) -> void:
	var kept: Array[Node] = []
	for target: Node in event.targets:
		if target is Tile and get_tile_use_cap(target as Tile) >= 0:
			continue
		kept.append(target)
	if kept.size() == event.targets.size():
		return
	event.targets = kept
	if kept.is_empty():
		event.canceled = true
	announce_triggered()


func get_trigger_text() -> String:
	return "x1"


## The budget changes the moment the rule arrives or leaves, mid-turn too,
## so every grid tile re-reads it rather than waiting for the next refill.
func on_registered(engine: ScenarioEngine) -> void:
	super(engine)
	_refresh_grid()


func on_unregistered(engine: ScenarioEngine) -> void:
	super(engine)
	_refresh_grid()


func _refresh_grid() -> void:
	if Globals.tile_grid == null:
		return
	for tile: Tile in Globals.tile_grid.tile_locations.values():
		if is_instance_valid(tile):
			tile.refresh_use_cap()
