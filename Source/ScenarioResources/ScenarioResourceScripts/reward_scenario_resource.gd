class_name RewardScenarioResource
extends ScenarioResourceBase

@export var reward_effects: Array[EffectResource]

func play() -> void:
	# Set up the effects variables for chaining effects
	var effect_variables = EffectVariables.new()
	effect_variables.source = Globals.state_manager
		
	for effect_resource in reward_effects:
		# Add the effect node to the scene
		var effect = effect_resource.effect_scene.instantiate()
		effect.amount = effect_resource.amount
		Globals.state_manager.add_child(effect)
		
		# Play the effect, recording the change in variables
		await effect.play(effect_variables)
		
		# Remove the effect node from the scene
		effect.queue_free()
