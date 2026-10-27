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
##   --policy=NAME        how it chooses: random (the default), or smart,
##                        aggressive, turtle or synergy (HeuristicPolicy);
##                        add -randpick (smart-randpick) to take salvage and
##                        shop stock at random
##   --out=DIR            where the transcript goes (default: user://autoplay)
##   --max-turns=N        give up after this many player turns (default 600)
##   --stall-seconds=N    give up after this long with nothing to do (default 90)
##   --max-loop-moves=N   give up after this many moves without progress (500)
##   --gauntlet=SPEC      play one gauntlet cell from the spec file at SPEC
##   --scenario=ID        ...this scenario (see AutoPilotGauntlet)
##   --loadout=NAME       ...with this loadout from the spec
##   --screenshots=DIR    save pictures of the run here (windowed runs only;
##                        see AutoPilotCamera)
##   --stop-at-turn=N     stop playing as player turn N starts and leave the
##                        game running, to look around or play on by hand
##   --no-mcp             free McpInteractionServer in a windowed run too,
##                        so a replay can't clash with a game on port 9090
##
## A gauntlet run starts in the chosen scenario with the chosen loadout, holds
## its ground (no jumping away mid-fight), and ends when that scenario's fight
## is decided: cleared, defeat, or fled/passed if it jumped on before one.
##
## One run per process: statics (forced rolls, forced actions) and the scene's
## own state would otherwise leak from one run into the next.
##
## The transcript is JSON lines: a header, a snapshot at the start of every
## player turn, every move, and how the run ended. Gameplay only, never
## positions or frame counts, so two runs from the same seed and policy should
## write identical files (tools/autoplay.sh --determinism checks that). The
## one exception is "memory" entries (node counts, and a leak warning once a
## count has grown too far), which the check skips.
##
## Along the way it watches for what a crash-free run can still get wrong:
## every engine or script error, with the move it followed ("error"), and
## every broken invariant ("violation", see AutoPilotInvariants). The result
## line counts both. The engine's own play-by-play goes to a .debug.txt
## beside the transcript (DebugLogger).
##
## For balance, it tallies what tiles and enemies did (AutoPilotTelemetry):
## a "visit" entry as each scenario is left, and the run's totals, final
## build and what dealt the last blow in the result. Each arrival records the
## build, and each salvage offer and shop its items ("offer"), so a tile can
## be judged against what it was taken over (tools/tile_balance.py).
## tools/autoplay_report.py reads a batch of them.

## Frames to let the game settle after acting before acting again. A patient
## player: dice reach the hand and chains finish before the next move.
const _SETTLE_FRAMES: int = 10

## Errors written to the transcript before the rest are only counted. One
## bug can repeat every frame.
const _MAX_ERRORS_WRITTEN: int = 200

## STALLED: nothing to do for too long. LOOPING: acting without the run
## getting anywhere (no new turn, scenario or won fight). CLEARED, FLED and
## PASSED end a gauntlet run: its fight won, jumped away from mid-fight, or
## left without one.
enum Outcome { NONE, VICTORY, DEFEAT, TURN_LIMIT, STALLED, LOOPING, CLEARED, FLED, PASSED }

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

