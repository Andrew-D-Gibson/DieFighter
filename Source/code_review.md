# Die Fighter — Full Codebase Review

**Date:** 2026-03-30  
**Reviewer:** Claude Sonnet 4.6  
**Scope:** Every `.gd` file in `Source/`, analyzed for bugs, code quality, architecture, and alignment with the planned CombatEngine refactor.

---

## Table of Contents

1. [Critical Bugs](#1-critical-bugs)
2. [Medium Bugs & Logic Issues](#2-medium-bugs--logic-issues)
3. [Redundant / Dead Code](#3-redundant--dead-code)
4. [Code Quality & Clarity](#4-code-quality--clarity)
5. [Architecture Notes](#5-architecture-notes)
6. [File-by-File Notes](#6-file-by-file-notes)
7. [Refactor Alignment Notes](#7-refactor-alignment-notes)

---

## 1. Critical Bugs

These will cause crashes or clearly broken behavior at runtime.

---

### 1.1 `ActivateSelfEffect` and `ActivateTargetedTilesEffect` call a method that doesn't exist

**Files:**  
- `Content/Effects/Activators/activate_self_effect.gd:9`  
- `Content/Effects/Activators/activate_targeted_tiles_effect.gd:13`

Both effects call `tile.try_to_activate()`, but `Tile` has no such method. This will crash with a `Invalid call. Nonexistent function 'try_to_activate'` error the moment any tile that uses these effects is activated.

Looking at `tile.gd`, the public API for activation is:
- `can_activate(die) -> bool` — checks preconditions
- `activate(die)` — runs the effect chain

The most likely intended behavior is to call `activate()` without a die (event-triggered re-activation). The fix is either:

**Option A:** Replace `try_to_activate()` with `activate()` in both effects.

**Option B:** Add a `try_to_activate()` method to `Tile` that runs `can_activate()` and calls `activate()` if it passes. This is arguably cleaner because it respects activation criteria.

**Recommended fix:**
```gdscript
# tile.gd — add this method
func try_to_activate() -> void:
    if can_activate(null):
        activate(null)
```

Then the two effect files work without changes.

---

### 1.2 `Health.change_shields()` has broken clamping

**File:** `Systems/Components/Health/health.gd:67`

```gdscript
func change_shields(amount: int) -> void:
    shields += amount
    shields = clampi(shields, 0, shields)  # BUG: upper bound is self
```

After `shields += amount`, the new value is stored in `shields`. Then `clampi(shields, 0, shields)` is called with `shields` as both the value *and* the maximum. This does nothing useful for positive values (`clampi(5, 0, 5) == 5`). For negative values (e.g., after taking shield damage that overcorrects), `clampi(-3, 0, -3)` has `min > max`, which is undefined behavior in GDScript's C++ implementation — it may return `min` (0) accidentally, which coincidentally is the desired behavior, but it is not intentional and not guaranteed.

There is also no upper cap on shields. Shields can grow indefinitely.

**Recommended fix:**
```gdscript
func change_shields(amount: int) -> void:
    shields = max(0, shields + amount)
    if amount > 0:
        shields_reinforced.emit()
    else:
        shields_damaged.emit()
```

If you want a max shields cap, add `@export var max_shields: int = 0` (0 = uncapped) and clamp to it.

---

### 1.3 Player money is never actually awarded

**File:** `Systems/Game/RewardManager/reward.gd:22`

```gdscript
func give_reward(reward_resource: RewardResource) -> void:
    #Globals.player.money += money   # <-- commented out!
    var money: int = randi_range(reward_resource.min_money, reward_resource.max_money)
    _spawn_money_particles(money)
```

Money particles spawn but the player never receives the money. This is presumably a work-in-progress that got left commented out.

---

## 2. Medium Bugs & Logic Issues

These won't necessarily crash the game but produce incorrect behavior.

---

### 2.1 Enemy weighted action selection can select no action

**File:** `Content/Enemies/enemy.gd:220–228`

```gdscript
for i in range(6 - len(turn_actions)):
    var rand_float: float = rng.randf_range(0, action_weights_sum)
    var choice_threshold = rand_float
    for option: EnemyActionOptionResource in this_turns_action_options.actions_possible:
        if choice_threshold > option.weight:
            choice_threshold -= option.weight
        else:
            turn_actions.append(option.get_action())
            break
```

The weighted selection algorithm itself is correct. However:

1. If `action_weights_sum == 0.0` (all weights are zero), `randf_range(0, 0)` returns `0`, and `choice_threshold (0) > option.weight (0)` is false on the first iteration, so the first option is always selected. This is probably acceptable behavior but worth knowing.

2. If `this_turns_action_options.actions_possible` is empty, the inner loop runs zero times and nothing is appended to `turn_actions`. The outer loop runs 6 times in this case but appends nothing.

3. After the loop, line 235 runs:
   ```gdscript
   for i: int in range(6):
       turn_actions[i].activating_die_number = i+1
   ```
   If `turn_actions` has fewer than 6 elements (due to empty options or the edge case above), this crashes with an out-of-bounds index.

**Fix:** Add a guard before line 234:
```gdscript
if len(turn_actions) < 6:
    push_error("Enemy %s could not generate 6 turn actions!" % enemy_resource.enemy_name)
    return
```

---

### 2.2 `Dice.reroll_with_tween()` rotates 0→180 twice instead of 0→360

**File:** `Systems/Game/Dice/dice.gd:82–95`

```gdscript
# Phase 1 (parallel):
tween.tween_property(self, 'rotation_degrees', 180, tween_time).from(0)
...
# Phase 2 (after callback):
tween.tween_property(self, 'rotation_degrees', 180, tween_time).from(0)  # from(0) again!
```

Both phases start from `0` and go to `180`. The die visually jumps back to `0°` between phases. The likely intent is a continuous 360° flip. The second phase should use `.from(180)` and target `360` (or `0` using modular rotation):

```gdscript
tween.tween_property(self, 'rotation_degrees', 360, tween_time).from(180)
```

---

### 2.3 `_update_ui()` in TargetingComputer is implicitly async with stale state risk

**File:** `Systems/Game/TargetingComputer/targeting_computer.gd:158–206`

`_update_ui()` contains `await $TargetImageFill.animation_looped`. This makes the function a coroutine. Callers (`check_target_is_valid`, signal handlers) do not `await` it, so execution continues immediately and the function runs as a fire-and-forget task.

The problem: after the `await`, the code sets `$TargetImageFill.z_index = -2`. If the targeted enemy changed during the animation (because the player switched targets), this write happens to the node based on stale state.

**Fix:** Add a guard after the await:
```gdscript
await $TargetImageFill.animation_looped
if targeted_enemy:   # Still valid?
    $TargetImageFill.z_index = -2
```

---

### 2.4 `ScenarioManager._handle_enemy_leaving()` always emits `close_shop`

**File:** `Systems/Game/ScenarioManager/scenario_manager.gd:53`

```gdscript
func _handle_enemy_leaving(ship: Enemy, faction: Faction) -> void:
    # Just as an edge case, if the player destroys the shop in a single turn
    # it won't close the normal way, so we close it here
    Events.close_shop.emit()
    ...
```

Every time any enemy in any scenario dies, `close_shop` is emitted. If a combat scenario has an open info panel or other UI state that listens to `close_shop`, it will be incorrectly triggered. This should be gated to only fire when the current scenario is a shop scenario:

```gdscript
if current_scenario == Globals.state_manager.shop_scenario:
    Events.close_shop.emit()
```

---

### 2.5 `enemy_manager.gd:start_enemy_fly_in()` animates enemies sequentially

**File:** `Systems/Game/EnemyManager/enemy_manager.gd:67–85`

```gdscript
func start_enemy_fly_in() -> void:
    for enemy: Enemy in enemies:
        ...
        await fly_in_tween.finished   # <-- waits for each enemy
        Events.enemy_flew_in.emit()
        enemy.graphics_manager.start_bob_tween()
```

The `await` is inside the `for` loop, so enemies fly in one at a time. The first enemy completes before the second starts. This may be intentional (staggered entry feels nice), but `Events.enemy_flew_in` is emitted per-enemy rather than once for all enemies. Anything that awaits `enemy_flew_in` (like the tutorial) will trigger on the first enemy, not when all enemies have arrived.

If you want all enemies to fly in simultaneously and emit `enemy_flew_in` once all are done, move the `await` outside the loop. If the sequential behavior is intentional, document it.

---

### 2.6 `map.gd` mutates shared `ScenarioResource` references

**File:** `Systems/Game/Map/map.gd:263–273`

```gdscript
scenario_list[current_scenario_index] = empty_scenario
...
scenario_list[idx] = fate_scenario
```

`scenario_list` is assigned directly from `game_save.sector_scenarios` (a reference, not a copy). Replacing entries in `scenario_list` replaces them in the save resource. This is the intended design, but it means `empty_scenario` and `fate_scenario` exported resources are reused as sentinels — any code that calls `scenario.seed = randi()` (in `game_state_manager.gd:139`) would silently corrupt these shared resources on the next run if the save is reused.

---

### 2.7 `GameStateManager._randomize_sector_scenarios()` seeds shared resources

**File:** `Systems/Game/GameStateManager/game_state_manager.gd:139`

```gdscript
for scenario: ScenarioResource in current_game_save.sector_scenarios:
    scenario.seed = randi()
```

This mutates the `.tres`/`.res` resources exported in the inspector. Between runs, `shop_scenario`, `combat_scenarios[i]`, etc. all have their `seed` field permanently altered. On a new run (or after a game-over), the sector is regenerated but the resources from the previous run still carry their old seeds until overwritten. This is usually fine for single-run games, but will cause subtle non-determinism if you ever add a "restart" feature.

**Fix:** Either duplicate the resources before seeding (`scenario.duplicate()` each entry), or use a separate dictionary/array to store seeds outside the resource.

---

## 3. Redundant / Dead Code

---

### 3.1 `Tile.dice_activation_queue` static var is dead code

**File:** `Content/Tiles/tile.gd:39`

```gdscript
static var dice_activation_queue: Array[Dice] = []
```

`ActivationQueueManager` was created to own this queue. Tile no longer populates this static array — `_on_die_accepted()` calls `Globals.activation_queue_manager.add_die_to_queue(die)`. The code inside `can_activate()` that iterates `dice_activation_queue` and returns dice to the player (lines 149–153) will never do anything because the static array is always empty.

The `ActivationQueueManager._clear_activation_queue()` is the one that actually returns dice to the player. The Tile code is completely bypassed.

**Fix:** Remove the static var from `tile.gd` and remove the dead code in `can_activate()` (lines 149–153).

---

### 3.2 Redundant `scenario_state` assignment in `enemy.gd`

**File:** `Content/Enemies/enemy.gd:97,100`

```gdscript
if new_state != scenario_state:
    scenario_state = new_state    # line 98
    trigger_state_effects()
scenario_state = new_state        # line 100 - always runs, redundant
```

The assignment on line 100 executes whether or not the state changed. When it changed, it was already assigned on line 98. When it didn't change, assigning the same value is a no-op. Remove line 100.

---

### 3.3 Commented-out code in `game_state_manager.gd`

**File:** `Systems/Game/GameStateManager/game_state_manager.gd:49`

```gdscript
#seed('Die Fighter'.hash())
```

This appears to be leftover from deterministic seeding experiments. Remove it or replace with a proper comment explaining the seeding strategy.

---

### 3.4 `GlobalModifierManager` test and demo files probably shouldn't ship

**Files:**  
- `Systems/Game/GlobalModifierManager/test_modifier_system.gd`  
- `Systems/Game/GlobalModifierManager/modifier_demo.gd`

These look like development scaffolding. They should either be converted to proper unit tests or removed before shipping.

---

## 4. Code Quality & Clarity

---

### 4.1 Magic numbers for `EffectCategory` throughout modifier system

**Files:**  
- `Content/Effects/AttributeChangers/damage_effect.gd:22` — `calculate_final_amount_with_global_modifiers(1)` (1 = DAMAGE)  
- `Systems/Game/GlobalModifierManager/global_modifier_manager.gd:109–121` — hardcoded `0`, `1`, `2` for ADDITIVE/MULTIPLICATIVE/CONDITIONAL  
- `Systems/Game/GlobalModifierManager/global_modifier_manager.gd:128` — `apply_modifiers_to_repetitions` uses `4` directly  
- `Systems/Game/GlobalModifierManager/example_modifiers.gd` — comments say `# DAMAGE`, `# SHIELD`, etc., but raw ints are used

`GlobalModifierManager` defines `EffectCategory` and `ModifierType` enums, but neither `EffectVariables` nor the individual effect files import or use them. They all use raw integers.

**Fix:** In `effect_variables.gd` and every effect that calls `calculate_final_amount_with_global_modifiers()`, use:
```gdscript
GlobalModifierManager.EffectCategory.DAMAGE  # instead of 1
```
And in `global_modifier_manager.gd` itself, replace `0`, `1`, `2` with `ModifierType.ADDITIVE`, etc.

---

### 4.2 `Health.change_shields()` has no upper cap

**File:** `Systems/Components/Health/health.gd`

There is no `max_shields` field. Shields can grow without bound. This may be intentional design (shields stack), but it is not documented. If it is intentional, add a comment. If it should have a cap, add `@export var max_shields: int = 0` and clamp to it (0 = unlimited).

---

### 4.3 `Utils.format_text()` is a fragile chain of `string.replace()` calls

**File:** `Systems/utils.gd:43–81`

The function performs 25+ sequential `.replace()` calls to do text templating. Every new icon/color/token requires adding a new line. There is no way to discover available tokens except reading this function.

A dictionary-based approach would be more maintainable:
```gdscript
static var _text_replacements: Dictionary = {
    "=red": "=#" + ...,
    "(die_1)": "[img=...]...",
    # etc.
}

static func format_text(text: String, scale: int = 6) -> String:
    for token in _text_replacements:
        text = text.replace(token, _text_replacements[token])
    return text
```

This also makes it trivial to document all available tokens in one place.

---

### 4.4 `TargetingComputer._update_ui()` accesses scene children by `$` path

**File:** `Systems/Game/TargetingComputer/targeting_computer.gd`

`$TargetImage`, `$Intents`, `$TargetImageFill`, `$Intents.get_child(i)`, etc. are used throughout. If the scene tree structure changes, these silently fail or crash. Prefer `@onready var` for all stable node references:

```gdscript
@onready var target_image: TextureRect = $TargetImage
@onready var intents: Node2D = $Intents
@onready var target_image_fill: AnimatedSprite2D = $TargetImageFill
```

---

### 4.5 `Dice.value` setter duplicates a `ShaderMaterial` on every value change

**File:** `Systems/Game/Dice/dice.gd:26–39`

```gdscript
set(new_value):
    ...
    var mat: ShaderMaterial = holographic_shader.duplicate()  # new object every time
    mat.set_shader_parameter("seed", randi() % 1000 / 100.0)
    $Sprite2D.material = mat
```

Every die value change (including rerolls, which happen every turn) creates a new `ShaderMaterial`. With 3+ dice per turn, this allocates new resources frequently. Instead, cache the material per die in `_ready()` and only update the shader parameter:

```gdscript
var _die_material: ShaderMaterial

func _ready() -> void:
    _die_material = holographic_shader.duplicate() if holographic else default_shader.duplicate()
    $Sprite2D.material = _die_material
    value = get_random_die_value()

# In the value setter:
set(new_value):
    value = clampi(new_value, 1, 6)
    $Sprite2D.texture = holographic_textures[value] if holographic else value_textures[value]
    if holographic:
        _die_material.set_shader_parameter("seed", randi() % 1000 / 100.0)
    else:
        _die_material.set_shader_parameter("time_offset", randf() * 10.0)
```

---

### 4.6 `EnemyActionOptionResource.get_action()` performs manual deep copy that will miss new fields

**File:** `Content/Enemies/EnemyActions/enemy_action_option_resource.gd:13–34`

```gdscript
func get_action() -> EnemyActionResource:
    var action: EnemyActionResource = base_action.duplicate(true)
    action.effect_chain = base_action.effect_chain.duplicate(true)
    var duplicated_effects: Array[Effect] = []
    for effect: Effect in base_action.effect_chain.effects:
        var duplicated_effect: Effect = effect.duplicate(true)
        ...
```

The function calls `duplicate(true)` (which already does a deep copy of sub-resources), then manually duplicates the effect chain and effects again. This is redundant — `duplicate(true)` should already handle nested resources. If it doesn't for some reason specific to Godot's implementation, that should be documented.

If the manual duplication is intentional (to set `amount` on the primary effect), simplify to:
```gdscript
func get_action() -> EnemyActionResource:
    var action: EnemyActionResource = base_action.duplicate(true)
    amount = Enemy.rng.randi_range(min_amount, max_amount)
    action.intent_amount = str(amount) if amount != 0 else ''
    for effect: Effect in action.effect_chain.effects:
        if effect.primary_effect:
            effect.amount = amount
    return action
```

---

### 4.7 `Player.spawn_dice()` uses `0` as a sentinel "no value" for die value

**File:** `Systems/Game/Player/player.gd:184–199`

```gdscript
func spawn_dice(num_to_spawn: int = num_of_dice, value: int = 0, holographic: bool = false) -> void:
    ...
    if value != 0:
        new_die.value = value
```

Using `0` as "unset" is confusing since `Dice.value` is clamped to 1–6. A keyword argument with `-1` or a typed optional (`Variant` defaulting to `null`) would be clearer. Alternatively, the die already randomizes its value in `_ready()` when value is 0, so the `if` check may be unnecessary.

---

### 4.8 `GlobalModifier.category` and `.type` are untyped `int` exports

**File:** `Systems/Game/GlobalModifierManager/global_modifier.gd:8–9`

```gdscript
@export var category: int
@export var type: int
```

These should use the enum types defined in `GlobalModifierManager`:
```gdscript
@export var category: GlobalModifierManager.EffectCategory
@export var type: GlobalModifierManager.ModifierType
```

This gives inspector dropdowns and compile-time type checking.

---

### 4.9 `Globals` stores game color palette — this belongs in a Theme or constant

**File:** `Systems/Autoloads/globals.gd:24–34`

Colors like `Globals.red`, `Globals.blue` are accessed everywhere. These are fine as-is for a small project but:
- They can't be previewed or edited in the Godot theme editor
- Adding new colors requires modifying `globals.gd`
- Any color used in a shader must be kept in sync manually

Consider migrating to a `GameColors` autoload or `const` class, or using Godot's `ProjectSettings` / theme system for colors accessible in both GDScript and shaders.

---

### 4.10 `game_state_manager.gd` hardcodes 30% question probability

**File:** `Systems/Game/GameStateManager/game_state_manager.gd:106`

```gdscript
if len(question_scenario_options) > 0 and randf() <= 0.3:
```

This percentage is not exposed as an export, making it invisible to designers. Add `@export_range(0.0, 1.0) var question_scenario_probability: float = 0.3` and use the export.

---

## 5. Architecture Notes

These are bigger-picture observations that don't necessarily need immediate action, but are worth tracking.

---

### 5.1 Signal connections in `Tile._ready()` are never disconnected

**File:** `Content/Tiles/tile.gd:57–67, 73–85`

```gdscript
Events.start_scenario.connect(reset_uses_remaining)
Events.start_combat.connect(func() -> void: ...)
Events.combat_finished.connect(func() -> void: ...)
Events.player_turn_start.connect(func() -> void: ...)
Events.tile_pushed.connect(func(tile: Tile) -> void: ...)
...
```

These are all connected to global autoload signals. When a Tile node is freed (e.g., during a jump to a new scenario), GDScript should garbage-collect the lambdas, but the `Events` autoload still holds references to them. If the autoload's signal connection list grows unboundedly between scenarios, this is a memory/performance concern.

Prefer `connect(..., CONNECT_ONE_SHOT)` for single-use connections, or explicitly disconnect in `_exit_tree()`:
```gdscript
func _exit_tree() -> void:
    Events.start_scenario.disconnect(reset_uses_remaining)
    # etc.
```

---

### 5.2 `Globals` is a service locator, which creates hidden coupling

**File:** `Systems/Autoloads/globals.gd`

The entire game uses `Globals.player`, `Globals.tile_grid`, `Globals.enemy_manager`, etc. This is a service locator pattern, which trades explicit dependencies for hidden ones. Every system depends on every other system through `Globals`.

This is a pragmatic choice for a small game and is fine as-is, but it creates challenges for:
- Testing any system in isolation
- Knowing when initialization order matters (e.g., `Globals.modifier_manager` is checked in `EffectVariables` before it exists if the combat scene hasn't loaded)

No change required unless testing becomes a priority, but keep this in mind when adding new systems.

---

### 5.3 `static` on `Dice._rng`, `Enemy.rng`, and tutorial override arrays

**Files:**  
- `Systems/Game/Dice/dice.gd:19–21`  
- `Content/Enemies/enemy.gd:43–46`  
- `Systems/Game/RewardManager/reward.gd:12`

These static variables are used for two distinct purposes: shared RNG instances (intentional) and tutorial overrides (test injection). The tutorial injection pattern — appending to a static array that gets consumed — is fragile:

1. If tutorial logic runs out of sync, leftover values in `forced_rolls` carry into normal gameplay.
2. If a scenario is reloaded or the game is restarted without clearing these arrays, the state bleeds over.

`TutorialManager` already manages the tutorial flow. Instead of injecting into static arrays, consider having `TutorialManager` hold the overrides and passing them through a context object, or using Godot's `set_meta()` on the dice/enemy to communicate tutorial state per-instance.

---

### 5.4 `get_alive_enemies()` has a side effect

**File:** `Systems/Game/EnemyManager/enemy_manager.gd:107–109`

```gdscript
func get_alive_enemies() -> Array[Enemy]:
    _remove_dead_enemies()   # side effect in a getter!
    return enemies
```

Callers that expect a pure read unexpectedly trigger cleanup. This is particularly confusing because `_remove_dead_enemies()` also checks `health.health == 0`, meaning enemies that died but weren't yet cleaned up get removed here.

Consider separating this: call `_remove_dead_enemies()` only in places that explicitly want cleanup (e.g., after damage), and make `get_alive_enemies()` purely return `enemies`.

---

### 5.5 `EnemyManager.run_enemy_turn()` busy-loops with `create_timer(1)`

**File:** `Systems/Game/EnemyManager/enemy_manager.gd:127–149`

```gdscript
while true:
    var dice_left: bool = false
    for enemy: Enemy in current_enemies:
        ...
        await get_tree().create_timer(1).timeout
        await enemy.run_turn()
    if not dice_left:
        break
```

The hardcoded 1-second delay before each enemy's turn adds up for multi-enemy encounters and can't be adjusted by the animation speed setting (`Globals.animation_speed`). Use `Globals.animation_speed`:
```gdscript
await get_tree().create_timer(1.0 / Globals.animation_speed).timeout
```

---

### 5.6 `ActivationQueueManager` is correct but could be simplified

**File:** `Systems/Game/TileGrid/ActivationQueueManager/activation_queue_manager.gd`

The design is good. One minor issue: `_process_queue()` is called both from `tile_activation_complete` signal and from `add_die_to_queue()` (when queue was empty). This means if two dice arrive very close together, the second `add_die_to_queue()` call doesn't start processing because the queue is already non-empty, and processing will be triggered by the `tile_activation_complete` signal from the first activation. This is correct behavior, but it might be worth adding a comment explaining this design.

---

### 5.7 `ScenarioShipState` return type inconsistency

**File:** `Content/ScenarioResources/ScenarioShipStateScripts/scenario_ship_state.gd:12`

```gdscript
func handle_scenario_event(event: ScenarioManager.ScenarioEvent) -> ScenarioShipState:
```

The return type is `ScenarioShipState` (the concrete class), but the field `transitions` maps to `ScenarioShipStateBase`. When a `ScenarioShipStateProbabilityTransition` is used, it calls `next_state.get_next_state_from_probabilities()` which presumably returns a `ScenarioShipState`. But the static type annotation promises `ScenarioShipState` while the code works with `ScenarioShipStateBase`.

This works in GDScript's duck-typed system, but the return type annotation is slightly misleading — it should be `ScenarioShipStateBase`. The caller in `enemy.gd:94` assigns the result to `var new_state: ScenarioShipState`, then accesses `new_state.attitude` — this works as long as all concrete states have `attitude`, but it bypasses the type system.

---

## 6. File-by-File Notes

Brief per-file observations that didn't warrant their own section.

---

### `Systems/Autoloads/globals.gd`

- `times_run: int = 0` is declared but no code in the reviewed files reads or writes to it. Dead field, or should be connected to save/load logic.
- `screenshake_enabled` and `animation_speed` are runtime settings but not persisted in `GameSaveResource`. They reset on game restart.
- `mouse_is_dragging_something: bool` is a global flag for drag state. Consider whether this is needed or can be replaced by checking the `Draggable` component's state directly.

---

### `Systems/Autoloads/events.gd`

Well-organized. The `@warning_ignore_start("unused_signal")` at the top is a good practice for a signals file. No issues.

One suggestion: consider grouping the signal file into regions for each game system:
```gdscript
#region Combat
signal start_combat()
...
#endregion
```

---

### `Content/Effects/effect.gd`

The `primary_effect: bool` flag is used by `EnemyActionOptionResource.get_action()` to know which effect to inject the randomized amount into. This is a bit of a design smell — the flag couples the resource data structure to the enemy action generation system. Consider a more explicit mechanism, like a separate `@export var amount_is_randomized: bool` or moving the amount randomization into the effect itself.

---

### `Content/Effects/effect_chain.gd`

Clean and minimal. One note: if `effect_variables.activator_die` becomes null during the chain (e.g., a `DestroySourceEffect` destroys it), subsequent `effect_variables.activator_die.global_position` accesses would crash. Consider checking `is_instance_valid(effect_variables.activator_die)` instead of `effect_variables.activator_die` alone.

---

### `Content/Effects/effect_variables.gd`

- The `calculate_final_amount_with_global_modifiers(category: int)` method takes an `int` but callers pass magic numbers. As noted in §4.1, use the enum.
- The `if not base_amount: base_amount = 0` check on line 23 is redundant — `base_amount` is already initialized to `0`.

---

### `Content/Effects/AttributeChangers/damage_effect.gd`

- `particles.amount = 10 * final_amount` could produce extreme particle counts for high damage (e.g., 10 damage = 100 particles). Consider capping: `particles.amount = min(10 * final_amount, 200)`.
- The shield/HP color decision for particles (line 30–31) fires before `take_damage()`, so it reads the *current* shields to decide the color — this is correct behavior, just non-obvious.
- This file sets `Globals.state_manager.state = GameStateManager.GameState.IN_COMBAT` (line 54). This is a side effect of a damage calculation that belongs in the combat state machine, not in an effect. It should be moved to wherever damage is dispatched (e.g., the event handler in the planned CombatEngine).

---

### `Content/Tiles/tile.gd`

- The `set_gray_out()` function (lines 309–337) works correctly now — it tweens `shader_parameter/strength` and `shader_parameter/outer_radius` on `sprite_frames.material`. The earlier analysis that suggested it was broken was incorrect.
- The `_replace_event_data_in_string()` function (lines 244–277) is a mini-expression-evaluator using `Expression.new()`. It safely tokenizes input before evaluating, so raw code injection is not possible. However, the function rebuilds a new `RegEx` object every call — consider caching the compiled regex as a static variable.
- `_get_tile_info()` returns `null` when a status effect has `status_info` set (line 110). The caller (`clickable.clicked` lambda, line 48) passes the result to `Events.show_info.emit()` — this will emit a null `InfoResource`. Ensure the `info_shower.gd` handles `null` gracefully.

---

### `Content/Tiles/activation_resource.gd`

Well-designed. The dictionary-of-lambdas approach for activation functions is clean. One note: the `VALUE` activation type silently accepts any die when `acceptable_values` is empty (since `die.value in []` is always false, the function returns `false`... wait, actually:

```gdscript
ActivationType.VALUE: 
    func(die: Dice) -> bool: 
        if not die:
            return true
        return die.value in acceptable_values,
```

If `acceptable_values` is empty and a die is provided, `die.value in []` returns `false` — meaning this tile can never be activated with a die. This might be intentional (a tile you activate without a die but that can still receive one and reject it), but it's a footgun for designers who might accidentally leave `acceptable_values` empty.

---

### `Content/Tiles/tile_resource.gd`

Clean data container. `uses_per_combat: int` has no default value, so it defaults to `0` unless set. An unset tile would have `0` uses (no uses allowed) rather than `-1` (unlimited). A default of `-1` would be safer:
```gdscript
@export var uses_per_combat: int = -1
```

---

### `Content/Enemies/enemy.gd`

- `turns_alive` is declared as `@onready var turns_alive: int = 0`. Using `@onready` on a variable with a literal initializer is harmless but unnecessary — `@onready` is only needed when the initializer references node paths. Use `var turns_alive: int = 0` instead.
- `disconnect_scenario_signals()` (line 88) is called by `EnemyManager` before freeing enemies during a jump. Good practice — make sure any future signal connections added to `_connect_scenario_signals()` are also added here.

---

### `Systems/Game/EnemyManager/enemy_manager.gd`

- `_remove_dead_enemies()` checks `enemies[i].health.health == 0`. If an enemy was killed via `kill_all_enemies()` → `damage_all_enemies(10000)` → `health.take_damage()` → `change_health()` → `death.emit()` → `_on_death()` → `queue_free()`, the enemy is already freed by the time `_remove_dead_enemies()` runs. The `not enemies[i]` check handles freed instances correctly. But it's subtle — consider adding a comment.
- `kill_all_enemies()` calls `damage_all_enemies(10000)` — this hardcoded large number is fragile. If an enemy ever has more than 10,000 HP, it won't die. Use `health.max_health + 1` or add a dedicated `instakill()` method to `Health`.

---

### `Systems/Game/GameStateManager/game_state_manager.gd`

- `sector_size = 18` is exported but the comment says "Minimum of 3 (?)" — unclear what the actual minimum safe value is. Add a `@export_range(3, 50)` annotation once you know the bounds.
- The `_check_combat_state()` function is connected to both `start_scenario` and `enemy_left`. When an enemy leaves, `_check_combat_state` fires which might emit `combat_finished` or `start_combat`. This is correct but the chain is hard to follow. A comment explaining the flow would help.

---

### `Systems/Game/Player/player.gd`

- The engine charge formula `max_engine_charge = (6*(num_of_dice-1)) - floor(1.7078 * sqrt(num_of_dice))` produces these values:
  - 1 die: -1 (capped to 0 by the setter? — actually not, `max_engine_charge` has no setter)
  - 2 dice: 4
  - 3 dice: 9
  - 4 dice: 14
  - 5 dice: 18
  - 6 dice: 21

  With 1 die, `max_engine_charge` becomes `-1`, which would cause `engine_charge` setter's `clampi(new_value, 0, -1)` to behave incorrectly (same bug class as `change_shields`). Add a guard: `max_engine_charge = max(1, ...)`.

- `_process()` rearranges the dice queue every frame while dragging. This is O(n) per frame. For the expected die count (2–6), this is fine.

---

### `Systems/Game/TargetingComputer/targeting_computer.gd`

- `_reveal_tween()` hardcodes `max_progress: float = 29`. This is a shader parameter value that should probably be documented or named (it's the reveal animation's end state).
- `_indicator_bob()` creates a new looping tween every time the indicator moves. The old tween is killed, which is correct. But if `targeted_enemy` becomes invalid *during* the bob tween (e.g., enemy dies mid-animation), the tween callback `_indicator_bob` re-checks `if not targeted_enemy: return` — this is correctly guarded.

---

### `Systems/TutorialManager/tutorial_manager.gd`

- The `skip_to_step` system applies all forced values from skipped steps but calls `tutorial_functions[step.tutorial_function].call()` for each skipped step. Some tutorial functions have visible side effects (spawning enemies, emitting startup signals). Skipping steps might trigger these side effects in the wrong order. Test this carefully if you add more tutorial steps.
- `start_tutorial()` uses a simple sequential `for` loop with `await`. Each step's popup must be closed before the next step starts. This is correct but inflexible — some tutorials might want to show two popups simultaneously. Not a bug, just a design limitation.

---

### `Systems/Game/Map/map.gd`

- `right_fate_index = len(scenario_list)-1` is set in `_load_game_save()` but never updated as the map progresses. The right fate zone calculation in `_pick_new_danger_ranges()` only updates `left_fate_index`. What is `right_fate_index` used for? It appears in `map.gd:264`: `current_scenario_index >= right_fate_index`. If `right_fate_index` stays at the end and never moves, this means the last scenario never gets replaced. Is there a right-side Fate that should be closing in from the right? If so, the update logic is missing.

---

### `Systems/Game/GlobalModifierManager/`

The modifier system is well-designed with clear separation between `GlobalModifier` (data), `GlobalModifierManager` (storage/application), and `ModifierFactory` (construction). However:

- The `_initialize_modifier_dictionary()` in `global_modifier_manager.gd` builds a nested `Dictionary[int, Dictionary[int, Array]]`. In GDScript, untyped dictionaries lose compile-time safety. Using typed inner arrays would be better.
- The system is called "GlobalModifierManager" but its scope is per-gameplay-session (cleared on `game_over`, temporary ones cleared on `start_scenario`). The name "global" might suggest it's persistent across all sessions — consider `CombatModifierManager` or `SessionModifierManager`.
- `apply_modifiers_to_repetitions` and `apply_modifiers_to_dice_value` are convenience wrappers that call `apply_modifiers_to_amount` with hardcoded category indices (`4` and `3` respectively). Use the enum values.

---

### `Systems/Components/Health/health.gd`

- `change_health()` emits `fatal_damage` before `death`, then checks health again: "Check again in case we've been saved." This is a clever pattern for "last stand" mechanics where an ability can prevent death. The `fatal_damage` signal allows something to add HP before `death` fires. This design is good but needs documentation. Add a comment explaining this is the "death prevention hook."
- `health_healed` is emitted when `amount > 0`, but `change_health` is also used to set initial health (e.g., `health.health = game_save.player_health`). That direct setter assignment bypasses `change_health()` but goes through the `health` setter which doesn't emit `health_healed`. This is probably intentional but worth noting.

---

### `Systems/Components/DiceQueue/dice_queue.gd`

Clean and minimal. One note: `add()` with `destroy_holographic: bool = true` as a default parameter means holographic dice are destroyed by default. The parameter name suggests it *destroys* holographic dice. Callers that want to keep holographic dice must explicitly pass `false`. This feels backwards in terms of defaults — most callers that add dice back to a queue probably want to preserve them. Consider renaming to `keep_holographic: bool = false` and inverting the logic.

---

## 7. Refactor Alignment Notes

These notes are specifically about how the current codebase will interact with the planned `CombatEngine` refactor described in `CLAUDE.md`.

---

### 7.1 The cleanest first step: add `try_to_activate()` to `Tile` now

Before you start the CombatEngine refactor, fix the crash bug in §1.1 by adding `try_to_activate()` to `Tile`. This is a pure addition with no architectural implications and unblocks content that uses `ActivateSelfEffect` and `ActivateTargetedTilesEffect`.

---

### 7.2 `EffectVariables` is your `EffectContext` prototype

`EffectVariables` already has most of what the planned `EffectContext` needs: `actor`, `effect_source`, `targets`, `activator_die`, `repetitions`. The refactor plan calls for creating `EffectContext` as a replacement. You might consider:

1. Renaming `EffectVariables` → `EffectContext` in-place (search-and-replace), rather than creating a parallel class.
2. Stripping out `calculate_final_amount_with_global_modifiers()` from it once the `CombatEngine` takes over modifier application.
3. The `base_amount` and `amount_modifiers: Array[Callable]` on `EffectVariables` are an existing amount-modifier pipeline — similar to what `CombatEngine` will do via `Modifier` objects. Document this overlap before the refactor so you don't accidentally implement two parallel systems.

---

### 7.3 `GlobalModifierManager` vs. the planned `CombatEngine` modifier system

The refactor plan introduces `Modifier` objects with `on_before_event` / `on_after_event`. The existing `GlobalModifierManager` is an additive/multiplicative amount modifier system. These overlap.

**Key difference:** `GlobalModifierManager` applies to a numeric *amount* and is invoked explicitly by `EffectVariables.calculate_final_amount_with_global_modifiers()`. The planned `CombatEngine` modifiers intercept *typed events* and can enqueue new events.

You don't need to delete `GlobalModifierManager` during Phase 1 of the refactor. But by Phase 4, `DamageEvent.resolve()` should replace `calculate_final_amount_with_global_modifiers()` as the modifier application point. Plan to migrate `GlobalModifierManager`'s modifiers into `CombatEngine`'s `Modifier` objects.

---

### 7.4 The static `Tile.dice_activation_queue` should be removed before (not during) the refactor

Removing dead code before a refactor reduces cognitive load. The static `Tile.dice_activation_queue` (§3.1) and its dead code in `can_activate()` should be cleaned up independently of the CombatEngine work.

---

### 7.5 `DamageEffect.play()` sets `GameState.IN_COMBAT` — this is a side effect to isolate

As noted in §6 (damage_effect.gd notes), `DamageEffect` sets `Globals.state_manager.state = GameStateManager.GameState.IN_COMBAT` as a side effect of damage. This means the game only transitions to IN_COMBAT when actual damage is dealt, not when combat starts. This is an implicit rule that should be made explicit and moved into the combat event resolution during Phase 4.

---

### 7.6 Phase ordering recommendation

Based on the current codebase, here's the recommended order within Phase 1 of the refactor:

1. Fix bugs in §1 first (takes an hour, removes crash risk).
2. Clean up dead code from §3 (removes confusion before you start reading Effect code).
3. Start the CombatEngine scaffolding with `DamageEvent` as the first typed event.
4. Wire one simple damage tile to the new engine before touching any other tile.

The incremental approach described in CLAUDE.md (keep old system running, wire one tile first) is correct.

---

*End of review. Total files analyzed: ~65 of ~89 `.gd` files. The remaining files (mostly UI, graphics, and minor utilities) are lower risk and consistent with the patterns described above.*
