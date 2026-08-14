# Multi-Sector Jump Gate Progression — Path to a Playable Demo

## Context

The game currently has a solid combat/content layer (tiles, enemies, the Effect Chain v2 pipeline) but no real progression: `GameStateManager._randomize_sector_scenarios()` builds exactly one linear sector ending in a boss fight, and defeating the boss only flips a UI label to "VICTORY!" — the run doesn't actually end, and there's no way to continue into a harder second sector. You'd already identified this gap and were considering either stopping at one sector, or building a "jump gate" to chain sectors with scaling difficulty.

Investigation turned up unused content that was clearly built toward the jump-gate idea already:
- `ScenarioResource.sector_gate_scenario` — a flag that protects boss/gate tiles from being cleared/overwritten, already respected by `Map` and `GameStateManager`.
- `Source/Content/ScenarioResources/Scenarios/JumpGate/jump_gate.tres` — a fully-defined combat encounter (2 enemies) flagged `sector_gate_scenario = true`, but never referenced by the sector generator. It's dead content sitting exactly where this feature needs it.
- `Source/Systems/Content/Enemies/enemy.gd:164-168` (`_update_health_from_resource`) — a single choke point where every spawned enemy's health/shields get set from its `EnemyResource`. This is the one place a difficulty multiplier needs to be applied.

Given that, the plan below finishes what was already started rather than inventing a new system: turn `_randomize_sector_scenarios()` into something callable more than once, put the orphaned `JumpGate` scenario at the end of each sector as the actual transition trigger, scale enemy stats by sector number, and give the demo a real, boundable win condition after N sectors (not an infinite roguelite).

## Design summary

- Sector layout becomes: `[fate] ... [combat/question mix] ... [boss] [jump gate]`. The **jump gate**, not the boss, is the last tile and the actual sector-end trigger — this matches the content that already exists (boss = big fight + reward, gate = guard checkpoint you clear to leave).
- Clearing the jump gate's enemies either generates sector N+1 (scaled up) or, once a configured `demo_sector_count` is reached, ends the run in a real victory state.
- Difficulty scaling is a single multiplier applied to enemy `max_health`/`starting_shields` at spawn time, derived from sector index. No per-enemy authoring needed, no changes to the effect chain.
- No new abstraction layer (no `SectorGenerator` class extraction) — `_randomize_sector_scenarios()` already resets state at the top and is naturally re-callable. The unchecked cleanup-plan item to extract it stays a separate, optional cleanup task, not a dependency of this feature.

## Phase 1 — Sector counting in the save

- Add `sector_index: int = 0` to `GameSaveResource` (`Source/Resources/SaveResources/game_save.gd`), incremented each time a new sector is generated.
- Add `@export var difficulty_scale_per_sector: float = 0.35` and a `func get_difficulty_multiplier() -> float: return 1.0 + current_game_save.sector_index * difficulty_scale_per_sector` on `GameStateManager`.

## Phase 2 — Make sector generation reusable, add the jump gate

- In `GameStateManager`, add `@export var jump_gate_scenario: ScenarioResource` (points at `jump_gate.tres`).
- Modify `_randomize_sector_scenarios()` (`game_state_manager.gd:92-163`) so that, after appending the boss scenario (line ~140), it also appends `jump_gate_scenario` as the new final entry. Boss stays `sector_gate_scenario = true` and protected as it is today; gate is already flagged the same way in its `.tres`.
- No other change needed here — the function already resets `sector_scenarios = []` at the top, so calling it again later for sector 2/3 is safe as-is.

## Phase 3 — Difficulty scaling hook

