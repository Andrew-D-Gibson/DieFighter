class_name ExampleModifiers
extends RefCounted

## Example implementations of common modifier patterns
## These can be used as templates or directly instantiated

## Create a nebula background modifier that doubles all shielding effects
static func create_nebula_shield_modifier() -> GlobalModifier:
	return ModifierFactory.create_background_modifier(
		0,  # SHIELD
		2.0,
		"nebula",
		"Nebula Shield Boost",
		"Nebula background doubles all shield effects"
	)


## Create a dice value modifier that adds repetition for 3-4 values
static func create_dice_repetition_modifier() -> GlobalModifier:
	return ModifierFactory.create_dice_value_conditional_modifier(
		4,  # REPETITIONS
		1,
		[3, 4],
		"Dice Value Repetition",
		"Adds one repetition when dice value is 3 or 4"
	)


## Create a tile-based modifier for an upgrade tile
static func create_upgrade_tile_modifier() -> GlobalModifier:
	return ModifierFactory.create_tile_modifier(
		4,  # REPETITIONS
		1,
		"upgrade_tile",
		0,  # ADDITIVE
		"Upgrade Tile Bonus",
		"Upgrade tile adds one repetition to any activation"
	)


## Create a custom modifier that doubles damage when player has low health
static func create_desperation_damage_modifier() -> GlobalModifier:
	return ModifierFactory.create_custom_modifier(
		1,  # DAMAGE
		1,  # MULTIPLICATIVE
		func(base_amount: int, effect_variables: EffectVariables) -> int:
			return int(base_amount * 2.0),
		func(effect_variables: EffectVariables) -> bool:
			if not effect_variables.actor or not effect_variables.actor.has_method("get_health_percentage"):
				return false
			return effect_variables.actor.get_health_percentage() < 0.25,  # Less than 25% health
		"Desperation Damage",
		"Doubles damage when player health is below 25%"
	)


## Create a modifier that adds shield based on dice value
static func create_dice_value_shield_modifier() -> GlobalModifier:
	return ModifierFactory.create_dice_value_conditional_modifier(
		0,  # SHIELD
		2,
		[5, 6],
		"High Value Shield Bonus",
		"Adds 2 shields when dice value is 5 or 6"
	)


## Create a modifier that reduces damage when player has high shields
static func create_shield_protection_modifier() -> GlobalModifier:
	return ModifierFactory.create_custom_modifier(
		1,  # DAMAGE
		1,  # MULTIPLICATIVE
		func(base_amount: int, effect_variables: EffectVariables) -> int:
			# Reduce damage by 50% when shields are high
			return int(base_amount * 0.5),
		func(effect_variables: EffectVariables) -> bool:
			if not effect_variables.actor or not effect_variables.actor.has_method("get_shield_percentage"):
				return false
			return effect_variables.actor.get_shield_percentage() > 0.75,  # More than 75% shields
		"Shield Protection",
		"Reduces incoming damage by 50% when shields are above 75%"
	)
