class_name ModifierDemo
extends RefCounted

## Demonstration script showing how to use the global modifier system
## This can be called from anywhere in the game to add/remove modifiers

## Add a nebula background modifier that doubles shields
static func add_nebula_shield_boost() -> void:
	if not Globals.modifier_manager:
		printerr("ModifierDemo: GlobalModifierManager not available")
		return
		
	var nebula_modifier = ExampleModifiers.create_nebula_shield_modifier()
	Globals.modifier_manager.add_modifier(nebula_modifier)
	print("Added nebula shield boost modifier")


## Add a dice value modifier for repetitions
static func add_dice_repetition_boost() -> void:
	if not Globals.modifier_manager:
		printerr("ModifierDemo: GlobalModifierManager not available")
		return
		
	var dice_modifier = ExampleModifiers.create_dice_repetition_modifier()
	Globals.modifier_manager.add_modifier(dice_modifier)
	print("Added dice repetition modifier")


## Add a custom modifier that doubles damage when health is low
static func add_desperation_damage() -> void:
	if not Globals.modifier_manager:
		printerr("ModifierDemo: GlobalModifierManager not available")
		return
		
	var desperation_modifier = ExampleModifiers.create_desperation_damage_modifier()
	Globals.modifier_manager.add_modifier(desperation_modifier)
	print("Added desperation damage modifier")


## Add a modifier that gives bonus shields for high dice values
static func add_high_value_shield_bonus() -> void:
	if not Globals.modifier_manager:
		printerr("ModifierDemo: GlobalModifierManager not available")
		return
		
	var shield_modifier = ExampleModifiers.create_dice_value_shield_modifier()
	Globals.modifier_manager.add_modifier(shield_modifier)
	print("Added high value shield bonus modifier")


## Remove all modifiers of a specific type
static func remove_shield_modifiers() -> void:
	if not Globals.modifier_manager:
		printerr("ModifierDemo: GlobalModifierManager not available")
		return
		
	Globals.modifier_manager.remove_modifiers_by_category(0)  # SHIELD
	print("Removed all shield modifiers")


## Clear all temporary modifiers
static func clear_temporary_modifiers() -> void:
	if not Globals.modifier_manager:
		printerr("ModifierDemo: GlobalModifierManager not available")
		return
		
	Globals.modifier_manager._clear_temporary_modifiers()
	print("Cleared all temporary modifiers")


## Print all active modifiers for debugging
static func print_active_modifiers() -> void:
	if not Globals.modifier_manager:
		printerr("ModifierDemo: GlobalModifierManager not available")
		return
		
	var active_modifiers = Globals.modifier_manager.get_active_modifiers()
	print("Active modifiers: ", active_modifiers.size())
	
	for modifier in active_modifiers:
		print("  - ", modifier.name, " (", modifier.category, ", ", modifier.type, ")")


## Create a custom modifier example
static func add_custom_modifier() -> void:
	if not Globals.modifier_manager:
		printerr("ModifierDemo: GlobalModifierManager not available")
		return
		
	# Create a custom modifier that triples damage when dice value is 6
	var custom_modifier = ModifierFactory.create_custom_modifier(
		1,  # DAMAGE
		1,  # MULTIPLICATIVE
		func(base_amount: int, _effect_variables: EffectVariables) -> int:
			return base_amount * 3,
		func(effect_variables: EffectVariables) -> bool:
			return effect_variables.activator_die and effect_variables.activator_die.value == 6,
		"Critical Six Damage",
		"Triples damage when dice value is 6"
	)
	
	Globals.modifier_manager.add_modifier(custom_modifier)
	print("Added custom critical six damage modifier")
