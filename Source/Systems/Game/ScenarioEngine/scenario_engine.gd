class_name ScenarioEngine
extends Node

signal event_resolved(event: EffectEvent)
signal began_processing_queue()
signal finished_processing_queue()

var _inject_index: int = 0

var currently_processing_queue: bool = false
var event_queue: Array[EffectEvent]

var modifiers: Array[Modifier]

	
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
	
	
func sort_modifiers() -> void:
	modifiers.sort_custom(func(a: Modifier, b: Modifier) -> bool:
		return a.priority < b.priority
	)
	
	
func clear_modifiers() -> void:
	modifiers.clear()
	
	
## Main Process Function
func process_event_queue() -> void:
	# Allow for multiple calls to happen without breaking
	if currently_processing_queue:
		return
		
	began_processing_queue.emit()
	currently_processing_queue = true
	
	while not event_queue.is_empty():
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
		
