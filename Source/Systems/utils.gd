class_name Utils
extends RefCounted

## Disconnects all the callables that have been attached to a particular signal
static func disconnect_all_callables(signal_to_disconnect: Signal) -> void:
	for connection: Dictionary in signal_to_disconnect.get_connections():
		signal_to_disconnect.disconnect(connection['callable'])


static func array_while_excluding(array: Array, elements_to_exclude: Array) -> Array:
	var array_without_excluded_elements: Array = array.filter(
		func(element: Variant) -> bool:
			return not elements_to_exclude.has(element)
	)
	return array_without_excluded_elements


## Sorts dice by position (x, then y), optionally pinning one die (e.g. the activator) to the front
static func sort_dice_by_position(dice: Array[Node], front_die: Node = null) -> Array[Node]:
	var sorted_dice: Array[Node] = dice.duplicate()

	if front_die:
		sorted_dice.erase(front_die)

	sorted_dice.sort_custom(func(a: Node, b: Node) -> bool:
		var ax: float = a.global_position.x
		var bx: float = b.global_position.x
		if ax != bx:
			return ax < bx
		else:
			return a.global_position.y < b.global_position.y
	)

	if front_die:
		sorted_dice.insert(0, front_die)

	return sorted_dice


static var dice_image_paths: Array[String] = [
	"res://Assets/Textures/Dice/Holographic/dice_blank.png",
	"res://Assets/Textures/Dice/Holographic/dice_1.png",
	"res://Assets/Textures/Dice/Holographic/dice_2.png",
	"res://Assets/Textures/Dice/Holographic/dice_3.png",
	"res://Assets/Textures/Dice/Holographic/dice_4.png",
	"res://Assets/Textures/Dice/Holographic/dice_5.png",
	"res://Assets/Textures/Dice/Holographic/dice_6.png"
]

static var info_cursor_image_path: String = "res://Assets/Textures/UI/MouseCursors/info_cursor_raw.png"
static var fate_image_path: String = "res://Assets/Textures/Fate/fate_image.png"
static var mouse_indicator_path: String = "res://Assets/Textures/TutorialManager/mouse_indicator.png"
static var attack_indicator_path: String = "res://Assets/Textures/Enemies/IntentIndicator/attack.png"
static var fate_scenario_image_path: String = "res://Assets/Textures/Map/EncounterIcons/fate_encounter.png"
static var targeting_arrows_image_path: String = "res://Assets/Textures/TutorialManager/targeting_computer_arrows_icon.png"
static var arrow_keys_image_path: String = "res://Assets/Textures/TutorialManager/arrow_keys_icon.png"
static var jump_gate_scenario_image_path: String = "res://Assets/Textures/Map/EncounterIcons/jump_gate.png"
static var dice_cannon_image_path: String = "res://Assets/Textures/Tiles/RedTiles/damage.png"
static var shield_burst_image_path: String = "res://Assets/Textures/Tiles/BlueTiles/shield.png"
static var credits_image_path: String = "res://Assets/Textures/Money/money_symbol.png"
static var right_controls_image_path: String = "res://Assets/Textures/Map/right_arrow_tile.png"
static var left_controls_image_path: String = "res://Assets/Textures/Map/left_arrow_tile.png"


## Icon heights as a fraction of the surrounding font size, so an icon reads
## at text scale in any label without the caller knowing its pixel scale.
const _DIE_ICON_HEIGHT_EM: float = 0.625
const _TILE_ICON_HEIGHT_EM: float = 0.625
const _SMALL_ICON_HEIGHT_EM: float = 0.5
const _NBSP: String = "\u00a0"

## Text token -> [texture path, height in em]. Only height is set, so each
## texture keeps its own aspect ratio.
static var _inline_icons: Dictionary = {
	'(die_blank)': [dice_image_paths[0], _DIE_ICON_HEIGHT_EM],
	'(die_1)': [dice_image_paths[1], _DIE_ICON_HEIGHT_EM],
	'(die_2)': [dice_image_paths[2], _DIE_ICON_HEIGHT_EM],
	'(die_3)': [dice_image_paths[3], _DIE_ICON_HEIGHT_EM],
	'(die_4)': [dice_image_paths[4], _DIE_ICON_HEIGHT_EM],
	'(die_5)': [dice_image_paths[5], _DIE_ICON_HEIGHT_EM],
	'(die_6)': [dice_image_paths[6], _DIE_ICON_HEIGHT_EM],
	'(fate)': [fate_image_path, _TILE_ICON_HEIGHT_EM],
	'(left_mouse)': [mouse_indicator_path, _TILE_ICON_HEIGHT_EM],
	'(attack_indicator)': [attack_indicator_path, _SMALL_ICON_HEIGHT_EM],
	'(fate_scenario)': [fate_scenario_image_path, _TILE_ICON_HEIGHT_EM],
	'(targeting_arrows)': [targeting_arrows_image_path, _TILE_ICON_HEIGHT_EM],
	'(arrow_keys)': [arrow_keys_image_path, _TILE_ICON_HEIGHT_EM],
	'(jump_gate_scenario)': [jump_gate_scenario_image_path, _TILE_ICON_HEIGHT_EM],
	'(dice_cannon)': [dice_cannon_image_path, _TILE_ICON_HEIGHT_EM],
	'(shield_burst)': [shield_burst_image_path, _TILE_ICON_HEIGHT_EM],
	'(credits)': [credits_image_path, _SMALL_ICON_HEIGHT_EM],
	'(right_controls)': [right_controls_image_path, _TILE_ICON_HEIGHT_EM],
	'(left_controls)': [left_controls_image_path, _TILE_ICON_HEIGHT_EM],
}


