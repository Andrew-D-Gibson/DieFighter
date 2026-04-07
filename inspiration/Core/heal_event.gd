## HealEvent
## ============================================================
## Restores HP to one or more targets.
##
## Created by HealHandler and enqueued into the ScenarioEngine.
## Modifiers can adjust 'amount' before resolution via on_before_event().
##
## Resolution: calls target.health.change_health(amount) on each target.
## ============================================================

class_name HealEvent
extends EffectEvent


func resolve(_engine: ScenarioEngine) -> void:
	if targets.is_empty():
		return

	for target: Node in targets:
		if not is_instance_valid(target):
			continue
		target.health.change_health(amount)
