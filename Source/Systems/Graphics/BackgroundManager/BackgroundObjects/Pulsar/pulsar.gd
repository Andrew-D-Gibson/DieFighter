extends Sprite2D
## A pulsar that actually pulses.
##
## Rides on self_modulate rather than modulate, because BackgroundManager
## writes modulate from the StaticBackgroundObjectResource and the two would
## otherwise fight every frame.

## Seconds per full brightness cycle.
@export var period: float = 1.6

## How far the brightness swings either side of full.
@export var depth: float = 0.35

var _time: float = 0.0


func _process(delta: float) -> void:
	_time += delta
	# sin() spends most of its time near the extremes; squaring the positive
	# lobe gives a sharper flash with a longer dim trough, which is what a
	# pulsar looks like.
	var wave: float = 0.5 + 0.5 * sin(TAU * _time / period)
	self_modulate.a = 1.0 - depth + depth * wave * wave
