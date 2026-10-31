class_name OverloadGauge
extends Node2D
## How close a ship with a breaker is to overloading. A bar of cells, five
## pips each, fills with the faces of the dice it holds toward the breaker
## glyph at the right end, with the count beside it:
##
## - CALM: yellow cells, room to spare.
## - WARNING: WARN_PIPS or fewer pips to go. The cells turn orange and the
##   empty ones left pulse, so "this many more" reads without counting.
## - ARMED: full. Its next turn is an overload; the bar and glyph blink red.
## - TRIPPED: it just overloaded (Enemy.overloaded). A white flash, then the
##   bar empties as the dice go home and grows by the threshold's rise.
##
## Hovering it gives a one-line hint; clicking it, the full rule.
##
## Polls the heat rather than listening: board-wide effects (REROLL_ALL, a
## flip) change the faces of dice already in a ship's hand without the ship
## hearing of it.

enum State { CALM, WARNING, ARMED, TRIPPED }

## Pips to go at or below which the gauge warns.
const WARN_PIPS: int = 3

const _PARTS: Texture2D = preload("res://Assets/Textures/Enemies/OverloadGauge/overload_gauge_parts.png")
const _GLYPH: Texture2D = preload("res://Assets/Textures/Enemies/OverloadGauge/overload_glyph-Sheet.png")

## Columns of the parts atlas (overload_gauge_parts.aseprite), each 1 px wide.
const _PART_CAP: int = 0
const _PART_SEPARATOR: int = 1
const _PART_UNLIT: int = 2
const _PART_LIT: int = 3
const _PART_WARNING: int = 4
const _PART_ARMED: int = 5
const _PART_FLASH: int = 6
const _PART_EMBER: int = 7

## Frames of the glyph sheet (overload_glyph.aseprite).
const _GLYPH_IDLE: int = 0
const _GLYPH_WARNING: int = 1
const _GLYPH_ARMED: int = 2
const _GLYPH_FLASH: int = 3

const _BAR_HEIGHT: int = 7
const _GLYPH_SIZE: int = 11
## The bar's top edge, relative to the gauge's origin. The glyph overhangs it
## by 2 px above and below.
const _BAR_TOP: int = -2
## Pips per cell, so a count reads in fives; each pip is _PIP_WIDTH px.
const PIPS_PER_CELL: int = 5
const _PIP_WIDTH: int = 2
const _LABEL_GAP: int = 2

const _BLINK_SECONDS: float = 0.25
const _PULSE_SECONDS: float = 0.4
const _TRIP_SECONDS: float = 0.7
const _TRIP_BLINK_SECONDS: float = 0.08

@export var label: Label
@export var clickable: Clickable
@export var hit_box: CollisionShape2D

## The ship this gauge reads. Set before adding the gauge to the tree.
var enemy: Enemy:
	set(value):
		if is_instance_valid(enemy) and enemy.overloaded.is_connected(_on_overloaded):
			enemy.overloaded.disconnect(_on_overloaded)
		enemy = value
		if is_instance_valid(enemy):
			enemy.overloaded.connect(_on_overloaded)

var _shown_heat: int = -1
var _shown_threshold: int = -1
var _state: State = State.CALM
## Toggles every blink or pulse period; what it lights depends on the state.
var _blink_on: bool = false
var _blink_clock: float = 0.0
var _trip_left: float = 0.0
## Left edge of the whole gauge (label first) and of the bar's cap.
var _left: int = 0
var _bar_left: int = 0


func _ready() -> void:
	clickable.clicked.connect(_show_info)
	_refresh(true)


func _process(delta: float) -> void:
	if not is_instance_valid(enemy):
		return
	if _trip_left > 0.0:
		_trip_left -= delta
		_tick_blink(delta, _TRIP_BLINK_SECONDS)
		if _trip_left <= 0.0:
			_refresh(true)
		return
	_refresh(false)
	if _state == State.ARMED:
		_tick_blink(delta, _BLINK_SECONDS)
	elif _state == State.WARNING:
		_tick_blink(delta, _PULSE_SECONDS)


## What the gauge shows for [param heat] held against [param threshold].
static func state_for(heat: int, threshold: int) -> State:
	if threshold <= 0:
		return State.CALM
	var to_go: int = threshold - heat
	if to_go <= 0:
		return State.ARMED
	if to_go <= WARN_PIPS:
		return State.WARNING
	return State.CALM


func state() -> State:
	return _state


## How far the gauge reaches left (x) and right (y) of its own origin, so the
## formation can keep neighbours clear of it.
func reach() -> Vector2:
	return Vector2(-_left, _left + _width())


## Picks up a new heat or threshold. [param force] relays it out even when
## nothing changed (after a trip, whose flash froze the old numbers).
func _refresh(force: bool) -> void:
	if not is_instance_valid(enemy):
		return
	var heat: int = enemy.held_heat()
	var threshold: int = enemy.overload_threshold
	if not force and heat == _shown_heat and threshold == _shown_threshold:
		return
	if heat > _shown_heat and _shown_heat >= 0:
		Juice.bump(self, 0.3, 0.2)
	if threshold != _shown_threshold:
		_shown_threshold = threshold
		_layout()
	_shown_heat = heat
	var new_state: State = state_for(heat, threshold)
	if new_state != _state:
		_state = new_state
		_blink_on = false
		_blink_clock = 0.0
	label.text = "%d/%d" % [heat, threshold]
	_update_label_colour()
	queue_redraw()


