# Tutorial System Documentation

## Overview

The tutorial system provides a flexible way to create step-by-step tutorials that guide players through the game. It tracks a list of `TutorialStep` resources and progresses through them based on specific trigger events.

## Components

### TutorialStep Resource

Each tutorial step is a `TutorialStep` resource with the following properties:

- **description**: The text to display to the player
- **text_position**: Where to position the tutorial popup
- **wait_for_action**: The event that triggers the next step
- **forced_dice**: Optional array of dice values to force for this step
- **forced_enemy_actions**: Optional array of enemy actions to force
- **skip_if_condition**: Optional condition to skip this step
- **highlight_elements**: Optional array of UI elements to highlight
- **disable_interactions**: Optional array of interactions to disable

### TutorialManager

The `TutorialManager` handles the tutorial flow:

- Tracks current step progress
- Listens for game events to trigger step progression
- Manages tutorial popup display
- Provides API for external systems to interact with tutorials

### TutorialTextPopup

A UI component that displays tutorial text with fade-in/out animations and optional auto-close functionality.

## Available Trigger Events

The tutorial system responds to these game events:

### Game Flow Events
- `player_turn_start` - Player's turn begins
- `player_turn_over` - Player ends their turn
- `enemy_turn_over` - Enemy turn ends
- `start_combat` - Combat begins
- `combat_finished` - Combat ends

### Dice Events
- `die_added` - A die is added to the player's queue
- `die_placed_on_tile` - A die is placed on a tile
- `enemy_received_die` - An enemy receives a die
- `enemy_used_die` - An enemy uses a die

### Tile Events
- `tile_activation_complete` - A tile finishes activating

### Other Events
- `enemy_acted` - An enemy performs an action
- `scenario_event` - A scenario event occurs
- `reward_picked` - Player picks up a reward
- `shop_opened` - Shop interface opens
- `shop_closed` - Shop interface closes

## Skip Conditions

Steps can be automatically skipped based on game state:

- `player_has_dice` - Skip if player has dice in queue
- `enemy_has_die` - Skip if any enemy has dice
- `player_health_low` - Skip if player health is 2 or less
- `combat_active` - Skip if currently in combat

## Usage Examples

### Basic Tutorial Step

```gdscript
# Create a tutorial step that waits for player to place a die
var step = TutorialStep.new()
step.description = "Drag a die from your queue to a tile to activate it!"
step.text_position = Vector2(200, 300)
step.wait_for_action = "die_placed_on_tile"
step.highlight_elements = ["dice_queue"]
```

### Forced Dice Tutorial

```gdscript
# Force specific dice values for tutorial consistency
var step = TutorialStep.new()
step.description = "This tile requires a 6 to activate. You have a 6!"
step.text_position = Vector2(150, 250)
step.forced_dice = [6, 4, 2]  # First die will be 6, then 4, then 2
step.wait_for_action = "tile_activation_complete"
```

### Conditional Skip

```gdscript
# Skip this step if player already knows how to play
var step = TutorialStep.new()
step.description = "Click the End Turn button when you're done"
step.text_position = Vector2(200, 100)
step.wait_for_action = "player_turn_over"
step.skip_if_condition = "player_has_dice"  # Skip if player still has dice
```

### Disable Interactions

```gdscript
# Prevent player from doing other actions during this step
var step = TutorialStep.new()
step.description = "Watch the enemy take their turn"
step.text_position = Vector2(300, 200)
step.wait_for_action = "enemy_turn_over"
step.disable_interactions = ["dice_dragging", "tile_clicking"]
```

## Integration with Game

### Setting Up Tutorials

1. Create `TutorialStep` resources for each step
2. Add them to the `TutorialManager`'s `tutorial_steps` array
3. Set `auto_start = true` to begin automatically, or call `start_tutorial()` manually

### Tutorial Manager API

```gdscript
# Start/stop tutorials
Globals.tutorial_manager.start_tutorial()
Globals.tutorial_manager.stop_tutorial()
Globals.tutorial_manager.skip_tutorial()

# Pause/resume
Globals.tutorial_manager.pause_tutorial()
Globals.tutorial_manager.resume_tutorial()

# Check status
var is_active = Globals.tutorial_manager.is_tutorial_active()
var progress = Globals.tutorial_manager.get_tutorial_progress()  # 0.0 to 1.0
var current_step = Globals.tutorial_manager.get_current_step()

# Modify steps at runtime
Globals.tutorial_manager.add_tutorial_step(new_step)
Globals.tutorial_manager.insert_tutorial_step(step, index)
Globals.tutorial_manager.remove_tutorial_step(index)
```

### Event Integration

The tutorial system automatically listens to game events. To add new trigger types:

1. Add the event to `events.gd`
2. Connect it in `TutorialManager._connect_game_events()`
3. Add a handler method that calls `_check_trigger("event_name")`

## Best Practices

1. **Keep steps focused**: Each step should teach one concept
2. **Use forced dice sparingly**: Only when necessary for tutorial flow
3. **Provide clear feedback**: Use highlighting and positioning to guide attention
4. **Allow skipping**: Always provide a way to skip tutorials
5. **Test thoroughly**: Ensure tutorials work in different game states
6. **Use skip conditions**: Avoid redundant steps for experienced players

## Advanced Features

### Custom Validation

Steps can use custom validation functions by setting the `custom_validation` property and implementing the validation logic in the `TutorialStep._call_custom_validation()` method.

### Dynamic Step Creation

Tutorials can be created dynamically at runtime based on game state, player progress, or other conditions.

### Multiple Tutorial Sequences

Different scenarios or game modes can have their own tutorial sequences by creating separate `TutorialManager` instances or managing different step arrays.
