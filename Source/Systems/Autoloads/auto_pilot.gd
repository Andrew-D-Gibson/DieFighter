extends Node
## AutoPilot
## Plays a run by itself for QA and balance testing, through the same entry
## points a player's input reaches (see AutoPilotMove).
##
## Off unless the game runs on an editor binary with `--autoplay` among the
## user args; otherwise it frees itself, like McpInteractionServer. Launch it
## with tools/autoplay.sh, which fast-forwards it headless:
##
##   Godot --headless --fixed-fps 60 --path . -- --autoplay --seed=7 --out=<dir>
##
## User args (after `--`):
##   --autoplay           turn it on
##   --seed=N             the run seed (default: random, and reported)
##   --policy=NAME        how it chooses (default: random; see AutoPilotPolicy)
##   --out=DIR            where the transcript goes (default: user://autoplay)
##   --max-turns=N        give up after this many player turns (default 600)
##   --stall-seconds=N    give up after this long with nothing to do (default 90)
##   --max-loop-moves=N   give up after this many moves without progress (500)
##
## One run per process: statics (forced rolls, forced actions) and the scene's
## own state would otherwise leak from one run into the next.
##
## The transcript is JSON lines: a header, a snapshot at the start of every
## player turn, every move, and how the run ended. Gameplay only, never
## positions or frame counts, so two runs from the same seed and policy should
## write identical files (tools/autoplay.sh --determinism checks that).

## Frames to let the game settle after acting before acting again. A patient
## player: dice reach the hand and chains finish before the next move.
const _SETTLE_FRAMES: int = 10

## STALLED: nothing to do for too long. LOOPING: acting without the run
## getting anywhere (no new turn, scenario or won fight).
enum Outcome { NONE, VICTORY, DEFEAT, TURN_LIMIT, STALLED, LOOPING }

var _policy: AutoPilotPolicy
var _policy_name: String = "random"
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _run_seed: int = -1
var _out_dir: String = "user://autoplay"
var _max_turns: int = 600
var _stall_frames: int = 90 * 60
var _max_moves_without_progress: int = 500

var _transcript: FileAccess
var _outcome: Outcome = Outcome.NONE
var _settle: int = 0
var _idle_frames: int = 0
var _moves_since_progress: int = 0
var _player_turn: int = 0
var _player_turn_active: bool = false
var _in_transit: bool = false
var _scenario_name: String = ""


func _ready() -> void:
	var args: Dictionary[String, String] = _parse_user_args()
	# Editor binaries only, like McpInteractionServer: no shipped build should
	# play itself, however it's launched.
	if not OS.has_feature("editor") or not args.has("autoplay"):
		queue_free()
		return

	process_mode = Node.PROCESS_MODE_ALWAYS
	_policy_name = args.get("policy", _policy_name)
	_policy = AutoPilotPolicy.named(_policy_name)
	if not _policy:
		_abort("unknown policy '%s'" % _policy_name)
		return
	_out_dir = args.get("out", _out_dir)
	_max_turns = int(args.get("max-turns", str(_max_turns)))
	_stall_frames = int(args.get("stall-seconds", "90")) * Engine.physics_ticks_per_second
	_max_moves_without_progress = int(args.get("max-loop-moves", str(_max_moves_without_progress)))

	if args.has("seed"):
		_run_seed = int(args["seed"])
	else:
		var seeder := RandomNumberGenerator.new()
		seeder.randomize()
		_run_seed = seeder.randi()

	_isolate_from_player_data()
	# Parallel headless runs would fight over the MCP port, and could take it
	# from a game the developer has open. A watched run keeps it.
	if DisplayServer.get_name() == "headless" and is_instance_valid(McpInteractionServer):
		McpInteractionServer.queue_free()
	TimeDirector.use_frame_clock()
	RNGManager.next_run_seed = _run_seed
	# The policy's own stream: drawing from a gameplay bucket would shift every
	# roll after the first decision.
	_rng.seed = hash([_run_seed, "autopilot"])

	if not _open_transcript():
		return
	_connect_game_signals()
	# Autoloads are ready before the main scene (main.tscn, the game itself)
	# is built, so everything above is in place before the run starts.
	get_tree().node_added.connect(_on_node_added)
	print("AutoPilot: seed %d, policy %s" % [_run_seed, _policy_name])


func _process(_delta: float) -> void:
	if _outcome != Outcome.NONE or not _game_is_up():
		return

	_idle_frames += 1
	if _idle_frames > _stall_frames:
		_finish(Outcome.STALLED)
		return

	if _settle > 0:
		_settle -= 1
		return
	if not _waiting_on_player():
		return

	var moves: Array[AutoPilotMove] = AutoPilotMove.list_legal()
	# Only dice and End Turn move the game on. Retargeting or flipping tabs
	# with nothing to play would just fill the wait while a chain finishes;
	# a die with nowhere to go on this tab may have somewhere on the other.
	if not moves.any(_advances_play) and AutoPilotMove.dice_in_hand().is_empty():
		return

	var move: AutoPilotMove = _policy.choose(moves, _rng)
	var entry: Dictionary = move.describe()
	entry["type"] = "move"
	entry["turn"] = _player_turn
	_write(entry)
	move.perform()
	_idle_frames = 0
	_settle = _SETTLE_FRAMES
	_moves_since_progress += 1
	if _moves_since_progress > _max_moves_without_progress:
		_finish(Outcome.LOOPING)


