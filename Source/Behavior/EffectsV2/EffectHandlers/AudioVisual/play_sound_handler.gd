class_name PlaySoundHandler
extends EffectHandler


func apply(data: EffectData, _context: EffectContext, engine: ScenarioEngine) -> void:
	if data.sound_resource == null:
		return

	var event := PlaySoundEvent.new()
	event.sfx = data.sound_resource
	engine.queue_event(event)
