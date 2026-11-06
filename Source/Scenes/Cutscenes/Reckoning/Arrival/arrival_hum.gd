class_name ArrivalHum
extends AudioStreamPlayer
## The only sound Alone has (RECKONING_ENDINGS.md §6.2): the player's drive,
## a low hum, and once, if anyone was left behind, a burst of comms static.
## Synthesised here until a recorded hum and crackle exist: there's no sound
## in the game close enough to borrow.
##
## Tween [member hum_level], [member pitch] and [member static_level]; 0 is
## silent.

const _MIX_RATE: float = 22050.0
## The drive's fundamental, in Hz; the hum is it and two overtones.
const _BASE_HZ: float = 55.0

var hum_level: float = 0.0
## The hum's pitch as a share of its own: the drive dimming a step drops it.
var pitch: float = 1.0
var static_level: float = 0.0

var _playback: AudioStreamGeneratorPlayback
var _phase: float = 0.0
var _time: float = 0.0
## Comms static isn't steady hiss: it cuts in and out.
var _crackle: float = 0.0
## Not a gameplay stream: noise for the static only.
var _noise: RandomNumberGenerator = RandomNumberGenerator.new()


func _ready() -> void:
	bus = &"SFX"
	var generator: AudioStreamGenerator = AudioStreamGenerator.new()
	generator.mix_rate = _MIX_RATE
	generator.buffer_length = 0.2
	stream = generator
	play()
	_playback = get_stream_playback() as AudioStreamGeneratorPlayback


func _process(_delta: float) -> void:
	if _playback == null:
		return
	var frames: int = _playback.get_frames_available()
	var step: float = 1.0 / _MIX_RATE
	for i: int in frames:
		_time += step
		_phase = fmod(_phase + _BASE_HZ * pitch * step, 1.0)
		# A slow swell, so the hum breathes like a running drive.
		var swell: float = 0.85 + 0.15 * sin(_time * 1.3)
		var hum: float = sin(TAU * _phase) * 0.6 + sin(TAU * _phase * 2.0) * 0.25 \
			+ sin(TAU * _phase * 3.0 + 0.7) * 0.1
		var sample: float = hum * hum_level * swell * 0.8
		if static_level > 0.0:
			if _noise.randf() < 0.0015:
				_crackle = _noise.randf_range(0.3, 1.0) if _crackle < 0.2 else 0.0
			sample += _noise.randf_range(-1.0, 1.0) * static_level * (0.25 + _crackle) * 0.4
		_playback.push_frame(Vector2(sample, sample))
