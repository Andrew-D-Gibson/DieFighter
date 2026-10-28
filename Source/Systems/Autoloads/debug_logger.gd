extends Node
## Writes a readable play-by-play of the run to user://debug_log.txt.
##
## Most of the log comes straight off the scenario engine: every gameplay event
## that resolves (damage, shields, statuses, tile and enemy actions, dice
## changes) gets a line, so new content shows up here without the logger
## learning about it. The Events bus fills in what the engine doesn't see:
## turn boundaries, the dice rolled, backgrounds and hazards, the run's map.
## Wording lives in DebugLogFormat.
##
## Errors the engine reports (with their GDScript backtraces) go into the same
## file, right after whatever the game was doing, so a playtester's log alone
## is enough to find a crash. The session header says which build, machine and
## run seed it came from.
##
## Each launch starts a fresh debug_log.txt; the previous few are kept beside
## it as debug_log_<time>.txt, since a player who crashes usually relaunches
## before sending anything.

var _log_file: FileAccess
## user://, not res://: an exported build can't write inside its own package.
## On macOS this is ~/Library/Application Support/Godot/app_userdata/DieFighter/.
var _log_path: String = "user://debug_log.txt"

## How many earlier sessions' logs a normal launch keeps.
const _KEEP_PREVIOUS_LOGS: int = 5

## Every write goes through this: engine errors arrive on whatever thread
## raised them.
var _mutex: Mutex = Mutex.new()
var _error_sink: ErrorSink = null
## The run seed last written, so each new run's seed is logged once.
var _logged_run_seed: int = -1

## The engine whose events are being logged. Each scenario builds a new one.
var _engine: ScenarioEngine = null
## Rounds into the current fight, counted at each player turn start.
var _turn: int = 0


func _ready() -> void:
	# Make this unpausable
	process_mode = Node.PROCESS_MODE_ALWAYS

	# Headless instances (script validation, GUT, --import) also load
	# autoloads. Opening the file would truncate the log of a game that's
	# running alongside them, so they stay out of it.
	if DisplayServer.get_name() == "headless":
		return
	# In a browser user:// is IndexedDB: flushing every line there is slow,
	# and the player can't open the file anyway.
	if OS.has_feature("web"):
		return
	start(_log_path, _KEEP_PREVIOUS_LOGS)


## Starts logging to [param path], overwriting it. A headless instance can
## still ask for a log of its own (the AutoPilot keeps one per run). With
## [param keep_previous] above 0, the log already at [param path] is kept
## under a timestamped name first, along with that many before it.
func start(path: String, keep_previous: int = 0) -> void:
	if _log_file != null:
		return
	_log_path = path
	if keep_previous > 0:
		keep_previous_logs(_log_path, keep_previous)
	_log_file = FileAccess.open(_log_path, FileAccess.WRITE)
	if _log_file == null:
		push_error("Failed to open debug log file at: " + _log_path)
		return

	_connect_run_signals()
	_connect_turn_signals()
	_connect_environment_signals()
	_connect_board_signals()

	_log("Debug logger initialized, %s" % Time.get_datetime_string_from_system(false, true))
	for line: String in session_header():
		_log(line)

	_error_sink = ErrorSink.new(_write_raw)
	OS.add_logger(_error_sink)


## What a bug report needs to say before anything happens: which build, which
## machine, which language.
static func session_header() -> PackedStringArray:
	var version: String = str(ProjectSettings.get_setting("application/config/version", ""))
	var build: String = "DieFighter %s" % (version if version != "" else "(unversioned)")
	var commit: String = _source_commit()
	if commit != "":
		build += ", source %s" % commit
	build += ", %s build" % ("debug" if OS.is_debug_build() else "release")
	return PackedStringArray([
		build,
		"Godot %s, %s %s, %s" % [
			Engine.get_version_info().string,
			OS.get_name(),
			OS.get_version(),
			RenderingServer.get_video_adapter_name(),
		],
		"Locale %s, window %s" % [TranslationServer.get_locale(), DisplayServer.window_get_size()],
	])


## The git commit the game is running from, with "+changes" when the working
## tree has edits. Only when running from the editor: an exported build has no
## checkout to ask, and its version setting has to say which build it is.
static func _source_commit() -> String:
	if not OS.has_feature("editor"):
		return ""
	var root: String = ProjectSettings.globalize_path("res://")
	var out: Array = []
	if OS.execute("git", ["-C", root, "rev-parse", "--short", "HEAD"], out) != 0 or out.is_empty():
		return ""
	var commit: String = str(out[0]).strip_edges()
	out.clear()
	if OS.execute("git", ["-C", root, "status", "--porcelain", "--untracked-files=no"], out) == 0 \
	and not out.is_empty() and str(out[0]).strip_edges() != "":
		commit += "+changes"
	return commit


