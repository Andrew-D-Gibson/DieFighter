class_name SoundEffectResource
extends Resource

@export var name: String
@export_range(0, 10) var limit: int = 5 ## Maximum number of this SoundEffect to play simultaneously before culled.
@export var sound_effect: AudioStream
@export_range(-40, 20) var volume: float = 0 
@export_range(0.0, 4.0,.01) var pitch_scale: float = 1.0 
@export_range(0.0, 1.0,.01) var pitch_randomness: float = 0.0 

# Pitch escalation properties
@export var enable_pitch_escalation: bool = false
@export_range(0.1, 10.0, 0.1) var max_pitch_escalation: float = 2.0 ## Maximum pitch multiplier when escalated
@export_range(0.1, 2.0, 0.1) var pitch_escalation_step: float = 0.1 ## How much to increase pitch per quick play
@export_range(0.1, 5.0, 0.1) var quick_play_threshold: float = 0.5 ## Time in seconds to consider a "quick play"

static var audio_count: int = 0 

# Track recent play times for pitch escalation
var recent_play_times: Array[int] = []
var current_escalation_level: int = 0


func on_audio_start() -> void:
	audio_count += 1
	_update_play_times()


func has_open_limit() -> bool:
	return audio_count < limit


func on_audio_finished() -> void:
	audio_count -= 1


func _update_play_times() -> void:
	var current_time = Time.get_ticks_msec()
	var cutoff_time = current_time - (quick_play_threshold * 1000)
	
	# Remove the previous play times if too much time has passed 
	# since the last play
	if len(recent_play_times) > 0 and recent_play_times[-1] < cutoff_time:
		recent_play_times = Array([current_time], TYPE_INT, "", null) 

	else:
		recent_play_times.append(current_time)

	current_escalation_level = max(0, recent_play_times.size() - 1)


func get_pitch_escalation() -> float:
	if not enable_pitch_escalation:
		return 0.0
	
	# Calculate escalation based on current level
	var escalation = current_escalation_level * pitch_escalation_step
	return min(escalation, max_pitch_escalation - pitch_scale)
