# Roadmap

What's left to do, in rough priority order. When something ships, record it in
`DEVLOG.md` and delete it here. Don't tick it off. This file replaces
`DEMO_PLAN.md`, `PLAN_FOR_FUN.md` and the August cleanup docs, which are in git
history if you need the old reasoning.

**Where things stand (2026-11-05).** The run loop is done: three sectors, a gate
boss on each sector's jump gate, scaling, victory/game-over screens and a run
summary. The content targets from the old plans are well past. The game has
been self-playtested and is fun. Next comes outside playtesting.

## Before outside playtests

- [x] Quit (Save and Quit, and closing the window) during a sector jump, then
      Continue. Make sure the run resumes in a sane state. A normal quit is
      known to save fine, but this window is async. Checked headless with the
      AutoPilot: the save on disk was copied at every jump, gate jump, enemy
      turn, shop and event-ship change across 7 seeds (270 snapshots), and
      each was continued and played on. Nothing is written mid-jump, and
      every continue was sane. One bug was found and fixed: continuing in a
      shop freed the die on its shelf.
- [ ] Run the outside playtests with `PLAYTEST_KIT.md`, which covers the
      build checklist, tester handout, feedback form and log locations.
      Testers' crash reports are their `user://debug_log.txt` (see
      `DebugLogger` in `ARCHITECTURE_OVERVIEW.md`).

## After playtests

- [ ] A balance pass driven by the feedback. Tile uses became per-turn and the
      relay die tax was added since the last pass, and outside players will find
      what solo testing can't.
- [ ] Tutorial changes, if testers get lost. The tutorial counts as done until
      then.

## Audio (next up)

- [ ] **Music.** There's no boss music, and music in general needs work.
      `MusicDirector` already supports layered stems (`set_layer_enabled()`),
      so a boss or high-danger layer could fade in rather than needing a hard
      track cut. Also consider a sector-cleared/jump stinger.
- [ ] **Tile activation sound with a combo pitch ladder.** The pitch climb is
      already built: `enable_pitch_escalation` on `SoundEffectResource`. What's
      missing is a sound that suits it.
- [ ] Everything else in `SOUND_EFFECTS_TODO.md` (P1 first).

## Later

- Trailer, store page and marketing shots: see `TRAILER_PLAN.md`.
- **Fate's Die and the Reckoning: follow-ups to the first pass** (see `LORE.md`
  §13 and DEVLOG 2026-11-05):
  - Play the secret route end to end on a real run and tune it: the escape goal
    (`ReckoningDirector.escape_goal_multiplier`), the Vanguard Drive's 2x, how
    fast the horizon eats, the face chains' numbers, and how often a careful run
    fills the die. The AutoPilot never takes the route, so this is hand testing.
  - The Front and the Vanguard (LORE.md §3-4). Until they exist, the dying
    Marshal at the last gate tells the secret.
  - The Fallen (LORE.md §8) borrows the Shroud's table and the Fate Attacker's
    scene with the player's hull swapped in; it could use a table of its own.
  - The Rearguard fighting on the player's side for a run that never paid a
    tithe. For now those echoes stay dead and Duty shields the player.
  - Real art for the Saved Ship / Old Debt / Vanguard Drive tiles and the Ruin
    glyph (machine-drawn first passes), and the SFX slots in
    `SOUND_EFFECTS_TODO.md` (P2, Fate's Die).
  - Faction reputation and gossip (LORE.md §9) can read the same ledger.
- Juice that was parked: vertical music layering, Fate/glitch as a visual
  language, ambient idle life (`Brainstorming.md` §8.5, §8.7–8.9). Check
  what already exists before starting any of them. The low-HP cockpit
  treatment is in (`HullAlarm`), except for a heartbeat sound.
- The rest of `Brainstorming.md` is the long-term idea backlog.

## Code health

Each of these was checked against the code on 2026-11-05, and none is urgent.
Fix them opportunistically when you're already in the file.

- [ ] **Extract a `SectorGenerator` from `GameStateManager`.** The file is 828
      lines with 23 exports, most of them sector-generation config, not
      state-machine concerns.
- [ ] **Move `GameAnimationPlayer`** in `main.tscn`. It's nested under
      `Systems/GameStateManager`, but its `root_node` is `Main`.
- [ ] **Store URL dedup.** The Steam URL is hard-coded in `main_menu.gd` and
      `pause_menu.gd`. Make it one constant or a `Utils.open_wishlist()`.
- [ ] **Tile directory path in one place.** `res://Source/Content/Tiles/TileResources/`
      is hard-coded in `content_registry.gd`, `reward_manager.gd`,
      `tile_palette.gd` and `tile_text_tokens_tool.gd`. `ContentRegistry` is the
      natural owner.
- [ ] **Starfield dedup.** Near-identical star spawning appears in `main_menu.gd`,
      `capsule_mockup.gd` and `opening_cutscene.gd`. Check whether the
      cutscene's differences are intentional first.
- [ ] **`MouseCursor`'s `z_index = 1000`** in `main.tscn`. It's already on its
      own `CursorLayer`, so this is probably dead weight. Remove it or explain
      it.
- [ ] **Naming.** `Source/Systems/UI/InfoShower/InfoResource.gd` should be
      `info_resource.gd`. Update every reference.
- [ ] (Judgment call.) Data-only resources such as `Source/Resources/BackgroundResources/`
      and `SoundEffectResources/`, plus `reward_resource.gd`, could move to
      `Source/Content/`.
- [ ] (Low value.) `GlitchShader`, `FPSCounter` and `FadeIn` are inline nodes
      in `main.tscn`, not their own scenes like the rest of the UI.
- [ ] **Big files.** The largest gameplay scripts are `map.gd` (1178),
      `enemy.gd` (911), `focus_selection.gd` (879), `player.gd` (871),
      `opening_cutscene.gd` (841), `tile.gd` (836), `tutorial_manager.gd` (833),
      `game_state_manager.gd` (828) and `targeting_computer.gd` (776). The
      August audit proposed splits when these were a third of their size, so
      plan the split boundaries fresh rather than reusing those.

The rest of the August audit has been fixed or is moot. This includes the
error popups, the PauseMenu layer, the tutorial decoupling, the enemy-turn
completion joint, "Receive Die from Target", `game_save` naming, the
enemy-intent die-number bug (the selector was rewritten) and the draggable
rewrite.
