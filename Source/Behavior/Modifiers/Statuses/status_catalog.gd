class_name StatusCatalog
extends RefCounted
## Every status in the game, keyed by the id authored effects use.
##
## Effects name a status with a string (EffectData.string_param) so authoring
## one needs no new resource type. The cost is that a typo fails silently in
## the editor; create() reports it at runtime, and the content tests check
## every authored id against this table.

static var _statuses: Dictionary[StringName, GDScript] = {
	&"burn": BurnStatus,
	&"scrambled": ScrambledStatus,
	&"jammed": JammedStatus,
	&"exposed": ExposedStatus,
}


static func has(status_id: StringName) -> bool:
	return _statuses.has(status_id)


static func ids() -> Array[StringName]:
	var result: Array[StringName] = []
	result.assign(_statuses.keys())
	return result


## A fresh, unregistered status on host. Null (with an error) for an unknown id.
static func create(status_id: StringName, host: Node2D, stacks: int) -> StatusModifier:
	if not has(status_id):
		push_error("StatusCatalog: no status with id '%s'" % status_id)
		return null
	var status: StatusModifier = _statuses[status_id].new()
	status.affected_node = host
	status.stacks = stacks
	return status
