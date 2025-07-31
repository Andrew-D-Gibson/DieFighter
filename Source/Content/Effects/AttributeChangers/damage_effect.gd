class_name DamageEffect
extends Effect

@export var amount: int = 0
@export var inherit_die_amount: bool = false
var hit_particles: PackedScene = preload("uid://doi43icsr46q0")
var explosion_particles: PackedScene = preload("uid://566ykra4buin")


func play(effect_variables: EffectVariables) -> void:
	# Don't do anything if there's no target
	if len(effect_variables.targets) <= 0:
		return
		
	# Set base damage
	if inherit_die_amount and effect_variables.activator_die:
		effect_variables.base_amount = effect_variables.activator_die.value
	elif amount != 0:
		effect_variables.base_amount = amount
	
	# Calculate final damage after all modifiers
	var final_amount = effect_variables.calculate_final_amount()
	
	for i in range(len(effect_variables.targets)):
		if not effect_variables.targets[i]:
			continue
		
		# Create hit particles
		var particles = hit_particles.instantiate()
		if effect_variables.targets[i].health.shields >= final_amount:
			particles.color = Globals.blue
		else:
			particles.color = Globals.red
			
		particles.amount = 10 * final_amount
		particles.rotation = (PI/2) +\
			effect_variables.effect_source.global_position.\
			angle_to_point(effect_variables.targets[i].global_position)
		effect_variables.targets[i].add_child(particles)
		
		# Create explosion particles
		var explosion = explosion_particles.instantiate()
		if effect_variables.targets[i].health.shields >= final_amount:
			explosion.color = Globals.blue
		else:
			explosion.color = Globals.red
		explosion.amount = 2 * final_amount
		effect_variables.targets[i].add_child(explosion)
		
		
		# Trigger scenario events as necessary
		if effect_variables.actor is Player\
		and effect_variables.targets[i] is Enemy:
			Globals.state_manager.state = GameStateManager.GameState.IN_COMBAT
			Events.player_attacked_ship.emit(
				effect_variables.targets[i], 
				effect_variables.targets[i].scenario_state.faction
			)
		
		effect_variables.targets[i].health.take_damage(final_amount)
	
