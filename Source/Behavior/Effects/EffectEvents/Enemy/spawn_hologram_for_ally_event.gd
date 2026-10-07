class_name SpawnHologramForAllyEvent
extends EffectEvent
## An enemy conjures a holographic die for an ally, who uses it straight away
## on its own intent table. The hologram's face is the action's rolled intent
## amount, so the intent tells the player exactly which of the ally's slots
## it will play. It's spent the first time it's handed anywhere.
##
## Chains the same way a Feed does; see FeedAllyEvent.

## The ally the slot was bound to.
var ally: Enemy

## Ships that already acted in this relay chain, the actor included.
var relay_visited: Array[Node] = []

var feed_depth: int = 0

const _HOLOGRAM_COLOR: Color = Color("#5fcde4")


## amount is the hologram's face value, not an output to boost.
func is_amplifiable() -> bool:
	return false


func resolve(engine: ScenarioEngine) -> void:
	if amount <= 0 or not is_instance_valid(Globals.player):
		return
	if not FeedAllyEvent.can_feed(ally, relay_visited):
		return

	var hologram: Dice = Globals.player.dice_scene.instantiate()
	hologram.holographic = true
	hologram.value = clampi(amount, 1, 6)
	hologram.global_position = _spawn_point()
	# Every die lives under the player node, including the ones enemies hold.
	Globals.player.add_child(hologram)
	hologram.draggable.state = Draggable.DragState.MOVING_WITH_CODE

	if is_instance_valid(actor) and actor is Node2D:
		var from: Node2D = actor as Node2D
		Juice.callout(from, "HOLO", _HOLOGRAM_COLOR)
		Juice.ring(from, hologram.global_position, _HOLOGRAM_COLOR, 14.0, 0.3, 4.0)

	ally.dice_manager.add(hologram, true, false)
	engine.inject_event(FeedAllyEvent.build_ally_action(ally, hologram, feed_depth + 1, relay_visited))


## Where a die hangs in front of a ship that's using it. The die that paid for
## the hologram may already be on its way home.
func _spawn_point() -> Vector2:
	if is_instance_valid(actor) and actor is Node2D:
		return (actor as Node2D).global_position + Vector2(0, 12)
	return Vector2.ZERO
