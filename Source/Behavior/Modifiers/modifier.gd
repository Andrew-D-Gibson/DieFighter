class_name Modifier
extends RefCounted

## Lower priority runs first
var priority: int = 50
##   Use these suggested ranges to keep ordering predictable:
##
##     0 –  9  : Cancellation / immunity effects (run first, can stop everything)
##    10 – 29  : Additive flat modifiers (+N damage, +N shields)
##    30 – 49  : Conditional additive modifiers (+N if die is odd, etc.)
##    50 – 69  : Multiplicative modifiers (×2 damage)
##    70 – 89  : Clamping / cap effects (cap damage at 10)
##    90 – 99  : Follow-up enqueuers (gain shield when dealing damage)
##               These run last so they see the final resolved amount.

## Human-readable name
var modifier_name: String = "Unnamed Modifier"

## The node this modifier visually and semantically affects (tile, enemy, dice, etc.)
## Set this in _init() of any modifier that targets a specific node.
var affected_node: Node2D = null

## Per-type visual scenes, keyed by GDScript class_name (e.g. &"Tile", &"Enemy", &"Dice").
## If the affected_node's class is not in this dict, status_visual_scene is used instead.
var status_visual_scenes: Dictionary = {}

## Default visual scene. Used when status_visual_scenes is empty or has no match.
## Leave null for modifiers with no visual.
var status_visual_scene: PackedScene = null

## If true, this modifier is swept out by ScenarioEngine.clear_temporary_modifiers()
## at the start of each player turn.
var is_temporary: bool = false

var _visual: Node2D = null  # tracks the live instance for cleanup


## Called before the event resolves.
## Use this to:
##   - Adjust event.amount  (e.g., event.amount += 2)
##   - Replace event.targets
##   - Cancel the event    (event.canceled = true)
##   - Enqueue a *replacement* event before this one resolves
##
## This is 'await'-safe: you can await animations here if needed,
## but most before-hooks will be instant math operations.
func on_before_event(_event: EffectEvent, _engine: ScenarioEngine) -> void:
	pass  # Override in subclass.


## Called after the event resolves (only called if the event was NOT canceled).
## Use this to:
##   - Enqueue follow-up events (e.g., "gain 1 shield when you deal damage")
##   - Track statistics / counters
##   - Apply status effects triggered by this event
##
## New events enqueued here are appended to the engine's queue and will be
## processed in order after the current event's after-hooks finish.
func on_after_event(_event: EffectEvent, _engine: ScenarioEngine) -> void:
	pass  # Override in subclass.
	
	
## Called by ScenarioEngine.add_modifier(). Override to add extra setup logic,
## but always call super.on_registered(engine) to ensure the visual spawns.
func on_registered(_engine: ScenarioEngine) -> void:
	_spawn_visual()


## Called by ScenarioEngine.remove_modifier(). Override for extra cleanup,
## but always call super.on_unregistered(engine) to ensure the visual is freed.
func on_unregistered(_engine: ScenarioEngine) -> void:
	if is_instance_valid(_visual):
		_visual.queue_free()
		_visual = null


func _spawn_visual() -> void:
	if not is_instance_valid(affected_node):
		return
	var scene: PackedScene = _get_visual_for_host(affected_node)
	if not scene:
		return
	_visual = scene.instantiate()
	# Optional: visual can implement configure(host) to adjust itself per host type
	if _visual.has_method("configure"):
		_visual.configure(affected_node)
	affected_node.add_child(_visual)


func _get_visual_for_host(host: Node2D) -> PackedScene:
	if host.get_script() != null:
		var key: StringName = host.get_script().get_global_name()
		if not key.is_empty() and status_visual_scenes.has(key):
			return status_visual_scenes[key]
	return status_visual_scene  # null is fine — no visual spawns
