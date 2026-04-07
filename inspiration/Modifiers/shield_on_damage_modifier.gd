## ShieldOnDamageModifier
## ============================================================
## Example Modifier: whenever the player deals damage, gain N shields.
##
## This is a classic "on_after_event" modifier — it reacts to a resolved
## event and enqueues a follow-up ShieldEvent.
##
## The ShieldEvent gets appended to the engine's queue and is processed
## in the next iteration of process_events(), *after* the current damage
## event's after-hooks finish. So the shield gain always happens after damage.
##
## PRIORITY: 90 (follow-up enqueuer range — runs after all value-adjustment
## modifiers so it sees the final resolved state)
## ============================================================

class_name ShieldOnDamageModifier
extends Modifier

## How many shields to grant per damage event.
var shield_amount: int = 1


func _init(amount: int = 1) -> void:
	priority = 90
	modifier_name = "Shield On Damage"
	shield_amount = amount


func on_after_event(event: EffectEvent, engine: ScenarioEngine) -> void:
	# Only trigger when the player successfully deals damage.
	if not event is DamageEvent:
		return
	if event.actor != Globals.player:
		return

	# Build a shield event targeting the player.
	var shield_event := ShieldEvent.new()
	shield_event.actor         = event.actor
	shield_event.effect_source = event.effect_source
	shield_event.targets       = [Globals.player]
	shield_event.amount        = shield_amount

	# Enqueue it — will be processed after all after-hooks for this event finish.
	engine.enqueue_event(shield_event)
