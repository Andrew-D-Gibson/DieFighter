class_name EchoVisual
extends Node2D
## An armed echo, shown on the tile that armed it: outlines ripple out from
## the tile's edge and fade, over and over, like the sound the name is for.
## Drawn rather than textured, in whole pixels, so it sits on any tile.

## Half the tile's 24px side: where a ripple starts.
const _START_HALF: float = 12.0
## How far past the edge a ripple travels before it's gone.
const _TRAVEL: float = 5.0
const _PERIOD_SECONDS: float = 1.1
## Ripples in flight at once, evenly staggered.
const _RIPPLES: int = 2

var _time: float = 0.0


func _ready() -> void:
	z_index = 1


func _process(delta: float) -> void:
	_time += delta
	queue_redraw()


func _draw() -> void:
	for i: int in _RIPPLES:
		var phase: float = fposmod(_time / _PERIOD_SECONDS + float(i) / _RIPPLES, 1.0)
		var half: float = roundf(_START_HALF + phase * _TRAVEL)
		var color: Color = Globals.yellow
		color.a = (1.0 - phase) * 0.8
		# Four filled 1px edges rather than an outline, which straddles pixels.
		var side: float = half * 2.0
		draw_rect(Rect2(-half, -half, side, 1.0), color)
		draw_rect(Rect2(-half, half - 1.0, side, 1.0), color)
		draw_rect(Rect2(-half, -half + 1.0, 1.0, side - 2.0), color)
		draw_rect(Rect2(half - 1.0, -half + 1.0, 1.0, side - 2.0), color)