## Renames the log at [param path], if there is one, to
## <name>_<when it was last written>.<ext> beside it, then deletes all but the
## newest [param keep] of those.
static func keep_previous_logs(path: String, keep: int) -> void:
	var base: String = path.get_basename()
	var extension: String = path.get_extension()
	if FileAccess.file_exists(path):
		# Local time, so it matches the clock the player saw.
		var bias_seconds: int = int(Time.get_time_zone_from_system().get("bias", 0)) * 60
		var written: int = FileAccess.get_modified_time(path) + bias_seconds
		var stamp: String = Time.get_datetime_string_from_unix_time(written).replace(":", ".")
		DirAccess.rename_absolute(path, "%s_%s.%s" % [base, stamp, extension])

	var directory: String = path.get_base_dir()
	var prefix: String = base.get_file() + "_"
	var kept: Array[String] = []
	for file_name: String in DirAccess.get_files_at(directory):
		if file_name.begins_with(prefix) and file_name.get_extension() == extension:
			kept.append(file_name)
	# The timestamps sort oldest first.
	kept.sort()
	for i: int in range(kept.size() - keep):
		DirAccess.remove_absolute(directory.path_join(kept[i]))


func _connect_run_signals() -> void:
	Events.load_scenario.connect(_on_load_scenario)
	Events.start_scenario.connect(_on_start_scenario)
	Events.start_combat.connect(_on_start_combat)
	Events.combat_finished.connect(func() -> void: _log("Combat finished"))
	Events.scenario_event.connect(_on_scenario_event)
	Events.enemies_arrived.connect(func() -> void: _log("Enemies arrived"))
	Events.enemy_left.connect(_on_enemy_left)
	Events.sector_advanced.connect(func(index: int) -> void: _log("Sector advanced to %d" % index))
	Events.jump.connect(func() -> void: _log("Jump"))
	Events.reward_tile_taken.connect(func() -> void: _log("Took reward tile"))
	Events.reward_money_taken.connect(func() -> void: _log("Took reward money"))
	Events.player_destroyed.connect(func() -> void: _log("Player destroyed"))
	Events.victory.connect(func() -> void: _log("VICTORY"))
	Events.game_over.connect(func() -> void: _log("GAME OVER"))


func _connect_turn_signals() -> void:
	# A fight's opening turn is announced by first_turn_start alone.
	Events.first_turn_start.connect(_on_player_turn_start)
	Events.player_turn_start.connect(_on_player_turn_start)
	Events.player_turn_over.connect(func() -> void: _log("Player turn over"))
	Events.enemy_turn_starting.connect(_on_enemy_turn_starting)
	Events.enemy_turn_over.connect(func() -> void: _log("Enemy turn over"))


func _connect_environment_signals() -> void:
	Events.background_changed.connect(_on_background_changed)
	Events.background_modifier_applied.connect(_on_background_modifier_applied)
	Events.hazard_armed.connect(_on_hazard_armed)
	Events.hazard_countdown_changed.connect(_on_hazard_countdown_changed)
	Events.hazard_triggered.connect(_on_hazard_triggered)


func _connect_board_signals() -> void:
	Events.die_placed_on_tile.connect(_on_die_placed_on_tile)
	Events.tile_manually_moved.connect(func(tile: Tile) -> void: _log("Moved %s" % DebugLogFormat.label(tile)))
	Events.modifier_triggered.connect(_on_modifier_triggered)


func _log(message: String) -> void:
	_write_raw("[%s] %s" % [ErrorSink.timestamp(), message])


## Writes [param text] as-is. Safe from any thread.
func _write_raw(text: String) -> void:
	_mutex.lock()
	if _log_file != null:
		_log_file.store_line(text)
		_log_file.flush()
	_mutex.unlock()


# ── Engine ──────────────────────────────────────────────────────────────────

## Follows the current scenario's engine. Safe to call repeatedly.
func _attach_engine() -> void:
	var engine: ScenarioEngine = ScenarioEngine.current()
	if engine == null or engine == _engine:
		return
	_engine = engine
	engine.event_resolved.connect(_on_event_resolved)
	engine.event_canceled.connect(_on_event_canceled)
	engine.modifier_added.connect(func(mod: Modifier) -> void: _log("  + Modifier %s" % DebugLogFormat.modifier(mod)))
	engine.modifier_removed.connect(func(mod: Modifier) -> void: _log("  - Modifier %s" % DebugLogFormat.modifier(mod)))


