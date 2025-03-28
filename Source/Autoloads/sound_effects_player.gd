class_name SFXPlayer
extends Node2D

var sound_effects_folder = 'res://Source/SoundEffectResources/SoundEffects'

var sound_effects_dict: Dictionary[String, SoundEffectResource]


func _hookup_audio_signals() -> void:
	Events.tile_dropped.connect(func(): play_sound('tile_dropped_click'))


func _ready() -> void:
	var sound_effects: Array[SoundEffectResource]
	
	for file in DirAccess.get_files_at(sound_effects_folder):
		var file_path: String = sound_effects_folder + '/' + file 
		var resource: Resource = load(file_path)
		# Check if the resource is valid and not already in the array
		if resource != null and resource is SoundEffectResource:
			sound_effects.append(resource)
	
	for effect in sound_effects:
		sound_effects_dict[effect.name] = effect

	_hookup_audio_signals()


func play_sound(name: String) -> void:
	if sound_effects_dict.has(name):
		var sound_effect := sound_effects_dict[name]
		if sound_effect.has_open_limit():
			sound_effect.on_audio_start()
			
			var player: AudioStreamPlayer = AudioStreamPlayer.new()
			add_child(player)
			player.stream = sound_effect.sound_effect
			player.volume_db = sound_effect.volume
			player.pitch_scale = sound_effect.pitch_scale
			player.pitch_scale += randf_range(-sound_effect.pitch_randomness, sound_effect.pitch_randomness)
			player.finished.connect(sound_effect.on_audio_finished)
			player.finished.connect(player.queue_free)
			player.play()
	else:
		push_error('No sound effect with name ', name)