static func _advances_play(move: AutoPilotMove) -> bool:
	return move.kind == AutoPilotMove.Kind.PLACE_DIE or move.kind == AutoPilotMove.Kind.END_TURN


## Whether a patient player would act: the game scene is up and not over,
## no jump is underway, nothing is resolving, and (in a fight) it's their
## turn. A player *can* act sooner, mid-jump or mid-chain; that's for an
## impatient mode to explore.
func _waiting_on_player() -> bool:
	if _in_transit:
		return false
	var state: GameStateManager.GameState = Globals.state_manager.state
	if state == GameStateManager.GameState.GAME_OVER or state == GameStateManager.GameState.VICTORY:
		return false
	var engine: ScenarioEngine = ScenarioEngine.current()
	if not engine or engine.currently_processing_queue or not engine.event_queue.is_empty():
		return false
	return state == GameStateManager.GameState.OUT_OF_COMBAT or _player_turn_active


func _game_is_up() -> bool:
	return is_instance_valid(Globals.state_manager) and is_instance_valid(Globals.player) \
		and Globals.state_manager.is_inside_tree()


func _connect_game_signals() -> void:
	Events.load_scenario.connect(func(scenario: ScenarioResource) -> void:
		_scenario_name = scenario.resource_path.get_file().get_basename()
	)
	# A fight's first turn has its own signal; every later one follows an
	# enemy turn.
	Events.first_turn_start.connect(_on_player_turn_start)
	Events.player_turn_start.connect(_on_player_turn_start)
	Events.player_turn_over.connect(func() -> void: _player_turn_active = false)
	Events.jump.connect(func() -> void: _in_transit = true)
	Events.start_scenario.connect(func() -> void:
		_in_transit = false
		_idle_frames = 0
		_moves_since_progress = 0
		_write({"type": "arrive", "turn": _player_turn, "scenario": _scenario_name,
			"map_index": Globals.map.current_scenario_index})
	)
	Events.combat_finished.connect(func() -> void:
		_moves_since_progress = 0
		_write({"type": "combat_won", "turn": _player_turn, "scenario": _scenario_name,
			"hull": Globals.player.health.health})
	)
	Events.player_destroyed.connect(func() -> void: _finish(Outcome.DEFEAT))
	Events.victory.connect(func() -> void: _finish(Outcome.VICTORY))


func _on_player_turn_start() -> void:
	_player_turn_active = true
	_player_turn += 1
	_idle_frames = 0
	_moves_since_progress = 0
	_settle = _SETTLE_FRAMES
	if _player_turn > _max_turns:
		_finish(Outcome.TURN_LIMIT)
		return
	var entry: Dictionary = AutoPilotSnapshot.turn(_scenario_name)
	entry["type"] = "turn"
	entry["turn"] = _player_turn
	_write(entry)


## The tutorial narrates the first fight and waits on popups; the bot plays
## the cold open as a returning player sees it. Set before the manager's
## _ready(), which is where it decides.
func _on_node_added(node: Node) -> void:
	if node is TutorialManager:
		(node as TutorialManager).auto_start = false


## Keeps the bot off the player's save, and parallel bots off each other's.
func _isolate_from_player_data() -> void:
	DirAccess.make_dir_recursive_absolute(_out_dir)
	SaveManager.save_path = _out_dir.path_join("save_%d.json" % OS.get_process_id())


func _open_transcript() -> bool:
	var path: String = _out_dir.path_join("seed_%d_%s.jsonl" % [_run_seed, _policy_name])
	_transcript = FileAccess.open(path, FileAccess.WRITE)
	if not _transcript:
		_abort("can't write %s (%s)" % [path, error_string(FileAccess.get_open_error())])
		return false
	_write({"type": "header", "seed": _run_seed, "policy": _policy_name})
	return true


func _write(entry: Dictionary) -> void:
	if _transcript:
		_transcript.store_line(JSON.stringify(entry, "", false))


func _finish(outcome: Outcome) -> void:
	if _outcome != Outcome.NONE:
		return
	_outcome = outcome
	var result: Dictionary = {"type": "result", "outcome": Outcome.keys()[outcome].to_lower(),
		"turns": _player_turn, "scenario": _scenario_name}
	if _game_is_up():
		result["sector"] = Globals.state_manager.current_game_save.sector_index
		result["hull"] = Globals.player.health.health
	_write(result)
	# Quitting waits for the frame to end, and signals can still arrive.
	_transcript.close()
	_transcript = null
	print("AutoPilot: %s after %d turns" % [result["outcome"], _player_turn])
	SaveManager.delete_save()
	# Not QuitManager: its cleanup bumps times_run and rewrites the player's
	# options file. A stuck run exits non-zero so the launcher can flag it.
	get_tree().quit(1 if outcome == Outcome.STALLED or outcome == Outcome.LOOPING else 0)


func _abort(reason: String) -> void:
	push_error("AutoPilot: " + reason)
	get_tree().quit(2)


## `--key=value` and bare `--flag` user args, keyed without the dashes.
static func _parse_user_args() -> Dictionary[String, String]:
	var parsed: Dictionary[String, String] = {}
	for arg: String in OS.get_cmdline_user_args():
		if not arg.begins_with("--"):
			continue
		var pair: PackedStringArray = arg.trim_prefix("--").split("=", true, 1)
		parsed[pair[0]] = pair[1] if pair.size() > 1 else ""
	return parsed
