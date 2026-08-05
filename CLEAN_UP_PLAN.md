# Clean Up Plan

## static_background_object_resource.gd
**Current responsibilities:** 
- Data container for background objects (scene reference, transform properties)
- Parallax level configuration

**Style issues:** 
- Missing `##` docstring comments (STYLE_GUIDE.md pattern shows docstrings on class_name lines)
- Blank line at start of file (line 3) — stylistic inconsistency
- Blank line before function definition (line 10) — STYLE_GUIDE.md shows no blank lines between property setters and methods

**Coupling issues:** 
- None found — pure data resource with no node references or hard-coded paths

**Split recommendation:** No — This is a pure data class (Resource subclass) with a single responsibility: storing transform + parallax configuration. It's already as small and focused as possible. No duplicated concerns, no unrelated reasons to change.

**Bugs:** 
- None found

**Suggested folder:** Libraries — This is a game-agnostic data class; could be copy-pasted into any project that needs background object configuration with parallax levels.

**Confidence:** High — The file's intent is clear: a simple data container. No reverse-dependencies visible in this file, but Resource subclasses like this are typically used by background managers for instantiation.

**Sonnet review:** Confirmed. Every claim checks out against the real 13-line file.

## background_resource.gd
**Current responsibilities:** 
- Data container for background configuration (colors, nebula, stars, debris, static objects)
- Aggregates multiple background elements into a single Resource

**Style issues:** 
- Missing `##` docstring comments (STYLE_GUIDE.md pattern shows docstrings on class_name lines)
- No blank line between category divider and first export under each category (lines 7, 11, 16, 20) — STYLE_GUIDE.md shows minimal spacing

**Coupling issues:** 
- None found — pure data resource referencing another Resource type (`StaticBackgroundObjectResource`), which is acceptable for content configuration

**Split recommendation:** No — This is a cohesive content configuration Resource. While it has many fields, they all relate to a single concept: "background definition." Changing background appearance (e.g., adding fog or changing star color) would naturally land here; no fragmentation needed.

**Bugs:** 
- None found

**Suggested folder:** Content — This file defines specific background configurations used by BackgroundManager. It depends on `StaticBackgroundObjectResource` (Library), fitting the "Content depends on Library" direction. Used to populate `background_manager.gd` scene nodes.

**Confidence:** High — The file's role as a content configuration Resource is clear. Forward-dependency (uses `StaticBackgroundObjectResource`) is visible; reverse-dependencies (who imports this) would be in BackgroundManager.

**Sonnet review:** Confirmed, with one caveat: the "no blank line between category divider and export" style claim isn't actually demonstrated anywhere in STYLE_GUIDE.md (the guide never shows `@export_category` usage), so treat it as a reasonable stylistic suggestion rather than a documented violation. See "Cross-File Findings" for a note on fabricated style rules appearing in multiple entries.

## sound_effect_resource.gd
**Current responsibilities:** 
- Data container for sound effect configuration (name, audio stream, volume, pitch settings)
- Runtime state tracking for play limits and pitch escalation
- Pitch escalation logic based on rapid successive plays

**Style issues:** 
- Missing `##` docstring comments (STYLE_GUIDE.md pattern shows docstrings on class_name lines)
- No blank line before `static var` declaration (line 17) — STYLE_GUIDE.md shows no blank lines between property declarations
- Mixed spacing around functions: blank line before `on_audio_start()` (line 24) but none before others

**Coupling issues:** 
- None found — uses only Engine APIs (`Time.get_ticks_msec()`), no hard-coded node references or Autoload calls

