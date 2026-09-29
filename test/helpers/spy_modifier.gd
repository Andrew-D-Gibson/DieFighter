extends Modifier
## Records its hook calls into a shared log as "<name>:before" / "<name>:after".
##
## Optional callables let a test decide what a hook does to the event:
## [member before] and [member after] receive (event, engine).

var record: Array
var before: Callable
var after: Callable


func _init(spy_name: String, spy_priority: int, shared_log: Array) -> void:
	modifier_name = spy_name
	priority = spy_priority
	record = shared_log


func on_before_event(event: EffectEvent, engine: ScenarioEngine) -> void:
	record.append(modifier_name + ":before")
	if before.is_valid():
		await before.call(event, engine)


func on_after_event(event: EffectEvent, engine: ScenarioEngine) -> void:
	record.append(modifier_name + ":after")
	if after.is_valid():
		await after.call(event, engine)
