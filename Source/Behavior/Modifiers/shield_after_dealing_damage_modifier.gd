class_name ShieldAfterDealingDamageModifier
extends Modifier

## How many shields to grant per damage event.
var shield_amount: int = 1


func _init(amount: int = 1) -> void:
	priority = 90
	modifier_name = "Shield After Dealing Damage"
	shield_amount = amount


func on_after_event(event: EffectEvent, engine: ScenarioEngine) -> void:
	# Only trigger when the player successfully deals damage.
	if event is not DamageEvent:
		return
	if event.actor != Globals.player:
		return

	# Build a shield event targeting the player.
	var shield_event := ShieldEvent.new()
	shield_event.actor         = event.actor
	shield_event.effect_source = event.effect_source
	shield_event.targets       = [Globals.player]
	shield_event.amount        = shield_amount

	# Queue it — will be processed after all after-hooks for this event finish.
	engine.queue_event(shield_event)
