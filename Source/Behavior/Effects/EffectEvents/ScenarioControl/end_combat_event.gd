class_name EndCombatEvent
extends EffectEvent
## Ends the fight in queue order, rather than at whatever stack depth the last
## enemy happened to die at.
##
## The kill is discovered deep inside DamageEvent.resolve() -> Health.death ->
## Enemy._on_death() -> enemy_left, and the state flip used to happen right
## there — mid-event, with the rest of the killing chain still queued behind
## it. Everything hanging off combat_finished (rewards, the sector advance,
## the checkpoint save, the engine refill) therefore ran before the chain that
## won the fight had finished paying for itself. A tile that strikes and then
## charges a price against the engine would bill that cost against the
## post-combat refill and strand the player below the jump gate.
##
## Queueing the transition puts it after the chain instead. It also gives
## modifiers an on_before_event hook, so "the fight doesn't end while X" is
## authorable rather than impossible.
##
## The event is deliberately thin: it owns the ordering, not the policy. What
## counts as "still in combat" stays on GameStateManager, next to the rest of
## the state machine.


func resolve(_engine: ScenarioEngine) -> void:
	if not Globals.state_manager:
		return

	Globals.state_manager.resolve_end_of_combat()
