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
- [ ] Check whether dice a Pilgrim **Relays** to a Zealot count toward the
      Zealot's **Overload**. Two Inbound elites are built on that (Procession
      and Twin Flames), so if relayed dice don't count, both lose their "let
      its faith burn it out" option. Flagged in the PR #3 review.
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
    (`ReckoningDirector.escape_goal_multiplier`), the Horizon Drive's 2x, how
    fast the horizon eats, the face chains' numbers, and how often a careful run
    fills the die. The AutoPilot never takes the route, so this is hand testing.
  - Story boxes beyond the Bastion's death: see `STORY_BOXES_PLAN.md`.
  - The Arc Dynamo / Chancellor naming (LORE.md §11): one character or two.
  - The Fallen (LORE.md §8) borrows the Shroud's table and the Fate Attacker's
    scene with the player's hull swapped in; it could use a table of its own.
  - The Rearguard fighting on the player's side for a run that never paid a
    tithe. For now those echoes stay dead and Duty shields the player.
  - Real art for the Saved Ship / Old Debt / Horizon Drive tiles and the Ruin
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

- [ ] (Optional.) **Big files.** `tile.gd` and `map.gd` were split on
      2026-11-05 (`TileHeldDice`, `FateState`). The rest are long but
      coherent, and are fine to leave. If one is ever split, these are the
      boundaries proposed then, lowest risk first:
      - `targeting_computer.gd`: the portrait comms/crackle, the reticle and
        the bound-slot arrows each become a child node; target selection and
        the intent panel stay.
      - `tutorial_manager.gd`: the highlight masks, the gameplay-action
        table, step waiting, then the combat holds.
      - `opening_cutscene.gd`: the skip overlay, the particle builders, then
        the ambient fields (their keyed properties need forwarding setters).
      - `enemy.gd`: scenario state and save capture, then the intent table.
      - `player.gd`: hand layout and engine charge; leave turn flow alone.
      - `focus_selection.gd`: the navigator and the reticle, then the target
        collector (also where to cut the per-frame `find_children` scans).
- [ ] **Unreproduced, found by reading (2026-11-05).** Each needs a repro
      before a fix:
      - `TileHeldDice.release_all()` (on `combat_finished`) returns every
        die on the tile, including one dropped after the last ship's death
        queued the `EndCombatEvent` but whose activation hasn't resolved. The
        die goes home, and `TileActivationEvent` doesn't check that its die is
        still on the tile. `release_for_turn_end()` has the same shape.
      - The tutorial's and targeting computer's `await`s on scene-tree timers
        can resume after a quit to the menu has freed them. That only logs
        errors.
      - `TutorialManager._spawn_dice()` locks dice only after every die has
        been dealt, though `_lock_dice()`'s comment says they're caught as
        they land. No shipped step depends on it yet.

The rest of the August audit has been fixed or is moot. This includes the
error popups, the PauseMenu layer, the tutorial decoupling, the enemy-turn
completion joint, "Receive Die from Target", `game_save` naming, the
enemy-intent die-number bug (the selector was rewritten) and the draggable
rewrite.
