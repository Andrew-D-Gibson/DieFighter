class_name Utils
extends RefCounted

## Disconnects all the callables that have been attached to a particular signal
static func disconnect_all_callables(signal_to_disconnect: Signal) -> void:
	for connection in signal_to_disconnect.get_connections():
		signal_to_disconnect.disconnect(connection['callable'])


static func array_while_excluding(array: Array, elements_to_exclude: Array):
	var array_without_excluded_elements = array.filter(
		func(element) -> bool:
			return not elements_to_exclude.has(element)
	)
	return array_without_excluded_elements
