class_name ScenarioEngine
extends Node

signal event_resolved(event: EffectEvent)
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


func _ready() -> void:
	Events.player_turn_start.connect(clear_temporary_modifiers)

	
## Event functions
func queue_event(event: EffectEvent) -> void:
	event_queue.append(event)
	process_event_queue()
	
	
func inject_event(event: EffectEvent) -> void:
	event_queue.insert(_inject_index, event)
	_inject_index += 1

	
func clear_events() -> void:
	event_queue.clear()
	

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
	for mod: Modifier in modifiers:
		remove_modifier(mod)
	
	
## Main Process Function
func process_event_queue() -> void:
	# Allow for multiple calls to happen without breaking
	if currently_processing_queue:
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
		# process the event
		for mod: Modifier in modifiers:
			await mod.on_before_event(event, self)
			
		# Check for cancelation
		if event.canceled:
			continue
			
		# Handle the event itself
		await event.resolve(self)
		
		# Handle any changes that need to happen AFTER we 
		# process the event
		for mod: Modifier in modifiers:
			await mod.on_after_event(event, self)
			
		# Tell everyone we're done!
		event_resolved.emit(event)
			
	currently_processing_queue = false
	finished_processing_queue.emit()
		
