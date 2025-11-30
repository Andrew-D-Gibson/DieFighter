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


static func format_text(text: String, scale: int = 6) -> String:
	# Change colors to match the palette
	text = text.replace('=red', '=#' + Globals.red.to_html(false))
	text = text.replace('=blue', '=#' + Globals.blue.to_html(false))
	text = text.replace('=green', '=#' + Globals.green.to_html(false))
	text = text.replace('=yellow', '=#' + Globals.yellow.to_html(false))
	text = text.replace('=purple', '=#' + Globals.purple.to_html(false))
	text = text.replace('=orange', '=#' + Globals.orange.to_html(false))
	
	# Add dice images to replace numbers
	var image_size: int = int(72.0 / scale)
	text = text.replace('(die_blank)', '[img={' + str(image_size) + '}x{' + str(image_size) + '}]' + dice_image_paths[0] + '[/img]')
	text = text.replace('(die_1)', '[img={' + str(image_size) + '}x{' + str(image_size) + '}]' + dice_image_paths[1] + '[/img]')
	text = text.replace('(die_2)', '[img={' + str(image_size) + '}x{' + str(image_size) + '}]' + dice_image_paths[2] + '[/img]')
	text = text.replace('(die_3)', '[img={' + str(image_size) + '}x{' + str(image_size) + '}]' + dice_image_paths[3] + '[/img]')
	text = text.replace('(die_4)', '[img={' + str(image_size) + '}x{' + str(image_size) + '}]' + dice_image_paths[4] + '[/img]')
	text = text.replace('(die_5)', '[img={' + str(image_size) + '}x{' + str(image_size) + '}]' + dice_image_paths[5] + '[/img]')
	text = text.replace('(die_6)', '[img={' + str(image_size) + '}x{' + str(image_size) + '}]' + dice_image_paths[6] + '[/img]')
	
	#text = text.replace('(info_cursor)', '[img=top,bottom {' + str(image_size) + '}x{' + str(image_size) + '}]' + info_cursor_image_path + '[/img]')

	text = text.replace('(fate)', '[img={' + str(18) + '}x{' + str(11) + '}]' + fate_image_path + '[/img]')
	text = text.replace('(left_mouse)', '[img={' + str(8) + '}x{' + str(8) + '}]' + mouse_indicator_path + '[/img]')
	text = text.replace('(attack_indicator)', '[img={' + str(8) + '}x{' + str(8) + '}]' + attack_indicator_path + '[/img]')
	text = text.replace('(fate_scenario)', '[img={' + str(8) + '}x{' + str(8) + '}]' + fate_scenario_image_path + '[/img]')
	text = text.replace('(targeting_arrows)', '[img={' + str(8) + '}x{' + str(11) + '}]' + targeting_arrows_image_path + '[/img]')
	text = text.replace('(arrow_keys)', '[img={' + str(16) + '}x{' + str(8) + '}]' + arrow_keys_image_path + '[/img]')
	text = text.replace('(jump_gate_scenario)', '[img={' + str(8) + '}x{' + str(8) + '}]' + jump_gate_scenario_image_path + '[/img]')
	
	text = text.replace('(dice_cannon)', '[img={' + str(8) + '}x{' + str(8) + '}]' + dice_cannon_image_path + '[/img]')
	text = text.replace('(shield_burst)', '[img={' + str(8) + '}x{' + str(8) + '}]' + shield_burst_image_path + '[/img]')
	
	text = text.replace('(credits)', '[img={' + str(8) + '}x{' + str(8) + '}]' + credits_image_path + '[/img]')
	
	text = text.replace('(right_controls)', '[img={' + str(8) + '}x{' + str(8) + '}]' + right_controls_image_path + '[/img]')
	text = text.replace('(left_controls)', '[img={' + str(8) + '}x{' + str(8) + '}]' + left_controls_image_path + '[/img]')
	
	
	return text


