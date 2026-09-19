class_name JumpEvent
extends EffectEvent

## Net signed jump distance (positive = forward, negative = backward).
## Computed by JumpHandler from data.amount / die value and direction.
var jump_delta: int = 0


func resolve(_engine: ScenarioEngine) -> void:
	var current_index: int = Globals.map.current_scenario_index
	var desired_index: int = clampi(
		current_index + jump_delta,
		0,
		len(Globals.map.scenario_list) - 1
	)

	if not Globals.map.is_valid_destination(desired_index):
		if is_instance_valid(activator_die):
			Globals.player.dice_manager.add(activator_die, true, false)
		if is_instance_valid(effect_source):
			Events.error_text_popup.emit("INVALID DESTINATION", effect_source.global_position)
		return

	Globals.map.jump(desired_index)
