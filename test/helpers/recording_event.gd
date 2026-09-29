extends EffectEvent
## An EffectEvent that records its label into a log shared with the test.
##
## [member on_resolve] runs during resolution with the engine, so a test can
## inject or queue follow-up events from inside a drain.

var label: String
var record: Array
var on_resolve: Callable


func _init(event_label: String = "", shared_log: Array = []) -> void:
	label = event_label
	record = shared_log


func resolve(engine: ScenarioEngine) -> void:
	record.append(label)
	if on_resolve.is_valid():
		await on_resolve.call(engine)