**Split recommendation:** Maybe — This script has two distinct concerns mixed together:
  - **Data container** (lines 4-16): configuration fields (all that's needed at design time)
  - **Runtime playback logic** (lines 18-65): play count tracking, pitch escalation (runtime-only behavior)
  
  Proposed split:
  - `SoundEffectResource.gd` → keep only data fields (lines 4-16), remove static vars and methods
  - `SoundEffectPlayerState.gd` (new file in same folder) → runtime state (lines 18-57), pitch escalation logic (lines 60-65)
  
  Why split? The static `audio_counts` dictionary implies global state management. If this is just a config Resource, the runtime state should live elsewhere (e.g., passed to SoundEffectResource at runtime or in an autoload). Currently, it's unclear who owns the state and when it resets.

**Bugs:** 
- Line 51: `recent_play_times[-1]` may crash if array is empty — should check `len(recent_play_times) > 0` first (line 51 already has check on line 51, but condition order could cause issue if written differently)
- Line 52: Array constructor syntax `Array([current_time], TYPE_INT, "", null)` is outdated; use `Array[int]([current_time])` or `[current_time]` with typed variable
- Line 65: `pitch_escalation_step` added to `current_escalation_level`, but escalation should be `pitch_scale + (escalation * pitch_scale)` or similar multiplier formula — currently returns additive value where a multiplier seems intended

**Suggested folder:** Libraries — SoundEffectResource is a game-agnostic data class for audio configuration. Pitch escalation logic could also live in a Library (SoundEffectManager) if reused across projects.

**Confidence:** Medium — The split recommendation depends on whether pitch escalation state should be per-resource-instance or shared globally. If `audio_counts` is intended to be global (shared across all SoundEffectResource instances), it should be an Autoload; if per-instance, the static should be removed. Without seeing how SFXPlayer.gd uses this, I can't confirm.

**Sonnet review:** Correction — several claims don't survive a closer read of the actual 67-line file:
- "Mixed spacing around functions" is backwards: every function (`on_audio_start`, `has_open_limit`, `on_audio_finished`, `_update_play_times`, `get_pitch_escalation`) has a consistent *double* blank line before it, matching STYLE_GUIDE.md's own convention exactly. Same for "no blank line before static var declaration" — line 16 is blank, directly before the comment on line 17 and the `static var` on line 18.
- Bug #1 is not a bug: `if len(recent_play_times) > 0 and recent_play_times[-1] < cutoff_time:` short-circuits correctly in GDScript — it never indexes an empty array.
- Bug #2 is not a bug: `Array([current_time], TYPE_INT, "", null)` is valid, current Godot 4 typed-array constructor syntax (`mcp__godot__validate_script` confirms zero errors), just more verbose than `[current_time]` would be given `recent_play_times` is already declared `Array[int]`.
- Bug #3 is factually wrong: line 65 is `current_escalation_level * pitch_escalation_step` — a multiplication, not the addition the claim describes.
- Split recommendation is overreach: at 67 lines with two related concerns, this doesn't meet local_prompt.md's own split criteria (250-300 lines, 3+ unrelated responsibility categories). The underlying observation is still worth keeping, just reframed: a `Resource` subclass holding `static var audio_counts` as de facto global state is architecturally odd for a data container — the more likely fix is moving play-count tracking into the `SFXPlayer` autoload (which already owns playback), not splitting into two Resource files.

## game_save.gd
**Current responsibilities:** 
- Data container for save file state (player stats, money, tile placements, map progress)
- Aggregates game state across multiple systems (Player, TileGrid, Map)

**Style issues:** 
- Missing `##` docstring comments (STYLE_GUIDE.md pattern shows docstrings on class_name lines)
- No blank line between category dividers and exports (lines 4, 14) — STYLE_GUIDE.md shows minimal spacing

**Coupling issues:** 
- Line 12: Direct dependency on `TileResource` (Content) — save/load must serialize/deserialize tile positions to resources
- Line 16: Direct dependency on `ScenarioResource` (Content) — scenario index and Array<ScenarioResource> implies save/load of entire scenario chain

**Split recommendation:** No — This is a cohesive data container for serialization. While it aggregates multiple systems, all fields relate to "save game state" and would change together (e.g., adding a new player stat or tile feature would touch this file). Splitting would add indirection without reducing coupling.

**Bugs:** 
- None found

**Suggested folder:** Systems — SaveResource is part of the gameplay persistence system. It depends on Content Resources (TileResource, ScenarioResource) but defines the contract for how game state flows between runtime and storage. It's not "content" itself (no level-specific data), nor "Library" (tied to Die Fighter's specific save format).

