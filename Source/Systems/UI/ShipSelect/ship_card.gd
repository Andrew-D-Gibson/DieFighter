class_name ShipCard
extends Control

## One ship on the ship-select popup: its hull, name, a map of its tile grid
## drawn from the ship's own layout, and its pitch. Click to pick it.

signal picked(card: ShipCard)

const SIZE: Vector2 = Vector2(98, 124)

const _HOVER_SFX: SoundEffectResource = preload("res://Source/Resources/SoundEffectResources/SoundEffects/hover_thump.tres")
const _PICK_SFX: SoundEffectResource = preload("res://Source/Resources/SoundEffectResources/SoundEffects/tile_dropped.tres")

const _BACKGROUND: Color = Color("#0f0c2e")
## Mixed toward the ship's theme colour.
const _BORDER: Color = Color("#463c91")
const _BORDER_PICKED: Color = Color("#eed35d")
const _CELL: Color = Color("#251c6b")

## Size of one grid cell on the map, and the gap between cells.
const _MAP_CELL: int = 4
const _MAP_GAP: int = 1
## The map's box on the card.
const _MAP_RECT: Rect2 = Rect2(4, 60, 90, 20)

var ship: ShipResource
var is_picked: bool = false:
	set(value):
		is_picked = value
		_name_label.add_theme_color_override(
			&"default_color", Globals.yellow if is_picked else Globals.white
		)
		queue_redraw()

var _hovered: bool = false
var _hull: TextureRect
var _name_label: RichTextLabel
var _bob_time: float = 0.0


func setup(for_ship: ShipResource) -> void:
	ship = for_ship
	custom_minimum_size = SIZE
	size = SIZE
	mouse_filter = Control.MOUSE_FILTER_STOP

	_hull = TextureRect.new()
	_hull.texture = ship.get_preview_texture()
	_hull.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	_hull.position = Vector2(0, 4)
	_hull.size = Vector2(SIZE.x, 32)
	_hull.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_hull)

	_name_label = _label(ship.display_name.to_upper(), Rect2(0, 34, SIZE.x, 14), 16)
	_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	var stats: RichTextLabel = _label(_stats_text(), Rect2(0, 45, SIZE.x, 14), 16)
	stats.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	# Formatted like tile text, so palette names ("orange", "purple") are the
	# palette's, not Godot's named colours.
	var description: RichTextLabel = _label(Utils.format_text(ship.description), Rect2(4, 81, SIZE.x - 8, 42), 16)
	description.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	mouse_entered.connect(func() -> void:
		_hovered = true
		if not is_picked:
			Events.play_sound.emit(_HOVER_SFX)
		queue_redraw()
	)
	mouse_exited.connect(func() -> void:
		_hovered = false
		queue_redraw()
	)
	is_picked = false


## What the ship starts a run with: hull and dice.
func _stats_text() -> String:
	if not ship.starting_save:
		return ""
	var start: GameSaveResource = ship.starting_save
	var hull: String = tr("SHIP_CARD_HULL").format({"health": start.player_health, "max": start.player_max_health})
	var dice: String = tr("SHIP_CARD_DICE").format({"dice": start.num_of_dice})
	return "[color=#d03656]%s[/color]  [color=#eed35d]%s[/color]" % [hull, dice]


## Slides the card up into place, after a delay so a row of them ripples in.
func play_entrance(delay: float) -> void:
	var home: Vector2 = position
	position.y += 10
	modulate.a = 0.0
	var tween: Tween = create_tween().set_parallel()
	tween.tween_property(self, "position", home, 0.25) \
		.set_delay(delay).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "modulate:a", 1.0, 0.15).set_delay(delay)


func _label(text: String, rect: Rect2, font_size: int) -> RichTextLabel:
	var label: RichTextLabel = RichTextLabel.new()
	label.bbcode_enabled = true
	label.scroll_active = false
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.position = rect.position
	label.size = rect.size
	label.add_theme_font_size_override(&"normal_font_size", font_size)
	label.add_theme_color_override(&"default_color", Globals.white)
	label.text = text
	add_child(label)
	return label


func _process(delta: float) -> void:
	# The picked hull idles on its engines; the rest sit still.
	_bob_time = _bob_time + delta if is_picked else 0.0
	_hull.position.y = 4.0 + roundf(sin(_bob_time * 3.0))


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed \
	and event.button_index == MOUSE_BUTTON_LEFT:
		if not is_picked:
			Events.play_sound.emit(_PICK_SFX)
		picked.emit(self)
		accept_event()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, SIZE), _BACKGROUND)
	# At rest the frame is a dim wash of the ship's colour; hovered, the colour
	# itself; picked, the gold every pick on the menu uses.
	var border: Color = ship.theme_color if _hovered else _BORDER.lerp(ship.theme_color, 0.45)
	if is_picked:
		border = _BORDER_PICKED
	draw_rect(Rect2(Vector2(0.5, 0.5), SIZE - Vector2.ONE), border, false, 1.0)
	if is_picked:
		# A soft inner glow, and bright corner brackets, so the pick reads
		# from across the screen.
		var glow: Color = Color(_BORDER_PICKED, 0.3)
		draw_rect(Rect2(Vector2(1.5, 1.5), SIZE - Vector2.ONE * 3), glow, false, 1.0)
		for left: bool in [true, false]:
			for top: bool in [true, false]:
				# An L of two 8px bars wrapped round the outside of the corner.
				var outer: Vector2 = Vector2(-2.0 if left else SIZE.x, -2.0 if top else SIZE.y)
				var bar_x: float = outer.x if left else outer.x - 6.0
				var bar_y: float = outer.y if top else outer.y - 6.0
				draw_rect(Rect2(bar_x, outer.y, 8, 2), _BORDER_PICKED)
				draw_rect(Rect2(outer.x, bar_y, 2, 8), _BORDER_PICKED)
	_draw_grid_map()


## The ship's tile grid in miniature: every cell it has, its holes, and where
## its starting tiles sit.
func _draw_grid_map() -> void:
	var cells: Array[Vector2i] = ship.get_cells()
	if cells.is_empty():
		return
	var bounds: Vector2i = Vector2i.ZERO
	for cell: Vector2i in cells:
		bounds = Vector2i(maxi(bounds.x, cell.x + 1), maxi(bounds.y, cell.y + 1))
	var pitch: int = _MAP_CELL + _MAP_GAP
	var map_size: Vector2 = Vector2(bounds * pitch - Vector2i.ONE * _MAP_GAP)
	var origin: Vector2 = (_MAP_RECT.position + (_MAP_RECT.size - map_size) / 2.0).floor()

	var starting: Dictionary = {}
	if ship.starting_save:
		starting = ship.starting_save.tile_locations

	for cell: Vector2i in cells:
		var rect: Rect2 = Rect2(origin + Vector2(cell * pitch), Vector2.ONE * _MAP_CELL)
		draw_rect(rect, ship.theme_color if starting.has(cell) else _CELL)
