class_name PlaySoundEvent
extends EffectEvent

var sfx: SoundEffectResource = null


func resolve(_engine: ScenarioEngine) -> void:
	if sfx == null:
		return
	Events.play_sound.emit(sfx)
