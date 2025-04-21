class_name DamageEffect
extends Effect

@export var amount: int = 0
var hit_particles: PackedScene = load("uid://doi43icsr46q0")

func play(effect_variables: EffectVariables) -> void:
	# Don't do anything if there's no target
	if len(effect_variables.targets) == 0 or not effect_variables.targets[0]:
		return
		
	# Set base damage
	if amount == 0 and effect_variables.activator_die:
		effect_variables.base_amount = effect_variables.activator_die.value
	else:
		effect_variables.base_amount = amount
	
	# Calculate final damage after all modifiers
	var final_amount = effect_variables.calculate_final_amount()
	
	# Create hit particles
	var particles = hit_particles.instantiate()
	if effect_variables.targets[0].health.shields >= final_amount:
		particles.color = Globals.blue
	else:
		particles.color = Globals.red
		
	particles.amount = 6 * final_amount
	particles.rotation = (PI/2) + effect_variables.effect_source.global_position.\
		angle_to_point(effect_variables.targets[0].global_position)
	effect_variables.targets[0].add_child(particles)
	
	# Trigger scenario events as necessary
	if effect_variables.actor is Player\
	and effect_variables.targets[0] is Enemy:
		Globals.state_manager.state = GameStateManager.GameState.IN_COMBAT
		Events.player_attacked_ship.emit(effect_variables.targets[0], effect_variables.targets[0].scenario_state.faction)
	
	effect_variables.targets[0].health.take_damage(final_amount)
	
	# Clear modifiers
	effect_variables.clear_amount_modifiers()
