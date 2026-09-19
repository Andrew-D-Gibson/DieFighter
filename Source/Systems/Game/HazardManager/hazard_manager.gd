class_name HazardManager
extends Node
## Runs the current scenario's environmental hazard, if it has one.
##
## Counts down in player turns and fires the hazard's chain through the
## scenario engine when it lands, so a flare's damage flows through the same
## modifier pipeline as everything else. The countdown is broadcast every turn
## because the whole design depends on the player seeing it coming.

## The hazard for the scenario currently loaded, or null for a quiet one.
var current_hazard: ScenarioHazardResource = null

## Player turns remaining before the hazard fires. Meaningless when
## current_hazard is null.
var turns_remaining: int = 0


func _ready() -> void:
	Globals.hazard_manager = self

	Events.load_scenario.connect(_arm_for_scenario)
	Events.player_turn_start.connect(_on_player_turn_start)


func has_hazard() -> bool:
	return current_hazard != null


## Picks up the new scenario's hazard and sets its first countdown.
func _arm_for_scenario(scenario: ScenarioResource) -> void:
	current_hazard = scenario.hazard if scenario else null

	if current_hazard == null:
		turns_remaining = 0
		Events.hazard_armed.emit(null, 0)
		return

	turns_remaining = maxi(1, current_hazard.turns_until_first)
	Events.hazard_armed.emit(current_hazard, turns_remaining)


func _on_player_turn_start() -> void:
	if current_hazard == null:
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

	var engine: ScenarioEngine = Globals.scenario_manager.engine
	if engine == null or current_hazard.effect_chain == null:
		return

	var event: HazardEvent = HazardEvent.new()
	event.actor = Globals.player
	event.effect_source = Globals.player
	event.chain = current_hazard.effect_chain
	engine.queue_event(event)
