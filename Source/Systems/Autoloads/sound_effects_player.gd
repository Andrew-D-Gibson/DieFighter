class_name SFXPlayer
extends Node2D


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	Events.play_sound.connect(play_sound)


func play_sound(sfx: SoundEffectResource) -> void:
	if sfx == null:
		push_error("SFXPlayer: received null SoundEffectResource")
		return

	if not sfx.has_open_limit():
		return

	sfx.on_audio_start()

	var player: AudioStreamPlayer = AudioStreamPlayer.new()
	add_child(player)

	player.bus = "SFX"
	player.stream = sfx.sound_effect
	player.volume_db = sfx.volume
	player.pitch_scale = sfx.pitch_scale
	player.pitch_scale += sfx.get_pitch_escalation()
	player.pitch_scale += randf_range(-sfx.pitch_randomness, sfx.pitch_randomness)

	player.finished.connect(sfx.on_audio_finished)
	player.finished.connect(player.queue_free)

	player.play()
