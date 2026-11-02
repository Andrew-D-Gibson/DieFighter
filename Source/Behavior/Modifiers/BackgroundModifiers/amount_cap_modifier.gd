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
##
## The rule's callout ("MAX {cap}") lives on its BackgroundModifierResource,
## whose 'cap' parameter sets [member cap].

## The largest amount any one effect may move. Never below 1, or the region
## would switch effects off rather than flatten them.
var cap: int = 3:
	set(value):
		cap = maxi(1, value)

## The region rule that put this in force (handed over by
## BackgroundModifierResource.create_modifier()). Its colour tints the
## uncapped number in a capped popup, so "12" reads as the Doldrums' doing.
var rule: BackgroundModifierResource = null


func _init(amount_cap: int = 3) -> void:
	cap = amount_cap
	modifier_name = "Amount Cap"
	priority = 75   # clamping; runs after additive and multiplicative changes


func on_before_event(event: EffectEvent, _engine: ScenarioEngine) -> void:
	if not (event is DamageEvent or event is HealEvent
			or event is ShieldEvent or event is ChangeEngineChargeEvent
			or event is SpendEngineChargeEvent):
		return

	var capped: int = clampi(event.amount, -cap, cap)
	if capped != event.amount:
		# Through the event, so its popup can still show what the cap took.
		event.cap_amount(capped, self)
		announce_triggered()


func get_trigger_color() -> Color:
	return rule.color if rule else super()
