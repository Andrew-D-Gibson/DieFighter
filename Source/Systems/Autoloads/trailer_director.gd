extends Node
## TrailerDirector
## Trailer capture mode: everything needed to shoot footage of the game.
##
## - Trailer mode (F1, or `trailer on`): the debug and bookkeeping overlays go
##   (FPS, "Saving...", the dev console), and the hotkeys below come alive.
## - Shots (`shot <id>`, F5 to retake): a TrailerShotResource sets a run up
##   exactly (ship, scenario, seed, sky, grid, dice, hull) and can play its
##   own beats (TrailerScript), so every take comes out the same.
## - Recording: launched with `--trailer-shot=<id>` under Godot's Movie Maker
##   (tools/trailer_capture.sh), a take records frame-perfect at full
##   resolution however slowly the machine renders it, and quits when its
##   beats are done. Every take writes a marker log of the frames its `mark`
##   beats (and F6) landed on, for the edit.
##
## Hotkeys, in trailer mode only (F1 itself always works in dev builds):
##   F1 trailer mode   F2 cursor   F3 speed 1x/0.5x/0.25x   F4 freeze frame
##   F5 retake shot    F6 marker
##   1 overkill  2 kill  3 shield break  4 critical hull  5 hazard  6 jump
##   7 death  8 red alert  9 glitch  0 reroll hand
## Digits are free in the game's own bindings; F-keys past F6 aren't used,
## since macOS keeps F11 and F12 for itself.
##
## Dev builds only (DevConsole.is_available()). It never touches the player's
## save: a shot runs on a save file of its own.

signal trailer_mode_changed(on: bool)

const SHOTS_DIR: String = "res://Source/Debug/Trailer/Shots/"
const TAKES_DIR: String = "user://trailer/takes/"

const _MAIN_GAME_SCENE: String = "uid://deisauteocrjl"
const _SAVE_PATH: String = "user://trailer_save.json"
const _MUSIC_BUS: StringName = &"Music"
const _SPEEDS: Array[float] = [1.0, 0.5, 0.25]

const _EFFECT_KEYS: Dictionary[Key, String] = {
	KEY_1: "overkill", KEY_2: "kill", KEY_3: "shield_break", KEY_4: "critical",
	KEY_5: "hazard", KEY_6: "jump", KEY_7: "death", KEY_8: "red_alert",
	KEY_9: "glitch", KEY_0: "reroll",
}

var trailer_mode: bool = false

## The shot being set up or filmed, and its id. Null between shots.
var shot: TrailerShotResource = null
var shot_id: String = ""

## Set from a shot's launch until the game scene asks for its save, so a run
## started any other way can be told apart from a shot.
var _launch_pending: bool = false
var _script: TrailerScript = null
var _quit_when_done: bool = false
var _movie_mode: bool = false
var _music_muted_here: bool = false
var _speed_index: int = 0
var _frozen_from: float = -1.0
var _take_log: FileAccess = null
var _take_start_physics_frame: int = 0
var _takes_dir: String = TAKES_DIR
var _take_start_msec: int = 0


func _ready() -> void:
	if not DevConsole.is_available():
		queue_free()
		return
	process_mode = Node.PROCESS_MODE_ALWAYS
	Events.load_game_save.connect(_on_load_game_save)
	get_tree().node_added.connect(_on_node_added)

	_movie_mode = Engine.get_write_movie_path() != ""
	if _movie_mode:
		# Movie Maker renders frames as fast as it can, each worth 1/fps of
		# game time; a wall-clock hitstop would hold for the wrong number of
		# frames. See TimeDirector.use_frame_clock().
		TimeDirector.use_frame_clock()
		# A recording has no use for the MCP port, and could take it from a
		# game the developer has open (the AutoPilot frees it too).
		if is_instance_valid(McpInteractionServer):
			McpInteractionServer.queue_free()

	var args: Dictionary[String, String] = _parse_user_args()
	_quit_when_done = args.has("trailer-quit") or _movie_mode
	# tools/trailer_capture.sh puts each marker log beside its video.
	_takes_dir = args.get("trailer-log-dir", TAKES_DIR)
	if args.has("trailer"):
		set_trailer_mode(true)
	if args.has("trailer-shot") and not args.has("autoplay"):
		_boot_into_shot(args["trailer-shot"])


