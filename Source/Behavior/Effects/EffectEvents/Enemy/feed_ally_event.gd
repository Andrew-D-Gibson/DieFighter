class_name FeedAllyEvent
extends EffectEvent
## An enemy hands its die to an ally. The die joins the ally's hold like any
## other: the ally spends it on its own turn, on whatever its slot for the
## die's face says, and if its turn has already gone EnemyTurn comes back for
## it once every ship has had theirs.
##
## The enemy-side cousin of a tile's Feed. The ally was picked when the
## feeding slot was rolled, so the player can read the whole chain before
## committing a die. EnemyTargetBinder never binds a Feed that could come
## back around; relay_visited is the backstop for anything that changes the
## die on the way (Scrambled flipping it as it lands).
##
## It used to be spent the instant it landed, and between the relaying ship's
## own effect and the ally's going off in the same breath the player couldn't
## tell who did what. Now the hand-off is a beat of its own.

## Where a relayed die has been, carried with it into the ally's hold. See
## Enemy.receive_relayed_die().
class Trail extends RefCounted:
	## How many Feeds carried the die to the ship holding it.
	var depth: int = 0
	## Ships that already acted with the die, so it can't come back to them.
	var visited: Array[Node] = []

	func _init(feed_depth: int, ships: Array[Node]) -> void:
		depth = feed_depth
		visited = ships.duplicate()

## The ally the feeding slot was bound to.
var ally: Enemy

## Ships that already acted with this die in the chain, the actor included.
var relay_visited: Array[Node] = []

## How many Feeds carried the die to the actor.
var feed_depth: int = 0

const _RELAY_COLOR: Color = Color("#ef9a3a")

## How long the turn holds on a hand-off once the die has been sent, so the
## player watches it cross to the ally before anything else happens.
const HANDOFF_SECONDS: float = 0.9


func resolve(_engine: ScenarioEngine) -> void:
	if not is_instance_valid(activator_die):
		return

	if not can_feed(ally, relay_visited):
		_return_to_player()
		return

	if is_instance_valid(actor) and actor is Node2D:
		var from: Node2D = actor as Node2D
		Juice.callout(from, "RELAY", _RELAY_COLOR)
		Juice.stream(from.get_parent(), activator_die.global_position, ally.global_position, _RELAY_COLOR, 6)

	hand_over(ally, activator_die, Trail.new(feed_depth + 1, relay_visited), _RELAY_COLOR)
	await wait_for_handoff(ally)


## Puts [param die] in [param target]'s hold along with where it has been,
## and marks the catch on the ally so the player sees who has it now.
static func hand_over(target: Enemy, die: Dice, trail: Trail, color: Color) -> void:
	target.dice_manager.add(die, true, false)
	target.receive_relayed_die(die, trail)
	Juice.ring(target, target.global_position, color, 18.0, 0.4, 4.0)


## The beat a hand-off holds the turn for, cut short if the ally is gone.
static func wait_for_handoff(target: Enemy) -> void:
	if not is_instance_valid(target) or not target.is_inside_tree():
		return
	await target.get_tree().create_timer(HANDOFF_SECONDS / Globals.animation_speed).timeout
	if is_instance_valid(target):
		Juice.bump(target.graphics_manager.ship_graphics, 0.12, 0.25)


## Whether [param target] can take a die in this relay chain.
static func can_feed(target: Enemy, visited: Array[Node]) -> bool:
	if not is_instance_valid(target) or target.health.health <= 0:
		return false
	if target in visited:
		return false
	return target.turn_actions.size() == EnemyActionSelector.SLOT_COUNT


## Nobody to feed: the die goes home with its face unchanged. A hologram is destroyed on the way.
func _return_to_player() -> void:
	if not is_instance_valid(Globals.player):
		return
	Globals.player.dice_manager.add(activator_die)
