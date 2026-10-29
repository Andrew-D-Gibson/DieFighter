extends "res://test/helpers/die_fighter_test.gd"
## The Color Symbols option: every tile shows its colour family as a shape
## while it's on, wherever the tile is drawn, and follows the option live.
## Nothing here saves, so the player's options file is never touched.

const TILE_SCENE: PackedScene = preload("res://Source/Content/Tiles/tile.tscn")
const TILE_DIR: String = "res://Source/Content/Tiles/TileResources/"
const RED_TILE: TileResource = preload("res://Source/Content/Tiles/TileResources/apex_cannon.tres")
const PURPLE_TILE: TileResource = preload("res://Source/Content/Tiles/TileResources/arc_tap.tres")
const ENEMY_ART: Texture2D = preload("res://Assets/Textures/Enemies/Attacker/Attacker_targeting_image.png")

var _was_enabled: bool


func before_each() -> void:
	super()
	_was_enabled = ColorSymbolBadge.symbols_enabled
	ColorSymbolBadge.symbols_enabled = false


func after_each() -> void:
	ColorSymbolBadge.symbols_enabled = _was_enabled
	super()


func test_the_option_is_off_by_default_and_sets_the_live_value() -> void:
	assert_eq(OptionsSettings.get_default(OptionsSettings.COLOR_SYMBOLS), false)
	watch_signals(OptionsSettings)
	OptionsSettings.set_option(OptionsSettings.COLOR_SYMBOLS, true)
	assert_true(ColorSymbolBadge.symbols_enabled)
	assert_eq(OptionsSettings.get_option(OptionsSettings.COLOR_SYMBOLS), true)
	assert_signal_emitted_with_parameters(OptionsSettings, "option_changed", [OptionsSettings.COLOR_SYMBOLS, true])


func test_every_tile_has_a_colour_family() -> void:
	var checked: int = 0
	for file: String in DirAccess.get_files_at(TILE_DIR):
		if not file.ends_with(".tres"):
			continue
		var tile: TileResource = load(TILE_DIR + file)
		assert_ne(ColorSymbolBadge.family_of_tile(tile), ColorSymbolBadge.Family.NONE,
			"%s's art isn't in a <Colour>Tiles folder" % file)
		checked += 1
	assert_gt(checked, 0)


func test_art_that_isnt_a_tile_has_no_family() -> void:
	assert_eq(ColorSymbolBadge.family_of(ENEMY_ART), ColorSymbolBadge.Family.NONE)
	assert_eq(ColorSymbolBadge.family_of(null), ColorSymbolBadge.Family.NONE)
	assert_eq(ColorSymbolBadge.family_of_tile(RED_TILE), ColorSymbolBadge.Family.RED)
	assert_eq(ColorSymbolBadge.family_of_tile(PURPLE_TILE), ColorSymbolBadge.Family.PURPLE)


func test_a_tile_badge_follows_the_option_live() -> void:
	var tile: Tile = TILE_SCENE.instantiate()
	tile.tile_resource = RED_TILE
	add_child_autofree(tile)
	var badge: ColorSymbolBadge = _badge_on(tile.sprite_frames)
	assert_not_null(badge)
	assert_eq(badge.family, ColorSymbolBadge.Family.RED)
	assert_false(badge.visible, "off by default")

	OptionsSettings.set_option(OptionsSettings.COLOR_SYMBOLS, true)
	assert_true(badge.visible)
	OptionsSettings.set_option(OptionsSettings.COLOR_SYMBOLS, false)
	assert_false(badge.visible)


func test_a_new_tile_resource_swaps_the_badge_rather_than_adding_one() -> void:
	ColorSymbolBadge.symbols_enabled = true
	var tile: Tile = TILE_SCENE.instantiate()
	tile.tile_resource = RED_TILE
	add_child_autofree(tile)
	tile.tile_resource = PURPLE_TILE
	var badges: Array[Node] = _badges_under(tile.sprite_frames)
	assert_eq(badges.size(), 1)
	assert_eq((badges[0] as ColorSymbolBadge).family, ColorSymbolBadge.Family.PURPLE)
	# Tucked inside the frame's top-left corner of the centred 24x24 sprite.
	assert_eq((badges[0] as ColorSymbolBadge).position, Vector2(-12, -12) + ColorSymbolBadge.INSET)


func test_a_scaled_up_rect_scales_its_badge_to_match() -> void:
	ColorSymbolBadge.symbols_enabled = true
	var rect: TextureRect = TextureRect.new()
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	rect.size = Vector2(48, 48)
	add_child_autofree(rect)
	rect.texture = CodexCatalog.tile_icon(RED_TILE)
	var badge: ColorSymbolBadge = ColorSymbolBadge.attach_to_rect(rect)
	assert_true(badge.visible)
	assert_eq(badge.scale, Vector2(2, 2))
	assert_eq(badge.position, ColorSymbolBadge.INSET * 2.0)

	# The codex portrait shows enemies too: no badge on them.
	rect.texture = ENEMY_ART
	assert_eq(ColorSymbolBadge.attach_to_rect(rect), badge, "reuses the badge")
	assert_false(badge.visible)


func test_only_a_found_codex_entry_shows_its_family() -> void:
	ColorSymbolBadge.symbols_enabled = true
	var found: CodexEntry = CodexEntry.new()
	add_child_autofree(found)
	found.setup("apex_cannon", 1, CodexCatalog.tile_icon(RED_TILE), true)
	var locked: CodexEntry = CodexEntry.new()
	add_child_autofree(locked)
	locked.setup("arc_tap", 2, CodexCatalog.tile_icon(PURPLE_TILE), false)
	assert_eq(_badges_under(found).size(), 1)
	assert_eq(_badges_under(locked).size(), 0)


func _badge_on(node: Node) -> ColorSymbolBadge:
	var badges: Array[Node] = _badges_under(node)
	return badges[0] as ColorSymbolBadge if badges.size() == 1 else null


## Every badge anywhere under [param node].
func _badges_under(node: Node) -> Array[Node]:
	var badges: Array[Node] = []
	for child: Node in node.find_children("*", "", true, false):
		if child is ColorSymbolBadge:
			badges.append(child)
	return badges
