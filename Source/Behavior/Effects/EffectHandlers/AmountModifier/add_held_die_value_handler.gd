class_name AddHeldDieValueHandler
extends EffectHandler
## Adds the face of the die the source tile is holding to running_amount, so a
## twin-dice tile can pay out on both dice. Nothing held adds nothing.


func apply(_data: EffectData, context: EffectContext, _engine: ScenarioEngine) -> void:
	var tile: Tile = context.effect_source as Tile
	if tile == null:
		return
	var held: Dice = tile.get_held_die(context.activator_die)
	if held:
		context.running_amount += held.value
