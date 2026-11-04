# DieFighter tests (GUT 9.7)

The suite is small on purpose. It guards the game's rules and the integrity of
authored content; it does not guard how the game looks, how it's tuned, or
how its animations are choreographed. Those change all the time and are
checked by playing.

## Running

Always headless: a windowed run (the editor's GUT panel) also hears the real
mouse, and moving it over the window fails tests that click.

```sh
GODOT=/Users/drew/Documents/Godot/Godot_4.7_stable.app/Contents/MacOS/Godot
$GODOT --headless --path . -s addons/gut/gut_cmdln.gd                                   # core (~40 s)
$GODOT --headless --path . -s addons/gut/gut_cmdln.gd -gselect=test_rng_manager         # one script
$GODOT --headless --path . -s addons/gut/gut_cmdln.gd -gconfig=res://.gutconfig_full.json  # core + extended
```

The exit code is non-zero on failure.

- **Core** (`test/core/`, the default `.gutconfig.json`): rules and content
  integrity. Run it before committing a change to game code or content.
- **Extended** (`test/extended/`, `.gutconfig_full.json`): input, UI widgets,
  fonts and localization tooling, the AutoPilot harness, and slower
  scene-level checks. Run it only when asked, or when a change is squarely
  in one of those systems (then `-gselect` just the scripts involved).

## Layout

| Folder | What goes here |
|---|---|
| `core/content/` | Data integrity over every authored `.tres` under `Source/Content`: stale effect ordinals, unbound text placeholders, unregistered tiles. |
| `core/integration/` | Several real pieces together, e.g. chain → registry → engine → modifiers → Health. |
| `core/engine/`, `effects/`, `modifiers/`, `enemies/`, `grid/`, `player/`, `components/`, `systems/` | One rule or system in isolation: event resolution, statuses, enemy action rolling, grid moves, saves, RNG, shops. |
| `extended/components/`, `extended/systems/` | Everything else that still earns its keep (see above). |
| `helpers/` | Shared fakes and builders. Loaded with `preload`, not `class_name`, so none of them show up in the game's global class list. |

## When to write a test

Don't, by default. Add one only when **all** of these hold:

1. It covers core behaviour: a game rule, save/load, RNG determinism, or
   content integrity. Not visuals, layout, animation timing, cursor art,
   sound, or AutoPilot heuristics.
2. It protects against a bug that could plausibly happen again, ideally one
   that already did.
3. It would still pass after any reasonable tuning or art change.

New tests go in `test/core/` unless they're slow (over ~0.5 s) or need a
scene-level setup, in which case `test/extended/`. Keep them few: one test
per rule, not one per tile that uses the rule.

## A test that breaks on tuning is deleted, not fixed

If changing a number, a tile, a ship, a sprite, a sound or a sentence fails a
test, the test was wrong. Delete it (or the assertion that pinned the value)
rather than updating it to the new value. Specifically, never:

- assert a shipped tile's, ship's or region's numbers (`countdown_cannon`
  deals 25), or which shipped content behaves which way;
- assert a balance constant (3% evasion a charge, a 50% cap, prices);
- assert positions, sizes, colours, frame counts or timings of anything drawn;
- type out player-facing wording (compare with `tr("KEY")` or the resource's
  own field instead).

Build the fixture in the test (`effects.gd`, `ships.gd`) and assert what the
code does with the numbers you gave it.

## Conventions

- Extend `res://test/helpers/die_fighter_test.gd`, and call `super()` if you override `before_each`/`after_each`. It snapshots and restores `Globals.*`, so a test that sets `Globals.player` can't leak it into the next one.
- **Build effects with `helpers/effects.gd`.** `EffectData.category`'s setter resets `subtype`, so setting them in the wrong order silently authors a different effect.
- **Test handlers against `RecordingEngine`**. It captures the events a handler produces rather than resolving them. Test the engine itself with a real `ScenarioEngine` plus `RecordingEvent`/`SpyModifier`/`GatedEvent`.
- **Prefer fresh instances over autoloads.** Load `rng_manager.gd` or `save_manager.gd` and `.new()` them. `SaveManager.save_path` exists so tests never touch `user://save_game.json`.
- **Nodes that reach for game systems in `_ready()`** (Tile, Dice) are instantiated from their scene and kept *out* of the tree.
- **Expected errors must be asserted.** GUT fails a test on any unexpected `push_error` or engine error, so a test that exercises an error path should say so with `assert_push_error("…")`, `assert_push_warning("…")` or `assert_engine_error_count(n)`.
- **No mid-wait timing checks.** A single slow frame can spend a whole short delay; assert before and after a wait, never partway through it.
- `test_effect_catalog.gd` pins every effect enum's ordinals. Appending a value passes. If it fails because a value was inserted or reordered, fix the enum, not the test. After appending, add the new name to the end of its pinned list too, so the next person's insert is caught.
