class_name ScenarioEngine
extends Node

signal event_resolved(event: EffectEvent)
## A modifier canceled this event before it resolved.
signal event_canceled(event: EffectEvent)
signal began_processing_queue()
signal finished_processing_queue()
signal modifier_added(mod: Modifier)
signal modifier_removed(mod: Modifier)

## Ceiling on how many events one drain of the queue may resolve.
##
## A runaway chain — two tiles activating each other, a repetition that feeds
## itself — would spin the loop below forever and hard-freeze the game with no
## error anywhere. Nothing legitimate comes close to this number: a full
## three-enemy turn resolves a few hundred events, and a single tile activation
## a couple of dozen.
const _MAX_EVENTS_PER_RUN: int = 2000

var _inject_index: int = 0

var currently_processing_queue: bool = false
var event_queue: Array[EffectEvent]

var modifiers: Array[Modifier]

## Set by shutdown(). A drain suspended in an await checks this on resuming
## and bails, rather than carrying on inside an engine that is being freed.
var _shut_down: bool = false


## The engine for the scenario being played, or null between scenarios (after
## a jump has shut the old one down and before the next has loaded).
##
## The single way to reach the engine. Nodes used to hold their own pushed
## reference, which went stale on every jump and was never handed to a tile
## that arrived mid-scenario, so it silently did nothing.
static func current() -> ScenarioEngine:
	if not is_instance_valid(Globals.scenario_manager):
		return null
	var engine: ScenarioEngine = Globals.scenario_manager.engine
	if not is_instance_valid(engine) or engine.is_shut_down():
		return null
	return engine


func _ready() -> void:
	Events.player_turn_start.connect(clear_temporary_modifiers)

	
## Event functions
func queue_event(event: EffectEvent) -> void:
	event_queue.append(event)
	process_event_queue()
	
	
## Inserts an event to resolve right after the one currently resolving (and
## after anything else it has already injected). Outside a drain there is no
## "current" event, so this is just a queue.
func inject_event(event: EffectEvent) -> void:
	if not currently_processing_queue:
		queue_event(event)
		return
	event_queue.insert(_inject_index, event)
	_inject_index += 1


## Modifier functions	
func add_modifier(mod: Modifier) -> void:
	modifiers.append(mod)
	sort_modifiers()
	mod.on_registered(self)   # modifier spawns its visual here
	modifier_added.emit(mod)  # for any other listeners (HUD, tutorial, etc.)
	
	
func remove_modifier(mod: Modifier) -> void:
	modifiers.erase(mod)
	mod.on_unregistered(self)   # modifier frees its visual here
	modifier_removed.emit(mod)
	
	
func sort_modifiers() -> void:
	modifiers.sort_custom(func(a: Modifier, b: Modifier) -> bool:
		return a.priority < b.priority
	)
	

func clear_temporary_modifiers() -> void:
	var to_remove: Array[Modifier] = []
	for mod: Modifier in modifiers:
		if mod.is_temporary:
			to_remove.append(mod)
	for mod: Modifier in to_remove:
		remove_modifier(mod)
	
	
func clear_modifiers() -> void:
	# Iterate a copy: remove_modifier() erases from the live array.
	for mod: Modifier in modifiers.duplicate():
		remove_modifier(mod)


## Tears the engine down before it is freed.
##
## Freeing an engine mid-drain (a jump resolved from inside the queue) would
## otherwise strand everything waiting on finished_processing_queue, and leave
## modifier status visuals parented to tiles that outlive the scenario.
func shutdown() -> void:
	event_queue.clear()
	clear_modifiers()
	_inject_index = 0
	if currently_processing_queue:
		currently_processing_queue = false
		finished_processing_queue.emit()
	_shut_down = true


func is_shut_down() -> bool:
	return _shut_down
	
	
## Main Process Function
func process_event_queue() -> void:
	# Allow for multiple calls to happen without breaking
	if currently_processing_queue or _shut_down:
		return
		
	began_processing_queue.emit()
	currently_processing_queue = true

	var resolved_count: int = 0

	while not event_queue.is_empty():
		resolved_count += 1
		if resolved_count > _MAX_EVENTS_PER_RUN:
			push_error(
				"ScenarioEngine: aborted after %d events in a single queue drain. " % _MAX_EVENTS_PER_RUN +
				"This is almost certainly a chain feeding itself — check for tiles " +
				"that activate each other, or a repetition that re-adds repetitions. " +
				"Dropping %d queued events to keep the game responsive." % event_queue.size()
			)
			event_queue.clear()
			break

		_inject_index = 0
		
		var event: EffectEvent = event_queue.pop_front()
		
		# Handle any changes that need to happen BEFORE we 
		# process the event. Hooks run against a snapshot, because a hook
		# can await, and anything resolving meanwhile may add or remove
		# modifiers.
		for mod: Modifier in modifiers.duplicate():
			if event.canceled or _shut_down:
				break
			if mod not in modifiers:
				continue
			await mod.on_before_event(event, self)

		if _shut_down:
			return

		# Check for cancelation
		if event.canceled:
			event_canceled.emit(event)
			continue
			
		# Handle the event itself
		await event.resolve(self)
		if _shut_down:
			return
		
		# Handle any changes that need to happen AFTER we 
		# process the event
		for mod: Modifier in modifiers.duplicate():
			if _shut_down:
				return
			if mod not in modifiers:
				continue
			await mod.on_after_event(event, self)
			
		# Tell everyone we're done!
		event_resolved.emit(event)

	_inject_index = 0
	currently_processing_queue = false
	finished_processing_queue.emit()
		