**Confidence:** High — The file's role as a save game container is clear. Forward-dependencies on Content Resources are visible; reverse-dependencies would be in GameStateManager or SaveManager.

**Sonnet review:** Confirmed. One naming note that's out of scope for a single-file pass: the class is `GameSaveResource` but the file is `game_save.gd` — every sibling Resource in this batch names its file after its full class name including the "Resource" suffix. See "Cross-File Findings."

## enemy_state_reward_resource.gd
**Current responsibilities:** 
- Data container for enemy spawn configuration (enemy resource, path location, starting state, reward)
- Used to define enemy instances when spawning into a scenario

**Style issues:** 
- Missing `##` docstring comments (STYLE_GUIDE.md pattern shows docstrings on class_name lines)

**Coupling issues:** 
- Line 4: Direct reference to `EnemyResource` (Content) — required for spawn logic
- Line 6: Direct reference to `ScenarioShipState` (Content) — runtime state class, not a Library

**Split recommendation:** No — This is a small, focused data container (only 7 lines). All fields relate to single responsibility: "enemy spawn setup." No duplicated concerns or unrelated reasons to change.

**Bugs:** 
- None found

**Suggested folder:** Content — This file defines enemy configurations for specific scenarios. It depends on `EnemyResource` and `ScenarioShipState` (both Content), so it fits in the Content layer as a "spawn recipe" for enemies.

**Confidence:** High — The file's role as an enemy spawn configuration Resource is clear. Forward-dependencies on Content Resources are visible; reverse-dependencies would be in EnemyManager.

**Sonnet review:** Confirmed. Minor addition: line 7 (`reward_resource: RewardResource`) is also a Content dependency, not mentioned in the original pass — doesn't change the verdict.

## scenario_ship_state.gd
**Current responsibilities:** 
- Concrete implementation of ScenarioShipStateBase for normal state transitions
- Stores dialogue, faction, attitude, and transition mappings
- Handles ScenarioEvent-driven state changes (including probability transitions)

**Style issues:** 
- Missing `##` docstring comments (STYLE_GUIDE.md pattern shows docstrings on class_name lines)
- No blank line before function definition (line 12) — STYLE_GUIDE.md shows minimal spacing

**Coupling issues:** 
- Line 5: Direct dependency on `ScenarioManager.Faction` enum — hard-wired to Autoload enum
- Line 6: Direct dependency on `Enemy.Attitude` enum — hard-wired to another Content class enum
- Line 7: Direct reference to `EffectChain` (legacy) — should use EffectChainV2 per refactoring status

**Split recommendation:** No — This is a small, focused state implementation (24 lines). All fields and methods relate to single responsibility: "state definition with transitions." Splitting would add unnecessary indirection.

**Bugs:** 
- Line 18: Type annotation `next_state: ScenarioShipStateBase` but returns `ScenarioShipState` on line 21 — mismatch if ProbabilityTransition returns a different subtype
- Line 18: No null check after `next_state = next_state.get_next_state_from_probabilities()` — could return null if probabilities don't sum to 1

**Suggested folder:** Content — This is a concrete state implementation used by enemy scenarios. It depends on `ScenarioShipStateBase` (same folder), `ScenarioManager` (System/Autoload), and `Enemy` (Content), fitting "Content depends on Systems" direction.

**Confidence:** Medium — The file's role as a state definition is clear, but I'm inferring that `ScenarioShipStateBase` defines the interface. Without reading the base class, I can't confirm if all subclasses follow the same pattern.

