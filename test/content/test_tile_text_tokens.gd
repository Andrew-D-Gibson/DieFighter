extends "res://test/helpers/die_fighter_test.gd"
## Tile text takes its numbers from the tile's data (TextTokens): every
## {placeholder} is bound to a step, every marked step shows in the text,
## and no number is left written into the prose of a converted family.

const TILE_DIR: String = "res://Source/Content/Tiles/TileResources/"
const _TOOL: GDScript = preload("res://Source/Systems/Localization/Tools/tile_text_tokens_tool.gd")
const _TEXT_FIELDS: Array[StringName] = [&"activation_description", &"description"]

## Families whose tiles have been through `tools/loc.sh tokens convert`. A
## literal number left in one of these fails. A family pass adds its family.
const _CONVERTED_FAMILIES: Array[String] = ["yellow"]

## The lint's switch: while false, literals in families not yet converted are
## only reported (the test is pending, listing them). Flip to true once every
## family is in _CONVERTED_FAMILIES.
const _STRICT: bool = false


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


func test_converted_families_have_no_literal_numbers() -> void:
	for path: String in _tile_paths():
		var tile: TileResource = load(path)
		if not _TOOL.family_of(tile) in _CONVERTED_FAMILIES:
			continue
		for field: StringName in _TEXT_FIELDS:
			var left: PackedStringArray = _TOOL.literals_left(path, tile.get(field))
			assert_true(left.is_empty(), "%s %s still writes %s; run tools/loc.sh tokens convert, or bind it by hand" % [
				path.get_file(), field, ", ".join(left)])


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
	elif _STRICT:
		fail_test("literal numbers in tile text:\n" + "\n".join(lines))
	else:
		pending("%d tile text fields still write literal numbers (report only until _STRICT)" % lines.size())


## The English the game shows is the filled text: a converted tile reads as
## its numbers say, never "{boost}".
func test_shown_text_has_no_placeholders_left() -> void:
	for path: String in _tile_paths():
		var tile: TileResource = load(path)
		assert_false("{" in tile.display_description(), "%s shows a raw placeholder: %s" % [path.get_file(), tile.display_description()])
		assert_false("{" in tile.display_activation_description(), "%s shows a raw placeholder" % path.get_file())


func test_yellow_tiles_show_the_numbers_they_did() -> void:
	# Spot checks from the old literal English, one per binding shape.
	_assert_shows("amplifier", "Tiles above and below get +2 to effects this turn")
	_assert_shows("shield_attractor", "Remove [color=blue]6 shields[/color]")
	_assert_shows("war_footing_plus", "deal +2 damage this fight, up to +6. [color=yellow]Hull hit[/color] -> -1")
	_assert_shows("opening_salvo_plus", "(echo) the first 2 tiles you activate")
	_assert_shows("phantom_squadron_plus", "until you own 6 dice")
	_assert_shows("pilot_light_plus", "Spawn a (hologram) (die_3)")
	_assert_shows("spotter_drone", "Apply 3 (exposed). Apply 2 (exposed) to you")


func _assert_shows(file: String, expected: String) -> void:
	var tile: TileResource = load(TILE_DIR + file + ".tres")
	assert_string_contains(tile.display_description(), expected)


func _tile_paths() -> Array[String]:
	var paths: Array[String] = []
	for path: String in Utils.list_resource_paths(TILE_DIR):
		if path.ends_with(".tres"):
			paths.append(path)
	return paths
