class_name SceneLoader
extends RefCounted
## Background-loads the next scene and switches to it when asked.
##
## The menu and both cutscenes used to switch only if the background load had
## already finished: a click while it was still loading did nothing, and a
## cutscene whose final animation frame called the switch mid-load stayed on
## its last frame forever. switch_to() finishes the load instead (blocking for
## whatever is left of it), and ignores repeat calls, so a skip-click racing the
## animation's own switch can't consume the load twice.

static var _switching: bool = false


## Starts loading a scene in the background. Call early (in _ready) so the
## switch later is instant.
static func request(path: String) -> void:
	_switching = false
	ResourceLoader.load_threaded_request(path)


## Switches to a scene started with request(), waiting for it if needed. Falls
## back to a plain load if it was never requested.
static func switch_to(tree: SceneTree, path: String) -> void:
	if _switching:
		return
	_switching = true

	var scene: PackedScene = null
	if ResourceLoader.load_threaded_get_status(path) == ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
		scene = load(path)
	else:
		scene = ResourceLoader.load_threaded_get(path)

	if scene == null:
		push_error("SceneLoader: failed to load %s" % path)
		_switching = false
		return

	tree.change_scene_to_packed(scene)
