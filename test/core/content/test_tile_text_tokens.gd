extends "res://test/helpers/die_fighter_test.gd"
## Tile text takes its numbers from the tile's data (TextTokens): every
## {placeholder} is bound to a step, every marked step shows in the text,
## and no number is left written into a tile's prose.

const TILE_DIR: String = "res://Source/Content/Tiles/TileResources/"
const _TOOL: GDScript = preload("res://Source/Systems/Localization/Tools/tile_text_tokens_tool.gd")
const _TEXT_FIELDS: Array[StringName] = [&"activation_description", &"description"]


func test_every_placeholder_is_bound_and_agrees() -> void:
	for path: String in _tile_paths():
		var tile: TileResource = load(path)
		for field: StringName in _TEXT_FIELDS:
			for problem: String in TextTokens.problems(tile.get(field), tile):
				fail_test("%s %s: %s" % [path.get_file(), field, problem])
	pass_test("checked")


## A marked step its text never shows is a number the player can't see, or
## a token whose text was rewritten without it.
func test_every_marked_step_shows_in_the_text() -> void:
	for path: String in _tile_paths():
		var tile: TileResource = load(path)
		var shown: PackedStringArray = TextTokens.names_in(tile.activation_description + " " + tile.description)
		for binding: TextTokens.Binding in TextTokens.bindings_of(tile):
			if binding.source == tile:
				continue # the tile's own numbers (countdown) are offered, not required
			assert_has(shown, binding.name, "%s marks {%s} but its text never shows it" % [path.get_file(), binding.name])


func test_no_tile_writes_a_literal_number() -> void:
	var lines: PackedStringArray = []
	for path: String in _tile_paths():
		var tile: TileResource = load(path)
		for field: StringName in _TEXT_FIELDS:
			var left: PackedStringArray = _TOOL.literals_left(path, tile.get(field))
			if not left.is_empty():
				lines.append("%s %s: %s" % [path.get_file(), field, ", ".join(left)])
	if lines.is_empty():
		pass_test("no literal numbers")
	else:
		fail_test("literal numbers in tile text; bind each to its step ({name} + text_token), or exempt it in LITERAL_EXEMPT if it isn't data:\n" + "\n".join(lines))


## The English the game shows is the filled text: a converted tile reads as
## its numbers say, never "{boost}".
func test_shown_text_has_no_placeholders_left() -> void:
	for path: String in _tile_paths():
		var tile: TileResource = load(path)
		assert_false("{" in tile.display_description(), "%s shows a raw placeholder: %s" % [path.get_file(), tile.display_description()])
		assert_false("{" in tile.display_activation_description(), "%s shows a raw placeholder" % path.get_file())


func _tile_paths() -> Array[String]:
	var paths: Array[String] = []
	for path: String in Utils.list_resource_paths(TILE_DIR):
		if path.ends_with(".tres"):
			paths.append(path)
	return paths
