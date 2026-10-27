class_name ErrorTextPopup
extends RichTextLabel

@export_category('Behavior')
@export var full_opacity_time: float = 2
@export var fade_time: float = 1
@export var movement_velocity: Vector2 = Vector2(0, -0.5)

@export_category('Layout')
## Widest the box grows before its text wraps onto more lines.
@export var max_width: float = 100.0
## Room between the text and the box's edges, both sides together.
@export var padding: Vector2 = Vector2(8.0, 8.0)

var _current_time_remaining: float 


func _ready() -> void:
	_current_time_remaining = full_opacity_time + fade_time


## Shows [param message], sizing the box to it: one line while that fits in
## max_width, else as few lines as it needs, with the words spread evenly
## across them so the last line isn't one stray word.
func set_message(message: String) -> void:
	text = message
	var font: Font = get_theme_font(&"normal_font")
	var font_size: int = get_theme_font_size(&"normal_font_size")
	var words: PackedStringArray = get_parsed_text().split(" ", false)
	var space: float = _width_of(" ", font, font_size)
	var word_widths: PackedFloat32Array = PackedFloat32Array()
	var widest_word: float = 0.0
	var one_line: float = 0.0
	for word: String in words:
		var width: float = _width_of(word, font, font_size)
		word_widths.append(width)
		widest_word = maxf(widest_word, width)
		one_line += width
	one_line += space * maxi(0, words.size() - 1)

	var room: float = max_width - padding.x
	var lines: int = 1
	var line_width: float = one_line
	if one_line > room:
		lines = _lines_at(room, word_widths, space)
		# Narrow the box until the text would need another line: that's the
		# width the words share most evenly.
		line_width = maxf(widest_word, ceilf(one_line / lines))
		while line_width < room and _lines_at(line_width, word_widths, space) > lines:
			line_width += 1.0

	autowrap_mode = TextServer.AUTOWRAP_WORD_SMART if lines > 1 else TextServer.AUTOWRAP_OFF
	var line_height: float = font.get_height(font_size) + get_theme_constant(&"line_separation")
	size = Vector2(
		maxf(custom_minimum_size.x, ceilf(line_width) + padding.x),
		maxf(custom_minimum_size.y, ceilf(line_height * lines) + padding.y)
	)


func _process(delta: float) -> void:
	_current_time_remaining -= delta
	
	position += movement_velocity *  delta
	
	if _current_time_remaining < fade_time:
		self.modulate = Color(1,1,1, _current_time_remaining / fade_time)
		
	if _current_time_remaining <= 0:
		queue_free()


func _width_of(snippet: String, font: Font, font_size: int) -> float:
	return font.get_string_size(snippet, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x


## How many lines greedy word wrap makes of the words at [param width].
static func _lines_at(width: float, word_widths: PackedFloat32Array, space: float) -> int:
	var lines: int = 1
	var used: float = 0.0
	for word_width: float in word_widths:
		if used > 0.0 and used + space + word_width > width:
			lines += 1
			used = word_width
		else:
			used += (space if used > 0.0 else 0.0) + word_width
	return lines
