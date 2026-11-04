class_name TileUnlockPopup
extends Node2D
## The card a gate jump stops on when it unlocks a tile family: the family's
## name, what it does, and every tile it adds to offers, popping in one by one.
## Pointing at a tile reads it out underneath. The jump waits for Close.
##
## In world space, like ConfirmDialog, so the tiles are drawn on the same
## pixel grid as the ones on the player's grid.

signal closed()

const _MEDIUM_BUTTON: PackedScene = preload("res://Source/Systems/UI/Buttons/medium_button.tscn")
const _OPEN_SFX: SoundEffectResource = preload("res://Source/Resources/SoundEffectResources/SoundEffects/upgrade_trigger.tres")
const _TILE_SFX: SoundEffectResource = preload("res://Source/Resources/SoundEffectResources/SoundEffects/shop_stock_pop.tres")
## Blue, like the region cards' Close: carry on, nothing to weigh up.
const _BUTTON_TEXTURE: Texture2D = preload("res://Assets/Textures/UI/Buttons/button_medium_blue.png")

const _DIM_COLOR: Color = Color(0.027451, 0.0117647, 0.054902, 0.83)
## Wide enough for the biggest family's tiles on one row.
const _WIDTH: int = 256
const _MAX_COLUMNS: int = 9
const _TILE_SIZE: int = 24
const _TILE_GAP: int = 4
const _PANEL_PADDING: Vector2 = Vector2(8, 6)
## Seconds between one tile popping in and the next.
const _TILE_STAGGER: float = 0.07
const _GLITCH_MS: int = 160

var _root: Control
var _dim: ColorRect
var _panel: _Panel
var _column: VBoxContainer
var _info_label: RichTextLabel
var _close_button: Button
var _keyword_popup: PanelContainer
var _keyword_label: RichTextLabel
var _tween: Tween


func _ready() -> void:
	z_index = 40
	_build()
	hide()


func _process(_delta: float) -> void:
	if visible and _keyword_popup and _keyword_popup.visible:
		_place_keyword_popup()


## Shows [param family] and the [param tiles] it just added to offers.
## [param number] counts this family among all [param total] of them.
func open(family: TileFamilyResource, tiles: Array[TileResource], number: int, total: int) -> void:
	_add_label(tr("TILE_UNLOCK_HEADER").format({"number": number, "total": total}), 1.0, Globals.white)
	_add_label(tr(family.family_name), 2.0, family.accent_color)
	_add_rich_text(Utils.format_text(tr(family.description), true), 0)

	var grid: GridContainer = GridContainer.new()
	grid.columns = mini(maxi(tiles.size(), 1), _MAX_COLUMNS)
	grid.add_theme_constant_override("h_separation", _TILE_GAP)
	grid.add_theme_constant_override("v_separation", _TILE_GAP)
	grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_column.add_child(grid)
	var icons: Array[TextureRect] = []
	for tile: TileResource in tiles:
		# The grid resets its children's scale whenever it lays them out, so
		# each icon pops inside a holder the grid places instead.
		var holder: Control = Control.new()
		holder.custom_minimum_size = Vector2(_TILE_SIZE, _TILE_SIZE)
		grid.add_child(holder)
		var icon: TextureRect = _tile_icon(tile)
		holder.add_child(icon)
		icons.append(icon)

	# Room held open for a tile's name and description, so pointing at one
	# doesn't resize the card.
	_info_label = _add_rich_text(tr("TILE_UNLOCK_HINT"), 40)
	_info_label.add_theme_color_override("default_color", Globals.purple)

	var button_row: CenterContainer = CenterContainer.new()
	_column.add_child(button_row)
	_close_button = _MEDIUM_BUTTON.instantiate()
	button_row.add_child(_close_button)
	_close_button.set_button_text("TILE_UNLOCK_CLOSE")
	OptionsMenu.set_button_texture(_close_button, _BUTTON_TEXTURE)
	_close_button.hover_text_color = family.accent_color
	_close_button.pressed_within_window.connect(_close)
	_close_button.disabled = true

	_panel.outline = family.accent_color
	# Clear until it has laid itself out and _play_in() fades it up.
	_dim.modulate.a = 0.0
	_panel.modulate.a = 0.0
	_column.modulate.a = 0.0
	show()
	_play_in.call_deferred(icons)


func _build() -> void:
	_root = Control.new()
	_root.size = Globals.SCREEN_SIZE
	add_child(_root)

	_dim = ColorRect.new()
	_dim.color = _DIM_COLOR
	_dim.size = Globals.SCREEN_SIZE
	# Swallows clicks so nothing under the card is touched while it's up.
	_dim.mouse_filter = Control.MOUSE_FILTER_STOP
	_root.add_child(_dim)

	_panel = _Panel.new()
	_root.add_child(_panel)

	_column = VBoxContainer.new()
	_column.custom_minimum_size.x = _WIDTH
	_column.add_theme_constant_override("separation", 2)
	_column.resized.connect(_fit_panel)
	_root.add_child(_column)

	_keyword_popup = PanelContainer.new()
	_keyword_popup.visible = false
	_keyword_popup.z_index = 5
	_keyword_popup.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.0156863, 0.00784314, 0.0901961, 1.0)
	style.set_border_width_all(1)
	style.border_color = Color(0.94902, 0.611765, 0.364706, 1.0)
	style.content_margin_left = 3.0
	style.content_margin_top = 1.0
	style.content_margin_right = 3.0
	style.content_margin_bottom = 1.0
	_keyword_popup.add_theme_stylebox_override("panel", style)
	_root.add_child(_keyword_popup)

	_keyword_label = RichTextLabel.new()
	_keyword_label.custom_minimum_size = Vector2(114, 0)
	_keyword_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_keyword_label.bbcode_enabled = true
	_keyword_label.fit_content = true
	_keyword_label.scroll_active = false
	_keyword_label.add_theme_color_override("default_color", Globals.white)
	_keyword_popup.add_child(_keyword_label)


