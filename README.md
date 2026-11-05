# Die Fighter

A turn-based sci-fi roguelike built in Godot 4.7. You place rolled dice on a
grid of ability tiles, and the die's face sets each tile's strength. Every die
you spend is then handed to the enemy, who acts with that same value. A run is
three sectors of the fleet fleeing Fate, a black hole eating the galaxy. Each
sector ends at a jump gate guarded by a boss.

[Steam page](https://store.steampowered.com/app/3689280/Die_Fighter/)

## Documentation

**Working on the game**
- `AGENTS.md`: conventions and rules for AI agents and contributors (Godot
  workflow, validation, tests, art pipeline).
- `ARCHITECTURE_OVERVIEW.md`: how the systems work (autoloads, the
  ScenarioEngine and effect pipeline, run progression, saves).
- `CONTENT_BUILD_GUIDE.md`: step-by-step workflows for adding tiles, enemies,
  scenarios and other content.
- `STYLE_GUIDE.md`: GDScript style.
- `test/README.md`: the GUT unit tests and the policy for writing them.
- `Art/README.md`: where the `.aseprite` sources live and how they're exported.

**Plans and status**
- `ROADMAP.md`: what's left to do, including code-health items.
- `DEVLOG.md`: what changed and why, newest first.
- `SOUND_EFFECTS_TODO.md`: the SFX production and integration checklist.

**Design and ideas**
- `LORE.md`: the world, the factions and the Fate storyline.
- `FACTION_SCENARIOS.md`: the faction encounters and where each one is dealt.
- `Brainstorming.md`: the long-term idea backlog (mechanics, AI, juice, onboarding).
- `TRAILER_PLAN.md`: the trailer shot list and what to build for it.
- `SOUND_EFFECTS.md`: creative sketches for SFX (an older snapshot; the TODO
  file above is authoritative).
- `Tile_Gap_Analysis_StS_Dicey.xlsx`: the tile gap analysis against Slay the
  Spire and Dicey Dungeons.
