class_name GlobalModifier
extends Resource

## Base class for all global effect modifiers
## Defines the interface and common properties for modifiers

@export var category: int
@export var type: int
@export var priority: int = 0
@export var temporary: bool = false
@export var name: String = "Unnamed Modifier"
@export var description: String = ""

## Optional condition for when this modifier should apply
var condition: Callable = func(_effect_variables: EffectVariables) -> bool: return true

## The actual modification function
var modifier_function: Callable


func _init(
	mod_category: int,
	mod_type: int,
	mod_priority: int = 0,
	mod_name: String = "Unnamed Modifier",
	mod_description: String = ""
) -> void:
	category = mod_category
	type = mod_type
	priority = mod_priority
	name = mod_name
	description = mod_description


## Check if this modifier should apply to the given effect variables
func should_apply(effect_variables: EffectVariables) -> bool:
	return condition.call(effect_variables)


## Apply this modifier to an amount
func apply_to_amount(amount: int, effect_variables: EffectVariables) -> int:
	if modifier_function.is_valid():
		return modifier_function.call(amount, effect_variables)
	return amount


## Set a custom condition for when this modifier applies
func set_condition(new_condition: Callable) -> GlobalModifier:
	condition = new_condition
	return self


## Set the modification function
func set_modifier_function(new_function: Callable) -> GlobalModifier:
	modifier_function = new_function
	return self
