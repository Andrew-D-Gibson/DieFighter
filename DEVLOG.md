# Die Fighter — Dev Log

Newest entries at the top.

---

## 2026-09-17 — The boss now fights differently as it loses

**Built:** `EnemyResource.pool_selection`, a two-value enum deciding how an
enemy picks which of its action pools to draw this turn's six slots from:
`TURN_CYCLE` (the old `turns_alive % len(pools)` behaviour, still the default)
or `HEALTH_THRESHOLD`, which maps its health bar onto its pools — full health
lands in the first, near-death in the last.

Rebuilt the sector boss around it. "Boss / Holy mama" is now the **Sector
Warden** with three phases across thirds of its 64 HP:
- **100–67% Guns Hot** — straightforward attacks, one guaranteed wasted face.
- **66–34% Turtle** — a guaranteed 8–12 shield, plus lockouts and grid quakes
  to break up your board while it hides behind it.
- **33–0% Enraged** — no wasted faces at all, attacks jump to 8–15, and it
  starts impounding your dice and siphoning your engine.

**Why:** Every enemy in the game behaves identically at full health and at one
hit from death — BRAINSTORMING calls this out as the biggest opportunity in the
codebase and it's right, especially for a boss you fight once per sector and
three times per run.

The important part is that this costs *nothing* from the game's
perfect-information pillar. The phase only changes which table the six slots are
drawn from; the resolved slots are still shown in full before the player commits
a die. You always know exactly what a 4 will do. You just might not like it.

**Verified live:** set the boss's HP to 64 / 40 / 20 / 5 and regenerated its
turn each time — pools 0, 1, 2, 2, with the enraged pool producing Engine Siphon
+ Impound + four heavy Dice Cannons and no blank face.

---

## 2026-09-17 — Two new enemies, five new enemy actions, five new fights

**Built:** Content on top of this morning's new verbs.

Actions (`EnemyActions/EnemyActionResources/`): Impound, Engine Siphon, Grid
Quake, Repair Beam, Aegis Link.

Enemies:
- **Tithe Collector** (16 HP / 4 shields) — a customs hull that taxes your dice
  economy instead of your hull. Exactly one of its six faces impounds: weight 0
  plus `force_include` guarantees one and only one, so the threat is a specific
  *number* you can route around rather than a coin flip. Uses the previously
  unused `viper.png`.
- **Ion Lance** (9 HP / 0 shields) — fragile interceptor that goes after the two
  things the rest of the game treats as safe: engine charge and grid layout. One
  guaranteed siphon face, one guaranteed quake face. Uses the unused
  `fighter_jet.png`.

Fights (combat templates 3 → 8): Tithe Collector solo, two Ion Lances, Tithe +
Ion escort, Wolfpack (2 Venom Fighters), Drone Battery (Defender + 2 Cannon
Drones). DEMO_PLAN flagged "~8 combat slots pulling from only 3 templates" as
the single biggest repetition risk; this roughly halves it.

Targeting-computer silhouettes for both new ships are generated from the ship
sprites by majority-downsample to 16×16 flat `#cef0f1`, matching how the
existing ones look.

