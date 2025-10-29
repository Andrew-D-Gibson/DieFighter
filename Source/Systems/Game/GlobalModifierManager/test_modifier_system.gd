class_name TestModifierSystem
extends RefCounted

## Test script to demonstrate the global modifier system
## This can be called from anywhere to test the modifier functionality

static func run_basic_test() -> void:
	print("=== Testing Global Modifier System ===")
	
	# Test 1: Add a nebula shield boost
	print("\n1. Adding nebula shield boost...")
	ModifierDemo.add_nebula_shield_boost()
	
	# Test 2: Add dice repetition modifier
	print("2. Adding dice repetition modifier...")
	ModifierDemo.add_dice_repetition_boost()
	
	# Test 3: Add desperation damage modifier
	print("3. Adding desperation damage modifier...")
	ModifierDemo.add_desperation_damage()
	
	# Test 4: Print all active modifiers
	print("4. Active modifiers:")
	ModifierDemo.print_active_modifiers()
	
	# Test 5: Remove shield modifiers
	print("\n5. Removing shield modifiers...")
	ModifierDemo.remove_shield_modifiers()
	
	# Test 6: Print remaining modifiers
	print("6. Remaining modifiers:")
	ModifierDemo.print_active_modifiers()
	
	print("\n=== Test Complete ===")


static func test_modifier_calculation() -> void:
	print("=== Testing Modifier Calculations ===")
	
	# Create a test effect variables object
	var test_variables = EffectVariables.new()
	test_variables.base_amount = 10
	test_variables.actor = null  # Would be player in real scenario
	test_variables.activator_die = null  # Would be dice in real scenario
	
	# Test shield calculation with modifiers
	print("Base shield amount: ", test_variables.base_amount)
	
	# Add a +2 shield modifier
	var shield_modifier = ModifierFactory.create_additive_modifier(
		0,  # SHIELD
		2,
		"Test Shield Boost",
		"Adds 2 shields for testing"
	)
	
	if Globals.modifier_manager:
		Globals.modifier_manager.add_modifier(shield_modifier)
		
		var final_shield = test_variables.calculate_final_amount_with_global_modifiers(0)  # SHIELD
		print("Final shield amount with +2 modifier: ", final_shield)
		
		# Add a x2 multiplier
		var multiplier_modifier = ModifierFactory.create_multiplicative_modifier(
			0,  # SHIELD
			2.0,
			"Test Shield Multiplier",
			"Doubles shield amount for testing"
		)
		
		Globals.modifier_manager.add_modifier(multiplier_modifier)
		
		var final_shield_with_multiplier = test_variables.calculate_final_amount_with_global_modifiers(0)  # SHIELD
		print("Final shield amount with +2 and x2 modifiers: ", final_shield_with_multiplier)
		
		# Clean up
		Globals.modifier_manager.remove_modifier(shield_modifier)
		Globals.modifier_manager.remove_modifier(multiplier_modifier)
	
	print("=== Calculation Test Complete ===")


static func test_conditional_modifiers() -> void:
	print("=== Testing Conditional Modifiers ===")
	
	# Create a test dice
	var test_dice = Dice.new()
	test_dice.value = 4  # Should trigger our conditional modifier
	
	# Create test effect variables
	var test_variables = EffectVariables.new()
	test_variables.base_amount = 1
	test_variables.activator_die = test_dice
	
	# Add dice value conditional modifier
	ModifierDemo.add_dice_repetition_boost()
	
	print("Base repetitions: ", test_variables.base_amount)
	
	if Globals.modifier_manager:
		var final_repetitions = test_variables.calculate_final_amount_with_global_modifiers(4)  # REPETITIONS
		print("Final repetitions with dice value 4: ", final_repetitions)
		
		# Test with different dice value
		test_dice.value = 6  # Should not trigger modifier
		var final_repetitions_no_trigger = test_variables.calculate_final_amount_with_global_modifiers(4)  # REPETITIONS
		print("Final repetitions with dice value 6: ", final_repetitions_no_trigger)
	
	print("=== Conditional Test Complete ===")

