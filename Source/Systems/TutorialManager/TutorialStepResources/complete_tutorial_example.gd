# Example script showing how to create a complete tutorial sequence
# This can be attached to a node or called from another script

extends Node

func create_basic_tutorial() -> Array[TutorialStep]:
	var steps: Array[TutorialStep] = []
	
	# Step 1: Welcome and dice explanation
	var step1 = TutorialStep.new()
	step1.description = "Welcome to Stella Roller! These are your dice. Each die has a value from 1 to 6."
	step1.text_position = Vector2(100, 200)
	step1.wait_for_action = "player_turn_start"
	step1.highlight_elements = ["dice_queue"]
	steps.append(step1)
	
	# Step 2: Explain tile placement
	var step2 = TutorialStep.new()
	step2.description = "Drag a die from your queue to a tile to activate it. Try placing a die on the damage tile!"
	step2.text_position = Vector2(300, 200)
	step2.wait_for_action = "die_placed_on_tile"
	step2.highlight_elements = ["dice_queue"]
	steps.append(step2)
	
	# Step 3: Explain tile activation
	var step3 = TutorialStep.new()
	step3.description = "Great! The tile activated and used your die's value. Different tiles have different effects."
	step3.text_position = Vector2(300, 150)
	step3.wait_for_action = "tile_activation_complete"
	steps.append(step3)
	
	# Step 4: Explain end turn
	var step4 = TutorialStep.new()
	step4.description = "When you're out of dice, click the End Turn button to let the enemies take their turn."
	step4.text_position = Vector2(200, 100)
	step4.wait_for_action = "player_turn_over"
	step4.highlight_elements = ["end_turn_button"]
	step4.skip_if_condition = "player_has_dice"  # Skip if player still has dice
	steps.append(step4)
	
	# Step 5: Explain enemy turns
	var step5 = TutorialStep.new()
	step5.description = "Now the enemies will take their turn. They'll use dice to attack you or use special abilities."
	step5.text_position = Vector2(400, 200)
	step5.wait_for_action = "enemy_turn_over"
	step5.disable_interactions = ["dice_dragging"]
	steps.append(step5)
	
	# Step 6: Tutorial complete
	var step6 = TutorialStep.new()
	step6.description = "That's the basics! You now know how to play. Good luck, pilot!"
	step6.text_position = Vector2(300, 250)
	step6.wait_for_action = ""  # No trigger - this is the final step
	steps.append(step6)
	
	return steps

func create_advanced_tutorial() -> Array[TutorialStep]:
	var steps: Array[TutorialStep] = []
	
	# Advanced tutorial with forced dice for specific scenarios
	var step1 = TutorialStep.new()
	step1.description = "This tile requires exactly a 5 to activate. You have a 5 in your queue!"
	step1.text_position = Vector2(250, 200)
	step1.forced_dice = [5, 3, 1]  # Force specific dice values
	step1.wait_for_action = "die_placed_on_tile"
	step1.highlight_elements = ["dice_queue"]
	steps.append(step1)
	
	var step2 = TutorialStep.new()
	step2.description = "Perfect! The tile activated with your 5. Some tiles have specific requirements."
	step2.text_position = Vector2(250, 150)
	step2.wait_for_action = "tile_activation_complete"
	steps.append(step2)
	
	return steps

# Function to set up tutorial in the game
func setup_tutorial_in_game() -> void:
	if not Globals.tutorial_manager:
		push_error("TutorialManager not found in Globals!")
		return
	
	# Clear existing steps
	Globals.tutorial_manager.tutorial_steps.clear()
	
	# Add tutorial steps
	var tutorial_steps = create_basic_tutorial()
	for step in tutorial_steps:
		Globals.tutorial_manager.add_tutorial_step(step)
	
	# Start the tutorial
	Globals.tutorial_manager.start_tutorial()

# Function to create a tutorial that only shows for new players
func setup_conditional_tutorial() -> void:
	if not Globals.tutorial_manager:
		return
	
	# Check if this is a new player (you might check save data, etc.)
	var is_new_player = true  # Replace with actual new player check
	
	if is_new_player:
		setup_tutorial_in_game()
	else:
		# Skip tutorial for returning players
		Globals.tutorial_manager.skip_tutorial()

