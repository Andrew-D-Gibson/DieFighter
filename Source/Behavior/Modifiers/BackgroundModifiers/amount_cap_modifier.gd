class_name AmountCapModifier
extends Modifier
## Nothing may move a number by more than the cap, in either direction.
##
## Flattens the whole board rather than favouring a side: a big enemy hit is
## blunted exactly as much as a big attack of the player's. What it really
## punishes is the spike — one enormous effect — and what it rewards is
## volume, so a wide cheap build walks through a region that a glass cannon
## struggles in.
##
## The cap applies to magnitude, so costs (negative amounts) are limited too
## and a capped region never turns an expensive tile into a cheap one.

var cap: int = 3


func _init(amount_cap: int = 3) -> void:
	cap = maxi(1, amount_cap)
	modifier_name = "Amount Cap"
	priority = 75   # clamping; runs after additive and multiplicative changes
	is_temporary = false


func on_before_event(event: EffectEvent, _engine: ScenarioEngine) -> void:
	if not (event is DamageEvent or event is HealEvent
			or event is ShieldEvent or event is ChangeEngineChargeEvent):
		return

	event.amount = clampi(event.amount, -cap, cap)
