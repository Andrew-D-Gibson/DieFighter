@tool
extends EditorInspectorPlugin
## Adds Play / Stop / Preview Escalation buttons to SoundEffectResources so a
## sound can be auditioned with its current volume and pitch settings without
## running the game.

const SFX_BUS: StringName = &"SFX"
const MIN_PITCH: float = 0.01

var _player: AudioStreamPlayer
var _preview_timer: Timer
var _preview_effect: SoundEffectResource
var _preview_level: int = 0
var _status_label: Label


func _can_handle(object: Object) -> bool:
	return object is SoundEffectResource


func _parse_begin(object: Object) -> void:
	var effect: SoundEffectResource = object as SoundEffectResource
	_ensure_nodes()
	_stop()

	var hbox: HBoxContainer = HBoxContainer.new()

	var play_button: Button = Button.new()
	play_button.text = "▶ Play"
	play_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	play_button.pressed.connect(_play_once.bind(effect))
	hbox.add_child(play_button)

	var stop_button: Button = Button.new()
	stop_button.text = "■ Stop"
	stop_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stop_button.pressed.connect(_stop)
	hbox.add_child(stop_button)

	var preview_button: Button = Button.new()
	preview_button.text = "▶ Preview Escalation"
	preview_button.tooltip_text = "Replays the sound faster than quick_play_threshold until stopped, stepping up the escalation level each time."
	preview_button.pressed.connect(_start_escalation_preview.bind(effect))

	_status_label = Label.new()
	_status_label.text = ""

	add_custom_control(hbox)
	add_custom_control(preview_button)
	add_custom_control(_status_label)


## Frees the editor-owned nodes; called by the EditorPlugin when it's disabled.
func cleanup() -> void:
	_stop()
	if is_instance_valid(_player):
		_player.queue_free()
	if is_instance_valid(_preview_timer):
		_preview_timer.queue_free()
	_player = null
	_preview_timer = null


func _ensure_nodes() -> void:
	if is_instance_valid(_player):
		return
	var base: Control = EditorInterface.get_base_control()

	_player = AudioStreamPlayer.new()
	base.add_child(_player)

	_preview_timer = Timer.new()
	_preview_timer.one_shot = false
	_preview_timer.timeout.connect(_on_preview_timeout)
	base.add_child(_preview_timer)


func _play_once(effect: SoundEffectResource) -> void:
	_stop_escalation_preview()
	_play(effect, 0)


func _start_escalation_preview(effect: SoundEffectResource) -> void:
	if effect.sound_effect == null:
		_set_status("No sound_effect assigned.")
		return
	_stop()
	_preview_effect = effect
	_preview_level = 0
	# Fire just inside the threshold so every replay counts as a "quick play".
	_preview_timer.wait_time = effect.quick_play_threshold * 0.9
	_preview_timer.start()
	_on_preview_timeout()


func _on_preview_timeout() -> void:
	if _preview_effect == null:
		return
	_play(_preview_effect, _preview_level)
	_preview_level += 1


func _stop() -> void:
	_stop_escalation_preview()
	if is_instance_valid(_player):
		_player.stop()


func _stop_escalation_preview() -> void:
	if is_instance_valid(_preview_timer):
		_preview_timer.stop()
	if _preview_effect != null:
		_preview_effect.current_escalation_level = 0
	_preview_effect = null
	_preview_level = 0


## Mirrors SFXPlayer.play_sound so the preview matches what the game plays.
## The escalation level is driven directly rather than via on_audio_start(),
## which would also bump the static per-name concurrency counts.
func _play(effect: SoundEffectResource, escalation_level: int) -> void:
	if effect.sound_effect == null:
		_set_status("No sound_effect assigned.")
		return

	effect.current_escalation_level = escalation_level
	var pitch: float = effect.pitch_scale + effect.get_pitch_escalation()
	pitch += randf_range(-effect.pitch_randomness, effect.pitch_randomness)
	pitch = maxf(pitch, MIN_PITCH)

	_player.stop()
	_player.bus = SFX_BUS if AudioServer.get_bus_index(SFX_BUS) != -1 else &"Master"
	_player.stream = effect.sound_effect
	_player.volume_db = effect.volume
	_player.pitch_scale = pitch
	_player.play()

	if effect.enable_pitch_escalation:
		_set_status("Escalation level %d — pitch %.2f" % [escalation_level, pitch])
	else:
		_set_status("Pitch %.2f (escalation disabled)" % pitch)


func _set_status(text: String) -> void:
	if is_instance_valid(_status_label):
		_status_label.text = text
