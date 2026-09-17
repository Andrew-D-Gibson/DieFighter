# Tutorial System Cleanup

## Context

`TutorialManager` (`Source/Systems/TutorialManager/tutorial_manager.gd`) drives the onboarding tutorial via a queue of data-driven `TutorialStep` resources (`.tres` files authored in the editor). That data-driven split is good and stays as-is. The manager itself, though, has accumulated several issues from organic growth: gameplay code outside the tutorial system reaches directly into tutorial-only state, some fields are dead, forcing logic is duplicated, and there's no way to recover if a step's closing signal never fires. This plan cleans up the `TutorialManager`/`TutorialStep`/`TutorialTextPopup` trio without touching the `.tres` content or changing tutorial behavior for players.

Confirmed via `main.tscn`: `TutorialManager` is a permanent child of the main scene (not conditionally instanced), so `Globals.tutorial_manager` is never actually null — but non-tutorial code (`enemy_manager.gd:28`, `game_state_manager.gd:52,75`) still branches directly on tutorial-only fields (`auto_start`, `tutorial_will_trigger_enemy_turns`), which is the coupling problem to fix.

## Changes

### 1. Decouple gameplay code from tutorial internals
Today `enemy_manager.gd` and `game_state_manager.gd` read `Globals.tutorial_manager.auto_start` / `.tutorial_will_trigger_enemy_turns` directly — gameplay systems know about tutorial internals.

- Add a single `Globals.tutorial_active: bool` (or an `Events.tutorial_mode_changed` signal) set once by `TutorialManager._ready()` instead of exposing `auto_start` for external reads.
- Rename `tutorial_will_trigger_enemy_turns` → `tutorial_controls_enemy_turns` (fixes the inverted-sounding name) and keep it as the single flag `EnemyManager` checks — but access it through `Globals`/`Events`, not a direct node reference, OR at minimum keep it since it's already boolean and clearly tutorial-specific; the priority is removing the `auto_start` reads in `game_state_manager.gd:52,75`, which are really asking "are we in the tutorial," not "should tutorial auto-start."
- Files: `Source/Systems/TutorialManager/tutorial_manager.gd`, `Source/Systems/Game/EnemyManager/enemy_manager.gd`, `Source/Systems/Game/GameStateManager/game_state_manager.gd`, `Source/Systems/Autoloads/globals.gd`.

### 2. Remove dead state / duplicate logic
- Delete `current_step_index` and `is_active` if truly unused after grep confirms no external reads — or, if `is_active` is meant to gate re-entrancy, actually use it (guard `start_tutorial()`/`play_step()` against concurrent calls) and keep `current_step_index` updated in the loop in `start_tutorial()` for debug/skip purposes.
- Extract the "apply forced dice / forced enemy actions / forced rewards" block (currently duplicated in `_ready()`'s skip loop at lines 48-58 and in `play_step()` at lines 100-110) into one `_apply_step_forcing(step: TutorialStep) -> void` helper, called from both places.
- File: `Source/Systems/TutorialManager/tutorial_manager.gd`.

### 3. Replace the enum+dictionary dispatch with per-step configuration
Current pattern: `TutorialStep.TutorialFunctions` enum + `tutorial_functions: Dictionary` in `TutorialManager` mapping enum → `Callable`. Adding a tutorial beat means touching 3 places (enum in `tutorial_step.gd`, dict entry, and a new `_foo()` method) — all in `TutorialManager`, which now also needs direct knowledge of `Globals.map`, `Globals.player`, `Globals.enemy_manager`.

Recommended: keep the enum (editor dropdown UX for designers is valuable — free-text method names in a `.tres` would be worse), but the plan is only to consolidate lookup/dispatch, not rearchitect to string-based calls. Concretely:
- Keep `tutorial_functions` dict but validate it in `_ready()`/via an `@tool` assertion that every `TutorialFunctions` enum value (except `NONE`) has a matching dict entry — catches typos/missing wiring at edit time instead of silently no-oping.
- No further restructuring needed beyond this — a full rearchitecture (e.g. splitting into per-responsibility command objects) is not worth the churn for a tutorial with ~13 actions; flag this as intentionally scoped down from "large refactor" to "guard the existing dispatch."

### 4. Add a stall/skip safety net
`start_tutorial()` awaits `current_popup.popup_closed`, which awaits whatever `close_on_signal` was configured. If that event never fires (e.g. a gameplay bug elsewhere prevents `Events.tile_activation_complete` from emitting), the tutorial hangs forever with no recovery.

- In `play_step()`, race the signal-wait against a timeout timer (e.g. `step.max_wait_time`, default e.g. 30s or 0 = no timeout) using `await` on whichever finishes first (pattern: two `create_timer`/signal awaits combined via `signal` grouping or a small helper that awaits `[timer.timeout, target_signal]` and proceeds on first). On timeout, log a warning and auto-close the popup so the tutorial doesn't soft-lock the game.
- Add optional `@export var max_wait_time: float = 0` to `TutorialStep` (0 = no timeout, opt-in per step) so this doesn't change behavior for existing steps unless explicitly set.
- Files: `Source/Systems/TutorialManager/tutorial_manager.gd`, `Source/Systems/TutorialManager/TutorialStepResources/tutorial_step.gd`.

## Verification
- `mcp__godot__validate_scripts` (scope: changed) on the modified `.gd` files to catch syntax/type errors headlessly.
- Run the project via `mcp__godot__run_project` (or the `run` skill) with `auto_start` on and step through the full intro tutorial in the editor/game window (`game_screenshot`/`game_get_logs`) to confirm: normal step progression still works, forced dice/enemy/reward steps still apply correctly, and enemy turns still auto-run once `ALLOW_NORMAL_COMBAT` fires.
- Manually verify the timeout path by temporarily setting `max_wait_time` low on one step and confirming it auto-advances with a logged warning instead of hanging.
- Confirm no remaining direct reads of `Globals.tutorial_manager.auto_start` outside `TutorialManager` itself via `grep -rn "tutorial_manager\.auto_start" Source`.