## Set for a gauntlet run.
var _gauntlet: AutoPilotGauntlet
var _invariants: AutoPilotInvariants = AutoPilotInvariants.new()
var _telemetry: AutoPilotTelemetry = AutoPilotTelemetry.new()
var _error_log: AutoPilotErrorLog
## Set for a windowed run asked for screenshots.
var _camera: AutoPilotCamera
## Set at each turn start and arrival: before its first move there the bot
## spends a frame looking at the board, and a replay photographs it. Headless
## runs look too, so a replay keeps the original's timing.
var _look_before_next_move: bool = false
var _shot_label: String = ""
## 0: play to the end.
var _stop_at_turn: int = 0
## Set once --stop-at-turn has been reached: the game is the developer's.
var _handed_over: bool = false
var _errors: int = 0
var _violations: int = 0
## The last move made, for an error to say what it followed.
var _last_move: Dictionary = {}
## Set on each arrival until the bot first gets to act there; the board is
## checked then, once the hand is dealt.
var _arrival_unchecked: bool = false
## Salvage offers already counted, by instance id.
var _offers_seen: Dictionary[int, bool] = {}
## Whether this stop's shop stock has gone in the transcript.
var _shop_written: bool = false


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
	_stop_at_turn = int(args.get("stop-at-turn", "0"))
	if args.has("screenshots") and AutoPilotCamera.can_capture():
		_camera = AutoPilotCamera.new(args["screenshots"])

	if args.has("seed"):
		_run_seed = int(args["seed"])
	else:
		var seeder := RandomNumberGenerator.new()
		seeder.randomize()
		_run_seed = seeder.randi()

	if args.has("gauntlet"):
		_gauntlet = AutoPilotGauntlet.new()
		var problem: String = _gauntlet.load_cell(args["gauntlet"], args.get("scenario", ""),
			args.get("loadout", ""), int(args.get("sector", "-1")))
		if problem != "":
			_abort(problem)
			return
		# Read by GameStateManager's _ready(), still to come.
		Globals.pending_load_save = _gauntlet.build_save()
		# The question is whether the loadout can win the fight.
		_policy.set_may_flee(false)
		Events.load_game_save.connect(_gauntlet.place_scenario)

	_isolate_from_player_data()
	# Parallel headless runs would fight over the MCP port, and could take it
	# from a game the developer has open. A watched run keeps it.
	if (DisplayServer.get_name() == "headless" or args.has("no-mcp")) \
	and is_instance_valid(McpInteractionServer):
		McpInteractionServer.queue_free()
	TimeDirector.use_frame_clock()
	RNGManager.next_run_seed = _run_seed
	# The policy's own stream: drawing from a gameplay bucket would shift every
	# roll after the first decision.
	_rng.seed = hash([_run_seed, "autopilot"])

	if not _open_transcript():
		return
	# The engine's play-by-play, for reading a flagged run after the fact.
	DebugLogger.start(_out_dir.path_join(_run_name() + ".debug.txt"))
	_error_log = AutoPilotErrorLog.new()
	OS.add_logger(_error_log)
	_connect_game_signals()
	# By the time autoloads are ready the main scene (main.tscn, the game
	# itself) has already entered the tree, but none of it is ready yet, so
	# everything above is in place before the run starts. The tutorial is
	# switched off now, before its own _ready() decides whether to run.
	if not _switch_off_tutorials(get_tree().root):
		return
	get_tree().node_added.connect(_on_node_added)
	print("AutoPilot: seed %d, policy %s%s" % [_run_seed, _policy_name,
		", gauntlet %s × %s" % [_gauntlet.scenario_id, _gauntlet.loadout_name] if _gauntlet else ""])


