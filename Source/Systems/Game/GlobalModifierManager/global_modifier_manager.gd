class_name GlobalModifierManager
extends Node

## Global modifier system for applying persistent effects across the game
## Handles additive, multiplicative, and conditional modifiers with priority ordering

enum ModifierType {
	ADDITIVE,      # +2 shields, +1 damage, etc. (Priority 1)
	MULTIPLICATIVE, # x2 shields, x1.5 damage, etc. (Priority 2) 
	CONDITIONAL    # "if dice value is 3-4, add repetition" (Priority 3)
}

enum EffectCategory {
	SHIELD,
	DAMAGE, 
	HEAL,
	DICE_VALUE,
	REPETITIONS,
	ENGINE_CHARGE,
	CUSTOM
}

## All active modifiers organized by category and type
var modifiers: Dictionary = {}

## Events for modifier changes
signal modifier_added(modifier: GlobalModifier)
signal modifier_removed(modifier: GlobalModifier)
signal modifiers_cleared()

func _ready() -> void:
	Globals.modifier_manager = self
	_initialize_modifier_dictionary()
	
	# Connect to game events for cleanup
	Events.start_scenario.connect(_clear_temporary_modifiers)
	Events.game_over.connect(_clear_all_modifiers)


func _initialize_modifier_dictionary() -> void:
	# Initialize the nested dictionary structure
	for category in EffectCategory.values():
		modifiers[category] = {}
		for type in ModifierType.values():
			modifiers[category][type] = []


## Add a modifier to the global system
func add_modifier(modifier: GlobalModifier) -> void:
	if not modifier:
		printerr("GlobalModifierManager: Cannot add null modifier")
		return
		
	modifiers[modifier.category][modifier.type].append(modifier)
	modifier_added.emit(modifier)
	
	# Sort modifiers by priority within their type
	_sort_modifiers_by_priority(modifier.category, modifier.type)


## Remove a specific modifier
func remove_modifier(modifier: GlobalModifier) -> void:
	if not modifier:
		return
		
	var modifier_array = modifiers[modifier.category][modifier.type]
	if modifier in modifier_array:
		modifier_array.erase(modifier)
		modifier_removed.emit(modifier)


## Remove all modifiers of a specific type and category
func remove_modifiers_by_type(category: int, type: int) -> void:
	var removed_modifiers = modifiers[category][type].duplicate()
	modifiers[category][type].clear()
	
	for modifier in removed_modifiers:
		modifier_removed.emit(modifier)


## Remove all modifiers for a specific category
func remove_modifiers_by_category(category: int) -> void:
	for type in ModifierType.values():
		remove_modifiers_by_type(category, type)


## Clear all temporary modifiers (called on scenario start)
func _clear_temporary_modifiers() -> void:
	for category in EffectCategory.values():
		for type in ModifierType.values():
			var temp_modifiers = modifiers[category][type].filter(func(m): return m.temporary)
			for modifier in temp_modifiers:
				remove_modifier(modifier)


## Clear all modifiers (called on game over)
func _clear_all_modifiers() -> void:
	for category in EffectCategory.values():
		for type in ModifierType.values():
			modifiers[category][type].clear()
	modifiers_cleared.emit()


## Apply all relevant modifiers to an effect calculation
func apply_modifiers_to_amount(category: int, base_amount: int, effect_variables: EffectVariables) -> int:
	var final_amount = base_amount
	
	# Apply additive modifiers first (Priority 1)
	for modifier in modifiers[category][0]:  # ADDITIVE
		if modifier.should_apply(effect_variables):
			final_amount = modifier.apply_to_amount(final_amount, effect_variables)
	
	# Apply multiplicative modifiers second (Priority 2)
	for modifier in modifiers[category][1]:  # MULTIPLICATIVE
		if modifier.should_apply(effect_variables):
			final_amount = modifier.apply_to_amount(final_amount, effect_variables)
	
	# Apply conditional modifiers last (Priority 3)
	for modifier in modifiers[category][2]:  # CONDITIONAL
		if modifier.should_apply(effect_variables):
			final_amount = modifier.apply_to_amount(final_amount, effect_variables)
	
	return final_amount


## Apply modifiers to repetitions
func apply_modifiers_to_repetitions(base_repetitions: int, effect_variables: EffectVariables) -> int:
	return apply_modifiers_to_amount(4, base_repetitions, effect_variables)  # REPETITIONS


## Apply modifiers to dice values
func apply_modifiers_to_dice_value(base_value: int, effect_variables: EffectVariables) -> int:
	return apply_modifiers_to_amount(3, base_value, effect_variables)  # DICE_VALUE


## Get all active modifiers for debugging/inspection
func get_active_modifiers() -> Array[GlobalModifier]:
	var all_modifiers: Array[GlobalModifier] = []
	
	for category in EffectCategory.values():
		for type in ModifierType.values():
			all_modifiers.append_array(modifiers[category][type])
	
	return all_modifiers


## Get modifiers for a specific category and type
func get_modifiers(category: int, type: int) -> Array[GlobalModifier]:
	return modifiers[category][type].duplicate()


func _sort_modifiers_by_priority(category: int, type: int) -> void:
	modifiers[category][type].sort_custom(func(a, b): return a.priority < b.priority)
