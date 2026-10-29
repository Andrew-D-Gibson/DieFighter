class_name GiveHeldDieToTargetHandler
extends EffectHandler
## Hands the die the source tile is holding to the first target: the same
## GiveDieToTargetEvent the activator goes out on, aimed at the held die.
## Only on the last repetition, like every die hand-off, so a repeated
## payout gives the die once.


func apply(_data: EffectData, context: EffectContext, engine: ScenarioEngine) -> void:
	if context.repetitions > 0:
		return
	var tile: Tile = context.effect_source as Tile
	if tile == null:
		return
	var held: Dice = tile.get_held_die(context.activator_die)
	if held == null:
		return

	var event := GiveDieToTargetEvent.new()
	_stamp(event, context)
	event.activator_die = held
	event.die_value = held.value
	event.targets = context.targets.duplicate()
	engine.inject_event(event)
