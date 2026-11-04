extends "res://test/helpers/die_fighter_test.gd"
## Draw order of main.tscn's screen-space layers. The hit glitch is a
## full-screen shader that warps whatever was drawn before it, so the pause
## menu has to sit on a later canvas layer than the glitch, and the mouse
## cursor on a later one still, or the menu would cover it.
##
## Reads the scene's text rather than loading it: loading main.tscn pulls in
## the whole game, and instancing it boots a run.

const MAIN_SCENE: String = "res://Source/Scenes/main.tscn"
## CanvasLayer.layer when the scene doesn't set it.
const _DEFAULT_LAYER: int = 1

var _nodes: Dictionary[String, Dictionary] = {}


func before_all() -> void:
	_nodes = _parse_nodes(FileAccess.get_file_as_string(MAIN_SCENE))


## Every node in [param text] by its path under the root, as
## {type, parent, props}. Property values stay as their scene text.
static func _parse_nodes(text: String) -> Dictionary[String, Dictionary]:
	var header: RegEx = RegEx.create_from_string('^\\[node name="([^"]+)"(?: type="([^"]+)")?(?: parent="([^"]+)")?')
	var nodes: Dictionary[String, Dictionary] = {}
	var current: Dictionary = {}
	for line: String in text.split("\n"):
		if line.begins_with("["):
			current = {}
			var found: RegExMatch = header.search(line)
			if not found:
				continue
			var parent: String = found.get_string(3)
			var path: String = found.get_string(1) if parent == "." \
					else parent.path_join(found.get_string(1))
			if parent.is_empty():
				path = "."
			current = {"type": found.get_string(2), "parent": parent, "props": {}}
			nodes[path] = current
		elif not current.is_empty() and " = " in line:
			var parts: PackedStringArray = line.split(" = ", true, 1)
			current["props"][parts[0]] = parts[1]
	return nodes


## The canvas layer [param path] draws on: its nearest CanvasLayer ancestor's
## layer, or 0 for the world.
func _layer_of(path: String) -> int:
	var parent: String = _nodes[path]["parent"]
	while parent != "." and not parent.is_empty():
		var node: Dictionary = _nodes[parent]
		if node["type"] == "CanvasLayer":
			return int(node["props"].get("layer", str(_DEFAULT_LAYER)))
		parent = node["parent"]
	return 0


func test_the_scene_has_the_nodes_this_checks() -> void:
	for path: String in ["UI/GlitchShader", "PauseLayer/PauseMenu", "CursorLayer/MouseCursor"]:
		assert_has(_nodes, path)


func test_pause_menu_draws_over_the_glitch() -> void:
	assert_gt(_layer_of("PauseLayer/PauseMenu"), _layer_of("UI/GlitchShader"))


## The menu is pixel art drawn through the game camera, like the world.
func test_pause_menu_still_follows_the_camera() -> void:
	assert_eq(_nodes["PauseLayer"]["props"].get("follow_viewport_enabled"), "true")


func test_cursor_draws_over_the_pause_menu() -> void:
	assert_gt(_layer_of("CursorLayer/MouseCursor"), _layer_of("PauseLayer/PauseMenu"))