func _exit_tree() -> void:
	_close_take_log()


# ── Trailer mode ─────────────────────────────────────────────────────────────

func set_trailer_mode(on: bool) -> void:
	trailer_mode = on
	TrailerView.clean_hud = on
	if on:
		Events.dev_console_close_requested.emit()
	else:
		TrailerView.cursor_hidden = false
	print("Trailer mode %s." % ("on" if on else "off"))
	trailer_mode_changed.emit(on)


func set_cursor_visible(shown: bool) -> void:
	TrailerView.cursor_hidden = not shown
	if shown:
		return
	TrailerView.puppet_active = false


## Game speed, via TimeDirector's base scale (slow-mo and hitstops still
## stack on top). 0 freezes the frame.
func set_speed(scale: float) -> void:
	TimeDirector.set_base_scale(maxf(scale, 0.0))
	print("Trailer speed %.2fx." % TimeDirector.base_scale)


func set_music_muted(muted: bool) -> void:
	var bus: int = AudioServer.get_bus_index(_MUSIC_BUS)
	if bus == -1:
		return
	AudioServer.set_bus_mute(bus, muted)
	_music_muted_here = muted


func _cycle_speed() -> void:
	_frozen_from = -1.0
	_speed_index = (_speed_index + 1) % _SPEEDS.size()
	set_speed(_SPEEDS[_speed_index])


func _toggle_freeze() -> void:
	if _frozen_from >= 0.0:
		set_speed(_frozen_from)
		_frozen_from = -1.0
	else:
		_frozen_from = TimeDirector.base_scale
		set_speed(0.0)


func _input(event: InputEvent) -> void:
	var key: InputEventKey = event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	# Typing in the console (or any text field) isn't a hotkey.
	if get_viewport().gui_get_focus_owner() is LineEdit:
		return
	var code: Key = key.physical_keycode
	if code == KEY_F1:
		set_trailer_mode(not trailer_mode)
	elif not trailer_mode:
		return
	elif code == KEY_F2:
		set_cursor_visible(TrailerView.cursor_hidden)
	elif code == KEY_F3:
		_cycle_speed()
	elif code == KEY_F4:
		_toggle_freeze()
	elif code == KEY_F5:
		retake()
	elif code == KEY_F6:
		mark("hotkey")
	elif _EFFECT_KEYS.has(code):
		_report(TrailerEffects.play(_EFFECT_KEYS[code]), "fx " + _EFFECT_KEYS[code])
	else:
		return
	get_viewport().set_input_as_handled()


# ── Shots ────────────────────────────────────────────────────────────────────

## Every shot in SHOTS_DIR by id (its file's base name), sorted.
func shot_ids() -> Array[String]:
	var ids: Array[String] = []
	for file: String in ResourceLoader.list_directory(SHOTS_DIR):
		if file.ends_with(".tres"):
			ids.append(file.get_basename())
	ids.sort()
	return ids


func load_shot(id: String) -> TrailerShotResource:
	var path: String = SHOTS_DIR.path_join(id + ".tres")
	if not ResourceLoader.exists(path):
		return null
	return load(path) as TrailerShotResource


## Sets [param id] up from a clean start and plays it. Answers "" or why not.
func launch(id: String) -> String:
	var problem: String = _prepare(id)
	if not problem.is_empty():
		return problem
	get_tree().paused = false
	get_tree().change_scene_to_file(_MAIN_GAME_SCENE)
	return ""


## The current shot again, from the top: same seed, same take.
func retake() -> String:
	if shot_id.is_empty():
		return _report("no shot to retake", "retake")
	return _report(launch(shot_id), "retake")


## Leaves the shot: the run carries on as an ordinary one, and the music,
## speed and save go back to normal.
func stop_shot() -> void:
	if _script:
		_script.stop()
		_script = null
	_launch_pending = false
	shot = null
	shot_id = ""
	_close_take_log()
	if _music_muted_here:
		set_music_muted(false)
	set_speed(1.0)
	# Only ours to undo: a Scenario Lab run starting now has set its own.
	if SaveManager.save_path == _SAVE_PATH:
		SaveManager.save_path = SaveManager.SAVE_PATH


