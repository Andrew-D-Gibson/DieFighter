class_name EffectEvent
extends RefCounted


## The actor (player Node or Enemy Node) who triggered this effect.
## Used by modifiers to distinguish "player deals damage" from "enemy deals damage".
var actor: Node = null

## The tile or enemy ship that owns the effect chain being executed.
## Used for directional particle FX, range calculations, etc.
var effect_source: Node = null

## The Dice node that activated this effect (may be null for non-die effects).
var activator_die: Node = null  # Type: Dice

## Shortcut to the activator die's face value at the moment of activation.
## Stored here so modifiers can read it even after the die has moved/changed.
var die_value: int = 0

## The targets this event will affect. Set by targeting handlers,
## and can be overridden by modifiers in on_before_event().
var targets: Array[Node] = []

## The primary numeric amount for this event (damage dealt, shields gained,
## HP healed, etc.). Modifiers adjust this value in on_before_event().
var amount: int = 0

## Set to true by a modifier's on_before_event() to prevent resolution.
## Once canceled, no further before-hooks run, resolve() is skipped,
## and after-hooks are also skipped.
var canceled: bool = false

## What [member amount] was before a cap (the Doldrums' AmountCapModifier)
## cut it down, so the popup can show what the cap took ("12→3") instead of
## a 3 the player can't account for. Meaningless while [member capped_by] is
## null.
var capped_from: int = 0

## The modifier that cut [member amount] down, or null if none did. Its
## trigger colour tints the uncapped number.
var capped_by: Modifier = null


# ── Interface ──────────────────────────────────────────────────────────────────

## Whether [member amount] is an output a flat boost should grow (damage,
## shields, charge gained, uses added). Events whose amount is a price, a
## duration or a stored counter override this to false, so an Amplifier on a
## tile makes it hit harder without also making it cost more or corrupting its
## tile data.
func is_amplifiable() -> bool:
	return true


## Whether resolving this changes the face of any die already in play: a
## reroll, a Bump, a flip, a merge. Flash Freeze (DiceFreezeModifier) cancels
## every event that says so, so a new way to change a face only has to say so
## here to be frozen with the rest.
func changes_die_values() -> bool:
	return false


## Records that [param cap] is cutting [member amount] down to [param capped].
## Only the first cap is kept: the number worth showing is the one the effect
## would have landed with, not a halfway step between two caps.
func cap_amount(capped: int, cap: Modifier) -> void:
	if capped_by == null:
		capped_from = amount
		capped_by = cap
	amount = capped


## The uncapped number for a popup of [param shown] to lead with ("12→3"), or
## 0 for none: nothing capped it, or later modifiers left the shown number
## no smaller than the uncapped one.
func uncapped_for_popup(shown: int) -> int:
	if capped_by == null or capped_from <= shown or shown <= 0:
		return 0
	return capped_from


## A gain's popup lead ("+12" before "+3"), or "" when nothing capped it.
func uncapped_gain_text() -> String:
	var uncapped: int = uncapped_for_popup(amount)
	return "+%d" % uncapped if uncapped > 0 else ""


## Colour of the uncapped number in a popup: the capping rule's own.
func cap_color() -> Color:
	return capped_by.get_trigger_color() if capped_by else Color.WHITE


## Override this in each concrete event class.
## The engine calls this after all before-hooks have run (and not canceled).
## Use 'await' here for animations, tweens, or any async work.
func resolve(_engine: ScenarioEngine) -> void:
	pass  # Base class no-op. Subclasses must override.


## The player doing something hostile to [param target] short of a hit
## (jamming it, burning it, rerolling the dice it holds) provokes it the same
## way a hit does: the fight starts and the ship's scenario hears it was
## attacked. Without this, a shopkeeper could be Jammed into uselessness and
## never notice.
func provoke(target: Node) -> void:
	if actor is not Player or target is not Enemy or not is_instance_valid(target):
		return
	if Globals.state_manager:
		Globals.state_manager.state = GameStateManager.GameState.IN_COMBAT
	Events.player_attacked_ship.emit(target, (target as Enemy).scenario_state.faction)


## A hit on [param target] starts the fight only when a ship is on one end of
## it. The player hurting their own ship (Chaos Explosion, Ablative Charge,
## the redline bleed) or a hazard hitting them is a cost, not an attack: with
## nothing hostile on the board, that "fight" had no enemy turn to end it, and
## every tile whose die finds no target handed it straight back, forever.
func enter_combat_if_ship_hit(target: Node) -> void:
	if actor is not Enemy and target is not Enemy:
		return
	if is_instance_valid(Globals.state_manager):
		Globals.state_manager.state = GameStateManager.GameState.IN_COMBAT


## Tells the game the player just put [param stacks] of a status on
## [param target], for the tiles that answer it (Hex Coil). Only the player
## putting one on an enemy counts: a status a tile puts on its own ship
## (Blowtorch, Fume Vent) is a cost, not an attack.
func announce_status_applied(target: Node, status_id: StringName, stacks: int) -> void:
	if actor is not Player or target is not Enemy or stacks <= 0:
		return
	Events.status_applied_to_enemy.emit(target as Enemy, status_id, stacks)


## Most outputs gain a flat amount; multiplicative outputs override the unit.
func amplify(bonus: int) -> void:
	amount += bonus
