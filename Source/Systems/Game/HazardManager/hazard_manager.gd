class_name HazardManager
extends Node
## Runs the current background's timed hazard, if it has one, for the length
## of each fight.
##
## Counts down in player turns — at each turn start, or each turn end for a
## YOUR_TURN_ENDS hazard — and fires the hazard's chain through the scenario
## engine when it lands, so a flare's damage flows through the same
## modifier pipeline as everything else. The countdown is broadcast every turn
## because the whole design depends on the player seeing it coming.
##
## Armed on start_combat rather than on arrival: a hazard only ever goes off
## between turns of a fight, so a countdown shown in a shop or after the last
## ship is down would be a warning about nothing.

## At or below this many turns a hazard is imminent: it goes off before the
## player acts again (at the next turn start, or as this turn ends).
## Everything that telegraphs it escalates here — the monitor turns red, the
## region's art starts acting up.
const URGENT_AT: int = 1

## The hazard counting down right now, or null outside a fight in a hazardous
## region.
var current_hazard: BackgroundHazardResource = null

## Player turns remaining before the hazard fires. Meaningless when
## current_hazard is null.
var turns_remaining: int = 0


func _ready() -> void:

	Events.start_combat.connect(_arm_for_background)
	Events.combat_finished.connect(_disarm)
	Events.load_scenario.connect(func(_scenario: ScenarioResource) -> void: _disarm())
	Events.jump.connect(_disarm)
	Events.background_changed.connect(_on_background_changed)
	Events.player_turn_start.connect(_on_player_turn_start)
	Events.enemy_turn_starting.connect(_on_enemy_turn_starting)


func has_hazard() -> bool:
	return current_hazard != null


## Swapping the background mid-fight (dev console, scripted sequences) swaps
## the hazard with it, or the monitor starts counting down to the wrong thing.
func _on_background_changed(_background: BackgroundResource) -> void:
	if Globals.state_manager and Globals.state_manager.state == GameStateManager.GameState.IN_COMBAT:
		_arm_for_background()


## Picks up the hazard of the background on screen and sets its first countdown.
func _arm_for_background() -> void:
	var background: BackgroundResource = null
	if is_instance_valid(Globals.background_manager):
		background = Globals.background_manager.current_background
	current_hazard = background.hazard if background else null

	if current_hazard == null:
		turns_remaining = 0
		Events.hazard_armed.emit(null, 0)
		return

	# Never resumed from a save: checkpoints are only taken outside a fight,
	# so a Continue always replays the fight, countdown included, from the top.
	turns_remaining = maxi(1, current_hazard.turns_until_first)

	Events.hazard_armed.emit(current_hazard, turns_remaining)


func _disarm() -> void:
	if current_hazard == null:
		return
	current_hazard = null
	turns_remaining = 0
	Events.hazard_armed.emit(null, 0)


func _on_player_turn_start() -> void:
	_count_down(BackgroundHazardResource.Timing.YOUR_TURN_STARTS)


## The player ended their turn and the dice they spent have landed with the
## ships, which have not used them yet.
func _on_enemy_turn_starting() -> void:
	_count_down(BackgroundHazardResource.Timing.YOUR_TURN_ENDS)


## One trigger point passed. Only the hazard's own trigger counts, so the
## number on the monitor is always "this many more of those".
func _count_down(trigger: BackgroundHazardResource.Timing) -> void:
	if current_hazard == null or current_hazard.timing != trigger:
		return

	turns_remaining -= 1

	if turns_remaining > 0:
		Events.hazard_countdown_changed.emit(current_hazard, turns_remaining)
		return

	turns_remaining = maxi(1, current_hazard.turns_between)
	_fire()
	Events.hazard_countdown_changed.emit(current_hazard, turns_remaining)


## Queues the hazard's chain onto the live scenario engine.
func _fire() -> void:
	Events.hazard_triggered.emit(current_hazard)

	# The environment hitting the whole board should land harder than any one
	# ship's attack, so it gets the big shake.
	Events.camera_shake_large.emit(true)

	var engine: ScenarioEngine = ScenarioEngine.current()
	if engine == null or current_hazard.effect_chain == null:
		return

	var event: HazardEvent = HazardEvent.new()
	event.actor = Globals.player
	event.effect_source = Globals.player
	event.chain = current_hazard.effect_chain
	engine.queue_event(event)
