# Global Modifier System

A comprehensive system for applying global effect modifiers across your Godot 4 game. This system allows you to create persistent effects that modify damage, shields, healing, dice values, repetitions, and more.

## Features

- **Priority-based application**: Additive modifiers (Priority 1) → Multiplicative modifiers (Priority 2) → Conditional modifiers (Priority 3)
- **Easy integration**: Works seamlessly with existing `EffectVariables` system
- **Flexible conditions**: Support for dice values, background types, tile types, and custom conditions
- **Clean management**: Add, remove, and query modifiers with simple API calls
- **Temporary modifiers**: Support for modifiers that expire on scenario start

## Architecture

### Core Components

1. **GlobalModifierManager**: Central singleton that manages all modifiers
2. **GlobalModifier**: Base class for all modifier types
3. **ModifierFactory**: Utility class for creating common modifier patterns
4. **ExampleModifiers**: Pre-built modifier examples for common scenarios

### Modifier Types

- **ADDITIVE (0)**: +2 shields, +1 damage, etc.
- **MULTIPLICATIVE (1)**: x2 shields, x1.5 damage, etc.
- **CONDITIONAL (2)**: "if dice value is 3-4, add repetition"

### Effect Categories

- **SHIELD (0)**: Shield effects
- **DAMAGE (1)**: Damage effects
- **HEAL (2)**: Healing effects
- **DICE_VALUE (3)**: Dice value modifications
- **REPETITIONS (4)**: Repetition modifications
- **ENGINE_CHARGE (5)**: Engine charge modifications
- **CUSTOM (6)**: Custom effect categories

## Usage Examples

### Basic Modifier Creation

```gdscript
# Add a +2 shield modifier
var shield_modifier = ModifierFactory.create_additive_modifier(
    0,  # SHIELD category
    2,  # +2 shields
    "Shield Boost",
    "Adds 2 shields to all shield effects"
)
Globals.modifier_manager.add_modifier(shield_modifier)

# Add a x2 damage multiplier
var damage_multiplier = ModifierFactory.create_multiplicative_modifier(
    1,  # DAMAGE category
    2.0,  # x2 damage
    "Damage Amplifier",
    "Doubles all damage"
)
Globals.modifier_manager.add_modifier(damage_multiplier)
```

### Conditional Modifiers

```gdscript
# Add repetition when dice value is 3 or 4
var dice_modifier = ModifierFactory.create_dice_value_conditional_modifier(
    4,  # REPETITIONS category
    1,  # +1 repetition
    [3, 4],  # When dice value is 3 or 4
    "Dice Value Bonus",
    "Adds repetition for dice values 3-4"
)
Globals.modifier_manager.add_modifier(dice_modifier)
```

### Background-Based Modifiers

```gdscript
# Double shields when in nebula background
var nebula_modifier = ModifierFactory.create_background_modifier(
    0,  # SHIELD category
    2.0,  # x2 shields
    "nebula",  # Background name
    "Nebula Shield Boost",
    "Nebula background doubles shields"
)
Globals.modifier_manager.add_modifier(nebula_modifier)
```

### Custom Modifiers

```gdscript
# Triple damage when dice value is 6
var custom_modifier = ModifierFactory.create_custom_modifier(
    1,  # DAMAGE category
    1,  # MULTIPLICATIVE type
    func(base_amount: int, _effect_variables: EffectVariables) -> int:
        return base_amount * 3,
    func(effect_variables: EffectVariables) -> bool:
        return effect_variables.activator_die and effect_variables.activator_die.value == 6,
    "Critical Six Damage",
    "Triples damage when dice value is 6"
)
Globals.modifier_manager.add_modifier(custom_modifier)
```

## Integration with Existing Effects

The system automatically integrates with existing effect classes. Simply use the new calculation method:

```gdscript
# In your effect classes, replace:
var final_amount = effect_variables.calculate_final_amount()

# With:
var final_amount = effect_variables.calculate_final_amount_with_global_modifiers(category)
```

Where `category` is the appropriate effect category (0 for SHIELD, 1 for DAMAGE, etc.).

## Management Functions

```gdscript
# Remove specific modifier
Globals.modifier_manager.remove_modifier(modifier)

# Remove all modifiers of a category
Globals.modifier_manager.remove_modifiers_by_category(0)  # SHIELD

# Clear all temporary modifiers
Globals.modifier_manager._clear_temporary_modifiers()

# Get all active modifiers
var active_modifiers = Globals.modifier_manager.get_active_modifiers()
```

## Testing

Use the provided test functions to verify the system works correctly:

```gdscript
# Run basic functionality test
TestModifierSystem.run_basic_test()

# Test modifier calculations
TestModifierSystem.test_modifier_calculation()

# Test conditional modifiers
TestModifierSystem.test_conditional_modifiers()
```

## Example Scenarios

### Scenario 1: Nebula Background
- Background: Nebula
- Effect: All shield effects are doubled
- Implementation: Background-based multiplicative modifier

### Scenario 2: Upgrade Tile
- Tile: Upgrade tile on the grid
- Effect: Any tile activation with dice value 3-4 gets +1 repetition
- Implementation: Tile-based conditional modifier

### Scenario 3: Desperation Mode
- Condition: Player health below 25%
- Effect: All damage is doubled
- Implementation: Custom conditional modifier

## Best Practices

1. **Use descriptive names**: Make modifier names clear and descriptive
2. **Set appropriate priorities**: Higher priority modifiers are applied first
3. **Clean up temporary modifiers**: Use temporary flag for modifiers that should expire
4. **Test thoroughly**: Use the test functions to verify modifier behavior
5. **Document custom conditions**: Add clear descriptions for complex conditional logic

## Troubleshooting

- **Modifiers not applying**: Check that the effect category matches the modifier category
- **Wrong calculation order**: Verify modifier types (additive before multiplicative)
- **Conditional not triggering**: Ensure the condition function returns true for expected scenarios
- **Performance issues**: Consider using temporary modifiers for short-lived effects

## Future Extensions

The system is designed to be easily extensible:

- Add new effect categories by extending the enum
- Create new modifier types for specialized behavior
- Implement modifier stacking rules for complex interactions
- Add visual indicators for active modifiers in the UI



