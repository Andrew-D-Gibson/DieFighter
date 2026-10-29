class_name ColorSymbolBadge
extends Node2D
## The Color Symbols accessibility option: a small shape in a tile's top-left
## corner naming its colour family, for players who can't tell the families
## apart by colour. Each family has its own silhouette (red triangle, blue
## shield, green diamond, purple ring, yellow star), so it reads with any kind
## of colour vision and in every language.
##
## A badge rides on whatever shows tile art: a Tile's sprite (the grid,
## rewards, the shop) or a TextureRect (the codex, the info panel). It works
## the family out from the art itself, so every place that draws a tile gets
## the same badge without being told what it shows, and art that isn't a
## tile's (an enemy portrait) gets none.
##
## Hidden while the option is off; every badge follows the option live.

enum Family {NONE, RED, BLUE, GREEN, PURPLE, YELLOW}

## One badge, outline included, in art pixels.
const SIZE: int = 7
## Where the badge sits on the tile: tucked just inside the frame's top-left
## corner, so the frame stays whole and the badge doesn't poke out into the
## next grid cell.
const INSET: Vector2 = Vector2(2, 1)

## One frame per family, in Family order from RED.
const _SHEET: Texture2D = preload("res://Assets/Textures/Tiles/ColorSymbols/color_symbols-Sheet.png")
const _NODE_NAME: StringName = &"ColorSymbolBadge"

## Tile art is filed by family (CONTENT_BUILD_GUIDE §1), so the folder is the
## family. Tile names are coloured too, but the badge sits on the art, so it
## follows the art.
const _FAMILY_FOLDERS: Dictionary[String, Family] = {
	"RedTiles": Family.RED,
	"BlueTiles": Family.BLUE,
	"GreenTiles": Family.GREEN,
	"PurpleTiles": Family.PURPLE,
	"YellowTiles": Family.YELLOW,
}

## The option's live value (OptionsSettings.COLOR_SYMBOLS). Static so every
## badge, including ones not made yet, reads the same setting.
static var symbols_enabled: bool = false

var family: Family = Family.NONE:
	set(value):
		family = value
		_update_visibility()
		queue_redraw()


## The family of a tile drawn with [param art] (a frame of its textures), or
## NONE for art that isn't a tile's.
static func family_of(art: Texture2D) -> Family:
	var source: Texture2D = art
	while source is AtlasTexture:
		source = (source as AtlasTexture).atlas
	if source == null:
		return Family.NONE
	var folder: String = source.resource_path.get_base_dir().get_file()
	return _FAMILY_FOLDERS.get(folder, Family.NONE)


static func family_of_tile(tile: TileResource) -> Family:
	return family_of(_tile_art(tile))


## The colour of [param tile]'s family, for effects that should match it.
## White for a tile outside the families.
static func color_of_tile(tile: TileResource) -> Color:
	match family_of_tile(tile):
		Family.RED:
			return Globals.red
		Family.BLUE:
			return Globals.blue
		Family.GREEN:
			return Globals.green
		Family.PURPLE:
			return Globals.purple
		Family.YELLOW:
			return Globals.yellow
	return Globals.white


## Puts a badge on [param sprite], a centred sprite drawing [param tile], or
## updates the one already there.
static func attach_to_tile_sprite(sprite: Node2D, tile: TileResource) -> ColorSymbolBadge:
	# Tile is a @tool script; a badge has no business in the editor.
	if Engine.is_editor_hint():
		return null
	var badge: ColorSymbolBadge = _find_or_add(sprite)
	var art: Texture2D = _tile_art(tile)
	if art:
		badge.position = (-art.get_size() / 2.0).floor() + INSET
	badge.family = family_of(art)
	return badge


## Puts a badge over the art [param rect] shows, or updates the one already
## there. Call it again whenever the rect's texture changes.
static func attach_to_rect(rect: TextureRect) -> ColorSymbolBadge:
	var badge: ColorSymbolBadge = _find_or_add(rect)
	if not rect.resized.is_connected(badge._fit_to_rect):
		rect.resized.connect(badge._fit_to_rect)
	badge._fit_to_rect()
	badge.family = family_of(rect.texture)
	return badge


## The tile's first frame, which is also the art the codex and the info panel
## show. Null for a tile with no art (test fixtures).
static func _tile_art(tile: TileResource) -> Texture2D:
	if tile == null or tile.textures == null or not tile.textures.has_animation(&"default") \
	or tile.textures.get_frame_count(&"default") == 0:
		return null
	return tile.textures.get_frame_texture(&"default", 0)


static func _find_or_add(parent: CanvasItem) -> ColorSymbolBadge:
	var badge: ColorSymbolBadge = parent.get_node_or_null(NodePath(_NODE_NAME)) as ColorSymbolBadge
	if badge == null:
		badge = ColorSymbolBadge.new()
		badge.name = _NODE_NAME
		parent.add_child(badge)
	return badge


func _ready() -> void:
	OptionsSettings.option_changed.connect(_on_option_changed)
	_update_visibility()


func _draw() -> void:
	if family == Family.NONE:
		return
	var frame: Rect2 = Rect2((family - Family.RED) * SIZE, 0, SIZE, SIZE)
	draw_texture_rect_region(_SHEET, Rect2(0, 0, SIZE, SIZE), frame)


func _on_option_changed(key: StringName, _value: Variant) -> void:
	if key == OptionsSettings.COLOR_SYMBOLS:
		_update_visibility()


func _update_visibility() -> void:
	visible = symbols_enabled and family != Family.NONE


## Lines the badge up with the art's top-left corner wherever the rect draws
## it, and at the same scale (the info panel shows a tile twelve times over).
func _fit_to_rect() -> void:
	var rect: TextureRect = get_parent() as TextureRect
	if rect == null or rect.texture == null:
		return
	var art_size: Vector2 = rect.texture.get_size()
	var art_scale: float = 1.0
	match rect.stretch_mode:
		TextureRect.STRETCH_KEEP_ASPECT_CENTERED, TextureRect.STRETCH_KEEP_ASPECT:
			art_scale = minf(rect.size.x / art_size.x, rect.size.y / art_size.y)
		TextureRect.STRETCH_SCALE:
			art_scale = rect.size.x / art_size.x
	var drawn: Vector2 = art_size * art_scale
	var corner: Vector2 = Vector2.ZERO
	if rect.stretch_mode in [TextureRect.STRETCH_KEEP_CENTERED, TextureRect.STRETCH_KEEP_ASPECT_CENTERED]:
		corner = ((rect.size - drawn) / 2.0).floor()
	position = corner + INSET * art_scale
	scale = Vector2.ONE * art_scale