func _process(_delta: float) -> void:
	if _outcome != Outcome.NONE or _handed_over:
		return
	_record_errors()
	if not _game_is_up():
		return
	_telemetry.follow(ScenarioEngine.current())
	_count_salvage_offers()
	_write_shop_stock()

	_idle_frames += 1
	if _idle_frames > _stall_frames:
		_finish(Outcome.STALLED)
		return

	if _settle > 0:
		_settle -= 1
		return
	if not _waiting_on_player():
		return
	if _arrival_unchecked:
		_arrival_unchecked = false
		_report(_invariants.on_arrival_settled())
		# Something seeding the run itself (the tutorial does) would make this
		# transcript describe a different run than its name says.
		if RNGManager.current_run_seed != _run_seed:
			_report([{"check": "run_seed_overridden",
				"detail": "asked for %d, the run is %d" % [_run_seed, RNGManager.current_run_seed]}])
		var memory: Dictionary = AutoPilotInvariants.memory()
		var leaks: Array[String] = _invariants.leaks(memory)
		if not leaks.is_empty():
			memory["leaks"] = leaks
		memory["type"] = "memory"
		memory["turn"] = _player_turn
		_write(memory)

	var moves: Array[AutoPilotMove] = AutoPilotMove.list_legal()
	if _gauntlet and Globals.state_manager.state == GameStateManager.GameState.IN_COMBAT:
		moves = moves.filter(_stays_in_the_fight)
	# Only dice and End Turn move the game on. Retargeting or flipping tabs
	# with nothing to play would just fill the wait while a chain finishes;
	# a die with nowhere to go on this tab may have somewhere on the other.
	if not moves.any(_advances_play) and AutoPilotMove.dice_in_hand().is_empty():
		return

	if _look_before_next_move:
		_look_before_next_move = false
		if _camera:
			_camera.capture(get_viewport(), _shot_label)
		return

	var move: AutoPilotMove = _policy.choose(moves, _rng)
	if not move:
		return
	var entry: Dictionary = move.describe()
	entry["type"] = "move"
	entry["turn"] = _player_turn
	_write(entry)
	_last_move = move.describe()
	if move.kind == AutoPilotMove.Kind.CLAIM or move.kind == AutoPilotMove.Kind.BUY:
		_telemetry.on_item_taken(move.kind == AutoPilotMove.Kind.BUY)
	elif move.kind == AutoPilotMove.Kind.REPAIR or move.kind == AutoPilotMove.Kind.SELL:
		_telemetry.on_station_used(move.kind == AutoPilotMove.Kind.SELL)
	move.perform()
	_idle_frames = 0
	_settle = _SETTLE_FRAMES
	_moves_since_progress += 1
	if _moves_since_progress > _max_moves_without_progress:
		_finish(Outcome.LOOPING)


## Moves that change the game for good. Taking a choice or buying uses it up,
## so they can't loop the way flipping tabs can; nor can a repair (the price
## climbs and the hull fills) or a sale (the tile is gone).
## A gauntlet asks whether the loadout can win the fight, so the bot doesn't
## jump out of one.
static func _stays_in_the_fight(move: AutoPilotMove) -> bool:
	return move.kind != AutoPilotMove.Kind.PLACE_DIE \
		or (move.tile != Globals.map.left_arrow_tile and move.tile != Globals.map.right_arrow_tile)


static func _advances_play(move: AutoPilotMove) -> bool:
	return move.kind in [AutoPilotMove.Kind.PLACE_DIE, AutoPilotMove.Kind.END_TURN,
		AutoPilotMove.Kind.CLAIM, AutoPilotMove.Kind.BUY, AutoPilotMove.Kind.REPAIR,
		AutoPilotMove.Kind.SELL]


## Whether a patient player would act: the game scene is up and not over,
## no jump is underway (from the moment one is decided), the hand is dealt,
## nothing is resolving, no salvage is about to appear, and (in a fight) it's
## their turn. A player *can* act sooner, mid-jump or mid-chain; that's for an
## impatient mode to explore.
func _waiting_on_player() -> bool:
	if _in_transit or Globals.player.is_dealing_hand() or Globals.player.is_jump_committed():
		return false
	var state: GameStateManager.GameState = Globals.state_manager.state
	if state == GameStateManager.GameState.GAME_OVER or state == GameStateManager.GameState.VICTORY:
		return false
	var engine: ScenarioEngine = ScenarioEngine.current()
	if not engine or engine.currently_processing_queue or not engine.event_queue.is_empty():
		return false
	# Salvage shows a moment after the ship that dropped it goes down; a
	# patient player sees what's on offer before moving on.
	if _salvage_on_its_way():
		return false
	return state == GameStateManager.GameState.OUT_OF_COMBAT or _player_turn_active


