extends SceneTree
## Command-line front end for the translation round trip (LocPipeline).
## Run it through tools/loc.sh, or directly:
##
##   Godot --headless --path . --script res://Source/Systems/Localization/Tools/loc_sync.gd -- sync [--ui]
##   Godot --headless --path . --script res://Source/Systems/Localization/Tools/loc_sync.gd -- check
##   Godot --headless --path . --script res://Source/Systems/Localization/Tools/loc_sync.gd -- export <locale>
##   Godot --headless --path . --script res://Source/Systems/Localization/Tools/loc_sync.gd -- import <file> [--status reviewed]
##
## Every line it reports starts with "loc: ", so a wrapper can pick them out
## of the engine's own start-up noise. Exits 1 when something needs fixing.

const _USAGE: String = "usage: loc_sync.gd -- sync [--ui] | check | export <locale> | import <file> [--status <state>]"


func _initialize() -> void:
	# Autoloads (ContentText's resources lean on a few) finish entering the
	# tree on the first frame.
	await process_frame
	quit(_run(Array(OS.get_cmdline_user_args())))


func _run(args: Array) -> int:
	if args.is_empty():
		args = ["sync"]
	var command: String = args.pop_front()
	var pipeline: LocPipeline = LocPipeline.new()
	var ok: bool = true
	match command:
		"sync":
			ok = pipeline.sync(LocCatalog.scan(), "--ui" in args)
		"check":
			var problems: Array[String] = pipeline.out_of_date(LocCatalog.scan())
			for problem: String in problems:
				pipeline.messages.append("stale    " + problem)
			if problems.is_empty():
				pipeline.messages.append("content.csv is up to date")
			ok = problems.is_empty()
		"export":
			if args.is_empty():
				return _fail(_USAGE)
			pipeline.export_locale(args[0])
		"import":
			if args.is_empty():
				return _fail(_USAGE)
			var status: String = ""
			var flag: int = args.find("--status")
			if flag >= 0 and flag + 1 < args.size():
				status = args[flag + 1]
			ok = pipeline.import_file(_project_path(args[0]), status) >= 0
		_:
			return _fail(_USAGE)
	for line: String in pipeline.messages:
		print("loc: " + line)
		if line.begins_with("ERROR"):
			ok = false
	return 0 if ok else 1


## A file named on the command line is relative to the project (where
## loc.sh runs), unless it is already absolute or a res:// path.
static func _project_path(file: String) -> String:
	if file.begins_with("res://") or file.begins_with("user://") or file.is_absolute_path():
		return file
	return "res://" + file


func _fail(message: String) -> int:
	print("loc: ERROR " + message)
	return 1
