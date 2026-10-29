class_name AddToActivatorValueEvent
extends EffectEvent
## Moves the activator die's face by amount, kept to 1-6 like every die.
##
## amount is the step, so it stays amplifiable: an Amplifier's +2 turns a +1
## into a +3. The callout is spawned here rather than authored on the tile, so
## it shows the step that actually landed — after modifiers and the cap.


## A step down (Nudge Down) isn't amplified: the Amplifier's +N would turn a
## -1 into a rise, the opposite of what the tile says.
func is_amplifiable() -> bool:
	return amount > 0


## See EffectEvent.changes_die_values().
func changes_die_values() -> bool:
	return true


func resolve(_engine: ScenarioEngine) -> void:
	if not is_instance_valid(activator_die):
		return

	var before: int = activator_die.value
	var after: int = clampi(before + amount, 1, 6)
	if after == before:
		return
	if is_instance_valid(effect_source) and effect_source is Node2D:
		var anchor: Node2D = effect_source as Node2D
		Juice.callout_at(anchor, Juice.anchor_of(anchor), "%+d" % (after - before),
				Globals.green if after > before else Globals.red)
	await activator_die.reroll_with_tween(after)