## Counts each salvage offer once, as its choices come on show. A ship's
## payout alone (Events.spawn_reward) may be only credits, with no choices.
func _count_salvage_offers() -> void:
	if not is_instance_valid(Globals.reward_manager):
		return
	for child: Node in Globals.reward_manager.get_children():
		var offer: Reward = child as Reward
		if offer and offer.visible and not offer.rewards.is_empty() \
		and not _offers_seen.has(offer.get_instance_id()):
			_offers_seen[offer.get_instance_id()] = true
			_telemetry.on_salvage_offered()
			var items: Array[String] = []
			for choice: Node2D in offer.rewards:
				if is_instance_valid(choice):
					items.append(AutoPilotMove.item_name(choice))
			_write({"type": "offer", "source": "salvage", "turn": _player_turn, "items": items,
				"room": Globals.tile_grid.has_free_cell()})


## Writes what the shop has, and at what price, once per stop: with the
## salvage offers, what a tile taken was chosen over.
func _write_shop_stock() -> void:
	if _shop_written or not is_instance_valid(Globals.shop) or not Globals.shop.is_visible_in_tree() \
	or Globals.shop.item_to_shop_index.is_empty():
		return
	_shop_written = true
	var items: Array[Dictionary] = []
	for stock: Node in Globals.shop.item_to_shop_index:
		if is_instance_valid(stock):
			items.append({"item": AutoPilotMove.item_name(stock), "price": Globals.shop.price_of(stock)})
	_write({"type": "offer", "source": "shop", "turn": _player_turn, "items": items,
		"money": AutoPilotSnapshot.credits(), "room": Globals.tile_grid.has_free_cell()})


func _salvage_on_its_way() -> bool:
	if not is_instance_valid(Globals.reward_manager):
		return false
	for child: Node in Globals.reward_manager.get_children():
		if child is Reward and (child as Reward).is_on_its_way():
			return true
	return false


func _game_is_up() -> bool:
	return is_instance_valid(Globals.state_manager) and is_instance_valid(Globals.player) \
		and Globals.state_manager.is_inside_tree()


func _connect_game_signals() -> void:
	Events.load_scenario.connect(func(scenario: ScenarioResource) -> void:
		_scenario_name = scenario.resource_path.get_file().get_basename()
		_invariants.reset_turns()
	)
	Events.first_turn_start.connect(_telemetry.on_fight_started)
	Events.start_combat.connect(func() -> void:
		_invariants.reset_turns()
		# A fight breaking out starts with its own first turn, whatever the
		# bot was doing out of combat.
		_player_turn_active = false
	)
	Events.combat_finished.connect(_invariants.reset_turns)
	Events.combat_finished.connect(_telemetry.on_combat_won)
	Events.enemy_left.connect(func(ship: Enemy, _faction: ScenarioManager.Faction) -> void:
		if is_instance_valid(ship):
			_telemetry.on_enemy_left(ship)
	)
	Events.enemy_turn_starting.connect(func() -> void: _report(_invariants.on_enemy_turn_starting()))
	Events.enemy_turn_over.connect(_invariants.on_enemy_turn_over)
	# A fight's first turn has its own signal; every later one follows an
	# enemy turn.
	Events.first_turn_start.connect(_on_player_turn_start)
	Events.player_turn_start.connect(_on_player_turn_start)
	Events.player_turn_over.connect(func() -> void:
		_player_turn_active = false
		_invariants.on_player_turn_over()
	)
	Events.jump.connect(func() -> void:
		var in_combat: bool = Globals.state_manager.state == GameStateManager.GameState.IN_COMBAT
		_write(_telemetry.end_visit("left", _player_turn))
		if _gauntlet:
			_finish(Outcome.FLED if in_combat else Outcome.PASSED)
			return
		_in_transit = true
		# A fight arrived at starts with its own first turn; until then the
		# ships are still flying in.
		_player_turn_active = false
	)
	Events.start_scenario.connect(func() -> void:
		_in_transit = false
		_arrival_unchecked = true
		_idle_frames = 0
		_moves_since_progress = 0
		_shop_written = false
		# The build at every stop says when each tile joined and left it.
		_write({"type": "arrive", "turn": _player_turn, "scenario": _scenario_name,
			"sector": Globals.state_manager.current_game_save.sector_index,
			"map_index": Globals.map.current_scenario_index, "build": AutoPilotTelemetry.build()})
		_shoot("arrive_%s" % _scenario_name)
		_telemetry.begin_visit(_scenario_name, Globals.state_manager.current_game_save.sector_index,
			Globals.map.current_scenario_index, _player_turn)
	)
	Events.combat_finished.connect(func() -> void:
		_moves_since_progress = 0
		_write({"type": "combat_won", "turn": _player_turn, "scenario": _scenario_name,
			"hull": Globals.player.health.health})
		# What the fight left behind: salvage, the open map.
		_shoot("won_%s" % _scenario_name)
		if _gauntlet:
			_finish(Outcome.CLEARED)
	)
	Events.player_destroyed.connect(func() -> void: _finish(Outcome.DEFEAT))
	Events.victory.connect(func() -> void: _finish(Outcome.VICTORY))


