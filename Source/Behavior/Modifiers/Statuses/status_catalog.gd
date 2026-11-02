class_name StatusCatalog
extends RefCounted
## Every status in the game, keyed by the id authored effects use.
##
## A status is a StatusResource among the keywords (Keywords loads them); its
## file name is its id and it names the script that runs it, so adding a
## status never touches this file.
##
## Effects name a status with a string (EffectData.string_param) so authoring
## one needs no new resource type. The cost is that a typo fails silently in
## the editor; create() reports it at runtime, and the content tests check
## every authored id against this catalog.


static func has(status_id: StringName) -> bool:
	return find(status_id) != null


## Every status id, sorted.
static func ids() -> Array[StringName]:
	var result: Array[StringName] = []
	for id: String in Keywords.ids():
		if Keywords.keyword(id) is StatusResource:
			result.append(StringName(id))
	return result


## The file describing [param status_id], or null for an unknown id.
static func find(status_id: StringName) -> StatusResource:
	return Keywords.keyword(String(status_id)) as StatusResource


## A fresh, unregistered status on host. Null (with an error) for an unknown id.
static func create(status_id: StringName, host: Node2D, stacks: int) -> StatusModifier:
	var definition: StatusResource = find(status_id)
	if definition == null:
		push_error("StatusCatalog: no status with id '%s'" % status_id)
		return null
	var status: StatusModifier = definition.create_modifier()
	if status == null:
		return null
	status.affected_node = host
	status.stacks = stacks
	return status
