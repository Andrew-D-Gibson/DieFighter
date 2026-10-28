extends "res://test/helpers/die_fighter_test.gd"
## The debug log is what a playtester sends back after a crash, so it has to
## survive a relaunch, carry the error itself, and say which build it was.

const DebugLoggerScript := preload("res://Source/Systems/Autoloads/debug_logger.gd")
const ErrorSink := DebugLoggerScript.ErrorSink

const _DIR: String = "user://test_debug_logger"


func before_each() -> void:
	super()
	DirAccess.make_dir_recursive_absolute(_DIR)


func after_each() -> void:
	for file_name: String in DirAccess.get_files_at(_DIR):
		DirAccess.remove_absolute(_DIR.path_join(file_name))
	DirAccess.remove_absolute(_DIR)
	super()


func _touch(file_name: String, text: String = "") -> void:
	var file: FileAccess = FileAccess.open(_DIR.path_join(file_name), FileAccess.WRITE)
	file.store_string(text)
	file.close()


# ── Keeping earlier sessions ───────────────────────────────────────────────────

func test_the_last_session_is_kept_under_its_time() -> void:
	_touch("debug_log.txt", "the crash")
	DebugLoggerScript.keep_previous_logs(_DIR.path_join("debug_log.txt"), 5)
	assert_false(FileAccess.file_exists(_DIR.path_join("debug_log.txt")))
	var kept: PackedStringArray = DirAccess.get_files_at(_DIR)
	assert_eq(kept.size(), 1)
	assert_true(kept[0].begins_with("debug_log_20"), kept[0])
	assert_eq(FileAccess.get_file_as_string(_DIR.path_join(kept[0])), "the crash")


func test_only_the_newest_sessions_are_kept() -> void:
	for day: int in range(1, 8):
		_touch("debug_log_2026-10-0%dT12.00.00.txt" % day)
	# Something else in the folder that only shares the start of the name.
	_touch("debug_logger_notes.md")
	DebugLoggerScript.keep_previous_logs(_DIR.path_join("debug_log.txt"), 5)
	var kept: PackedStringArray = DirAccess.get_files_at(_DIR)
	assert_eq(kept.size(), 6)
	assert_false(kept.has("debug_log_2026-10-01T12.00.00.txt"))
	assert_false(kept.has("debug_log_2026-10-02T12.00.00.txt"))
	assert_true(kept.has("debug_log_2026-10-07T12.00.00.txt"))
	assert_true(kept.has("debug_logger_notes.md"))


func test_nothing_to_keep_on_a_first_launch() -> void:
	DebugLoggerScript.keep_previous_logs(_DIR.path_join("debug_log.txt"), 5)
	assert_eq(DirAccess.get_files_at(_DIR).size(), 0)


# ── Errors ─────────────────────────────────────────────────────────────────────

func _sink(lines: Array[String]) -> ErrorSink:
	return ErrorSink.new(func(text: String) -> void: lines.append(text))


func test_a_script_error_is_logged_with_where_it_happened() -> void:
	var lines: Array[String] = []
	var backtraces: Array[ScriptBacktrace] = Engine.capture_script_backtraces()
	_sink(lines)._log_error("threat_of_face", "res://enemy.gd", 515, "", "previously freed",
		false, Logger.ERROR_TYPE_SCRIPT, backtraces)
	assert_eq(lines.size(), 1)
	assert_string_contains(lines[0], "!! SCRIPT ERROR: previously freed")
	# The GDScript call stack that led here, this test included.
	assert_string_contains(lines[0], "test_a_script_error_is_logged_with_where_it_happened")


func test_an_engine_error_with_no_script_behind_it_says_where_it_was() -> void:
	var lines: Array[String] = []
	_sink(lines)._log_error("load", "core/io/resource_loader.cpp", 300, "", "missing file",
		false, Logger.ERROR_TYPE_ERROR, [])
	assert_string_contains(lines[0], "at: load (core/io/resource_loader.cpp:300)")


func test_warnings_stay_out() -> void:
	var lines: Array[String] = []
	_sink(lines)._log_error("f", "x.cpp", 1, "", "just a note", false, Logger.ERROR_TYPE_WARNING, [])
	assert_eq(lines.size(), 0)


func test_an_error_every_frame_is_capped() -> void:
	var lines: Array[String] = []
	var sink: ErrorSink = _sink(lines)
	for i: int in range(20):
		sink._log_error("f", "x.gd", 3, "", "again", false, Logger.ERROR_TYPE_ERROR, [])
	sink._log_error("f", "x.gd", 4, "", "elsewhere", false, Logger.ERROR_TYPE_ERROR, [])
	assert_eq(lines.size(), ErrorSink.MAX_REPEATS + 2)
	assert_string_contains(lines[ErrorSink.MAX_REPEATS], "no longer logged")
	assert_string_contains(lines[-1], "elsewhere")


# ── Header ─────────────────────────────────────────────────────────────────────

func test_the_header_names_the_build_and_machine() -> void:
	var header: PackedStringArray = DebugLoggerScript.session_header()
	assert_eq(header.size(), 3)
	assert_true(header[0].begins_with("DieFighter "), header[0])
	assert_string_contains(header[1], Engine.get_version_info().string)
	assert_string_contains(header[1], OS.get_name())
