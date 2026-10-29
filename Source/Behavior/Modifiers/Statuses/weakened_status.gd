class_name WeakenedStatus
extends StatusModifier
## The ship's own hits deal a quarter less damage: an enemy's shots, or on the
## player every tile's. At the end of each of the ship's own turns it loses 1
## Weakened, so N Weakened is the ship's next N turns. The defensive mirror of
## Exposed, which grows the hits a ship takes rather than shrinking the ones
## it lands.
##
## The quarter comes off rounded up, like every fraction in the game, so even
## a 2-damage hit loses 1 (rounding to nearest would leave 2 and 6 almost
## untouched, and dice-sized hits are most of what gets thrown). A hit never
## drops below 1: a weakened shot is still a hit, so anything that listens
## for one (Exposed, a hull-hit tile) still hears it, and nothing reads as a
## hit for 0.
##
## Only damage the ship deals counts: Burn and hazards have no tile or ship
## behind them, and a tile's own cost to the player's hull isn't an attack.
##
## The stack decays on the ship's own turn end rather than the shared status
## tick, which comes before an enemy acts and after the player's turn has
## already gone: a tick there would spend a stack before the ship ever fired
## a weakened shot.
##
## Priority 60: a multiplier, after the flat additions (Amplifier, Exposed)
## and Double Damage, so the quarter comes off the whole hit.

## The share of each hit a weakened ship still deals, as a fraction.
const _KEPT_NUMERATOR: int = 3
const _KEPT_DENOMINATOR: int = 4

## The turn-end signal this status counts down on, kept so it can be let go
## of even after its host has been freed.
var _turn_end: Signal


func _init() -> void:
	status_id = &"weakened"
	display_name = "Weakened"
	color = Globals.purple
	icon = preload("res://Assets/Textures/Statuses/weakened.png")
	info_icon = preload("res://Assets/Textures/Statuses/weakened_info.png")
	priority = 60


## What a hit of [param amount] deals from a weakened ship. Also read by the
## AutoPilot, which prices a weakened ship's intents the way its badge says.
static func weakened(amount: int) -> int:
	if amount <= 1:
		return amount
	return maxi(1, amount * _KEPT_NUMERATOR / _KEPT_DENOMINATOR)


func on_before_event(event: EffectEvent, _engine: ScenarioEngine) -> void:
	if event is not DamageEvent or stacks <= 0 or event.amount <= 1:
		return
	if not _is_own_hit(event):
		return
	event.amount = weakened(event.amount)
	announce_triggered()


## A hit this ship lands: one of its own actions for an enemy, or for the
## player a tile's hit on another ship.
func _is_own_hit(event: EffectEvent) -> bool:
	if not is_on_player():
		return event.effect_source == affected_node
	if event.effect_source is not Tile:
		return false
	return event.targets.any(func(target: Node) -> bool: return target != affected_node)


func on_registered(engine: ScenarioEngine) -> void:
	super(engine)
	_turn_end = Events.player_turn_over if is_on_player() else Events.enemy_turn_over
	if not _turn_end.is_connected(_on_own_turn_end):
		_turn_end.connect(_on_own_turn_end)


func on_unregistered(engine: ScenarioEngine) -> void:
	if not _turn_end.is_null() and _turn_end.is_connected(_on_own_turn_end):
		_turn_end.disconnect(_on_own_turn_end)
	super(engine)


func _on_own_turn_end() -> void:
	consume(1)
