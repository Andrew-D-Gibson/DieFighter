class_name PlaySoundEffect
extends Effect

@export var sound_effect: SoundEffectResource

func play(_effect_variables: EffectVariables) -> void:
	Events.play_sound.emit(sound_effect)
