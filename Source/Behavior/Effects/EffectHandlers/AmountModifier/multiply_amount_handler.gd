class_name MultiplyAmountHandler
extends EffectHandler

## Slack for float error, so a product that is a whole number on paper
## (10 x 0.3) doesn't land a hair above it and round up a step too far.
const _WHOLE_EPSILON: float = 0.0001


func apply(data: EffectData, context: EffectContext, _engine: ScenarioEngine) -> void:
	context.running_amount = rounded_product(context.running_amount, data.multiplier)


## [param amount] x [param multiplier], with any fraction rounded up (away
## from zero). The game's rule is that "half of" always rounds up: half of 5
## is 3, and half of a 5-charge cost is still 3. Truncating would make an odd
## amount quietly worth less than the tile says.
static func rounded_product(amount: int, multiplier: float) -> int:
	var product: float = amount * multiplier
	var magnitude: int = ceili(absf(product) - _WHOLE_EPSILON)
	return magnitude if product >= 0.0 else -magnitude
