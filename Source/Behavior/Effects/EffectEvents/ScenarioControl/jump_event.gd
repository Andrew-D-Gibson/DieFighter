class_name JumpEvent
extends EffectEvent

## Net signed jump distance (positive = forward, negative = backward).
## Computed by JumpHandler from data.amount / die value and direction.
var jump_delta: int = 0


func resolve(_engine: ScenarioEngine) -> void:
	# One jump at a time. A die that reaches an arrow tile while the map is
	# still panning to the last one (it was on a tile, or came back to the
	# hand mid-pan) rides along with the rest rather than launching a second
	# jump, which would advance Fate twice and strand the first launcher.
	if Globals.player.is_jump_committed():
		Globals.player.stow_die_for_jump(activator_die)
		return

	var current_index: int = Globals.map.current_scenario_index
	var desired_index: int = clampi(
		current_index + jump_delta,
		0,
		len(Globals.map.scenario_list) - 1
	)

	# Forward from the sector's last tile, the jump gate, is through the gate.
	if jump_delta > 0 and current_index == len(Globals.map.scenario_list) - 1:
		if Globals.jump_gate and Globals.jump_gate.is_open():
			Globals.player.commit_to_jump(activator_die)
			Globals.state_manager.go_through_gate()
		else:
			_refuse("ERROR_GATE_LOCKED")
		return

	if not Globals.map.is_valid_destination(desired_index):
		_refuse("ERROR_INVALID_DESTINATION")
		return

	# Checked before committing: Map.jump() refuses too, but a commit it then
	# refused would leave the hand locked and End Turn off until an arrival
	# that never comes.
	if not Globals.map.can_jump():
		_refuse("ERROR_NO_ESCAPE")
		return

	Globals.player.commit_to_jump(activator_die)
	Globals.map.jump(desired_index)


## Hands the die back and says why nothing happened ([param reason] is a
## translation key).
func _refuse(reason: String) -> void:
	if is_instance_valid(activator_die):
		Globals.player.dice_manager.add(activator_die, true, false)
	if is_instance_valid(effect_source):
		Events.error_text_popup.emit(TranslationServer.translate(reason), effect_source.global_position)
