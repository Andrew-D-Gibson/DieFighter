class_name LockoutModifier
extends Modifier

func _init(tile: Tile) -> void:
	modifier_name = "Lockout"
	affected_node = tile
	priority = 5
	is_temporary = false
	status_visual_scene = preload("uid://bmigs3ltcqtec")


func on_before_event(event: EffectEvent, engine: ScenarioEngine) -> void:
	if event is TileActivationEvent and (event as TileActivationEvent).tile == affected_node:
		event.canceled = true

		var lockout_event: LockoutEffectEvent = LockoutEffectEvent.new()
		lockout_event.effect_source = affected_node
		lockout_event.activator_die = event.activator_die
		lockout_event.metadata["active_lockout_modifier"] = self
		engine.inject_event(lockout_event)
