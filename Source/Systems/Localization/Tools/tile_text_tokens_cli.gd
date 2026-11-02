extends SceneTree
## Command-line front end for tile_text_tokens_tool.gd. Run it through
## tools/loc.sh tokens, or directly:
##
##   Godot --headless --path . --script res://Source/Systems/Localization/Tools/tile_text_tokens_cli.gd -- convert --family yellow --dry-run
##
## Every line it reports starts with "tokens: ". Exits 1 when something needs
## a hand.

const _TOOL: String = "res://Source/Systems/Localization/Tools/tile_text_tokens_tool.gd"


func _initialize() -> void:
	# The tool reads tiles, whose scripts lean on autoloads that finish
	# entering the tree on the first frame; it is loaded only then, so nothing
	# here names a game class at compile time.
	await process_frame
	var tool: RefCounted = (load(_TOOL) as GDScript).new()
	var status: int = tool.call(&"run", Array(OS.get_cmdline_user_args()))
	for line: String in tool.get(&"messages"):
		print("tokens: " + line)
	quit(status)
