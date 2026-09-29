extends RefCounted
## Builders for effect data, so a test reads like the chain it describes.
##
## Category must be assigned before subtype: EffectData's category setter
## resets subtype to 0, so the other order silently authors the wrong effect.

const Cat := EffectEnums.Category


static func data(category: EffectEnums.Category, subtype: int, amount: int = 0) -> EffectData:
	var d := EffectData.new()
	d.category = category
	d.subtype = subtype
	d.amount = amount
	return d


static func set_amount(value: int) -> EffectData:
	return data(Cat.AMOUNT_MODIFIER, EffectEnums.AmountModifierSubtype.SET, value)


static func add_amount(value: int) -> EffectData:
	return data(Cat.AMOUNT_MODIFIER, EffectEnums.AmountModifierSubtype.ADD, value)


static func multiply(by: float) -> EffectData:
	var d := data(Cat.AMOUNT_MODIFIER, EffectEnums.AmountModifierSubtype.MULTIPLY)
	d.multiplier = by
	return d


static func die_value() -> EffectData:
	return data(Cat.AMOUNT_MODIFIER, EffectEnums.AmountModifierSubtype.SET_TO_DIE_VALUE)


static func damage() -> EffectData:
	return data(Cat.ATTRIBUTE_CHANGE, EffectEnums.AttributeChangeSubtype.DAMAGE)


static func shield() -> EffectData:
	return data(Cat.ATTRIBUTE_CHANGE, EffectEnums.AttributeChangeSubtype.SHIELD)


static func add_repetitions() -> EffectData:
	return data(Cat.REPETITION, EffectEnums.RepetitionSubtype.ADD_REPETITIONS)


static func conditional(
	subtype: EffectEnums.ConditionalSubtype,
	if_true: Array[EffectData] = [],
	if_false: Array[EffectData] = []
) -> ConditionalEffectData:
	var d := ConditionalEffectData.new()
	d.category = Cat.CONDITIONAL
	d.subtype = subtype
	d.if_true_effects = if_true
	d.if_false_effects = if_false
	return d


static func chain(effects: Array[EffectData], base_repetitions: int = 1) -> EffectChain:
	var c := EffectChain.new()
	c.effects = effects
	c.base_repetitions = base_repetitions
	return c
