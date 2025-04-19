class_name DamageEffect
extends Effect

@export var amount: int = 0
var hit_particles: PackedScene = load("uid://doi43icsr46q0")


func play(effect_variables: EffectVariables) -> void:
	# Don't do anything if there's no target
	if len(effect_variables.targets) == 0 or not effect_variables.targets[0]:
		return
		
	# If not given an amount (amount is 0),
	# use the activator die's value
	var _instance_amount: int = amount
	if amount == 0 and effect_variables.activator_die:
		_instance_amount = effect_variables.activator_die.value
	
	
	# Create hit particles
	var particles = hit_particles.instantiate()
	if effect_variables.targets[0].health.shields >= _instance_amount:
		particles.color = Globals.blue
	else:
		particles.color = Globals.red
		
	particles.amount = 6 * _instance_amount
	particles.rotation = (PI/2) + effect_variables.effect_source.global_position.\
		angle_to_point(effect_variables.targets[0].global_position)
	effect_variables.targets[0].add_child(particles)
	
	
	# Trigger scenario events as necessary
	if effect_variables.actor is Player\
	and effect_variables.targets[0] is Enemy:
		Globals.state_manager.state = GameStateManager.GameState.IN_COMBAT
		Events.player_attacked_ship.emit(effect_variables.targets[0], effect_variables.targets[0].scenario_state.faction)
	
	
	effect_variables.targets[0].health.take_damage(_instance_amount)
