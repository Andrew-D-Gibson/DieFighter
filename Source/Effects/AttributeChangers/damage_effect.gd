extends Effect

@export var hit_particles: PackedScene


func play(effect_variables: EffectVariables) -> void:
	# Don't do anything if there's no target
	if len(effect_variables.targets) == 0 or not effect_variables.targets[0]:
		return
		
	# If not given an amount (amount is 0),
	# use the activator die's value
	if amount == 0 and effect_variables.activator_die:
		amount = effect_variables.activator_die.value
	
	
	# Create hit particles
	var particles = hit_particles.instantiate()
	
	if effect_variables.targets[0].health.shields >= amount:
		particles.color = Globals.blue
	else:
		particles.color = Globals.red
		
	particles.amount = 6 * amount
		
	particles.global_position = effect_variables.targets[0].global_position
	particles.rotation = (PI/2) + global_position.angle_to_point(effect_variables.targets[0].global_position)

	get_tree().get_root().add_child(particles)
	
	effect_variables.targets[0].health.take_damage(amount)