## With hoverable_keywords, keyword labels carry meta so the label showing the
## text can pop up their rules on hover.
static func format_text(text: String, hoverable_keywords: bool = false) -> String:
	# Keywords first: their styling uses palette color names resolved below
	text = Keywords.render(text, hoverable_keywords)

	# Change colors to match the palette
	text = text.replace('=red', '=#' + Globals.red.to_html(false))
	text = text.replace('=blue', '=#' + Globals.blue.to_html(false))
	text = text.replace('=green', '=#' + Globals.green.to_html(false))
	text = text.replace('=yellow', '=#' + Globals.yellow.to_html(false))
	text = text.replace('=purple', '=#' + Globals.purple.to_html(false))
	text = text.replace('=orange', '=#' + Globals.orange.to_html(false))

	for token: String in _inline_icons:
		var icon: Array = _inline_icons[token]
		var image: String = '[img height=%sem]%s[/img]' % [icon[1], icon[0]]
		# A non-breaking space keeps the icon wrapping with the word before
		# it. Alone on a line, an icon is shorter than the theme's tight
		# line separation allows for, and overlaps the line above.
		text = text.replace(" " + token, _NBSP + image)
		text = text.replace(token, image)

	return text


## Formats text written with (delay=x) pause tags for a typewriter reveal.
## Returns "text" (the BBCode to display, tags removed), "length" (its visible
## character count) and "delays" (seconds to pause before revealing the
## character at each visible index). Each stretch between tags is formatted on
## its own, so its visible length is exactly what it contributes.
static func format_with_delays(text: String) -> Dictionary:
	var regex: RegEx = RegEx.new()
	regex.compile(r"\(delay=([0-9.]+)\)")

	var bbcode: String = ""
	var length: int = 0
	var delays: Dictionary[int, float] = {}
	var start: int = 0
	for tag: RegExMatch in regex.search_all(text):
		var segment: String = format_text(text.substr(start, tag.get_start() - start))
		bbcode += segment
		length += strip_bbcode_tags(segment).length()
		delays[length] = float(tag.get_string(1))
		start = tag.get_end()

	var tail: String = format_text(text.substr(start))
	bbcode += tail
	length += strip_bbcode_tags(tail).length()
	return {"text": bbcode, "length": length, "delays": delays}


static func strip_bbcode_tags(text: String) -> String:
	var regex: RegEx = RegEx.new()
	# First, remove [img ...]...[/img] blocks entirely (including the file paths inside)
	# Example: [img={8}x{8}]res://Assets/Textures/.../icon.png[/img]
	regex.compile(r"\[img[^\]]*\][\s\S]*?\[/img\]")
	text = regex.sub(text, "", true)

	# As a safety net, remove any standalone engine-style resource paths like res://... or user://...
	regex.compile(r"(?:res|user)://[^\s\]]+")
	text = regex.sub(text, "", true)

	# Finally, remove any remaining BBCode tags like [b], [color=#...], [/b], etc.
	regex.compile(r"\[/?[^\]]+\]")
	return regex.sub(text, "", true)


## Every .tres under [param dir], sorted so anything rolled from the list
## stays reproducible. Uses ResourceLoader.list_directory() rather than
## DirAccess: an exported build converts text resources, and DirAccess would
## list them as "*.tres.remap".
static func list_resource_paths(dir: String, recursive: bool = false) -> Array[String]:
	var paths: Array[String] = []
	for entry: String in ResourceLoader.list_directory(dir):
		var path: String = dir.path_join(entry)
		if entry.ends_with("/"):
			if recursive:
				paths.append_array(list_resource_paths(path, true))
		elif entry.ends_with(".tres"):
			paths.append(path)
	paths.sort()
	return paths


static func slice_texture_right(sprite: Texture2D, pixels: int) -> Texture2D:
	if not sprite:
		push_error("No sprite provided")
		return null
	
	# Get the sprite's image data
	var image: Image = sprite.get_image()
	var width: int = image.get_width()
	var height: int = image.get_height()

	# Clamp N to valid range
	pixels = clamp(pixels, 0, width)

	# Crop to the rightmost N pixels
	var cropped_image: Image = image.get_region(Rect2(width - pixels, 0, pixels, height))

	# Convert cropped Image back to Texture2D
	var new_texture: ImageTexture = ImageTexture.create_from_image(cropped_image)
	return new_texture
