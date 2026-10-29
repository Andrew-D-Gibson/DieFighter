class_name MergeHeldDieHandler
extends EffectHandler


func apply(_data: EffectData, context: EffectContext, engine: ScenarioEngine) -> void:
	if not is_instance_valid(context.activator_die):
		return
	if not is_instance_valid(context.effect_source) or context.effect_source is not Tile:
		return

	var held: Dice = (context.effect_source as Tile).get_held_die(context.activator_die)
	if held == null:
		return

	var event := MergeHeldDieEvent.new()
	_stamp(event, context)
	event.held_die = held
	engine.inject_event(event)

	# The held die goes home whether or not the weld happens.
	var home := GiveDieToPlayerEvent.new()
	_stamp(home, context)
	home.activator_die = held
	home.die_value = held.value
	engine.inject_event(home)
