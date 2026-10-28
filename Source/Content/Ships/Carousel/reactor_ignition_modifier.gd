class_name ReactorIgnitionModifier
extends Modifier
## Aims the Reactor's Feed at whatever tile is passing the ignition slot.
##
## The Reactor sits in the hub, off the tile grid (its cell is a hole), so the
## usual TARGET_TILE_WITH_OFFSET can't find it a neighbour. Its chain ends in
## an ordinary PASS_DIE_TO_TILE; this rewrites that one event's targets to the
## ignition tile, or to nothing when the slot is empty, in which case Feed's
## own rule sends the die on to the target as a spent Engine Charger's would.
## Registered on every scenario's engine by the Carousel's behavior.

## The CarouselBehavior node that owns the ring.
var behavior: CarouselBehavior


func _init() -> void:
	# Before any other modifier reads the Feed's targets.
	priority = 5
	modifier_name = "Reactor Ignition"


func on_before_event(event: EffectEvent, _engine: ScenarioEngine) -> void:
	if event is not PassDieToTileEvent or not is_instance_valid(behavior):
		return
	if event.effect_source == null or event.effect_source != behavior.get_reactor():
		return
	var ignition: Tile = behavior.get_ignition_tile()
	var targets: Array[Node] = []
	if ignition:
		targets.append(ignition)
	event.targets = targets
	behavior.play_ignition(ignition)
