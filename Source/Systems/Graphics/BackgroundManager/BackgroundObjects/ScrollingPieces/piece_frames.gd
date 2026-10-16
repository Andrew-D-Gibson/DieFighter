class_name PieceFrames
extends Sprite2D
## Steps a scrolling piece's sprite sheet: a flicker, a blinking light, a
## crackle of arcs. Each copy starts somewhere random in its loop, so a field
## of the same piece never pulses in step.

@export var fps: float = 6.0
## The frames to loop through, in order. Repeat a frame to hold it, e.g. a run
## of blank frames between rare arcs. Empty loops every frame of the sheet.
@export var sequence: PackedInt32Array = []

var _step: int = 0
var _time: float = 0.0


func _ready() -> void:
	_step = RNGManager.randi_range(RNGManager.Bucket.COSMETIC, 0, _length() - 1)
	_time = RNGManager.randf_range(RNGManager.Bucket.COSMETIC, 0.0, 1.0 / fps)
	_show_step()


func _process(delta: float) -> void:
	_time += delta
	var step_seconds: float = 1.0 / fps
	if _time < step_seconds:
		return
	while _time >= step_seconds:
		_time -= step_seconds
		_step = (_step + 1) % _length()
	_show_step()


func _length() -> int:
	return sequence.size() if not sequence.is_empty() else hframes * vframes


func _show_step() -> void:
	frame = sequence[_step] if not sequence.is_empty() else _step
