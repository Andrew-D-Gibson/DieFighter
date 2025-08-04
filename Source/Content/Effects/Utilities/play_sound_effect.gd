class_name PlaySoundEffect
extends Effect

@export var sound_effect_name: String

func play(effect_variables: EffectVariables) -> void:
	Events.play_sound.emit(sound_effect_name)
