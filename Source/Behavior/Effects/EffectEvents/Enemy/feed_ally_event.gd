class_name FeedAllyEvent
extends EffectEvent
## An enemy hands its die to an ally, who uses it straight away on its own
## intent table: whatever that ally's slot for the die's face says.
##
## The enemy-side cousin of a tile's Feed. The ally was picked when the
## feeding slot was rolled, so the player can read the whole chain before
## committing a die. EnemyTargetBinder never binds a Feed that could come
## back around; relay_visited is the backstop for anything that changes the
## die on the way (Scrambled flipping it as it lands).

## The ally the feeding slot was bound to.
var ally: Enemy

## Ships that already acted with this die in the chain, the actor included.
var relay_visited: Array[Node] = []

## How many Feeds carried the die to the actor.
var feed_depth: int = 0

const _RELAY_COLOR: Color = Color("#ef9a3a")


func resolve(engine: ScenarioEngine) -> void:
	if not is_instance_valid(activator_die):
		return

	if not can_feed(ally, relay_visited):
		await _return_to_player()
		return

	if is_instance_valid(actor) and actor is Node2D:
		var from: Node2D = actor as Node2D
		Juice.callout(from, "RELAY", _RELAY_COLOR)
		Juice.stream(from.get_parent(), activator_die.global_position, ally.global_position, _RELAY_COLOR, 6)

	ally.dice_manager.add(activator_die, true, false)
	engine.inject_event(build_ally_action(ally, activator_die, feed_depth + 1, relay_visited))


## Whether [param target] can take a die in this relay chain.
static func can_feed(target: Enemy, visited: Array[Node]) -> bool:
	if not is_instance_valid(target) or target.health.health <= 0:
		return false
	if target in visited:
		return false
	return target.turn_actions.size() == EnemyActionSelector.SLOT_COUNT


## The action [param target] takes with [param die] the moment it arrives.
## Read after the die has landed, so a face changed on arrival plays the slot
## it now shows.
static func build_ally_action(target: Enemy, die: Dice, depth: int, visited: Array[Node]) -> EnemyActionEvent:
	var event := EnemyActionEvent.new()
	event.enemy = target
	event.activator_die = die
	event.die_value = die.value
	event.action = target.turn_actions[clampi(die.value, 1, 6) - 1]
	event.feed_depth = depth
	event.relay_visited = visited.duplicate()
	return event


## Nobody to feed: the die goes home, rerolled, the way any hand-off with no
## one to take it does. A hologram is destroyed on the way.
func _return_to_player() -> void:
	if not is_instance_valid(Globals.player):
		return
	activator_die.draggable.state = Draggable.DragState.ENEMY_HOLDING
	await activator_die.reroll_with_tween()
	if is_instance_valid(activator_die):
		Globals.player.dice_manager.add(activator_die)
