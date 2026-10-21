class_name LockoutModifier
extends Modifier

func _init(tile: Tile) -> void:
	modifier_name = "Lockout"
	affected_node = tile
	priority = 5
	status_visual_scene = preload("uid://bmigs3ltcqtec")


func on_before_event(event: EffectEvent, engine: ScenarioEngine) -> void:
	if event is TileActivationEvent and (event as TileActivationEvent).tile == affected_node:
		event.canceled = true
		announce_triggered()

		var lockout_event: LockoutEffectEvent = LockoutEffectEvent.new()
		lockout_event.effect_source = affected_node
		lockout_event.activator_die = event.activator_die
		lockout_event.lockout_modifier = self
		engine.inject_event(lockout_event)


## Shown in the tile's info panel, so a lock the player can see on the board
## is explained when they click the tile. The lock has no timer: it lasts
## until a 2 opens it or the player jumps away (the engine shuts down), so
## there is no countdown to show. A tile locked twice still gets one line:
## the first lock on it writes it and the rest stay quiet.
func get_info_text() -> String:
	var engine: ScenarioEngine = ScenarioEngine.current()
	if engine:
		for mod: Modifier in engine.modifiers:
			if mod is LockoutModifier and mod.affected_node == affected_node:
				if mod != self:
					return ""
				break
	return tr("INFO_TILE_LOCKED")
