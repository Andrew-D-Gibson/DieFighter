class_name BackgroundModifierManager
extends Node
## Keeps the current background's permanent rule registered on the live
## scenario engine.
##
## Backgrounds are picked from a random pool, so the player does not choose
## their rule directly — they read it off the banner on arrival and plan the
## fight around it. That only works if the rule is in force before the first
## die is placed, so registration happens on start_scenario, once the engine
## for the new scenario exists and before the player acts.
##
## Each scenario gets a fresh ScenarioEngine, so a rule normally dies with the
## engine it was registered on. The explicit removal below is for the case
## that outlives an engine: the background being swapped mid-scenario.

## The rule in force right now, or null in plain space.
var current_modifier_resource: BackgroundModifierResource = null

## The live Modifier built from it, so it can be pulled back off the engine if
## the background changes underneath us.
var _active_modifier: Modifier = null

## The engine the active modifier is registered on.
var _active_engine: ScenarioEngine = null


func _ready() -> void:
	Globals.background_modifier_manager = self

	Events.start_scenario.connect(_apply_current_background)
	Events.background_changed.connect(_on_background_changed)


## Swapping the background mid-scenario (dev console, scripted sequences)
## should swap the rule with it, or the banner starts lying. Before a scenario
## has an engine there is nothing to modify and nothing to announce —
## start_scenario applies the rule for real once there is.
func _on_background_changed(_background: BackgroundResource) -> void:
	if _get_engine() == null:
		return
	_apply_current_background()


func has_modifier() -> bool:
	return current_modifier_resource != null


## Reads whatever background is on screen and puts its rule on the engine.
func _apply_current_background() -> void:
	_remove_active_modifier()

	var background: BackgroundResource = null
	if is_instance_valid(Globals.background_manager):
		background = Globals.background_manager.current_background

	current_modifier_resource = background.global_modifier if background else null

	if current_modifier_resource == null:
		Events.background_modifier_applied.emit(null)
		return

	var engine: ScenarioEngine = _get_engine()
	if engine == null:
		# No engine yet means no scenario to modify. Announce nothing rather
		# than showing a banner for a rule that isn't actually in force.
		current_modifier_resource = null
		Events.background_modifier_applied.emit(null)
		return

	_active_modifier = current_modifier_resource.create_modifier()
	if _active_modifier == null:
		current_modifier_resource = null
		Events.background_modifier_applied.emit(null)
		return

	_active_engine = engine
	engine.add_modifier(_active_modifier)
	Events.background_modifier_applied.emit(current_modifier_resource)


func _remove_active_modifier() -> void:
	if _active_modifier != null and is_instance_valid(_active_engine):
		_active_engine.remove_modifier(_active_modifier)
	_active_modifier = null
	_active_engine = null


func _get_engine() -> ScenarioEngine:
	if not is_instance_valid(Globals.scenario_manager):
		return null
	var engine: ScenarioEngine = Globals.scenario_manager.engine
	return engine if is_instance_valid(engine) else null