func _on_event_resolved(event: EffectEvent) -> void:
	if DebugLogFormat.should_log(event):
		_log(DebugLogFormat.event_line(event))


func _on_event_canceled(event: EffectEvent) -> void:
	if DebugLogFormat.should_log(event):
		_log("  CANCELED %s" % DebugLogFormat.event_line(event).strip_edges())


func _on_modifier_triggered(mod: Modifier) -> void:
	_log("  Triggered %s" % DebugLogFormat.modifier(mod))


# ── Run ─────────────────────────────────────────────────────────────────────

func _on_load_scenario(scenario: ScenarioResource) -> void:
	_log("======== Loading scenario: %s ========" % scenario.resource_path.get_file().get_basename())
	_log_run_seed()
	# ScenarioManager builds the new engine in its own handler for this signal,
	# which runs after this autoload's.
	_attach_engine.call_deferred()


## The seed a new run started from, which replays it (the AutoPilot's --seed).
## A continued save doesn't keep it, so that's said instead.
func _log_run_seed() -> void:
	var run_seed: int = RNGManager.current_run_seed
	if run_seed == _logged_run_seed:
		return
	_logged_run_seed = run_seed
	if run_seed == -1:
		_log("Run seed: unknown (continued from a save)")
	else:
		_log("Run seed: %d" % run_seed)


func _on_start_scenario() -> void:
	_attach_engine()
	_log("Starting scenario")


func _on_start_combat() -> void:
	_attach_engine()
	_turn = 0
	_log("Starting combat")


func _on_scenario_event(event: ScenarioManager.ScenarioEvent) -> void:
	_log("Scenario event: %s" % ScenarioManager.ScenarioEvent.keys()[event])


func _on_enemy_left(ship: Enemy, faction: ScenarioManager.Faction) -> void:
	_log("%s left (%s)" % [DebugLogFormat.label(ship), ScenarioManager.Faction.keys()[faction]])


# ── Turns ───────────────────────────────────────────────────────────────────

func _on_player_turn_start() -> void:
	_turn += 1
	# Deferred so the snapshot comes after everything else that reacts to the
	# turn starting: the intent tables are rolled in EnemyManager's handler.
	_log_player_turn_snapshot.call_deferred(_turn)


func _log_player_turn_snapshot(turn: int) -> void:
	_log("---- Player turn %d ----" % turn)
	if is_instance_valid(Globals.player):
		_log(DebugLogFormat.player_summary(Globals.player))
		_log("Rolled %s" % DebugLogFormat.dice_values(Globals.player.dice_manager.queue))
	# Deferred: a jump can free the engine in between.
	var engine: ScenarioEngine = _engine if is_instance_valid(_engine) else null
	for enemy: Enemy in _live_enemies():
		_log(DebugLogFormat.enemy_summary(enemy, engine))
		_log("    intents %s" % DebugLogFormat.intent_table(enemy))


func _on_enemy_turn_starting() -> void:
	_log("---- Enemy turn %d ----" % _turn)
	for enemy: Enemy in _live_enemies():
		if not enemy.dice_manager.queue.is_empty():
			_log("%s holds %s" % [DebugLogFormat.label(enemy), DebugLogFormat.dice_values(enemy.dice_manager.queue)])


func _live_enemies() -> Array[Enemy]:
	var live: Array[Enemy] = []
	if not is_instance_valid(Globals.enemy_manager):
		return live
	# Read the roster directly: get_alive_enemies() prunes it, and a log must
	# not change what it's watching.
	for enemy: Enemy in Globals.enemy_manager.enemies:
		if is_instance_valid(enemy) and enemy.health.health > 0:
			live.append(enemy)
	return live


# ── Board ───────────────────────────────────────────────────────────────────

func _on_die_placed_on_tile(die: Dice, tile: Tile) -> void:
	_log("Placed %s on %s" % [DebugLogFormat.die(die), DebugLogFormat.label(tile)])


# ── Environment ─────────────────────────────────────────────────────────────

func _on_background_changed(background: BackgroundResource) -> void:
	# The file name, because BackgroundManager's display name is just the
	# look ("nebula") and several backgrounds share one.
	var background_name: String = background.resource_path.get_file().get_basename() if background else "-"
	_log("Background: %s" % background_name)


