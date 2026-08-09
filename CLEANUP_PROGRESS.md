# Cleanup Progress Tracker

Source docs: `CLEAN_UP_PLAN.md` (per-file detail, 101 files analyzed), `GLOBAL_CLEANUP_PLAN.md`
(cross-cutting/architectural), `tutorial_cleanup.md` (TutorialManager-specific). This file is
the checklist — go here to see *what's left and in what order*; go to the source docs when you
need the full reasoning/line numbers for a specific item.

**How to use this:** work top to bottom within a phase, but phases themselves don't have to be
done in one sitting each — pick whatever phase matches the energy/time you have today. Phase 0
items are all small and independent, good for a spare 20 minutes. Later phases need more focus.

Check items off as `[x]` as you go. If you skip something intentionally, leave a note instead of
just leaving it unchecked, so future-you knows it was a decision, not an oversight.

---

## Phase 0 — Bug fixes & dead-code deletes (do these first)

Small, low-risk, high-value, mostly single-file. No architecture decisions required — just do
them. This phase alone fixes the single most impactful bug in the whole review.

- [X] **Global RNG determinism bug** — delete `seed('Die Fighter'.hash())` from `main_menu.gd:32`.
      This is currently making every playthrough generate identical sectors/enemies/dice/backgrounds.
      *(GLOBAL_CLEANUP_PLAN.md #4, CLEAN_UP_PLAN.md Top Finding #1)*
- [X] **`opening_cutscene.gd` particle bug** — `_player_ship_hit()` adds `particles` to the tree
      twice instead of adding the `explosion` node; `explosion` leaks. (`CLEAN_UP_PLAN.md` →
      `opening_cutscene.gd`)
- [X] **Fix `Addons/` casing** — rename folder to lowercase `addons/` to match `project.godot`
      and the plugin's own preload path (works today only because macOS is case-insensitive).
      *(GLOBAL_CLEANUP_PLAN.md #6)*
- [X] **Delete dead duplicate `engine_charger.gd`** at `Source/Systems/Game/EngineCharger/` +
      its orphaned `.tscn`; move the real one in from `MainViewer/` and update
      `main_viewer.tscn`'s ext_resource path. *(GLOBAL_CLEANUP_PLAN.md #7)*
- [X] **Delete dead `FactionSystem`** (`Source/Content/Enemies/faction_system.gd`) — confirmed
      unreferenced anywhere; `ScenarioManager.Faction` is the real one in use.
      *(GLOBAL_CLEANUP_PLAN.md #10)*
- [ ] **Remove dead `Globals.jump_manager` singleton registration** — confirmed 0 external reads.
      *(GLOBAL_CLEANUP_PLAN.md #19)*
- [ ] **Remove redundant `scenario_state = new_state` line** in `enemy.gd` (`_handle_scenario_event`,
      ~line 106) — dead reassignment.
- [ ] **`action_popup.gd`** — either wire the unused `@export var sprite` into the tween code, or
      delete it; currently the tween hardcodes `$Sprite2D` and the export does nothing.
- [ ] **Register or remove the "Receive Die from Target" dropdown option** — `effect_registry.gd`
      has 9 handlers for `DICE_CONTROL` but the inspector plugin lists 10; check
      `effect_enums.gd`'s `DiceControlSubtype` to see which one is missing a handler.
      *(GLOBAL_CLEANUP_PLAN.md #13)*
- [ ] **Implement `pause_menu.gd`'s `_save_game()`** — currently just `print('Saving game!')`
      despite being wired to a "Save and Quit" button. *(GLOBAL_CLEANUP_PLAN.md #14)*
- [ ] **Implement or delete `Draggable.snap_back()`** — currently an empty stub; a passive
      per-frame homing lerp elsewhere may already cover this, confirm before implementing.
      *(GLOBAL_CLEANUP_PLAN.md #12)*
- [ ] **`enemy.gd` `activating_die_number` bug** — the early-return path in
      `generate_turn_actions()` (when forced actions already fill all 6 slots) skips the shuffle
      and the loop that assigns `activating_die_number`, so intent/hint UI could show stale values
      for that case. Worth a fix or at least a verified "doesn't happen in practice" note.
- [ ] Sweep the small style nits noted throughout `CLEAN_UP_PLAN.md` (single-blank-line-before-func
      violations) — optional, batch these into one pass if you care about it; not worth tracking
      individually here.

---

## Phase 1 — Cross-cutting architecture (`GLOBAL_CLEANUP_PLAN.md`)

Bigger than Phase 0 but still scoped and independent of each other. Do in roughly this order —
earlier items unblock or simplify later ones.

- [ ] **#16 — Centralize scenario RNG seeding.** Root-cause fix for the class of bug #4 was an
      instance of. One call site (`ScenarioManager._load_scenario()`, or a small `ScenarioRNG`
      service) seeds `Dice`/`Enemy`/`BackgroundManager` instead of three independent call sites.
- [ ] **#1 — Split `UIEvents` autoload out of `Events.gd`.** Start with just `error_text_popup`;
      decide later whether to keep splitting further.
- [ ] **#2 — Simplify `error_popup_manager.gd`** (single-popup storage, layout-timing fix,
      `show_error` rename, centering-math cleanup). Natural follow-on to #1.
- [ ] **#3 — Move `PauseMenu` into the `UI` CanvasLayer** instead of being a `Main`-level sibling
      that only looks correct because the camera never pans/zooms.
- [ ] **#15 / #21 — Extract `SectorGenerator` out of `GameStateManager`.** 8 of 9 exported fields
      are sector-gen config, not state-machine concerns.
- [ ] **#20 — Move `GameAnimationPlayer`** to be a direct child of `Main` instead of nested under
      `GameStateManager` (its `root_node` already points at `Main`).
- [ ] **#17 — Document or restructure the `ScenarioEngine.finished_processing_queue` /
      `Events.enemy_turn_over` joint** in `enemy_manager.gd`. Either a doc comment or have
      `EnemyManager` own its own completion signal.
- [ ] **#11 / #18.4 — Consolidate `TileResource` directory scanning**, currently duplicated
      across `dev_console.gd` (x2) and `reward_manager.gd`.
- [ ] **#18.1 — Consolidate starfield generation** (3 near-identical copies in
      `opening_cutscene.gd`, `capsule_mockup.gd`, `main_menu.gd`). Decide first whether the
      cutscene's different position formula is intentional.
- [ ] **#18.2 — Consolidate flash-by-color effects** (`enemy_graphics_manager.gd`, `vignette.gd`
      into one `_flash(color)` each; `button.gd` into a shared `_apply_wave_text(...)` helper).
- [ ] **#18.3 — Consolidate options-menu label↔value lookup tables** into a shared
      `options_maps.gd` (animation speed, FPS limit, window scale — each duplicated 2-3x across
      `options_menu.gd` / `options_saving_manager.gd`).
- [ ] **#18.5 — Wishlist button dedup** — one `Globals.STEAM_STORE_URL` const or `Utils.open_wishlist()`
      instead of two copies of the URL.
- [ ] **#18.6 — `main_viewer.gd` tab-pair mirroring** — small `TabButton`-style component owning
      label/frame/hover-color state, instantiated twice.
- [ ] **#22 — Remove or document `MouseCursor`'s `z_index = 1000`** in `main.tscn`.
- [ ] **#23 — Standardize UI packaging**: wrap `GlitchShader`, `FPSCounter`, `MouseCursor`,
      `FadeIn` into their own `.tscn` files to match `InfoShower`/`DevConsole`/`GameOver`.
- [ ] **#8 — Rename resource files to match convention** (`game_save.gd` → `game_save_resource.gd`,
      `InfoResource.gd` → `info_resource.gd`). Update all `ext_resource`/`preload`/`load` refs.
- [ ] **#9 — Relocate data-only Resource classes into `Source/Content/`** (`BackgroundResources/`
      group, `sound_effect_resource.gd` after deciding Content-vs-Libraries, `game_save_resource.gd`,
      `reward_resource.gd`).
- [ ] **#5 — Clarity-only:** `health.gd:67` — replace `clampi(shields, 0, shields)` with
      `maxi(shields, 0)`. Not a bug, just a misreadable expression.

---

## Phase 2 — Tutorial system cleanup (`tutorial_cleanup.md`)

Self-contained — safe to do as its own pass whenever, independent of Phases 0/1/3. Do in this
order since each step's verification benefits from the previous step being done.

- [ ] **1. Decouple gameplay code from tutorial internals** — add `Globals.tutorial_active`
      (or an `Events.tutorial_mode_changed` signal); stop `game_state_manager.gd`/`enemy_manager.gd`
      from reading `Globals.tutorial_manager.auto_start` directly.
- [ ] **2. Remove dead state / duplicate logic** — resolve `current_step_index`/`is_active`
      (delete if unused, or actually use `is_active` as a re-entrancy guard); extract the
      duplicated forced-dice/enemy/reward-applying block into one `_apply_step_forcing()` helper.
- [ ] **3. Guard the enum+dictionary dispatch** — add an `@tool`-time assertion that every
      `TutorialFunctions` enum value has a matching `tutorial_functions` dict entry. (Explicitly
      *not* a full rearchitecture — scope stays here.)
- [ ] **4. Add a stall/skip safety net** — race `popup_closed` against an optional
      `step.max_wait_time` timer in `play_step()`; auto-close + warn on timeout instead of
      soft-locking.
- [ ] **Verify:**
  - [ ] `mcp__godot__validate_scripts` on changed files
  - [ ] Run the project with `auto_start` on, step through the full intro tutorial
  - [ ] Confirm forced dice/enemy/reward steps still apply correctly
  - [ ] Confirm enemy turns still auto-run once `ALLOW_NORMAL_COMBAT` fires
  - [ ] Temporarily set `max_wait_time` low on one step, confirm timeout auto-advances w/ warning
  - [ ] `grep -rn "tutorial_manager\.auto_start" Source` returns nothing outside `TutorialManager`

---

## Phase 3 — File splits (from `CLEAN_UP_PLAN.md`)

These are the "this file is doing too much" findings. Ordered roughly by confidence/value — the
`Yes` ones are the clearer calls, `Maybe` ones are judgment calls, read the full reasoning in
`CLEAN_UP_PLAN.md` before starting each one since the extraction boundaries matter more than the
checkbox.

**Clear splits (`Yes`):**
- [ ] `tile.gd` (~230 lines) — extract `_replace_event_data_in_string()` → `utils.gd`; extract
      visual/juice methods → `TileVisuals` component; extract event dispatch → `TileEventDispatcher`.
- [ ] `options_menu.gd` (259 lines) — split into `GameOptionsTab`/`GraphicsOptionsTab`/`AudioOptionsTab`,
      `OptionsMenu` becomes a thin coordinator. Pairs well with Phase 1's #18.3 lookup-table dedup.
- [ ] `dev_console.gd` (542 lines) — extract command implementations into per-domain scripts
      (`DevConsoleTileCommands`, `DevConsolePlayerCommands`, `DevConsoleEnemyCommands`,
      `DevConsoleMiscCommands`); keep UI mechanics in `dev_console.gd`.
- [ ] `utils.gd` (264 lines) — separate generic helpers, game-asset-path/BBCode logic, the
      delay-tag character-alignment subsystem, and the dice-sort helper.
- [ ] `map.gd` (314 lines) — extract `MapCameraMath`, `MapSpriteBuilder`, `MapCorruptionTracker`.

**Judgment calls (`Maybe` — read the reasoning before deciding):**
- [ ] `enemy.gd` — consider extracting `generate_turn_actions()` + `forced_actions`/`rng` into
      `EnemyTurnActionGenerator`.
- [ ] `main_viewer.gd` — may shrink enough from the #18.6 dedup alone; otherwise extract a
      `TabButton`-style component.
- [ ] `game_state_manager.gd` — covered by Phase 1's #15/#21 (`SectorGenerator` extraction).
- [ ] `targeting_computer.gd` (252 lines) — lowest-risk piece is extracting the startup/reveal
      tween logic; the intent-icon UI builder is a closer call.
- [ ] `player.gd` (221 lines) — the drag-based dice-queue-reordering logic in `_process()` is a
      plausible self-contained extraction.
- [ ] `draggable.gd` (175 lines) — the floating/idle-bob animation subsystem could become a
      `FloatingIdleAnimator` component.
- [ ] `tutorial_manager.gd` — narrow: break `play_step()` into named helper steps. Do this
      alongside Phase 2 rather than separately.
- [ ] `background_manager.gd` (289 lines) — hyperspace jump-sequencing logic could move into
      `jump_transition.gd`, which already exists for the visual side.

---

## Phase 4 — Everything else / long tail

Lower-value or purely cosmetic items from `CLEAN_UP_PLAN.md` not called out above: remaining
style nits (blank-line-before-function spacing), the `sound_effect_resource.gd` audio-count
decrement-on-early-exit risk (worth verifying against `SFXPlayer` usage), the
`scenario_ship_state.gd` return-type covariance risk, and similar "worth verifying" notes
scattered through the per-file entries. Treat this phase as "read CLEAN_UP_PLAN.md again once
Phases 0-3 are done and see what's left that still bugs you" rather than a fixed list — most of
it is genuinely optional polish.

---

## Notes / decisions log

*(Add a line here whenever you deliberately skip or defer something, so it doesn't look like an
oversight later.)*

-
