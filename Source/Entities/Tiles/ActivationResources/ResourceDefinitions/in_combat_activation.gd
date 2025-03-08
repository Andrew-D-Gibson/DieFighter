class_name InCombatActivation
extends ActivationResource

func criteria_satisfied(die: Dice) -> bool:
	return Globals.state_manager.state == GameStateManager.GameState.IN_COMBAT
