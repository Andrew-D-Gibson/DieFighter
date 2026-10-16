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
## Overwritten at every launch, so it only ever holds the latest session.

var _log_file: FileAccess
## user://, not res://: an exported build can't write inside its own package.
## On macOS this is ~/Library/Application Support/Godot/app_userdata/DieFighter/.
var _log_path: String = "user://debug_log.txt"

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

	# Clear the log file at startup
	_log_file = FileAccess.open(_log_path, FileAccess.WRITE)
	if _log_file == null:
		push_error("Failed to open debug log file at: " + _log_path)
		return

	_connect_run_signals()
	_connect_turn_signals()
	_connect_environment_signals()
	_connect_board_signals()

	_log("Debug logger initialized, %s" % Time.get_datetime_string_from_system(false, true))


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
	if _log_file == null:
		return

	var time_dict: Dictionary = Time.get_time_dict_from_system()
	var msec: int = int(fmod(Time.get_unix_time_from_system(), 1.0) * 1000.0)
	var timestamp: String = "%02d:%02d:%02d.%03d" % [
		time_dict.hour,
		time_dict.minute,
		time_dict.second,
		msec,
	]
	_log_file.store_line("[%s] %s" % [timestamp, message])
	_log_file.flush()


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
	# ScenarioManager builds the new engine in its own handler for this signal,
	# which runs after this autoload's.
	_attach_engine.call_deferred()


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
	for enemy: Enemy in _live_enemies():
		_log(DebugLogFormat.enemy_summary(enemy, _engine))
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
	_log("Hazard %s: %d to go" % [hazard.hazard_name, turns_remaining])


func _on_hazard_triggered(hazard: BackgroundHazardResource) -> void:
	_log("HAZARD FIRES: %s" % hazard.hazard_name)


func _exit_tree() -> void:
	if _log_file != null:
		_log_file.close()
