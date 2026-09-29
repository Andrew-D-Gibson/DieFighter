# DieFighter tests (GUT 9.7)

## Running

- **Editor:** open the GUT panel (bottom dock) and hit *Run All*. It reads `.gutconfig.json`.
- **Headless:**
  ```sh
  GODOT=/Users/drew/Documents/Godot/Godot_4.7_stable.app/Contents/MacOS/Godot
  $GODOT --headless --path . -s addons/gut/gut_cmdln.gd                          # everything
  $GODOT --headless --path . -s addons/gut/gut_cmdln.gd -gselect=test_rng_manager  # one script
  ```
  Exit code is non-zero on failure, so this drops straight into CI or a pre-commit hook.

## Layout

| Folder | What goes here |
|---|---|
| `unit/` | One class or system in isolation. Mirrors `Source/` loosely: `engine/`, `effects/`, `modifiers/`, `components/`, `grid/`, `player/`, `systems/`. |
| `integration/` | Several real pieces together, e.g. chain → registry → engine → modifiers → Health. |
| `content/` | Data integrity over every authored `.tres` under `Source/Content`. These catch a stale effect ordinal or a half-added effect before it becomes a tile that silently does nothing. |
| `helpers/` | Shared fakes and builders. Loaded with `preload`, not `class_name`, so none of them show up in the game's global class list. |

## Conventions

- Extend `res://test/helpers/die_fighter_test.gd`, and call `super()` if you override `before_each`/`after_each`. It snapshots and restores `Globals.*`, so a test that sets `Globals.player` can't leak it into the next one.
- **Build effects with `helpers/effects.gd`.** `EffectData.category`'s setter resets `subtype`, so setting them in the wrong order silently authors a different effect.
- **Test handlers against `RecordingEngine`**. It captures the events a handler produces rather than resolving them. Test the engine itself with a real `ScenarioEngine` plus `RecordingEvent`/`SpyModifier`/`GatedEvent`.
- **Prefer fresh instances over autoloads.** Load `rng_manager.gd` or `save_manager.gd` and `.new()` them. `SaveManager.save_path` exists so tests never touch `user://save_game.json`.
- **Nodes that reach for game systems in `_ready()`** (Tile, Dice) are instantiated from their scene and kept *out* of the tree.
- **Expected errors must be asserted.** GUT fails a test on any unexpected `push_error` or engine error, so a test that exercises an error path should say so with `assert_push_error("…")`, `assert_push_warning("…")` or `assert_engine_error_count(n)`.
- `test_effect_catalog.gd` pins every effect enum's ordinals. Appending a value passes. If it fails because a value was inserted or reordered, fix the enum, not the test.

## Not covered yet (good next targets)

- Targeting handlers, and tile/dice-control handlers that need a populated `TileGrid` / `EnemyManager`.
- `DamageEvent.resolve()`, which needs `Globals.state_manager` and spawns particles.
- `Enemy` action selection (`TURN_CYCLE` / `HEALTH_THRESHOLD` / `SQUAD_LOSSES` pools), `Map` Fate state, `GameStateManager` sector generation and checkpoint capture. These want a small test double for GameStateManager, or some logic pulled out into RefCounted classes first.