## Parses delay tags from text and returns a dictionary of character positions and their delays
## Returns positions in the original text
static func parse_delay_tags(text: String) -> Dictionary:
	var delay_positions: Dictionary = {}
	var regex: RegEx = RegEx.new()
	regex.compile(r"\(delay=([0-9.]+)\)")
	
	var search_start: int = 0
	while true:
		var result: RegExMatch = regex.search(text, search_start)
		if not result:
			break
			
		var delay_time: float = float(result.get_string(1))
		var position: int = result.get_start()
		delay_positions[position] = delay_time
		search_start = result.get_end()
	
	return delay_positions


## Maps delay positions from original text (with delay tags) to processed text (without delay tags, formatted, BBCode stripped)
## Returns a dictionary mapping positions in the processed text to delay times
static func map_delay_positions(original_text: String, text_without_delays: String, bb_code_text: String, processed_text: String, delay_positions: Dictionary) -> Dictionary:
	if delay_positions.is_empty():
		return {}
	
	# Find all delay tag positions in original text
	var regex: RegEx = RegEx.new()
	regex.compile(r"\(delay=[0-9.]+\)")
	
	var search_start: int = 0
	var delay_matches: Array = []
	while true:
		var result: RegExMatch = regex.search(original_text, search_start)
		if not result:
			break
		delay_matches.append(result)
		search_start = result.get_end()
	
	# Map delay positions from original text to processed text
	# We do this by:
	# 1. Finding the position in text_without_delays (accounting for removed delay tags)
	# 2. Finding the corresponding position in processed_text by character alignment
	#    (accounting for formatting changes and BBCode removal)
	var mapped_delays: Dictionary = {}
	
	for original_pos in delay_positions.keys():
		# Find which delay tag this position corresponds to
		var delay_tag_index: int = -1
		for i in range(delay_matches.size()):
			var match: RegExMatch = delay_matches[i]
			if original_pos == match.get_start():
				delay_tag_index = i
				break
		
		if delay_tag_index == -1:
			continue
		
		# Calculate cumulative length of delay tags before this one
		var cumulative_delay_length: int = 0
		for i in range(delay_tag_index):
			cumulative_delay_length += delay_matches[i].get_string().length()
		
		# Position in text_without_delays (before the delay tag)
		var no_delays_pos: int = original_pos - cumulative_delay_length
		
		# Map from text_without_delays to processed_text by aligning visible characters
		# This accounts for both formatting changes (die_1 -> image tags) and BBCode removal
		var processed_pos: int = _find_corresponding_position(text_without_delays, processed_text, no_delays_pos)
		if processed_pos != -1:
			mapped_delays[processed_pos] = delay_positions[original_pos]
	
	return mapped_delays


## Helper function to find corresponding position in processed text
## Uses character alignment accounting for BBCode tags and formatting changes
static func _find_corresponding_position(source_text: String, target_text: String, source_pos: int) -> int:
	if source_pos < 0 or source_pos > source_text.length():
		return -1
	
	# Simple approach: align by matching characters character-by-character
	# This handles cases where format_text might have replaced some characters (like die_1 -> image tag -> removed)
	var source_index: int = 0
	var target_index: int = 0
	
	# Align characters up to source_pos
	while source_index < source_pos and source_index < source_text.length():
		if target_index >= target_text.length():
			# Target text is shorter - return current position
			break
		
		if source_text[source_index] == target_text[target_index]:
			# Characters match - advance both
			source_index += 1
			target_index += 1
		else:
			# Characters don't match - this might be due to formatting changes
			# Try to find the next matching character in target_text
			var found: bool = false
			for lookahead in range(1, min(20, target_text.length() - target_index)):  # Look ahead up to 20 chars
				if target_index + lookahead < target_text.length() and source_text[source_index] == target_text[target_index + lookahead]:
					# Found a match ahead - skip the mismatched characters in target
					target_index += lookahead + 1
					source_index += 1
					found = true
					break
			
			if not found:
				# No match found ahead - skip this character in source (it was removed by formatting)
				source_index += 1
	
	return target_index


## Removes delay tags from text for display
static func remove_delay_tags(text: String) -> String:
	var regex: RegEx = RegEx.new()
	regex.compile(r"\(delay=[0-9.]+\)")
	return regex.sub(text, "", true)


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