## Small text at [param scale] (see FontRoles).
func _add_label(text: String, scale: float, color: Color) -> Label:
	var label: Label = Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.theme_type_variation = FontRoles.slot(FontRoles.SMALL, scale)
	label.add_theme_color_override("font_color", color)
	_column.add_child(label)
	return label


func _add_rich_text(text: String, minimum_height: int) -> RichTextLabel:
	var label: RichTextLabel = RichTextLabel.new()
	label.bbcode_enabled = true
	label.fit_content = true
	label.scroll_active = false
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.custom_minimum_size = Vector2(_WIDTH, minimum_height)
	label.add_theme_color_override("default_color", Globals.white)
	label.mouse_filter = Control.MOUSE_FILTER_PASS
	label.meta_hover_started.connect(_on_keyword_hover_started)
	label.meta_hover_ended.connect(_on_keyword_hover_ended)
	label.text = text
	_column.add_child(label)
	return label


## The tile with its use lights lit, as it looks at the start of a turn.
func _tile_icon(tile: TileResource) -> TextureRect:
	var icon: TextureRect = TextureRect.new()
	icon.size = Vector2(_TILE_SIZE, _TILE_SIZE)
	icon.pivot_offset = Vector2(_TILE_SIZE, _TILE_SIZE) / 2.0
	if tile.textures:
		var last: int = tile.textures.get_frame_count(&"default") - 1
		icon.texture = tile.textures.get_frame_texture(&"default", last)
	icon.mouse_filter = Control.MOUSE_FILTER_STOP
	icon.mouse_entered.connect(_read_out.bind(tile))
	icon.scale = Vector2.ZERO
	return icon


func _read_out(tile: TileResource) -> void:
	_keyword_popup.hide()
	_info_label.remove_theme_color_override("default_color")
	var no_counters: Dictionary[String, int] = {}
	_info_label.text = Utils.format_text("%s\n%s" % [
		tile.display_name(), Tile.fill_data_tokens(tile.display_description(), no_counters)], true)


func _on_keyword_hover_started(meta: Variant) -> void:
	var rule: String = Keywords.definition(str(meta))
	if rule.is_empty():
		return
	_keyword_label.text = Utils.format_text("[color=orange]%s[/color]: %s" % [Keywords.title(str(meta)), rule])
	_keyword_popup.reset_size()
	_keyword_popup.show()
	_place_keyword_popup()


func _on_keyword_hover_ended(_meta: Variant) -> void:
	_keyword_popup.hide()


func _place_keyword_popup() -> void:
	var popup_size: Vector2 = _keyword_popup.size
	var mouse: Vector2 = get_local_mouse_position()
	var pos: Vector2 = mouse + Vector2(6, 6)
	pos.x = clampf(pos.x, 2.0, Globals.SCREEN_SIZE.x - popup_size.x - 2.0)
	if pos.y + popup_size.y > Globals.SCREEN_SIZE.y - 2.0:
		pos.y = mouse.y - popup_size.y - 4.0
	_keyword_popup.position = pos.floor()


## Once the card has laid itself out: the dim fades up, the card lands with a
## glitch, then the tiles pop in one by one and Close wakes up.
func _play_in(icons: Array[TextureRect]) -> void:
	_column.position = ((Globals.SCREEN_SIZE - _column.size) / 2.0).round()
	_fit_panel()

	Events.play_sound.emit(_OPEN_SFX)
	Events.glitch_burst.emit(_GLITCH_MS)
	Events.camera_shake_small.emit()

	if _tween:
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(_dim, "modulate:a", 1.0, 0.2)
	_tween.parallel().tween_property(_panel, "modulate:a", 1.0, 0.12)
	_tween.parallel().tween_property(_column, "modulate:a", 1.0, 0.12)
	_tween.tween_interval(0.1)
	# One step, each tile delayed a little more than the last, so the pops
	# overlap instead of queueing.
	for i: int in icons.size():
		var delay: float = i * _TILE_STAGGER
		var step: PropertyTweener = (_tween if i == 0 else _tween.parallel())\
			.tween_property(icons[i], "scale", Vector2.ONE, 0.18)
		step.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT).set_delay(delay)
		_tween.parallel().tween_callback(Events.play_sound.emit.bind(_TILE_SFX)).set_delay(delay)
	_tween.tween_callback(func() -> void: _close_button.disabled = false)


func _close() -> void:
	if _tween:
		_tween.kill()
	_close_button.disabled = true
	_tween = create_tween()
	_tween.tween_property(_root, "modulate:a", 0.0, 0.2)
	_tween.tween_callback(func() -> void:
		hide()
		closed.emit()
	)


func _fit_panel() -> void:
	var around: Rect2 = Rect2(_column.position, _column.size)
	_panel.box = around.grow_individual(_PANEL_PADDING.x, _PANEL_PADDING.y, _PANEL_PADDING.x, _PANEL_PADDING.y)


class _Panel:
	extends Control

	var outline: Color = Color.WHITE:
		set(value):
			outline = value
			queue_redraw()
	var box: Rect2:
		set(value):
			# On whole pixels, so the outline stays one pixel wide.
			box = Rect2(value.position.round(), value.size.round())
			queue_redraw()

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		if box.has_area():
			OptionsFrame.draw_box(self, box, outline)