**Sonnet review:** Correction — several claims don't hold up:
- "No blank line before function definition (line 12)" is backwards: there are two blank lines (lines 10-11) before `handle_scenario_event`, matching STYLE_GUIDE.md's convention.
- The `EffectChain` (legacy) coupling catch on line 7 is accurate and genuinely valuable — it ties directly to the in-progress `effect_chain_v2` migration described in ARCHITECTURE_OVERVIEW.md and visible in recent commits.
- Bug #2 (possible null return) doesn't hold: `get_next_state_from_probabilities()` always returns a valid state via its fallback (see the `scenario_ship_state_probability_transition.gd` review below) unless `weighted_probabilities` is empty — a content-authoring risk, not a code-logic bug.
- Bug #1 (type looseness: `next_state: ScenarioShipStateBase` returned where `-> ScenarioShipState` is declared) is real but harmless in practice: `mcp__godot__validate_script` reports zero errors on this file, and the only two `ScenarioShipStateBase` subclasses in the codebase are already resolved correctly by the `is ScenarioShipStateProbabilityTransition` check.

## scenario_ship_state_base.gd
**Current responsibilities:** 
- Abstract base class for ScenarioShipState types (no implementation visible)
- Extends Resource — intended to be used as a data resource for state configs

**Style issues:** 
- Missing `##` docstring comments (STYLE_GUIDE.md pattern shows docstrings on class_name lines)

**Coupling issues:** 
- None found — pure base class with no dependencies

**Split recommendation:** No — This is 2 lines; no split needed. It's a clear abstract base class pattern.

**Bugs:** 
- None found

**Suggested folder:** Content — This is part of the enemy state transition system, which is scenario-specific content logic (not reusable across games). Used by `scenario_ship_state.gd` and `scenario_ship_state_probability_transition.gd`.

**Confidence:** High — The file's role as an abstract base class is clear from naming and inheritance. No reverse-dependencies visible in this file.

**Sonnet review:** Confirmed. Two lines, nothing to add.

## scenario_ship_state_probability_transition.gd
**Current responsibilities:** 
- Probability-based state transition implementation for enemy scenarios
- Selects next state from weighted dictionary of states-to-probabilities

**Style issues:** 
- Missing `##` docstring comments (STYLE_GUIDE.md pattern shows docstrings on class_name lines)
- No blank line before function definition (line 7) — STYLE_GUIDE.md shows minimal spacing
- Line 20: Missing blank line after `return state` — STYLE_GUIDE.md shows no blank lines between return and next statement

**Coupling issues:** 
- Line 4: Direct dependency on `ScenarioShipState` (Content) — required for transition dictionary

**Split recommendation:** No — This is a clear-weight probability selection algorithm (29 lines). Single responsibility: "weighted random state selection." No unrelated concerns.

**Bugs:** 
- Line 8: `weighted_probabilities.values()` returns a Dictionary.Values iterator, not an Array — `Array[float]` cast required or use `.values().array()`
- Line 17: `randf_range(0, prob_sum)` may select value equal to `prob_sum`, which would fall off the end since checks use `<=` on line 19
- Line 27: Dead code warning — function always returns earlier (line 20), unreachable code

**Suggested folder:** Content — This is part of the enemy state transition system, used by `scenario_ship_state.gd` to handle probability-based transitions. It's scenario-specific logic, not reusable across games.

**Confidence:** High — The file's role as a probability Transition is clear. Forward-dependency on `ScenarioShipState` is visible; reverse-dependencies would be in the state machine usage.

**Sonnet review:** Correction — none of the three claimed bugs survive a closer read, and the style claims are backwards:
- "No blank line before function (line 7)" and "missing blank line after `return state` (line 20)" are both backwards — the actual spacing matches STYLE_GUIDE.md's double-blank-line convention in both places (this is the third file in this batch with this exact false-positive; see "Cross-File Findings").
- Bug #1 is wrong: `Dictionary.values()` returns a real `Array` in GDScript 4, not an iterator — no cast needed. `mcp__godot__validate_script` confirms this compiles with zero errors.
- Bug #2 is backwards: using `<=` is the *correct* choice given `randf_range()` is inclusive on both ends. `<` would be the version that risks falling off the end, not `<=`.
- Bug #3 is wrong: lines 24-27 are not dead/unreachable code — they're a defensive fallback for the loop completing without a match (e.g. float rounding in the accumulated `prob_sum`), reachable whenever no `state` satisfies the `<=` check. The one genuine (minor) edge case is an *empty* `weighted_probabilities` dict falling through to `.pick_random()` on an empty array — a content-authoring risk, not a logic bug.

