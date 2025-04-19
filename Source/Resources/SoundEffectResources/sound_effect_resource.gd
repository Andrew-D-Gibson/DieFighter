class_name SoundEffectResource
extends Resource

@export var name: String
@export_range(0, 10) var limit: int = 5 ## Maximum number of this SoundEffect to play simultaneously before culled.
@export var sound_effect: AudioStream
@export_range(-40, 20) var volume: float = 0 
@export_range(0.0, 4.0,.01) var pitch_scale: float = 1.0 
@export_range(0.0, 1.0,.01) var pitch_randomness: float = 0.0 

static var audio_count: int = 0 

func on_audio_start() -> void:
	audio_count += 1

func has_open_limit() -> bool:
	return audio_count < limit

func on_audio_finished() -> void:
	audio_count -= 1