func _on_overloaded() -> void:
	_state = State.TRIPPED
	_trip_left = _TRIP_SECONDS
	_blink_on = true
	_blink_clock = 0.0
	Juice.bump(self, 0.5, 0.3)
	_update_label_colour()
	queue_redraw()


func _tick_blink(delta: float, period: float) -> void:
	# A steady colour still tells every state apart; only the motion goes.
	if Globals.reduce_flashing:
		return
	_blink_clock += delta
	if _blink_clock < period:
		return
	_blink_clock = 0.0
	_blink_on = not _blink_on
	_update_label_colour()
	queue_redraw()


## Lays the label, bar and glyph out centred on the origin. The label keeps
## room for the widest count this threshold can show, so it doesn't shove the
## bar about as the heat changes.
func _layout() -> void:
	var widest: String = "%d/%d" % [_shown_threshold, _shown_threshold]
	var font: Font = label.get_theme_font(&"font")
	var font_size: int = label.get_theme_font_size(&"font_size")
	var label_width: int = ceili(font.get_string_size(widest, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	label.size.x = label_width
	var total: int = label_width + _LABEL_GAP + _width()
	_left = -floori(total / 2.0)
	label.position.x = _left
	_bar_left = _left + label_width + _LABEL_GAP

	var shape: RectangleShape2D = hit_box.shape as RectangleShape2D
	shape.size = Vector2(total, _GLYPH_SIZE)
	hit_box.position = Vector2(_left + total / 2.0, _BAR_TOP - 2 + _GLYPH_SIZE / 2.0)


## The bar and glyph: a cap, the pips with a separator between cells, then
## the glyph.
func _width() -> int:
	var pips: int = maxi(_shown_threshold, 0)
	var separators: int = maxi(ceili(pips / float(PIPS_PER_CELL)) - 1, 0)
	return 1 + _PIP_WIDTH * pips + separators + _GLYPH_SIZE


func _draw() -> void:
	if _shown_threshold <= 0:
		return
	var x: int = _bar_left
	_draw_part(_PART_CAP, x)
	x += 1
	for i: int in range(_shown_threshold):
		if i > 0 and i % PIPS_PER_CELL == 0:
			_draw_part(_PART_SEPARATOR, x)
			x += 1
		var part: int = _pip_part(i)
		for column: int in range(_PIP_WIDTH):
			_draw_part(part, x + column)
		x += _PIP_WIDTH
	var frame: int = _glyph_frame()
	draw_texture_rect_region(_GLYPH,
		Rect2(x, _BAR_TOP - 2, _GLYPH_SIZE, _GLYPH_SIZE),
		Rect2(frame * _GLYPH_SIZE, 0, _GLYPH_SIZE, _GLYPH_SIZE))


func _draw_part(part: int, x: int) -> void:
	draw_texture_rect_region(_PARTS, Rect2(x, _BAR_TOP, 1, _BAR_HEIGHT), Rect2(part, 0, 1, _BAR_HEIGHT))


## Which part pip [param index] (0 is the leftmost) wears right now.
func _pip_part(index: int) -> int:
	var lit: bool = index < _shown_heat
	match _state:
		State.TRIPPED:
			return _PART_FLASH if _blink_on else _PART_ARMED
		State.ARMED:
			return _PART_FLASH if _blink_on else _PART_ARMED
		State.WARNING:
			if lit:
				return _PART_WARNING
			return _PART_EMBER if _blink_on else _PART_UNLIT
	return _PART_LIT if lit else _PART_UNLIT


func _glyph_frame() -> int:
	match _state:
		State.TRIPPED:
			return _GLYPH_FLASH if _blink_on else _GLYPH_ARMED
		State.ARMED:
			return _GLYPH_ARMED
		State.WARNING:
			return _GLYPH_WARNING
	return _GLYPH_IDLE


func _update_label_colour() -> void:
	var colour: Color = Globals.white
	match _state:
		State.WARNING:
			colour = Globals.orange
		State.ARMED:
			colour = Globals.white if _blink_on else Globals.red
	label.add_theme_color_override(&"font_color", colour)


## The full rule, the way a status badge explains itself.
func _show_info() -> void:
	if not is_instance_valid(enemy):
		return
	var icon: AtlasTexture = AtlasTexture.new()
	icon.atlas = _GLYPH
	icon.region = Rect2(_GLYPH_ARMED * _GLYPH_SIZE, 0, _GLYPH_SIZE, _GLYPH_SIZE)
	var info: InfoResource = InfoResource.new()
	info.title_label_text = "[color=orange]%s[/color]" % tr(&"OVERLOAD_GAUGE_TITLE")
	info.top_label_text = tr(&"OVERLOAD_GAUGE_HELD").format({
		"heat": enemy.held_heat(), "threshold": enemy.overload_threshold})
	info.texture = icon
	info.bottom_label_text = tr(&"OVERLOAD_GAUGE_RULE").format({
		"growth": enemy.enemy_resource.overload_threshold_growth})
	Events.show_info.emit(info)