## scenario_resource.gd
**Current responsibilities:** 
- Data container for scenario configuration (map icon, background, starting enemies, faction rewards)
- Tracks scenario-specific seed for deterministic RNG

**Style issues:** 
- Missing `##` docstring comments (STYLE_GUIDE.md pattern shows docstrings on class_name lines)

**Coupling issues:** 
- Line 5: Direct dependency on `RandomBackgroundResource` (Content) — required for background selection
- Line 7: Direct dependency on `EnemyStateRewardResource` (Content) — enemy spawn configuration
- Line 9: Direct reference to `ScenarioManager.Faction` enum and `RewardResource` (Content) — faction reward mapping

**Split recommendation:** No — This is a small, focused scenario config container (11 lines). All fields relate to "scenario definition" — no unrelated concerns.

**Bugs:** 
- None found

**Suggested folder:** Content — This defines specific scenarios for gameplay. It aggregates EnemyStateRewardResource (Content), RewardResource (Content), and uses ScenarioManager (System) enums, fitting "Content depends on Systems."

**Confidence:** High — The file's role as a scenario configuration Resource is clear. Forward-dependencies on Content Resources are visible; reverse-dependencies would be in ScenarioManager.

**Sonnet review:** Confirmed. All field/dependency claims match the real 11-line file.

## tile_event.gd
**Current responsibilities:** 
- Data container for tile event types and configuration
- Defines when tiles should respond to game events (turn start, push, manual move, fatal damage)

**Style issues:** 
- Missing `##` docstring comments (STYLE_GUIDE.md pattern shows docstrings on class_name lines)
- `listen_only_for_self` field name uses snake_case — STYLE_GUIDE.md uses camelCase for local variables

**Coupling issues:** 
- None found — pure data Resource with no node references or hard-coded paths

**Split recommendation:** No — This is 12 lines defining enum + 2 config fields. Single responsibility: "tile event definition." No split needed.

**Bugs:** 
- Line 8: `ON_PLAYER_FATAL_DAMAGE = 100` — unusual to assign non-sequential values without clear gap (e.g., 100 is far from 7). Consider `ON_TILE_MANUALLY_MOVED = 10` and increment, or use explicit values only for special cases

**Suggested folder:** Content — TileEvent defines the event types for tile responses. It's part of the tile system, which is scenario-specific content logic. Not reusable across games without tile event patterns.

**Confidence:** High — The file's role as an event type Definition Resource is clear. Forward-dependencies would be in Tile.gd; reverse-dependencies not visible in this file.

**Sonnet review:** Correction — both flagged items should be retracted:
- The style claim is backwards: STYLE_GUIDE.md uses **snake_case** throughout for variables and functions (`is_active`, `_state_name`, `target_state_path` in the reference example), not camelCase. `listen_only_for_self` is correctly styled, not a violation.
- `ON_PLAYER_FATAL_DAMAGE = 100` isn't a bug — reserving a value range for a rare/special enum case is a common, deliberate pattern (leaves room to grow the sequential group without a future collision).

## tile.gd
**Current responsibilities:** 
- Core tile behavior: activation logic, drag/drop, visual states, event responses (TODO)
- Manages uses remaining, visual feedback (gray out), and dice queue integration
- Handles die placement by enqueuing TileActivationEvent to ScenarioEngine

**Style issues:** 
- Missing `##` docstring comments (STYLE_GUIDE.md pattern shows docstrings on class_name lines)
- Line 13: `_saturation_tween` uses underscore prefix (private) — STYLE_GUIDE.md doesn't show private variable convention; assume it's acceptable
- Line 29-30: Comment says "tile_data" but variable is named `effect_data` — misleading comment

