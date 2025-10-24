class_name ModifierFactory
extends RefCounted

## Factory class for creating common modifier types
## Provides convenient methods for creating standard modifiers

## Create an additive modifier (e.g., +2 shields)
static func create_additive_modifier(
	category: int,
	amount: int,
	name: String = "",
	description: String = "",
	condition: Callable = func(_effect_variables: EffectVariables) -> bool: return true
) -> GlobalModifier:
	var modifier = GlobalModifier.new(
		category,
		0,  # ADDITIVE
		0,
		name if name != "" else "Add " + str(amount),
		description if description != "" else "Adds " + str(amount) + " to effect"
	)
	
	modifier.set_condition(condition)
	modifier.set_modifier_function(func(base_amount: int, _effect_variables: EffectVariables) -> int:
		return base_amount + amount
	)
	
	return modifier


## Create a multiplicative modifier (e.g., x2 shields)
static func create_multiplicative_modifier(
	category: int,
	multiplier: float,
	name: String = "",
	description: String = "",
	condition: Callable = func(_effect_variables: EffectVariables) -> bool: return true
) -> GlobalModifier:
	var modifier = GlobalModifier.new(
		category,
		1,  # MULTIPLICATIVE
		0,
		name if name != "" else "Multiply by " + str(multiplier),
		description if description != "" else "Multiplies effect by " + str(multiplier)
	)
	
	modifier.set_condition(condition)
	modifier.set_modifier_function(func(base_amount: int, _effect_variables: EffectVariables) -> int:
		return int(base_amount * multiplier)
	)
	
	return modifier


## Create a dice value conditional modifier (e.g., if dice is 3-4, add repetition)
static func create_dice_value_conditional_modifier(
	category: int,
	amount: int,
	dice_values: Array[int],
	name: String = "",
	description: String = ""
) -> GlobalModifier:
	var modifier = GlobalModifier.new(
		category,
		2,  # CONDITIONAL
		0,
		name if name != "" else "Dice Value Bonus",
		description if description != "" else "Bonus when dice value is " + str(dice_values)
	)
	
	modifier.set_condition(func(effect_variables: EffectVariables) -> bool:
		if not effect_variables.activator_die:
			return false
		return effect_variables.activator_die.value in dice_values
	)
	
	modifier.set_modifier_function(func(base_amount: int, _effect_variables: EffectVariables) -> int:
		return base_amount + amount
	)
	
	return modifier


## Create a background-based modifier (e.g., nebula doubles shields)
static func create_background_modifier(
	category: int,
	multiplier: float,
	background_name: String,
	name: String = "",
	description: String = ""
) -> GlobalModifier:
	var modifier = GlobalModifier.new(
		category,
		1,  # MULTIPLICATIVE
		0,
		name if name != "" else background_name + " Effect",
		description if description != "" else "Effect from " + background_name + " background"
	)
	
	modifier.set_condition(func(effect_variables: EffectVariables) -> bool:
		# Check if current background matches
		if Globals.background_manager and Globals.background_manager.current_background_name == background_name:
			return true
		return false
	)
	
	modifier.set_modifier_function(func(base_amount: int, _effect_variables: EffectVariables) -> int:
		return int(base_amount * multiplier)
	)
	
	return modifier


## Create a tile-based modifier (e.g., upgrade tile adds repetition)
static func create_tile_modifier(
	category: int,
	amount: int,
	tile_name: String,
	modifier_type: int = 0,  # ADDITIVE
	name: String = "",
	description: String = ""
) -> GlobalModifier:
	var modifier = GlobalModifier.new(
		category,
		modifier_type,
		0,
		name if name != "" else tile_name + " Effect",
		description if description != "" else "Effect from " + tile_name + " tile"
	)
	
	modifier.set_condition(func(effect_variables: EffectVariables) -> bool:
		# Check if the effect source is the specific tile type
		if effect_variables.effect_source and effect_variables.effect_source.has_method("get_tile_name"):
			return effect_variables.effect_source.get_tile_name() == tile_name
		return false
	)
	
	if modifier_type == 0:  # ADDITIVE
		modifier.set_modifier_function(func(base_amount: int, _effect_variables: EffectVariables) -> int:
			return base_amount + amount
		)
	elif modifier_type == 1:  # MULTIPLICATIVE
		modifier.set_modifier_function(func(base_amount: int, _effect_variables: EffectVariables) -> int:
			return int(base_amount * amount)
		)
	
	return modifier


## Create a custom modifier with user-defined logic
static func create_custom_modifier(
	category: int,
	modifier_type: int,
	modifier_function: Callable,
	condition: Callable = func(_effect_variables: EffectVariables) -> bool: return true,
	name: String = "Custom Modifier",
	description: String = "User-defined modifier"
) -> GlobalModifier:
	var modifier = GlobalModifier.new(
		category,
		modifier_type,
		0,
		name,
		description
	)
	
	modifier.set_condition(condition)
	modifier.set_modifier_function(modifier_function)
	
	return modifier
