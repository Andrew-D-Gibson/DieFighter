class_name ShipRules
extends RefCounted
## How tile effects reach the flown ship's own rules without naming the ship.
##
## A ship's behavior scene (ShipResource.behavior_scene) can put nodes in two
## groups:
## - READINGS_GROUP: numbers its rules keep that a tile may read
##   (SET_TO_SHIP_READING). A member has
##   `has_ship_reading(key: StringName) -> bool` and
##   `ship_reading(key: StringName, context: EffectContext) -> int`.
##   The Outrigger's pods (OutriggerSync) answer `pod_lead` and `pod_level`.
## - MECHANISMS_GROUP: a moving part a tile may drive
##   (ADVANCE_SHIP_MECHANISM). A member has `advance_mechanism(steps: int)`,
##   awaited until the move has landed. The Carousel's ring (CarouselBehavior).
## On a ship with neither, readings are 0 and advancing does nothing, so a tile
## that leans on them is only worth having on its own ship (its
## ShipResource.signature_tiles).

const READINGS_GROUP: StringName = &"ship_readings"
const MECHANISMS_GROUP: StringName = &"ship_mechanisms"


## The flown ship's reading [param key] for the chain in [param context], or 0
## when nothing on this ship keeps one by that name.
static func reading(key: StringName, context: EffectContext) -> int:
	for node: Node in _members(READINGS_GROUP):
		if node.has_method(&"has_ship_reading") and node.has_ship_reading(key):
			return int(node.ship_reading(key, context))
	return 0


## The flown ship's mechanism, or null on a ship without one.
static func mechanism() -> Node:
	for node: Node in _members(MECHANISMS_GROUP):
		if node.has_method(&"advance_mechanism"):
			return node
	return null


static func _members(group: StringName) -> Array[Node]:
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if tree == null:
		return []
	var members: Array[Node] = []
	for node: Node in tree.get_nodes_in_group(group):
		if is_instance_valid(node) and not node.is_queued_for_deletion():
			members.append(node)
	return members