func _on_background_modifier_applied(modifier: BackgroundModifierResource) -> void:
	if modifier == null:
		_log("Background modifier: none")
		return
	_log("Background modifier: %s (%s, cap %d)" % [
		modifier.modifier_name,
		BackgroundModifierResource.Effect.keys()[modifier.effect],
		modifier.amount_cap,
	])


func _on_hazard_armed(hazard: BackgroundHazardResource, turns_remaining: int) -> void:
	if hazard == null:
		_log("Hazard: none")
		return
	_log("Hazard armed: %s (%s), first in %d, then every %d" % [
		hazard.hazard_name,
		BackgroundHazardResource.Timing.keys()[hazard.timing],
		turns_remaining,
		hazard.turns_between,
	])


func _on_hazard_countdown_changed(hazard: BackgroundHazardResource, turns_remaining: int) -> void:
	# A hazard that ends the fight when it fires is disarmed before its
	# countdown resets.
	if hazard == null:
		return
	_log("Hazard %s: %d to go" % [hazard.hazard_name, turns_remaining])


func _on_hazard_triggered(hazard: BackgroundHazardResource) -> void:
	_log("HAZARD FIRES: %s" % hazard.hazard_name)


func _exit_tree() -> void:
	if _error_sink != null:
		OS.remove_logger(_error_sink)
		_error_sink = null
	_mutex.lock()
	if _log_file != null:
		_log_file.close()
		_log_file = null
	_mutex.unlock()


## Writes each error the engine reports into the log, backtrace and all.
## Called on whatever thread raised the error.
class ErrorSink extends Logger:
	## One error firing every frame would bury everything else.
	const MAX_REPEATS: int = 3

	var _write: Callable
	var _mutex: Mutex = Mutex.new()
	## How often each error (by where and what) has been seen.
	var _seen: Dictionary[String, int] = {}

	func _init(write: Callable) -> void:
		_write = write

	func _log_error(function: String, file: String, line: int, code: String, rationale: String,
			_editor_notify: bool, error_type: int, script_backtraces: Array[ScriptBacktrace]) -> void:
		# Warnings are mostly the engine's own startup notes, not faults.
		if error_type == ERROR_TYPE_WARNING:
			return
		var message: String = rationale if rationale != "" else code
		var key: String = "%s %s" % [_where(function, file, line, script_backtraces), message]
		_mutex.lock()
		var count: int = _seen.get(key, 0) + 1
		_seen[key] = count
		_mutex.unlock()
		if count > MAX_REPEATS + 1:
			return
		if count == MAX_REPEATS + 1:
			_write.call("[%s] !! (that error keeps repeating; no longer logged)" % timestamp())
			return
		_write.call(format(function, file, line, message, error_type, script_backtraces))

	## The block the log shows for one error.
	static func format(function: String, file: String, line: int, message: String,
			error_type: int, script_backtraces: Array[ScriptBacktrace]) -> String:
		var kind: String = "ERROR"
		match error_type:
			ERROR_TYPE_SCRIPT:
				kind = "SCRIPT ERROR"
			ERROR_TYPE_SHADER:
				kind = "SHADER ERROR"
		var indent: String = " ".repeat(15)
		var text: String = "[%s] !! %s: %s" % [timestamp(), kind, message]
		var traced: bool = false
		for backtrace: ScriptBacktrace in script_backtraces:
			if backtrace and not backtrace.is_empty():
				text += "\n" + backtrace.format(indent.length(), 4)
				traced = true
		# For an error a script caused, the engine's own location points into
		# its C++ (push_error's is always variant_utility.cpp); the backtrace
		# already says where in the game it came from.
		if not traced:
			text += "\n%sat: %s (%s:%d)" % [indent, function, file, line]
		return text

	## The innermost GDScript frame when there is one, else the engine's own
	## location.
	static func _where(function: String, file: String, line: int,
			script_backtraces: Array[ScriptBacktrace]) -> String:
		for backtrace: ScriptBacktrace in script_backtraces:
			if backtrace and not backtrace.is_empty():
				return "%s:%d" % [backtrace.get_frame_file(0), backtrace.get_frame_line(0)]
		return "%s:%d %s" % [file, line, function]

	## The clock every log line starts with.
	static func timestamp() -> String:
		var time_dict: Dictionary = Time.get_time_dict_from_system()
		var msec: int = int(fmod(Time.get_unix_time_from_system(), 1.0) * 1000.0)
		return "%02d:%02d:%02d.%03d" % [
			time_dict.hour,
			time_dict.minute,
			time_dict.second,
			msec,
		]
