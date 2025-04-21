class_name Utils
extends RefCounted

## Disconnects all the callables that have been attached to a particular signal
static func disconnect_all_callables(signal_to_disconnect: Signal) -> void:
	for connection in signal_to_disconnect.get_connections():
		signal_to_disconnect.disconnect(connection['callable'])
