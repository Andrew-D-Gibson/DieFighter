extends SceneTree
## Runs the localization audit as a process of its own:
##   Godot --path <project> -s res://Source/Debug/LocAudit/loc_audit_cli.gd -- [locale|all|pseudo] [surface ...]
## tools/loc.sh audit and the dev console's loc_audit both start it. With
## --headless it checks text but takes no photos.
##
## It keeps out of the way of anything else running: the McpInteractionServer
## autoload is removed before it can open its port (the editor's MCP tools
## talk to whichever game holds it), the debug log goes to the audit's own
## folder instead of rotating the game's, and nothing is saved.
##
## This script compiles before the autoloads exist, so it names no game
## classes; it loads the runner by path.

const _RUNNER_PATH: String = "res://Source/Debug/LocAudit/loc_audit.gd"
const _SURFACES_PATH: String = "res://Source/Debug/LocAudit/loc_audit_surfaces.gd"

var _frame: int = 0
var _started: bool = false


func _initialize() -> void:
	var server: Node = root.get_node_or_null("McpInteractionServer")
	if server:
		root.remove_child(server)
		server.free()
	var logger: Node = root.get_node_or_null("DebugLogger")
	if logger:
		DirAccess.make_dir_recursive_absolute("user://loc_audit")
		logger.set("_log_path", "user://loc_audit/debug_log.txt")


func _process(_delta: float) -> bool:
	_frame += 1
	# Autoloads are ready from the second frame.
	if _frame >= 2 and not _started:
		_started = true
		_run()
	return false


func _run() -> void:
	AudioServer.set_bus_mute(AudioServer.get_bus_index(&"Master"), true)
	if DisplayServer.get_name() != "headless":
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		DisplayServer.window_set_size(Vector2i(960, 540))
		DisplayServer.window_set_title("Localization audit")

	var args: PackedStringArray = OS.get_cmdline_user_args()
	var requested: String = args[0] if not args.is_empty() else "all"
	var surface_ids: PackedStringArray = args.slice(1)

	var runner_script: GDScript = load(_RUNNER_PATH)
	var runner: Node = runner_script.new()
	root.add_child(runner)
	var surfaces: Array = load(_SURFACES_PATH).call(&"named", surface_ids)
	_show_progress(runner)
	var report: String = await runner.call(&"run", runner_script.call(&"locales_for", requested), surfaces)
	quit(0 if report != "" else 1)


## Puts the stage on the window, so whoever started the audit can watch it.
func _show_progress(runner: Node) -> void:
	await process_frame
	var stage: Node = runner.get_child(0) if runner.get_child_count() > 0 else null
	if stage == null:
		return
	var view: TextureRect = TextureRect.new()
	view.texture = stage.get("viewport").get_texture()
	view.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	view.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	view.set_anchors_preset(Control.PRESET_FULL_RECT)
	var layer: CanvasLayer = CanvasLayer.new()
	layer.layer = 100
	layer.add_child(view)
	root.add_child(layer)
