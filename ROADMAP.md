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

- [ ] Quit (Save and Quit, and closing the window) during a sector jump, then
      Continue. Make sure the run resumes in a sane state. A normal quit is
      known to save fine, but this window is async.
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

- [ ] **Big files.** The largest gameplay scripts are `map.gd` (1183),
      `enemy.gd` (911), `focus_selection.gd` (885), `player.gd` (879),
      `opening_cutscene.gd` (852), `tutorial_manager.gd` (840), `tile.gd` (836)
      and `targeting_computer.gd` (801). Split boundaries proposed fresh on
      2026-11-05, lowest risk first in each:
      - `targeting_computer.gd`: the portrait comms/crackle, the reticle and
        the bound-slot arrows each become a child node; target selection and
        the intent panel stay.
      - `tutorial_manager.gd`: the highlight masks (`_show_highlight`, the
        cut-outs), then the gameplay-action table, then step waiting (the
        timeouts and `_await_*`), then the combat holds (arrows, opening strike).
      - `opening_cutscene.gd`: the skip overlay (one `skip_confirmed` signal),
        the particle builders (static), then the ambient fields (stars, debris,
        speed lines), whose keyed properties need forwarding setters or new
        track paths.
      - `tile.gd`: a `TileHeldDice` helper beside `TileUseLights` and
        `TileCountdown`, then the info/text code, then the visual feedback.
        The event responders last: connection order and the synchronous fatal-
        damage save matter.
      - `map.gd`: the camera (bounds, slider, pan), then the caption and hover,
        then a `FateState` data class. The fate zone view goes last, and the
        RUN-stream draw order must stay exactly as it is.
      - `enemy.gd`: scenario state and save capture, then the intent table
        (keep a `turn_actions` pass-through), then dice spending and overload.
      - `player.gd`: hand layout, engine charge, then jump transit. Turn flow
        goes last; its await ordering is subtle.
      - `focus_selection.gd`: the navigator (pure list logic) and the reticle,
        then the target collector, which is also where to cut the per-frame
        `find_children` scans.
- [ ] **Unreproduced, found by reading (2026-11-05).** Each needs a repro
      before a fix:
      - `Tile.release_held_dice()` returns every die in the queue on
        `combat_finished`, including one dropped after the last ship's death
        queued the `EndCombatEvent` but whose activation hasn't resolved. The
        die goes home, and `TileActivationEvent` doesn't check that its die is
        still on the tile. `release_dice_held_for_the_turn()` has the same
        shape.
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