**Fixed along the way:** Grid Quake picked a random cardinal direction and then
silently did nothing whenever the tile was against a wall or boxed in — a
telegraphed "your grid gets shoved" that doesn't shove is a broken promise, not
an interesting outcome. Added `TileGrid.can_push_tile()` (extracted from
`push_tile`'s own validation, which now calls it) and made the handler shuffle
the cardinals and take the first direction that actually moves something.

**Verified in a live session:** jumped into the Tithe+Ion fight, fed the
Collector a 5 (Impound) and the Lance a 1 (Grid Quake). Hull 20 → 18, a tile
slid from (3,1) to (4,1), and the Collector ended the turn visibly holding the
die — one fewer die in the player's hand, and an extra action for it next turn.

**Two things worth knowing:**
- `.tres` files written by hand need a real UID in the header; invented strings
  like `uid://ct1thcollectr1` aren't valid base-31 and won't resolve. Generated
  a batch with `ResourceUID.create_id()` from a throwaway headless script.
  Round-tripping a `.tres` through `ResourceSaver.save()` to get a UID does NOT
  work — it strips `script_class` and adds no UID. Don't do that.
- A hand-built `EffectData.new()` + direct `handler.apply()` from an MCP eval
  hung the game hard (main thread wedged, no further evals). Real gameplay
  paths are fine. Not chased — `EffectData` is a `@tool` script whose setters
  call `notify_property_list_changed()`, which is the obvious suspect outside
  the editor. Test effects through actions, not by constructing EffectData live.

---

## 2026-09-17 — Three new effect verbs, and icons for five new enemy actions

**Built:** Plumbing for enemy actions the engine couldn't previously express,
plus the art they'll be seen through.

New EffectsV2 subtypes + handlers:
- `TARGETING/TARGET_RANDOM_OTHER_ENEMY` — `TARGET_RANDOM_ENEMY` can (and
  usually does) pick the actor itself, so a medic ship was impossible to author.
  Falls back to the actor when nobody else is alive.
- `DICE_CONTROL/KEEP_DIE_WITH_ACTOR` — the enemy holds onto your die instead of
  handing it back. Every existing enemy action ends in `GIVE_DIE_TO_PLAYER`, so
  "I'm keeping this" is a genuinely new verb — and because `Enemy.run_turn()`
  iterates whatever is in its queue, a kept die becomes an *extra action* for
  that enemy next turn. That escalation is emergent, not authored, and it's
  honest: you can see the die sitting in its queue.
- `TILE_CONTROL/PUSH_TARGETED_TILES` — `PUSH_TILE_IN_DIRECTION` pushes the
  chain's own `effect_source`, which only works for a tile shoving itself.
  This reads `context.targets`, so an enemy can shove *your* grid around. A
  zero `grid_offset` means "random cardinal", rolled per target.

Art: 7×7 intent indicators + 24×24 info textures for impound / siphon / quake /
repair / aegis, all on the project palette. Reused the existing colour grammar —
orange for denial (matching the padlock), blue for shields, green for repair.

**Why:** The whole game has five enemy verbs: attack, shield, flee, lock a tile,
do nothing. BRAINSTORMING calls this the highest-leverage content gap and it's
right — intent telegraphing is the game's best system and it has almost nothing
to say.

**Snags:**
- First drafts of the siphon and aegis icons were outline-only and dissolved
  into the dark cockpit background at 7×7. Redrew both with solid fills.
- New `.gd` files written outside the editor aren't in
  `.godot/global_script_class_cache.cfg`, so `validate_script` reports every
  new `class_name` as undeclared — including in files that merely reference
  them. `Godot --headless --path . --import` refreshes the cache. Worth
  remembering: a wall of "Identifier not declared" after adding files is a
  stale cache, not a real error.

---

## 2026-09-17 — Sector progress indicator

**Built:** A `SECTOR n/3` readout in the Systems/Map tab strip
(`Source/Systems/UI/SectorIndicator/`). Dimmed at rest so it sits behind the
two tab buttons in the reading order, and pulses purple for 2.5s on
`Events.sector_advanced` — the one moment in a run where the entire map is
replaced deserves to be noticed.

**Why:** Sectors only started meaning something an hour ago, and DEMO_PLAN
lists "no run-progress UI" as a must-fix. The tab strip had ~60px of dead
space between SYSTEMS and MAP; sector depth is run-level info, so it belongs
where it's readable from either view rather than inside the map panel.

**Snag:** First attempt put the new `ext_resource` line after the scene's
`sub_resource` block, which Godot rejects with "Unknown tag 'ext_resource'" —
the whole scene failed to load and took `main.tscn` down with it. `.tscn`
section order is load-bearing: all `ext_resource` first. Fixed by moving it
into the header block.

---

## 2026-09-17 — Multi-sector runs, jump gates, and a real victory condition

**Built:** The whole DEMO_PLAN progression spine. A run is now three sectors
long instead of one open-ended sector that never ended.

- `GameSaveResource.sector_index` tracks how deep the run is, and persists
  through `SaveManager` (additive JSON key, old saves read it as 0 — no
  version bump needed).
- `_randomize_sector_scenarios()` now appends the previously-orphaned
  `jump_gate.tres` *after* the boss, so the gate — not the boss — is the last
  tile of every sector. That scenario already existed, flagged
  `sector_gate_scenario = true`, and was never referenced by anything.
- New `GameStateManager._check_sector_cleared()` fires on `combat_finished`;
  if the cleared tile was the last one and it's a sector gate, it hands off to
  `_advance_to_next_sector()`, which either generates a fresh, harder sector
  and replays the normal hyperspace jump into it, or ends the run.
- `Map.load_sector()` extracted out of `_load_game_save()` so the map can be
  repointed at a brand-new scenario list mid-run without faking a save load
  (which would have clobbered player/tile state).
- `JumpManager._jump_to_scenario` → public `jump_to_scenario`, and
  `Globals.jump_manager` added, so sector transitions reuse the exact same
  jump animation the player already knows.
- Difficulty is one number: `get_difficulty_multiplier()` = `1 + sector *
  0.35`, applied at `Enemy._update_health_from_resource()` — the single choke
  point every spawned enemy passes through. Verified live: an 18 HP Venom
  Fighter spawns at 25 HP in sector 2.
- `Events.victory` + `GameState.VICTORY`. `game_over.gd` used to show
  "VICTORY!" on *every* `BOSS_DEFEATED`, which would now fire once per sector;
  it listens to `Events.victory` instead. `SaveManager` deletes the save on
  victory the same way it does on game over.

**Why:** The game had a combat layer and no run. Nothing escalated, nothing
ended. This is the smallest change that makes a session have a shape.

**Verified:** Ran the project, drove `_check_sector_cleared()` from a live
eval at the gate index — sector 2 generated with a fresh gate at its end, the
jump animation played, enemy HP scaled 1.35x, and forcing the third clear
produced state `VICTORY`, a deleted save, and the victory screen.

**Known noise (pre-existing, not mine):** boot spews ~184 errors from the four
`ComplicatedTileResources/*.tres` still referencing the deleted pre-V2 effect
system. `RewardManager._load_tile_resources()` tries to load them every run.
Worth porting to EffectChainV2 — they have good ideas in them.
