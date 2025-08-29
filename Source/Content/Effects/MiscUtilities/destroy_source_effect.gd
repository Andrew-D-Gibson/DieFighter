class_name DestroySourceEffect
extends Effect

func play(effect_variables: EffectVariables) -> void:
	if not effect_variables.effect_source:
		printerr("DestroySourceEffect does not have an effect source!")
		return
		
	effect_variables.effect_source.queue_free()