## Runs one beat now, as a shot's script would (`beat <command>` in the dev
## console), for trying a line out before it goes in a shot.
func run_beat(line: String) -> void:
	var runner: TrailerScript = _script if _script else _new_script()
	_report(await runner.execute(line), line)


## Notes the current frame in the take's marker log.
## Seconds are video seconds under Movie Maker, where physics frames keep
## the recording's clock (they tick through hitstops too), else real ones.
func mark(label: String) -> void:
	var seconds: float = (Engine.get_physics_frames() - _take_start_physics_frame) \
		/ float(Engine.physics_ticks_per_second) if _movie_mode \
		else (Time.get_ticks_msec() - _take_start_msec) / 1000.0
	var line: String = "%d\t%.3f\t%s" % [Engine.get_frames_drawn(), seconds, label]
	print("Trailer mark: " + line)
	if _take_log:
		_take_log.store_line(line)
		_take_log.flush()


func _boot_into_shot(id: String) -> void:
	var problem: String = _prepare(id)
	if not problem.is_empty():
		push_error("TrailerDirector: " + problem)
		if _quit_when_done:
			get_tree().quit(2)
		return
	# The game scene has entered the tree but none of it is ready yet (the
	# AutoPilot boots the same way), so the shot's save is read as it starts,
	# with no scene change. Its tutorial hasn't decided to run yet either.
	_switch_off_tutorials(get_tree().root)


## Everything a shot needs in place before the game scene starts.
func _prepare(id: String) -> String:
	var next: TrailerShotResource = load_shot(id)
	if next == null:
		return "no shot '%s' (have: %s)" % [id, ", ".join(PackedStringArray(shot_ids()))]
	var problem: String = next.problem()
	if not problem.is_empty():
		return "shot '%s': %s" % [id, problem]

	stop_shot()
	shot = next
	shot_id = id
	var ship: ShipResource = ShipCatalog.find(shot.ship_id)
	# Before the game scene's _ready(): the TileGrid shapes itself from it.
	Globals.selected_ship = ship
	SaveManager.save_path = _SAVE_PATH
	SaveManager.delete_save()
	RNGManager.next_run_seed = shot.run_seed
	Globals.pending_load_save = shot.build_save(ship)
	# The shot's faces go in on arrival (_begin_take); until then the dice the
	# save spawns roll from the seed.
	Dice.forced_rolls.clear()
	_script = _new_script()
	_launch_pending = true
	# Now, not on arrival: the arrival's own checkpoint flashes "Saving...".
	set_trailer_mode(shot.clean_hud or trailer_mode)
	set_cursor_visible(shot.show_cursor)
	set_music_muted(shot.mute_music)
	_speed_index = maxi(_SPEEDS.find(shot.time_scale), 0)
	set_speed(shot.time_scale)
	print("Trailer shot '%s' (seed %d, %s)." % [id, shot.run_seed, shot.scenario_id])
	return ""


func _new_script() -> TrailerScript:
	var runner: TrailerScript = TrailerScript.new(self)
	runner.on_director_command = _on_director_command
	return runner


## The game scene reading its save: the shot's scenario takes the opening
## slot, keeping that slot's seed (as a Scenario Lab run does). Any other run
## (a New Game, a lab run) ends the shot.
func _on_load_game_save(game_save: GameSaveResource) -> void:
	if not _launch_pending:
		if shot != null:
			stop_shot()
		return
	_launch_pending = false
	# The Scenario Lab hands the save path back on any run that isn't its own.
	SaveManager.save_path = _SAVE_PATH

	var slot: int = game_save.current_scenario_index
	var scenario: ScenarioResource = load(ContentRegistry.get_scenario_path(shot.scenario_id))
	scenario.scenario_seed = game_save.sector_scenarios[slot].scenario_seed
	game_save.sector_scenarios[slot] = scenario

	# Connected now, after the BackgroundManager's own load_scenario handler
	# (it's ready before the GameStateManager reads the save), so the shot's
	# sky replaces the drawn one in the same frame.
	if shot.background:
		Events.load_scenario.connect(_show_shot_background, CONNECT_ONE_SHOT)
	Events.start_scenario.connect(_begin_take, CONNECT_ONE_SHOT)