func _on_player_turn_start() -> void:
	_report(_invariants.on_player_turn_start(_in_transit))
	_player_turn_active = true
	_player_turn += 1
	_idle_frames = 0
	_moves_since_progress = 0
	_settle = _SETTLE_FRAMES
	if _player_turn > _max_turns:
		_finish(Outcome.TURN_LIMIT)
		return
	if _stop_at_turn > 0 and _player_turn >= _stop_at_turn:
		_hand_over()
		return
	_shoot("turn_%03d" % _player_turn)
	var entry: Dictionary = AutoPilotSnapshot.turn(_scenario_name)
	entry["type"] = "turn"
	entry["turn"] = _player_turn
	_write(entry)


## The tutorial narrates the first fight, waits on popups and fixes the run's
## seed; the bot plays the cold open as a returning player sees it. Set before
## each manager's _ready(), which is where it decides. One already ready has
## started, and the run would be the tutorial's, not this seed's.
func _switch_off_tutorials(root: Node) -> bool:
	var stack: Array[Node] = [root]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		if node is TutorialManager:
			if node.is_node_ready():
				_abort("the tutorial started before the AutoPilot could switch it off")
				return false
			(node as TutorialManager).auto_start = false
		stack.append_array(node.get_children())
	return true


## A tutorial built later (a scene change) is caught as it arrives.
func _on_node_added(node: Node) -> void:
	if node is TutorialManager:
		(node as TutorialManager).auto_start = false


## Keeps the bot off the player's save and options, and parallel bots off
## each other's saves. Options aren't redirected but silenced: nothing in a
## bot run (finishing the tutorial, the dev console) may change a setting the
## player chose.
func _isolate_from_player_data() -> void:
	DirAccess.make_dir_recursive_absolute(_out_dir)
	SaveManager.save_path = _out_dir.path_join("save_%d.json" % OS.get_process_id())
	if Events.save_options_config.is_connected(OptionsSettings.save_options_settings):
		Events.save_options_config.disconnect(OptionsSettings.save_options_settings)


## What this run's files are called: seed_<N>_<policy>, plus the gauntlet
## cell for a gauntlet run (tools/autoplay.sh names them the same way).
func _run_name() -> String:
	var run_name: String = "seed_%d_%s" % [_run_seed, _policy_name]
	if _gauntlet:
		run_name += "__%s__%s" % [_gauntlet.scenario_id, _gauntlet.loadout_name]
	return run_name


