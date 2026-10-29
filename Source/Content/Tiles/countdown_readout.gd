class_name CountdownReadout
extends Node2D
## The number a countdown tile shows: what's left of its count, in lit pixel
## digits on the dark readout window its art leaves in the lower panel, where
## other tiles draw their die slot.
##
## Countdown art leaves that window, 9x7 at (6, 15), in the darkest shade of
## the tile's ramp (CONTENT_BUILD_GUIDE §1). Two digits at most, so a count
## tops out at 99.

## The readout window's top-left on the 24x24 art, and its size.
const WINDOW: Rect2i = Rect2i(6, 15, 9, 7)

const _DIGIT_WIDTH: int = 3
const _DIGIT_HEIGHT: int = 5

## 3x5 digits, row by row, "#" lit.
const _DIGITS: Array[String] = [
	"####.##.##.####",
	".#.##..#..#.###",
	"###..#####..###",
	"###..#.##..####",
	"#.##.####..#..#",
	"####..###..####",
	"####..####.####",
	"###..#.#..#..#.",
	"####.#####.####",
	"####.####..####",
]

var value: int = 0:
	set(new_value):
		value = clampi(new_value, 0, 99)
		queue_redraw()


## Where the readout's centre is, in global space, for effects that should
## burst off it.
func centre() -> Vector2:
	return to_global(Vector2(WINDOW.get_center()))


func _draw() -> void:
	for pixel: Vector2i in lit_pixels(value):
		draw_rect(Rect2(pixel, Vector2.ONE), Globals.white)


## The art pixels lit to show [param shown], centred in the window.
static func lit_pixels(shown: int) -> Array[Vector2i]:
	var text: String = str(clampi(shown, 0, 99))
	var width: int = text.length() * (_DIGIT_WIDTH + 1) - 1
	var left: int = WINDOW.position.x + (WINDOW.size.x - width) / 2
	var top: int = WINDOW.position.y + (WINDOW.size.y - _DIGIT_HEIGHT) / 2
	var lit: Array[Vector2i] = []
	for i: int in text.length():
		var glyph: String = _DIGITS[int(text[i])]
		var x0: int = left + i * (_DIGIT_WIDTH + 1)
		for row: int in _DIGIT_HEIGHT:
			for column: int in _DIGIT_WIDTH:
				if glyph[row * _DIGIT_WIDTH + column] == "#":
					lit.append(Vector2i(x0 + column, top + row))
	return lit