- In `Source/Content/Enemies/enemy.gd`, update `_update_health_from_resource()` (lines 164-168) to multiply `max_health` and `starting_shields` by `Globals.state_manager.get_difficulty_multiplier()` (rounded/`ceil`'d to int) before assigning to `health`. This is the only balance lever for the demo — don't touch intent amounts or damage effects.

## Phase 4 — Sector transition trigger

- In `GameStateManager`, detect "the tile that was just cleared was the last entry in `scenario_list`" inside the existing `Events.combat_finished` handling path (near `_checkpoint_after_combat`, `game_state_manager.gd:211-219`). When `Globals.map.current_scenario_index == len(Globals.map.scenario_list) - 1` and that scenario is `sector_gate_scenario`, branch into a new `_advance_to_next_sector()` instead of the normal checkpoint/clear-slot flow.
- `_advance_to_next_sector()`:
  1. If `current_game_save.sector_index + 1 >= demo_sector_count` (see Phase 5), trigger the win state instead of generating more content — stop here.
  2. Otherwise increment `current_game_save.sector_index`, call `_randomize_sector_scenarios()` again to rebuild `sector_scenarios`/`current_scenario_index` for the new sector, checkpoint the save, then reuse the existing jump machinery (`Events.jump`, `Events.load_scenario`, `Events.start_scenario`, `Globals.background_manager.play_jump_intro/outro` — same sequence `JumpManager._jump_to_scenario` already runs) so the player gets the same jump-animation transition they already see moving between tiles, just now between sectors.

## Phase 5 — Real win condition for the demo

- Add `@export var demo_sector_count: int = 3` to `GameStateManager` (tunable — start at 3, adjust after playtesting pacing).
- Add `GameState.VICTORY` to the `GameState` enum (`game_state_manager.gd:21-25`) and an `Events.victory` signal (mirroring `Events.game_over` in `events.gd:21`), wired the same way `game_over` is wired at `game_state_manager.gd:68-70`.
- Update `Source/Systems/Autoloads/save_manager.gd` so `victory` also deletes the save (same treatment as `game_over` today, line 12) — a demo run ends either way.
- Update `Source/Systems/UI/GameOver/game_over.gd`: currently shows "VICTORY!" on every `ScenarioEvent.BOSS_DEFEATED` (lines 33-39), which will now fire once per sector, not just at the true end. Change it to listen for the new `Events.victory` signal instead, so "VICTORY!" only shows at the actual end of the demo run.

## Phase 6 — Playtest pass (not code)

- With scaling and 3 sectors in place, play through end-to-end and check: does difficulty feel meaningfully harder by sector 3, does content (9 enemies / ~24 tiles) start repeating noticeably across 3 sectors × 18 tiles, does the jump-gate transition read clearly as "you cleared this sector"? Tune `difficulty_scale_per_sector` and `demo_sector_count` from there — these are both single-number knobs by design.

## Critical files

- `Source/Systems/Game/GameStateManager/game_state_manager.gd` — sector generation, transition trigger, win state wiring
- `Source/Resources/SaveResources/game_save.gd` — `sector_index` field
- `Source/Content/Enemies/enemy.gd` — difficulty multiplier applied at `_update_health_from_resource()`
- `Source/Systems/Autoloads/events.gd` — new `victory` signal
- `Source/Systems/Autoloads/save_manager.gd` — delete save on victory
- `Source/Systems/UI/GameOver/game_over.gd` — victory UI keyed off the new signal
- `Source/Content/ScenarioResources/Scenarios/JumpGate/jump_gate.tres` — already exists, just needs to be referenced

## Verification

- Use the Godot MCP tools to run the project (`run_project`), play through a sector to the boss and then the jump gate, and confirm: sector 2 generates, the jump transition plays, and enemies in sector 2 have visibly higher health/shields than sector 1 (check via `game_get_property` on a spawned enemy's `Health` node, or just eyeball the health bar).
- Repeat through sector 3 and confirm the run ends with the real victory state (not just a label) — check `Globals.state_manager.state == GameState.VICTORY`, save file deleted, and that reaching sector 1 or 2's boss no longer incorrectly shows "VICTORY!".
- Confirm losing (player death) still behaves exactly as before — this phase touches shared code (`GameState` enum, `game_over.gd`) so regression-check the existing game-over path.

---

# Appendix: Content Scope Targets & Shippability Blindspots

(For content-authoring execution — not code.)

## Current baseline (grounded in actual resource counts)

| Pool | Count | Notes |
|---|---|---|
| Combat scenario templates | 3 | Attacker, CannonDrone, DefenderDisabler |
| Question/event scenarios | 2 | PiratesAttackingCivilian, SleepingDrone (each has branching narrative states) |
| Boss scenarios | 1 | SectorBoss |
| Fate scenario | 1 | |
| Enemy resources | 9 files → ~5 real combat enemies (attacker, cannon_drone, defender, disabler, fate_attacker) + 1 boss + civilian_transport (non-hostile) + shop (non-combat) + tutorial_attacker (tutorial-only) |
| Tiles | 21 | |
| sector_size | 18 | |

With `sector_size = 18`, after 2-3 shops, the fate tile, the boss, and the jump gate, ~11-12 slots remain, split ~70/30 combat/question — meaning **~8 combat slots pulling from only 3 templates** per sector. Across 3 sectors that's the same 3 fights recurring 6-9 times each. This is the single biggest repetition risk for the demo, ahead of tile/enemy count.

## Rough content targets before shippable

- [ ] **Combat scenario templates: 6-8** (from 3). Highest-leverage, cheapest fix — new combinations of the existing 5 enemies (2x attacker, cannon_drone + defender, disabler + attacker, a 3-enemy swarm, etc.) before authoring any new enemy.
- [ ] **Enemy types (combat-capable): 8-10** (from ~5). Add a swarm (low HP, more actions), a support/healer, a shield-focused type to round out the existing aggressive/artillery/tank/disruptor/corrupted spread.
- [ ] **Bosses: 1 kit, 2-3 escalation variants.** Reuse `sector_boss` with a different `action_options` set per sector rather than building new bosses from scratch.
- [ ] **Question/event scenarios: 4-6** (from 2). Lower priority than combat (more expensive to author), but 2 is thin across 54 tile-pulls over 3 sectors.
- [ ] **Tiles: keep at ~21.** In genre-typical range for a demo (20-35); spend time balancing what exists rather than growing the count.
- [ ] **Sectors: 3** (~54 total encounters, ~45-75 min). If the combat-template authoring load above is too much, cutting to 2 sectors is a legitimate way to reduce scope instead of adding more content.

## Blindspots — must-fix before shippable

- [ ] **Enemy damage doesn't scale with sector.** The difficulty-scaling phase above only scales enemy `max_health`/`starting_shields`; enemy intent *damage amounts* are flat, hand-authored min/max per action. Meanwhile player builds get stronger every sector. Net risk: sector 3 enemies are tankier but hit no harder, while the player out-scales them — verify difficulty actually increases in playtesting, not just fight length.
- [ ] **`Source/Content/ScenarioResources/Scenarios/TEST/test.tres`** exists — confirm it's excluded from every exported scenario pool before shipping.
- [ ] **No run-progress UI** — nothing currently shows "Sector X of 3" or overall run progress; add one now that sectors mean something.
- [ ] **Save/quit mid sector-transition** — the sector-advance flow is async (jump animation await); define a safe checkpoint boundary for a quit during that window.
- [ ] **No post-run loop** — confirm GAME_OVER/VICTORY both lead to a clear "play again"/return-to-menu flow, ideally with a run summary (sectors reached, encounters cleared).

## Blindspots — worth a deliberate pass

- [ ] Tutorial covers the sector/jump-gate concept, not just single-sector combat.
- [ ] Audio coverage: sector-cleared/jump stinger, boss music, per-sector ambience variation.
- [ ] Options menu basics (volume, resolution/window mode), controller support if targeting itch.io/Steam.
- [ ] Tooltip/description completeness for all new tiles/enemies added above.
- [ ] Outside playtesting pass before calling anything "balanced" — the damage-scaling issue above is not self-detectable through solo testing.

## Explicitly deferred (not part of "is the build shippable")

- Store page assets, trailer, marketing screenshots/description.
