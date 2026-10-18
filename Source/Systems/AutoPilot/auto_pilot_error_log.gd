class_name AutoPilotErrorLog
extends Logger
## Catches every error the engine reports during an AutoPilot run, so the
## transcript can say which turn and move it came after. The console log has
## the same errors, but with no idea what the game was doing.
##
## Errors arrive on whatever thread raised them; the AutoPilot takes them on
## the main thread with take().

## Engine object ids and addresses differ from run to run. Masked so two runs
## of one seed still write identical transcripts.
static var _volatile: RegEx = RegEx.create_from_string("0x[0-9A-Fa-f]+|#-?\\d{5,}|<[A-Za-z0-9_]+#-?\\d+>")

var _mutex: Mutex = Mutex.new()
var _pending: Array[Dictionary] = []


func _log_error(function: String, file: String, line: int, code: String, rationale: String,
		_editor_notify: bool, error_type: int, script_backtraces: Array[ScriptBacktrace]) -> void:
	# Warnings and shader errors aren't faults in the run.
	if error_type != ERROR_TYPE_ERROR and error_type != ERROR_TYPE_SCRIPT:
		return
	var message: String = rationale if rationale != "" else code
	var entry: Dictionary = {
		"kind": "script" if error_type == ERROR_TYPE_SCRIPT else "error",
		"message": _volatile.sub(message, "#", true),
		"at": _where(function, file, line, script_backtraces),
	}
	_mutex.lock()
	_pending.append(entry)
	_mutex.unlock()


## Everything caught since the last call, oldest first.
func take() -> Array[Dictionary]:
	_mutex.lock()
	var caught: Array[Dictionary] = _pending
	_pending = []
	_mutex.unlock()
	return caught


## The innermost GDScript frame when there is one: the engine's own
## function/file/line point into C++ for an error a script caused.
static func _where(function: String, file: String, line: int,
		script_backtraces: Array[ScriptBacktrace]) -> String:
	for backtrace: ScriptBacktrace in script_backtraces:
		if backtrace and not backtrace.is_empty():
			return "%s:%d %s" % [backtrace.get_frame_file(0), backtrace.get_frame_line(0),
				backtrace.get_frame_function(0)]
	return "%s:%d %s" % [file, line, function]
