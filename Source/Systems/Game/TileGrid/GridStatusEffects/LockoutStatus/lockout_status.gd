class_name LockoutStatus
extends GridStatusEffect

@export var on_lockout_disabled_effects: EffectChain

func clears_status_activation_criteria(activator_die: Dice = null) -> bool:
	return true
	
	if not activator_die:
		Events.error_text_popup.emit("LOCATION LOCKED", self.global_position)
		return false
		
	# The die is in the static Tile activation queue,
	# so we need to remove it
	#if len(Tile.dice_activation_queue) > 0 and \
	#Tile.dice_activation_queue[0] and \
	#Tile.dice_activation_queue[0] == activator_die:
		#Tile.dice_activation_queue.remove_at(0)
		
	var effect_variables: EffectVariables = EffectVariables.new()
	effect_variables.actor = Globals.player
	effect_variables.effect_source = self
	effect_variables.activator_die = activator_die
	activator_die.draggable.state = Draggable.DragState.MOVING_WITH_CODE
	
	await on_lockout_disabled_effects.play(effect_variables)
	
	# The lockout should have been cleared, but that still
	# consumes the die, preventing activation
	return false
