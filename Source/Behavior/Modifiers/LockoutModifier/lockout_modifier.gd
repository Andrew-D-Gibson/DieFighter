class_name LockoutModifier
extends Modifier

## A die showing less than this opens the lock instead of being turned away.
const UNLOCK_BELOW: int = 4
## The Locked keyword, in the capitals a status line reads in.
const KEYWORD_TOKEN: String = "(LOCKED)"


## Whether a die showing [param face] opens a locked tile.
static func unlocks(face: int) -> bool:
	return face < UNLOCK_BELOW


func _init(tile: Tile) -> void:
	modifier_name = "Lockout"
	affected_node = tile
	priority = 5
	status_visual_scene = preload("uid://bmigs3ltcqtec")


func on_before_event(event: EffectEvent, engine: ScenarioEngine) -> void:
	# A tile that never takes a die (Napalm Vent) acts through its event
	# responses instead. A lock stops those too; with no die there's nothing
	# that could open it, so the response just doesn't happen.
	if event is TileEventTriggeredEvent and (event as TileEventTriggeredEvent).responder == affected_node:
		event.canceled = true
		announce_triggered()
		return
	if event is TileActivationEvent and (event as TileActivationEvent).tile == affected_node:
		event.canceled = true
		announce_triggered()

		var activation: TileActivationEvent = event as TileActivationEvent
		var lockout_event: LockoutEffectEvent = LockoutEffectEvent.new()
		lockout_event.actor = activation.actor
		lockout_event.effect_source = affected_node
		lockout_event.activator_die = activation.activator_die
		lockout_event.lockout_modifier = self
		lockout_event.feed_depth = activation.feed_depth
		engine.inject_event(lockout_event)


## Whether [param node] is locked in [param engine] right now.
static func locks(engine: ScenarioEngine, node: Node) -> bool:
	if engine == null or not is_instance_valid(node):
		return false
	for mod: Modifier in engine.modifiers:
		if mod is LockoutModifier and mod.affected_node == node:
			return true
	return false


## The board marks a lock with its padlock alone; the word lives here, under
## the tile's description, where hovering it explains the rule.
func get_info_text() -> String:
	return KEYWORD_TOKEN


## An opened lock pops off its tile rather than vanishing (see the visual's
## release()). Jumping away clears it the same way.
func on_unregistered(engine: ScenarioEngine) -> void:
	if is_instance_valid(_visual) and _visual.has_method("release"):
		_visual.release()
		_visual = null
	super.on_unregistered(engine)
