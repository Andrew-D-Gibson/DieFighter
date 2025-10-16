class_name SFXPlayer
extends Node2D

var sound_effects_folder = 'res://Source/Resources/SoundEffectResources/SoundEffects'

var sound_effects_dict: Dictionary[String, SoundEffectResource]


func _ready() -> void:
	# Make this unpausable
	process_mode = Node.PROCESS_MODE_ALWAYS
	
	var sound_effects: Array[SoundEffectResource]
	
	for file in DirAccess.get_files_at(sound_effects_folder):
		var file_path: String
		if file.ends_with(".tres"):
			file_path = sound_effects_folder + "/" + file
		elif file.ends_with(".tres.remap"):
			file_path = sound_effects_folder + "/" + file.trim_suffix(".remap")
		else:
			continue
			
		var resource: Resource = load(file_path)
		if resource != null and resource is SoundEffectResource:
			sound_effects.append(resource)

	
	for effect in sound_effects:
		sound_effects_dict[effect.name] = effect

	Events.play_sound.connect(play_sound)


func play_sound(name: String) -> void:
	if sound_effects_dict.has(name):
		var sound_effect := sound_effects_dict[name]
		if sound_effect.has_open_limit():
			sound_effect.on_audio_start()
			
			var player: AudioStreamPlayer = AudioStreamPlayer.new()
			add_child(player)
			
			player.bus = 'SFX'
			player.stream = sound_effect.sound_effect
			player.volume_db = sound_effect.volume
			player.pitch_scale = sound_effect.pitch_scale
			
			# Apply pitch escalation
			player.pitch_scale += sound_effect.get_pitch_escalation()
			
			# Apply random pitch variation
			player.pitch_scale += randf_range(-sound_effect.pitch_randomness, sound_effect.pitch_randomness)
			
			player.finished.connect(sound_effect.on_audio_finished)
			player.finished.connect(player.queue_free)
			
			player.play()
	else:
		push_error('No sound effect with name ', name)
