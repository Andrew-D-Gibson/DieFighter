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
- [ ] Run the outside playtests. Testers' crash reports are their
      `user://debug_log.txt` (see `DebugLogger` in `ARCHITECTURE_OVERVIEW.md`).

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
- The secret Fate boss and the endings: proposals in `LORE.md` §6–8.
- Juice that was parked: vertical music layering, Fate/glitch as a visual
  language, ambient idle life, low-HP cockpit treatment (`Brainstorming.md`
  §8.5, §8.7–8.9). Check what already exists before starting any of them.
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
