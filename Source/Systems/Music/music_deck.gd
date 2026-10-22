class_name MusicDeck
extends AudioStreamPlayer
## One playing track for MusicDirector.
##
## Plays the track's layers as one AudioStreamSynchronized, so stems stay
## sample-locked, and owns every fade on them: its own gain for crossfades, and
## each layer's for dynamic music. A crossfade gives the incoming track a new
## deck rather than reusing the outgoing one, so a cue arriving mid-fade never
## cuts off a tail that is still audible.
##
## Fades run on real time: hitstop sets Engine.time_scale to 0, which would
## otherwise freeze a fade halfway.

## The track ran out by itself. Not emitted by stop() or retire().
signal track_finished(deck: MusicDeck)

## Below this a gain counts as silent; linear_to_db(0) is -inf.
const _SILENT_DB: float = -80.0

var track: MusicTrackResource

var _sync: AudioStreamSynchronized
## Crossfade gain, linear 0..1.
var _gain: float = 1.0
## Per-layer gain as currently applied, and where each layer is heading.
var _layer_gains: Array[float] = []
var _layer_targets: Array[bool] = []
var _gain_tween: Tween
var _layer_tweens: Dictionary[int, Tween] = {}


func _init() -> void:
	bus = &"Music"
	finished.connect(func() -> void: track_finished.emit(self))


## Starts `new_track` from the top at `start_gain`.
func start(new_track: MusicTrackResource, start_gain: float) -> void:
	track = new_track
	_sync = AudioStreamSynchronized.new()
	_sync.stream_count = track.layers.size()
	_layer_gains.clear()
	_layer_targets.clear()
	for i: int in track.layers.size():
		var layer: MusicLayerResource = track.layers[i]
		_sync.set_sync_stream(i, layer.stream)
		_layer_targets.append(layer.starts_enabled)
		_layer_gains.append(1.0 if layer.starts_enabled else 0.0)
		_apply_layer_gain(i)

	stream = _sync
	_set_gain(start_gain)
	play()


## Fades the whole deck to `target` (linear 0..1).
func fade_to(target: float, duration: float) -> void:
	if _gain_tween:
		_gain_tween.kill()
	if duration <= 0.0:
		_set_gain(target)
		return
	_gain_tween = _fade_tween(target > _gain)
	_gain_tween.tween_method(_set_gain, _gain, target, duration)


## Fades out, then frees the deck.
func retire(duration: float) -> void:
	fade_to(0.0, duration)
	if _gain_tween:
		_gain_tween.finished.connect(queue_free)
	else:
		queue_free()


func set_layer_enabled(index: int, enabled: bool, duration: float) -> void:
	_layer_targets[index] = enabled
	if _layer_tweens.has(index):
		_layer_tweens[index].kill()
		_layer_tweens.erase(index)

	var target: float = 1.0 if enabled else 0.0
	if duration <= 0.0:
		_set_layer_gain(target, index)
		return
	var tween: Tween = _fade_tween(enabled)
	tween.tween_method(_set_layer_gain.bind(index), _layer_gains[index], target, duration)
	_layer_tweens[index] = tween


func is_layer_enabled(index: int) -> bool:
	return _layer_targets[index]


func get_gain() -> float:
	return _gain


func get_layer_gain(index: int) -> float:
	return _layer_gains[index]


## Sine easing makes a crossfade equal-power: the in and out curves are
## sin and cos, so the pair doesn't dip in loudness halfway through.
func _fade_tween(fading_in: bool) -> Tween:
	return create_tween()\
		.set_ignore_time_scale(true)\
		.set_trans(Tween.TRANS_SINE)\
		.set_ease(Tween.EASE_OUT if fading_in else Tween.EASE_IN)


func _set_gain(gain: float) -> void:
	_gain = gain
	volume_db = _gain_to_db(gain)


func _set_layer_gain(gain: float, index: int) -> void:
	_layer_gains[index] = gain
	_apply_layer_gain(index)


func _apply_layer_gain(index: int) -> void:
	var layer: MusicLayerResource = track.layers[index]
	_sync.set_sync_stream_volume(index, track.volume_db + layer.volume_db + _gain_to_db(_layer_gains[index]))


func _gain_to_db(gain: float) -> float:
	return maxf(linear_to_db(gain), _SILENT_DB)