func _show_shot_background(_scenario: ScenarioResource) -> void:
	if shot and shot.background and is_instance_valid(Globals.background_manager):
		Globals.background_manager.show_background(shot.background)


func _begin_take() -> void:
	if shot == null:
		return
	Globals.player.health.invulnerable = shot.god_mode
	# The player arrives by rerolling the hand the save spawned (after a beat,
	# Player._start_scenario), so the shot's faces are the ones it lands on.
	Dice.forced_rolls.clear()
	Dice.forced_rolls.append_array(shot.forced_rolls)
	_open_take_log()
	mark("start " + shot_id)

	if shot.beats.is_empty():
		return
	var runner: TrailerScript = _script
	await runner.run(shot.beats)
	if runner != _script or runner.is_stopped():
		# Retaken or stopped part way: that take is over.
		return
	mark("end " + shot_id)
	_close_take_log()
	if _quit_when_done:
		get_tree().quit()


## time, hud, cursor, music, mark, still and quit, from a shot's beats.
func _on_director_command(command: String, args: PackedStringArray) -> String:
	var arg: String = args[0] if not args.is_empty() else ""
	match command:
		"time":
			if not arg.is_valid_float():
				return "time <scale>"
			set_speed(float(arg))
		"hud":
			if arg not in ["clean", "full"]:
				return "hud clean|full"
			set_trailer_mode(arg == "clean")
		"cursor":
			if arg not in ["show", "hide"]:
				return "cursor show|hide"
			set_cursor_visible(arg == "show")
		"music":
			if arg not in ["on", "off"]:
				return "music on|off"
			set_music_muted(arg == "off")
		"mark":
			mark(" ".join(args) if not args.is_empty() else "mark")
		"still":
			Events.take_screenshot.emit()
		"quit":
			if _script:
				_script.stop()
			mark("end " + shot_id)
			_close_take_log()
			if _quit_when_done:
				get_tree().quit()
	return ""


# ── Take log ─────────────────────────────────────────────────────────────────

func _open_take_log() -> void:
	_close_take_log()
	DirAccess.make_dir_recursive_absolute(_takes_dir)
	var stamp: String = Time.get_datetime_string_from_system().replace(":", "-")
	var path: String = _takes_dir.path_join("%s_%s.txt" % [shot_id, stamp])
	_take_log = FileAccess.open(path, FileAccess.WRITE)
	_take_start_physics_frame = Engine.get_physics_frames()
	_take_start_msec = Time.get_ticks_msec()
	if _take_log:
		_take_log.store_line("# %s, seed %d. frame (since boot) / seconds into the take / label" % [shot_id, shot.run_seed if shot else 0])
		print("Trailer take log: " + ProjectSettings.globalize_path(path))


func _close_take_log() -> void:
	if _take_log:
		_take_log.close()
		_take_log = null


# ── Helpers ──────────────────────────────────────────────────────────────────

## The tutorial narrates the first fight and seeds the run itself, so a shot
## switches it off before its _ready() decides to start (as the AutoPilot
## does). One built by a later scene change is caught as it arrives.
func _switch_off_tutorials(root: Node) -> void:
	var stack: Array[Node] = [root]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		if node is TutorialManager:
			(node as TutorialManager).auto_start = false
		stack.append_array(node.get_children())


func _on_node_added(node: Node) -> void:
	if (_launch_pending or shot != null) and node is TutorialManager:
		(node as TutorialManager).auto_start = false


## Prints what a hotkey or console command did. Answers [param problem].
func _report(problem: String, what: String) -> String:
	if problem.is_empty():
		print("Trailer: " + what)
	else:
		push_warning("Trailer: %s: %s" % [what, problem])
	return problem


## `--key=value` and bare `--flag` user args (after `--`), keyed without the
## dashes.
static func _parse_user_args() -> Dictionary[String, String]:
	var parsed: Dictionary[String, String] = {}
	for arg: String in OS.get_cmdline_user_args():
		if not arg.begins_with("--"):
			continue
		var pair: PackedStringArray = arg.trim_prefix("--").split("=", true, 1)
		parsed[pair[0]] = pair[1] if pair.size() > 1 else ""
	return parsed
