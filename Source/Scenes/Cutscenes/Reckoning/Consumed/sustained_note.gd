class_name SustainedNote
extends AudioStreamPlayer
## The Last Die's single sustained note (RECKONING_ENDINGS.md §6.4): what the
## music falls away to while the ship drifts into the hole, ending with its
## light. A stand-in, synthesised here, until the real cue is recorded
## (SOUND_EFFECTS_TODO.md): a soft tone with a slow beat between two voices,
## so it breathes rather than buzzes.

## The note, in Hz. A low D.
@export var pitch_hz: float = 146.83
## How loud it swells to, linear 0-1, under the music bus.
@export var peak: float = 0.22

const _MIX_RATE: float = 22050.0
## Hz the second voice sits off the first: the slow beat.
const _BEAT_HZ: float = 0.6

var _playback: AudioStreamGeneratorPlayback
var _phase: float = 0.0
var _phase_detuned: float = 0.0
## The level the note is heading for, and how fast it moves there (per second).
var _level: float = 0.0
var _target: float = 0.0
var _rate: float = 1.0


func _init() -> void:
	var generator: AudioStreamGenerator = AudioStreamGenerator.new()
	generator.mix_rate = _MIX_RATE
	generator.buffer_length = 0.25
	stream = generator
	bus = &"Music"


## Swells in over [param seconds].
func swell(seconds: float) -> void:
	if not playing:
		play()
		_playback = get_stream_playback() as AudioStreamGeneratorPlayback
	_target = peak
	_rate = peak / maxf(seconds, 0.01)


## Lets go over [param seconds]. It stops once silent.
func release(seconds: float) -> void:
	_target = 0.0
	_rate = maxf(_level, 0.001) / maxf(seconds, 0.01)


func _process(_delta: float) -> void:
	if not playing or _playback == null:
		return
	var frames: int = _playback.get_frames_available()
	var step: float = TAU * pitch_hz / _MIX_RATE
	var step_detuned: float = TAU * (pitch_hz + _BEAT_HZ) / _MIX_RATE
	var level_step: float = _rate / _MIX_RATE
	for i: int in frames:
		_level = move_toward(_level, _target, level_step)
		_phase = fmod(_phase + step, TAU)
		_phase_detuned = fmod(_phase_detuned + step_detuned, TAU)
		# The fundamental, a little of the octave and the twelfth, in two voices.
		var a: float = sin(_phase) + 0.3 * sin(2.0 * _phase) + 0.12 * sin(3.0 * _phase)
		var b: float = 0.5 * (sin(_phase_detuned) + 0.3 * sin(2.0 * _phase_detuned))
		var sample: float = _level * (a + b) / 2.1
		_playback.push_frame(Vector2(sample, sample))
	if _target == 0.0 and _level == 0.0:
		stop()