**Coupling issues:** 
- Line 5: Hard-coded path for SFX preload — should be a TileResource field or passed at runtime
- Lines 51-54, 56-59: Inline lambdas with signal connections — fine for small cases, but mixing UI (Events.show_info) here couples presentation logic to tiles
- Line 129: Calls `Events.error_text_popup.emit()` directly — tile shouldn't know about this Autoload; should emit a generic "activation_failed" signal
- Lines 220-237: `set_gray_out()` has unused variables (`outer_radius`, `strength` in if/else branches) — logic is incomplete (lines 214-218 set values but they're not used)

**Split recommendation:** Yes — This script has 241 lines with multiple responsibilities:
  - **Tile behavior** (lines 7-43): core fields, components, and _ready setup
  - **Activation handling** (lines 108-198): event responses, die acceptance, ScenarioEngine queueing  
  - **Visual state management** (lines 205-240): highlight, gray_out, saturation tweens

  Proposed split:
  - `tile.gd` → keep fields, _ready, signal wiring (lines 1-74), remove event handling logic
  - `tile_activation.gd` (new file) → move `_connect_tile_event_signals()` and `handle_tile_event()` to new file, extend Tile via group or signal routing
  - `tile_visuals.gd` (new file) → move `set_highlight()`, `set_gray_out()`, saturation tween logic

  Why split? These are independent concerns: activation logic shouldn't break if visual changes are tweaked, and event signal wiring could be centralized in a TileSystem autoload.

**Bugs:** 
- Line 16: `tile_resource.uses_per_combat` used before tile_resource is set — setter calls `tile_resource` but it may be null on first call
- Line 94: References `Globals.state_manager` directly — should use signal or passed context
- Line 127-130: `error_text_popup` called for each failed check — spams popup if multiple activation checks fail
- Lines 214-218: `outer_radius`, `strength` variables set but never used in `set_gray_out()` — likely leftover code, should remove or complete implementation

**Suggested folder:** Content — Tile is the core content class for gameplay logic. It depends on TileResource (Content), Draggable/Clickable/Shakeable (Systems/Components), and ScenarioEngine (Systems/Game). Fits "Content depends on Systems."

**Confidence:** Medium — I'm inferring that event signal wiring should be split based on architectural concerns, not line count alone. The file works as-is but has coupling between activation logic and visual state.

**Sonnet review:** Correction — several claims need adjustment on this, the largest file in the batch:
- The "misleading comment" catch (line 28 says `tile_data`, the variable is `effect_data`) is accurate and worth keeping — genuine leftover-from-a-rename issue.
- The `set_gray_out()` "unused variables" bug is wrong: `outer_radius` and `strength` ARE used, in the two `tween_property()` calls at lines 229 and 235. The function is complete, not incomplete — the local pass appears to have stopped reading partway through the function body.
- The `clears_activation_criteria()` "spams popup" bug is wrong: every failed-check path does `emit()` then `return false` immediately, so at most one popup fires per call — it can never reach a second check.
- The `Events.error_text_popup` and `Globals.state_manager` "coupling" complaints are overstated. `Events` and `Globals` are this project's documented Systems-tier singletons (central signal bus / system registry, per ARCHITECTURE_OVERVIEW.md) — this exact file already calls `Events.X.emit()` five other times (lines 52, 58, 190, plus the two flagged). Singling out two of seven equivalent calls isn't a real coupling problem; it's the codebase's established pattern. See "Cross-File Findings" — this same blind spot shows up in `scenario_ship_state.gd` too.
- The `uses_remaining` null-`tile_resource` initialization-order concern (line 16) is plausible but not fully confirmable from static reading — GDScript's setter-on-declared-default timing is subtle. `_ready()`'s `assert(tile_resource)` before `_set_up_resource()` likely prevents it in the normal instantiation path. Worth a quick runtime check before treating it as certain; not worth deep static speculation.
- Split recommendation: reasonable in principle, but the proposed `tile_activation.gd` extraction is premature — `handle_tile_event()` is currently a complete no-op stub (the real logic is commented out pending the `effect_chain_v2` rework), so there's nothing live to extract yet. If/when the visual half (`set_highlight`/`set_gray_out`) is split out, it should follow this codebase's existing `Systems/Components/` pattern (Shakeable, Draggable, Clickable — all already used by this very file) rather than an ad hoc `tile_visuals.gd`.

## Cross-File Findings & Low-Hanging Fruit

**1. The local pass repeatedly flags this project's own sanctioned Systems-tier dependencies as "coupling issues."**
`tile.gd` gets dinged for calling `Events.error_text_popup.emit()` and reading `Globals.state_manager` directly; `scenario_ship_state.gd` gets dinged for depending on `ScenarioManager.Faction` and `Enemy.Attitude` enums. But per ARCHITECTURE_OVERVIEW.md, `Events` and `Globals` *are* this project's documented Systems-tier singletons (the central signal bus and system registry, respectively), and the local model's own stated rule is "Content depends on Systems" is the correct direction — these are exactly that. `tile.gd` even uses `Events.X.emit()` five other times in the same file without complaint, so the two flagged instances aren't actually distinguishable from the "fine" ones. This isn't five unrelated bugs — it's one recurring blind spot: the "hardcoded autoload = coupling smell" heuristic doesn't distinguish *problematic* coupling (bypassing signals to reach into unrelated node internals) from *expected* coupling (Content using a project-wide Systems API it was designed to use). Worth keeping in mind for the rest of the per-file pass — expect more of these as it works through Content-tier scripts.

**2. A second, independent local-pass blind spot: false "missing blank line before function" claims.**
Three separate files in this batch — `sound_effect_resource.gd`, `scenario_ship_state.gd`, and `scenario_ship_state_probability_transition.gd` — were each flagged for missing a blank line before a function definition, and in all three cases the real file has the correct double-blank-line spacing that STYLE_GUIDE.md itself demonstrates. This looks like a mechanical read error (possibly miscounting blank/whitespace-only lines) rather than an isolated mistake. Worth spot-checking blank-line claims specifically as the remaining files come in.

**3. Some style claims aren't actually supported by STYLE_GUIDE.md, and one contradicts it outright.**
`background_resource.gd` and `game_save.gd` both cite a "no blank line between category divider and export" rule that STYLE_GUIDE.md never actually demonstrates (it has no `@export_category` example at all) — treat these as reasonable suggestions, not documented violations. More seriously, `tile_event.gd`'s claim that "STYLE_GUIDE.md uses camelCase for local variables" is flatly false — the guide is snake_case throughout (`is_active`, `_state_name`, `target_state_path`). Any future file citing a "camelCase" violation should be treated as suspect by default.

**4. Confidence ratings are systematically miscalibrated against the local pass's own rule.**
local_prompt.md states: "You can't see reverse dependencies... so default to Medium/Low confidence [on folder placement] unless the file's full dependency picture is visible in what you're reading." Yet 8 of these 11 entries are rated "High" confidence while their own reasoning text explicitly admits reverse-dependencies aren't visible (e.g. "reverse-dependencies would be in BackgroundManager," "reverse-dependencies not visible in this file"). Only the two files where the local model was genuinely uncertain about something else (`sound_effect_resource.gd`'s static state, `scenario_ship_state.gd`'s base-class inference) landed on Medium — but that's not why the rule calls for Medium/Low here. This doesn't change any of the actual placements (which all look correct on review), but the confidence labels shouldn't be read as "folder placement is well-verified" — none of these 11 files had reverse dependencies visible from a single-file read.

**5. Naming inconsistency: `game_save.gd` breaks this codebase's file-naming convention.**
Every other Resource subclass in this batch names its file after its *full* class name in snake_case: `StaticBackgroundObjectResource` → `static_background_object_resource.gd`, `BackgroundResource` → `background_resource.gd`, `SoundEffectResource` → `sound_effect_resource.gd`, `EnemyStateRewardResource` → `enemy_state_reward_resource.gd`, `ScenarioResource` → `scenario_resource.gd`. But `GameSaveResource`'s file is `game_save.gd`, dropping the "Resource" suffix. This is invisible to a per-file pass (nothing wrong with the file in isolation) and only shows up when the files are lined up side by side. Trivial fix: rename to `game_save_resource.gd` (and update the one `.tres`/reference that points at it) for consistency — low-risk, low-effort, do it whenever convenient.

**6. No genuine "two split candidates solving the same problem" found in this batch.**
Only `tile.gd` (Yes) and `sound_effect_resource.gd` (Maybe) were flagged as split candidates in this set of 11, and they don't overlap — one is presentation/state-wiring, the other is a Resource-holding-global-state problem. However: if `tile.gd`'s visual half (`set_highlight`/`set_gray_out`) does get split out eventually, it should land in `Source/Systems/Components/` alongside `Shakeable`, `Draggable`, `Clickable`, `CanAcceptDice`, `Health`, `HealthBarController`, and `DiceQueue` — this project already has an established, working pattern for exactly this kind of composable node behavior, and `tile.gd` already uses four of those components. Don't invent a parallel "tile_visuals.gd" convention when the right folder and pattern already exist.

**7. Dead code confirmed, not just suspected: `tile.gd`'s `handle_tile_event()` is a complete no-op.**
The entire body is commented out except `pass` (lines 108-118). This means `_connect_tile_event_signals()` (lines 75-87) is currently wiring up four signal listeners that call into a function that does nothing — dead weight at runtime, not just an incomplete TODO. This is already implicitly known (ARCHITECTURE_OVERVIEW.md notes the hook as "disabled, TODO"), but worth stating plainly: don't refactor or split this code path yet (see the `tile.gd` review above) — wait until it's reimplemented for `effect_chain_v2`, since right now there's nothing real to preserve or extract.

**8. Migration debt marker worth tracking as the pass continues.**
`scenario_ship_state.gd` still exports `effects_on_enter: EffectChain` (the legacy chain type). Given the recent commit history ("Mostly transition enemy actions to effect_chain_v2. Needs intents") shows this migration actively in progress elsewhere, expect more `EffectChain`-typed fields to surface as the remaining ~90 files get analyzed. Worth aggregating these into a single migration checklist rather than treating each as an isolated per-file "coupling issue" — that's a more useful shape for actually tracking the refactor's completion.

## Recommended for Fable Review

- **`tile.gd`'s restructuring timing, in the context of the live `effect_chain_v2` migration.** This is the largest and most architecturally central file reviewed so far (it's the entry point for the core tile-activation pipeline described in ARCHITECTURE_OVERVIEW.md §4.4), and it currently straddles both the legacy and refactored systems (`handle_tile_event()` disabled/stubbed, `_on_die_accepted()` already wired to the new `ScenarioEngine`/`TileActivationEvent` path). Whether to split now, split after the v2 rework lands, or leave it alone entirely is a sequencing call that depends on the shape of the rest of the in-flight migration — not something visible from this file or even this batch alone.

- **Whether the `Events`/`Globals` autoload-heavy pattern (Cross-File Finding #1) is a long-term risk worth actively reducing, or the correct call for a solo-dev project at this scale.** This recurs constantly and will keep recurring across the ~90 remaining files. It's worth one whole-codebase judgment call early — rather than the local pass re-litigating "is this coupling" file by file for the rest of the pass — on whether heavy signal-bus/autoload-registry usage is a deliberate, appropriate tradeoff here (per ARCHITECTURE_OVERVIEW.md's own stated architecture) or a smell that should start getting reduced as the codebase grows past what one signal bus can stay legible for.

- **The `EffectChain` → `EffectChainV2` migration's actual completion state across Content resources** (Cross-File Finding #8). This is squarely the kind of "does the refactor plan in ARCHITECTURE_OVERVIEW.md actually resolve what's being surfaced" question the Fable pass is meant to answer holistically, once more instances have accumulated from the rest of the file list.










