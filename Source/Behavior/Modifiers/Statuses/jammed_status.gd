class_name JammedStatus
extends StatusModifier
## Each die the ship uses on an action that would do something instead does
## nothing and comes back to the player, spending one Jammed.
##
## A die that was going to fizzle anyway (Do Nothing, or a Repair Beam whose
## ally has died) passes through untouched, keeping the stacks for a die that
## matters: otherwise a jam could be wasted on a die the player chose
## precisely because it does nothing. See EnemyActionResource.outcome_of().
##
## Rather than cancel the ship's action, which would strand the die in its
## queue, the action is swapped for Do Nothing — whose chain already hands
## the die back.
##
## Priority 35, past the flat-modifier band: anything that later rewrites
## enemy actions should sit below it, so a jam always has the last word.
##
## On the player, the next die placed on a tile that would take it does
## nothing and goes to the target instead (JammedTileEvent). A die the tile
## would turn away anyway bounces back as usual and keeps the stack, as an
## idle enemy die does. A lock sits earlier in the queue and stops the
## activation first, so a jam is never spent on a locked tile.

const _DO_NOTHING: EnemyActionResource = preload("res://Source/Content/Enemies/EnemyActions/EnemyActionResources/do_nothing.tres")


func _init() -> void:
	status_id = &"jammed"
	display_name = "Jammed"
	color = Globals.yellow
	icon = preload("res://Assets/Textures/Statuses/jammed.png")
	info_icon = preload("res://Assets/Textures/Statuses/jammed_info.png")
	priority = 35


func on_before_event(event: EffectEvent, engine: ScenarioEngine) -> void:
	if stacks <= 0:
		return
	if is_on_player():
		_jam_tile(event, engine)
		return
	if event is not EnemyActionEvent:
		return
	var action_event: EnemyActionEvent = event as EnemyActionEvent
	if action_event.enemy != affected_node:
		return
	if EnemyActionResource.outcome_of(action_event.action, action_event.enemy) != EnemyActionResource.Outcome.ACTS:
		return

	# A copy, like every rolled action: the preloaded one is shared.
	action_event.action = _DO_NOTHING.duplicate(true)
	announce_triggered()
	consume(1)


func _jam_tile(event: EffectEvent, engine: ScenarioEngine) -> void:
	if event is not TileActivationEvent:
		return
	var activation: TileActivationEvent = event as TileActivationEvent
	if not is_ship_system(activation.tile) or not is_instance_valid(activation.activator_die):
		return
	if not activation.tile.activation_refusal(activation.activator_die as Dice).is_empty():
		return

	activation.canceled = true
	var jam: JammedTileEvent = JammedTileEvent.new()
	jam.actor = affected_node
	jam.tile = activation.tile
	jam.activator_die = activation.activator_die
	jam.die_value = activation.die_value
	engine.inject_event(jam)
	announce_triggered_at(activation.tile)
	consume(1)


## Whether [param tile] is one of the ship's systems a status can interfere
## with: a tile on the grid an enemy could lock. The map's jump tiles and the
## Engine Charger are the cockpit's own controls, not systems.
static func is_ship_system(tile: Tile) -> bool:
	if not is_instance_valid(tile) or not tile.can_be_locked_out():
		return false
	return Globals.tile_grid != null and tile in Globals.tile_grid.tile_locations.values()