func _open_transcript() -> bool:
	var path: String = _out_dir.path_join(_run_name() + ".jsonl")
	_transcript = FileAccess.open(path, FileAccess.WRITE)
	if not _transcript:
		_abort("can't write %s (%s)" % [path, error_string(FileAccess.get_open_error())])
		return false
	var header: Dictionary = {"type": "header", "seed": _run_seed, "policy": _policy_name}
	if _gauntlet:
		header["gauntlet"] = _gauntlet.describe()
	_write(header)
	return true


func _write(entry: Dictionary) -> void:
	if _transcript and not entry.is_empty():
		_transcript.store_line(JSON.stringify(entry, "", false))


## The next picture: the board as the bot is about to make its first move
## here, once the hand is dealt and the intents are up.
func _shoot(label: String) -> void:
	_look_before_next_move = true
	_shot_label = label


## Stops playing (--stop-at-turn) and leaves the game as it is.
func _hand_over() -> void:
	_handed_over = true
	_write({"type": "stopped", "turn": _player_turn, "scenario": _scenario_name})
	_transcript.flush()
	if _camera:
		_camera.capture(get_viewport(), "stopped_turn_%03d" % _player_turn)
	print("AutoPilot: stopped at turn %d as asked; the game is yours" % _player_turn)


func _report(violations: Array[Dictionary]) -> void:
	for violation: Dictionary in violations:
		_violations += 1
		if _camera:
			_camera.capture_flagged(get_viewport(), "violation_%s_turn_%03d" % [violation["check"], _player_turn])
		violation["type"] = "violation"
		violation["turn"] = _player_turn
		violation["scenario"] = _scenario_name
		_write(violation)


func _record_errors() -> void:
	if not _error_log:
		return
	for error: Dictionary in _error_log.take():
		_errors += 1
		if _errors > _MAX_ERRORS_WRITTEN:
			continue
		error["type"] = "error"
		error["turn"] = _player_turn
		error["scenario"] = _scenario_name
		error["after"] = _last_move
		_write(error)
		if _camera:
			_camera.capture_flagged(get_viewport(), "error_turn_%03d" % _player_turn)


func _finish(outcome: Outcome) -> void:
	if _outcome != Outcome.NONE:
		return
	_outcome = outcome
	_record_errors()
	var result: Dictionary = {"type": "result", "outcome": Outcome.keys()[outcome].to_lower(),
		"turns": _player_turn, "scenario": _scenario_name, "errors": _errors,
		"violations": _violations}
	if _game_is_up():
		var how: String = "died" if outcome == Outcome.DEFEAT else "run_over"
		if outcome == Outcome.VICTORY:
			how = "left"
		elif outcome == Outcome.CLEARED:
			how = "won"
		_write(_telemetry.end_visit(how, _player_turn))
		result["sector"] = Globals.state_manager.current_game_save.sector_index
		result["map_index"] = Globals.map.current_scenario_index
		result["hull"] = Globals.player.health.health
		result["dice"] = Globals.player.num_of_dice
		result["money"] = AutoPilotSnapshot.credits()
		result["build"] = AutoPilotTelemetry.build()
		if outcome == Outcome.DEFEAT:
			result["killed_by"] = _telemetry.last_hit
	result["tiles"] = _telemetry.tiles
	result["enemies"] = _telemetry.enemies
	_write(result)
	# Quitting waits for the frame to end, and signals can still arrive.
	_transcript.close()
	_transcript = null
	OS.remove_logger(_error_log)
	_error_log = null
	print("AutoPilot: %s after %d turns, %d errors, %d violations" % [
		result["outcome"], _player_turn, _errors, _violations])
	if _camera:
		await _camera.capture(get_viewport(), "end_%s" % result["outcome"])
	SaveManager.delete_save()
	# Not QuitManager: its cleanup bumps times_run and rewrites the player's
	# options file. A stuck run exits non-zero so the launcher can flag it.
	get_tree().quit(1 if outcome == Outcome.STALLED or outcome == Outcome.LOOPING else 0)


func _abort(reason: String) -> void:
	if _error_log:
		OS.remove_logger(_error_log)
		_error_log = null
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
