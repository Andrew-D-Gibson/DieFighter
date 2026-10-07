# Die Fighter — Dev Log

Newest entries at the top.

---

## 2026-10-06 — Every tile and enemy action gets its own juice

**Goal:** the first juice pass was systemic. This one is per-content: make
each of the 72 tiles and 12 enemy actions look like what it does, so a
player can read a machine from its effects alone.

**Toolkit first.** Nine new `AUDIO_VISUAL` effects, appended to the enum and
served by one `JuiceHandler` / `JuiceEvent` pair:

| Effect | What it draws | Parameters |
|---|---|---|
| `SHOCKWAVE` | Ring out from each target; a **negative** radius closes in (a lock-on) | amount, color |
| `SPARK_BURST` | Spark burst; `string_param = "rise"` drifts them up | amount, multiplier (speed), color |
| `CALLOUT` | Floating text; `{amount}` shows the running amount | string_param, color |
| `BUMP` | Squash-and-stretch the target's body | multiplier |
| `ZAP` | Crackling bolt from source to each target, **holds the chain** for `amount` ms | amount, color |
| `GRID_RIPPLE` | Flash + bump spreading cell by cell from the source tile | amount (ms/step), color |
| `SCREEN_RIPPLE` | New `screen_ripple.gdshader`: refraction ring + chromatic split over the whole screen | multiplier |
| `STREAM` | Motes drained target → source (`"out"`: the other way; `"engine"`: the player's end is the engine bar), **holds** until they land | amount, string_param, color |
| `DIE_FLARE` | Activator die spins, pops and rings | color |

They read authored parameters only (never `running_amount`, except
`CALLOUT`'s token), and aren't amplifiable, so they can sit anywhere in a chain
without changing the numbers around them. They play at the targets, or at the
source when nothing is targeted yet, so a flourish authored at the top of a
chain lands on the tile or ship itself. Effects aimed at the player land on
their health bar (`Player.get_juice_anchor()`). Every target is fine: a
`BUMP` on the player squashes the health bar.

**Then content.** An authoring script inserted the flourishes into 71 tiles
and all 12 enemy actions, including inside conditional branches and
event-response chains. Some themes:

- **Relays crackle a bolt** to the tile they Feed, in their own colour, and the
  routers say where the die went (`ODD`/`EVEN`, `LOW`/`MID`/`HIGH`,
  `PASS`/`FILTERED`, `<<`/`>>`) over the destination.
- **Drains are visible.** Siphon Engine pulls motes out of your engine bar;
  Leech Relay sucks uses out of its neighbours; Heat Sink pulls heat off the
  burning ship; Regenerative Brake harvests your hit into the drive.
- **Status appliers have a look each.** Lock-on rings close in for Exposed
  (Sensor Spike, Spotter Drone, Target Painter), Chaff Pod throws a white
  cloud with static, Crossed Wires and Static Bloom zap and glitch.
- **Big payoffs bend the screen.** Chaos Explosion slows time, ripples the
  screen and the grid, and rings every ship. Overdraw pours the drive into the
  target. Siege Shot announces itself, then slows time for the hit.
- **Die-changers flare the die** (Bump `+1`, Inverter `FLIP`, Polarizer,
  Grounding Rod `GROUNDED`, Welder `WELD`).
- **Enemies telegraph:** `CHARGING` with an imploding ring, `IMPOUNDED` with a
  red die flare, `RETREAT!`, and a deadpan `...` for Do Nothing.

Dead Man's Switch was left alone: its save is already the loudest thing in the
game.

**SOUND_EFFECTS.md** lists every place a sound should go: systemic moments,
every tile and action with the slot in its chain, the statuses, and a
top-ten. `dice_cannon` currently plays for ~35 different attacks.

**Bugs found by running everything live:**
- A lone ship rolling **Aegis Ally or Repair Ally halted the game** in the
  debugger. `TargetRandomOtherEnemyHandler`'s fallback assigned a ternary of
  array literals, which is an untyped `Array`, to the typed `targets`.
- **Emergency Shield left a freed tile in the grid.** `DestroySourceEvent`
  never told `TileGrid`, so neighbour targeting (and the next checkpoint
  save) read a freed node. `TileGrid.forget_tile()` clears the cell.

**Verified live:** swapped every tile onto one grid slot and activated it with
a real die (and fired its event responses), then ran all 12 enemy actions
against a ship: no runtime errors after the two fixes above. Screenshots of
the bolt, the stream (Siphon Engine), the screen ripple + grid ripple (Chaos
Explosion), and the ripple at rest all looked right. 234/234 tests pass,
including new ones for the flourish handler, `forget_tile`, and the lone
medic.

**Snags:**
- A uniform a `ShaderMaterial` has never been given doesn't exist as a
  property, so tweening `shader_parameter/progress` failed until it was set
  once first.
- `.tres` parsing: a description line starting with `[color=...]` looks like a
  section header to a naive splitter. The authoring script splits only on real
  `[sub_resource`/`[ext_resource`/`[resource` headers.

---

## 2026-10-06 — Juice pass, and upgrades that show themselves working

**Goal:** make effect chains feel physical, and make passive upgrades visible.
A modifier that quietly turns a 3 into a 5 is invisible: the player sees a
bigger number and never learns which tile earned it.

**Upgrade procs.** `Modifier` gained `source` (the node that put it in play)
and `announce_triggered()`, which a modifier calls only when it actually
changed something — doubled a hit, clamped an amount, cancelled an event,
added a stack. It emits `Events.modifier_triggered`, and whoever owns the
modifier reacts:

- **The source tile** bumps, flashes the modifier's colour, throws a ring and
  sparks, plays a rising blip, and calls out what it did (`+2`, `x2`,
  `SAVED`). The Amplifier, Dead Man's Switch and Lockout events now set
  `source`. A 150 ms window keeps one activation from stacking callouts,
  since an Amplifier touches every amplifiable event in a chain.
- **The background badge** kicks when its rule bites (a blackout cancels, the
  cap clamps).
- **Statuses** flash their ship in the status colour and call out their name
  (Burn skips the callout: its damage number already says it).
- **Reactive tiles** (`event_responses`) pop when their chain fires, but only
  if it queued something. Half of them are conditional, and a tile lighting
  up for a check that failed would teach the player to ignore it.

**Everything else** goes through a new `Juice` helper (bump, wiggle, ring,
sparkle, callout). All of it is fire-and-forget, so no turn got longer.

| Moment | Feedback |
|---|---|
| Die lands in a tile | tile squashes, white flash, ring; die pops |
| Tile refuses a die | red flash, head-shake wiggle |
| Enemy commits an action | ship squashes, die pops with a ring |
| Ship killed | 70 ms hitstop, zoom punch toward it, two shockwave rings |
| Player hull hit by anything | 45 ms hitstop (player tiles author their own) |
| Status applied | ship flashes, ring, sparks, `+3 BURN` |
| Shields / hull gained | enemy: `+N` callout; health bars: icon pop, sparks, flash |
| Die rerolled / tile dropped | face pops / tile bumps |

Tiles flash through two new `tile.gdshader` uniforms (`flash_color`,
`flash_amount`): the shader overwrites `COLOR` from the texture, so `modulate`
alone never reached it.

**Verified live:** with time slowed to 5%, screenshotted an Amplifier sourced
from the Bump tile firing on a Dice Cannon (Bump flashed yellow with `+2`), a
Burn application and tick, an enemy wind-up, health and shield gains on the
player's bar, a kill, and a refused die. A reactive chain with nothing to do
stayed quiet; one that queued an event popped. No runtime errors. New
`test_modifier_triggers.gd` pins "announce only when it changed something";
229/229 tests pass.

**Snag:** `EnemyGraphicsManager.flash()` assumed loaded ship graphics; the
status tests use bare enemies, so it now returns quietly without them.

---

## 2026-09-30 — Enemy statuses, and 14 tiles that use them

**Goal:** the player had no way to put a status on an enemy. Their only verbs
were damage, stripping shields, and choosing which die to hand over. Add
statuses that work through the dice and the intents, not just extra damage,
and enough tiles to make each one a build.

**The system:** a status is a `StatusModifier`, an ordinary engine modifier
that sits on one enemy, counts stacks, and removes itself when they run out or
the ship leaves. Stacks are its only number; each status decides what a stack
means. One verb applies any of them (`APPLY_STATUS`, with the id in
`string_param`, amplifiable stacks), and three read them (`SET_TO_TARGET_STATUS`,
`IF_TARGET_HAS_STATUS`, `CLEAR_STATUS`). Each shows a badge with its stack count
beside the enemy's health ring; clicking it explains the rule.

- **Burn** — when your turn ends, the ship takes damage equal to its Burn,
  then loses one. Ticks before any ship acts, so a ship that burns to death
  doesn't take its turn.
- **Scrambled** — each die handed to the ship lands on its opposite face, one
  stack per die. Dice it already holds are untouched: scramble first, then
  hand over the six.
- **Jammed** — each die the ship uses does nothing and comes back to you.
- **Exposed** — the next single-target tile hit deals extra damage equal to
  its Exposed, all spent at once.

**Tiles** (art and `.tres` from the machine-tile generators):

| Status | Tiles |
|---|---|
| Burn | Incendiary Round (1/2: 3 Burn), Napalm Vent (no dice: 1 Burn per neighbour activation), Flashpoint (6, rare: 3x Burn as damage, then put out), Heat Sink (4: shields = 2x Burn) |
| Scrambled | Crossed Wires (any, 2 uses: 1 Scrambled, die comes back), Turncoat Cannon (5/6: 4 damage, 10 if Scrambled), Static Bloom (no dice: 1 Scrambled at turn start) |
| Jammed | Chaff Pod (1: 1 Jammed), Sabotage Charge (8 charge: 2 Jammed), Interdiction Net (no dice, rare: 1 Jammed whenever your hull is hit) |
| Exposed | Target Painter (Exposed = the die), Sensor Spike (2 Exposed, Feed right), Spotter Drone (no dice: 3 Exposed after every enemy turn), Flare Burst (5, rare: 3 Exposed on every enemy) |

**Why these:** each status gets an applier, a payoff, and a passive, and they
lean on the handover. Crossed Wires into Turncoat Cannon deals 10 *and* hands
the target a 1. Burn stacks additively, so Flashpoint rewards stoking one
fire. Exposed is a set-up for one big hit, the opposite of Burn's slow
pressure, and Sensor Spike makes it a machine part.

**Snags:**
- Burn first listened to `player_turn_over`, but `EnemyManager` connects first
  and had already queued every action by then. `run_enemy_turn()` now ticks
  statuses explicitly and waits for them to resolve.
- Scrambled flipped dice after they joined the queue, so the targeting
  computer highlighted the intent of the face the ship *didn't* hold.
  `EnemyDiceManager` now emits `die_arriving` before the die joins. A ship
  putting back a die it already held (Charge Bore) isn't an arrival, or it
  would flip twice.
- `TARGET_ENEMIES` had never worked: it cast `Array[Enemy]` to `Array[Node]`,
  which fails at runtime. Flare Burst was its first user.

**Verified live:** every tile played in a fight, and each status checked with
`game_eval` — Turncoat hit for 10 and its 6 landed as a 1 (intent highlight
on the 1); Target Painter (4) + Sensor Spike Fed into a Dice Cannon for
3 + 6; Burn ticked 2 before the enemy acted; Flashpoint dealt 15 from 5 Burn;
two hull hits through Interdiction Net left 2 Jammed; Spotter Drone and Static
Bloom fired on their turn boundaries. 224 tests pass (20 new).

**Not built yet:** statuses on the player or tiles (Lockout and Amplifier are
still their own modifiers), immunity, and status-aware activation checks.

---

## 2026-09-30 — Machine tiles

**Goal:** 19 tiles built around Feed, so the grid can be wired into machines.
Built one at a time, each committed once it's verified live.

**Rules they follow:** unlimited-use tiles only Feed right; anything that
Feeds up, down or left has limited uses, so every loop runs dry. Die values stay
capped at 6. Holographic dice are left alone (an enemy receiving one destroys
it, as intended).

**Art pipeline:** a Lua generator (run through the Aseprite MCP) draws the tile
chrome exactly as the existing tiles have it — frame, screen, plate, 7×7
activation face, and the use-pip column for 1–3 uses with one sprite frame per
remaining use. Each tile only supplies a 20×11 icon, colour family, use count
and die face. The `.tres` files come from a matching generator, so every
Feed tile's chain is the same shape: `TARGET_TILE_WITH_OFFSET` →
`PASS_DIE_TO_TILE`, and every hit is the Dice Cannon's full attack block.

**Progress:**
- [x] Filter Gate — a 4+ Feeds right; lower deals 4 and goes to the target
- [x] Parity Junction — 1 damage, then odd Feeds up, even Feeds down (2 uses)
- [x] Value Sorter — 1 damage, then 1-2 Feed up, 3-4 right, 5-6 down (2 uses)
- [x] Scatter Router — 2 damage, then Feed a random occupied neighbour (2 uses).
  New effect `TARGETING/TARGET_RANDOM_ADJACENT_TILE` (appended), and a
  `(feed_random)` keyword token.
- [x] Inverter — turn the die to its opposite face (7 − value), then Feed right.
  Data only: SET_TO_DIE_VALUE → MULTIPLY −1 → ADD 7 → CHANGE_ACTIVATOR_VALUE.
- [x] Polarizer — 1-3 becomes a 1, 4-6 becomes a 6, then Feed right
- [x] Surge Relay — reroll the die, then Feed right
- [x] Afterburner Relay — spend 3 engine charge to deal 6, then Feed right
  (refuses the die when you can't pay, so an upstream Feed sends it to the
  target instead)
- [x] Leech Relay — 5 damage, the tiles above and below lose 1 use, then Feed
  right. Found and fixed: a negative `ADD_USES_REMAINING` on a spent tile
  clamped to −1, which means *unlimited* — draining a tile could make it fire
  forever. The event now skips unlimited tiles and floors at 0.
- [x] Toll Relay — gain 2 engine charge, then Feed right (combat only, so an
  unlimited charge source can't be farmed between fights)
- [x] Booster Stage — the tile to the right gets +2 this turn, then Feed right
  into it. 2 uses: it only Feeds right, but amplifiers stack, so unlimited
  uses would let one cannon climb without bound.
- [x] Grounding Rod — deal the die's value, then the target gets it as a 1.
  1 use per turn: otherwise it's strictly a better Dice Cannon.
- [x] Receiver Dish — 3 damage, or 8 if the die was Fed; then give the die.
  New plumbing: `EffectContext.feed_depth`, carried through
  `PassDieToTileEvent` into the next `TileActivationEvent` (+1 per Feed), and
  two appended effects that read it — `CONDITIONAL/IF_FED` and
  `AMOUNT_MODIFIER/SET_TO_FEED_DEPTH` (both unit-tested). A `(fed)` keyword
  explains the term in the info panel.
- [x] Relay Terminal — a 6 deals 3, +3 per Feed that carried it here; then give
  the die (rare; the 6 requirement is the limit, so uses are unlimited)
- [x] Beam Splitter — Feed the die right and a holographic copy down (1 use).
  New effect `TILE_CONTROL/FEED_HOLOGRAM` (appended): spawns a hologram at the
  tile and Feeds it through the ordinary `PassDieToTileEvent`, so refusals and
  enemy destruction behave exactly as for a real die. The hologram is queued
  on its tile and taken back out, like a placed die — `Dice.reroll_with_tween()`
  reads `host_queue`, and a hologram without one would crash a Surge Relay.
- [x] Pilot Light — takes no dice; at turn start it Feeds a holographic 1 right.
  Like every turn-start tile, it doesn't fire on a fight's first turn (the
  opening turn has no `player_turn_start`).
- [x] Crescendo Cannon — 1 damage per tile activated this turn, counting
  itself. New `Events.tile_activated(tile)` fires when a tile commits (criteria
  passed, use spent); `TileGrid.activations_this_turn` counts it and resets on
  `player_turn_refresh` and `start_scenario`; appended
  `AMOUNT_MODIFIER/SET_TO_ACTIVATIONS_THIS_TURN` reads it (unit-tested).
- [x] Spark Gap — takes no dice; whenever an orthogonal neighbour activates,
  1 damage to a random enemy. New `TileEvent.ON_ADJACENT_TILE_ACTIVATED`
  (appended before the pinned `= 100`), raised by `Tile` from
  `Events.tile_activated` when the activating tile is directly beside it.
- [x] Welder — holds the first die; the next gains its value (capped at 6)
  and Feeds right, and the held die returns to the hand. New
  `DICE_CONTROL/MERGE_HELD_DIE` and `CONDITIONAL/IF_SOURCE_HOLDS_DIE`
  (appended), and the first real use of `KEEP_DIE_WITH_TILE`.
  New general rule in `Tile`: any die a tile is holding goes back to the hand
  on `player_turn_over` and `combat_finished`. Without it, a held die would
  sit in the tile's queue after a jump freed it, and the queue-layout code
  would read freed dice.

**Verified live:**
- Filter Gate → Dice Cannon: a 5 passed through (12 → 7); a 2 dealt 4
  (7 → 3) and went to the enemy.
- Parity Junction with a Dice Cannon above, empty cell below: a 3 dealt 1 + 3
  (12 → 8); a 4 dealt 1 and went to the enemy; the third die was refused
  with 0 uses and returned to the hand. Sprite frame tracked uses (2 → 0).
- Value Sorter with Bump above, Dice Cannon right, empty below: a 1 dealt 1
  and came back from Bump as a 2; a 3 dealt 1 + 3 (6 → 2); a 6 dealt 1 and
  went to the enemy.
- Scatter Router whose only neighbour was a Dice Cannon on its left: a 1
  dealt 2 + 1 (12 → 9). With no neighbours: 2 damage, the die to the enemy.
- Inverter → Dice Cannon: a 2 became a 5, the cannon dealt 5 (7 → 2), and the
  enemy ended up holding the 5.
- Polarizer → Bump: a 2 became a 1 and Bump returned it as a 2; a 4 became a
  6, Bump refused it, and it went to the enemy.
- Surge Relay → Dice Cannon: a 2 rerolled to a 4; the cannon dealt 4 and the
  enemy got the 4.
- Afterburner Relay: at 10 charge it dealt 6 and left 7; at 2 charge it
  refused the die, which came back to the hand, and dealt nothing.
- Leech Relay with Bump above, a spent Parity Junction below, Dice Cannon
  right: a 3 dealt 5 + 3; Bump 3 → 2; the Junction stayed at 0; the cannon
  (unlimited) was untouched.
- Toll Relay → Bump: charge 5 → 7, and Bump returned the 2 as a 3.
- Booster Stage → Dice Cannon with a 1: the cannon hit for 3.
- Grounding Rod with a 4: dealt 4; the enemy received a 1.
- Receiver Dish: Fed by a Toll Relay it dealt 8; placed by hand, 3.
- Toll → Toll → Relay Terminal: a 6 hit for 9 (3 + 3×2); a 5 was refused at
  the Terminal and went to the enemy.
- Beam Splitter with Dice Cannons right and below: a 3 hit for 3 + 3, the
  enemy kept only the real 3, and no hologram survived. With a Surge Relay
  below instead, the hologram rerolled without error and was destroyed on
  hand-off.
- Pilot Light → Dice Cannon, through a real end-turn and enemy turn: the new
  turn opened with a 1 damage hit (4 → 3), the hand refilled, and no
  hologram was left over.
- Toll → Toll → Crescendo Cannon dealt 3 (three activations); a die placed
  straight on it next dealt 4. The count was back to 0 after a real enemy
  turn.
- Spark Gap under the middle of three Toll Relays: a die through all three
  sparked once (only the middle one is adjacent). A 2 on the Dice Cannon to
  its left dealt 2 + 1.
- Welder → Dice Cannon: held a 2; a 3 became a 5 and hit for 5, and the 2 was
  back in hand. A held 5 plus a 4 became a 6. A die left on it came back when
  the turn ended, and the next turn opened with a full hand.
- Info-panel sweep: every tile's panel shown in turn and measured. Welder and
  Relay Terminal overflowed the screen by 12px; their text was tightened.

**Whole machine, verified live:** Polarizer → Toll → Toll → Relay Terminal
with a Spark Gap under the second Toll. One 5 became a 6, paid 4 charge on the
way, sparked once, and hit the Terminal at feed depth 3 for 12 — the 12 HP
raider died to a single die and the fight ended cleanly.

**Done:** all 19 tiles, 39 → 58 player tiles. Suite 201 → 204 tests
(IF_FED, SET_TO_FEED_DEPTH, SET_TO_ACTIVATIONS_THIS_TURN), plus pinned ordinals
for every appended effect. `ARCHITECTURE_OVERVIEW.md` updated with the new
effects, signals, tile event, and the Feed/loop rules.

**Docs pass:** every markdown doc brought in line with the code.
`ARCHITECTURE_OVERVIEW.md` gains a Feed / machine-tiles section (6.2) and a
Keywords section (5.3), updated turn flow, Tile/TileGrid APIs and file tree, and
a fixed `SAVE_VERSION` (the autoload table still said 1). The plan docs and
`Brainstorming.md` got dated status notes, with checkboxes ticked only where the
code confirms them. Found along the way: `Brainstorming.md` §11 describes the
grid as 3 wide × 5 tall (it's 5 × 3), and the `SectorIndicator` added on 09-17
was removed in the "Map cleanup" commit, so DEMO_PLAN's run-progress item is
open again. `AGENTS.md` records the class-cache and `modify_scene_node`
pitfalls.

**For the rebalance:** Grounding Rod (1 use) and Booster Stage (2 uses) are
limited for balance rather than the loop rule. Toll Relay is combat-only.
Pilot Light and every other turn-start tile skip a fight's first turn.

**Noted, not fixed:** die icons in tile text (`(die_4)`) render tiny in the info
panel on every tile, not just these. `Utils.format_text` emits
`[img={72}x{72}]` — the braces look like they stop Godot reading the size.

---

## 2026-09-30 — Uses refill every turn, and relays that Feed

**Uses are per turn now.** `uses_per_combat` → `uses_per_turn` across every tile
resource, refilled on a new `Events.player_turn_refresh` beat that fires just
before `player_turn_start`. It's its own signal because turn-start effects run
synchronously inside `player_turn_start`: a Pilot Light-style tile spending a
neighbour's use would otherwise get it refunded or not depending on signal
connection order. The first turn of a scenario is still covered by the existing
`start_scenario` reset. Every limited tile is now much stronger; bigger payoffs
will carry costs (charge, credits, hull, dice, neighbours' uses) in the
rebalance.

**Relays Feed.** `PassDieToTileEvent` now asks the next tile whether it will
take the die *before* passing it. If it won't, the die goes to your target —
through `GiveDieToTargetEvent`, so it gets the tractor beam and dead-target
fallback like any other tile's die. Previously a refusal fell through to
`TileActivationEvent`, which hands the die back to the player: an unlimited
Signal Relay pointed at a spent or picky tile was free damage forever
(verified live before the fix: 2 damage, die back in hand, enemy got nothing).

The design reason, not just the bug: a relay should be an ordinary attack tile
when it's alone, and a better one when it's wired into a machine. Connecting it
should earn more value, never recover a die.

**Loop rule:** no loop counter. Every loop must pass through a tile with limited
uses and dries up when that tile refuses. Unlimited relays only Feed right,
which guarantees that — any tile that Feeds another direction needs limited uses.

**Keywords.** New `Keywords` registry (`Source/Systems/keywords.gd`). Tokens like
`(feed_right)` render as styled terms via `Utils.format_text`, and the tile info
panel appends a definition for every keyword the description uses. Info panel
layout tightened so the hint column no longer overlaps the description.

**Verified live:** Bump 3 → 2 on use, back to 3 after a real enemy turn;
relay → spent Bump dealt 2 and gave the die to the enemy; relay → relay →
Dice Cannon with a 3 dealt 2 + 2 + 3; queue idle afterwards, no runtime errors.

**Tooling gotcha:** `godot_modify_scene_node` re-saves the whole scene in a
headless context without autoloads. On `info_shower.tscn` that failed to compile
the script (`Events` unknown) and silently saved the scene *without its script*
and without UIDs. Restored from git and hand-edited. Check `git diff` after any
scene-tool edit to a node whose script references autoloads.

---

## 2026-09-22 — Save the whole run

**Goal:** a Continue recreates the run exactly. User chose the "replay fight"
model: never checkpoint mid-fight; quitting mid-fight replays it from the
last checkpoint with the same RNG.

**Design:**
- Checkpoint kinds: *arrival* (start_scenario → `scenario_progress` empty, a
  reload replays the scenario from its seed) and *mid-scenario* (after combat,
  or a reward/shop pickup while OUT_OF_COMBAT → `scenario_progress` captures
  the live scenario). reward_picked during combat writes nothing.
- `scenario_progress` (JSON dict): scenario id+seed, cleared flag, enemies by
  spawn index (alive/state path/hp/shields), pending reward offers, shop
  stock, hazard countdown, dice in hand, tile uses, per-scenario RNG states.
- Run-level additions: RUN rng state, map Fate indices/danger, RunStats,
  tile effect_data. BACKGROUND bucket seeded per scenario (bg rules were
  re-rolling on reload); shop prices move RUN→REWARDS.
- Restored ship states that aren't the starting state skip effects_on_enter
  (mercy call heal / tollkeeper charge are one-time payouts).
- Save version 2; v1 saves still load (missing fields default).
- Enemy/Reward/Dice forced_* statics are already cleared by TutorialManager
  on every game-scene load — not an issue.

**Progress:**
- [x] save format + GSM capture/restore plumbing
- [x] map / run stats / rng / tile effect_data
- [x] scenario progress: enemies, offers, shop, hazard, dice, tile uses
- [x] live verification — all passed:
  - arrival replay: same hand, enemies, background, Fate
  - win → reload: no enemies, untaken offer back, same stats
  - pick offer → offer gone from save
  - jump-from-checkpoint twice: identical scenario, enemies, hand, Fate, RUN state
  - shop: buy tile / buy die → reload shows the same stock minus sales, same prices, hand, dice count
  - salvage event: taken salvage stays taken, ship states and HP kept
  - mercy call heals once, not twice, across a reload
  - a reward_picked mid-fight writes nothing
  - tile effect_data survives a reload
  - a second New Game in one session starts clean
  - replaying a combat round from arrival gives identical results
  - a v1 save still loads

**Bugs found along the way:**
- The checkpoint captured scenario progress before its settling frame, so a
  just-taken offer was still recorded.
- An arrival snapshot taken a frame late could include a medic's arrival heal
  (double heal on replay); it's now synchronous.
- `run_start.tres` was mutated in place: a second New Game in a session opened
  on the last run's final checkpoint.
- Every shop visit left the previous shop's unsold tiles and die as hidden
  children.
- `tile_grid.gd` connected `Events.start_combat` to `Events.show_systems.emit`
  (autoload to autoload). The connection outlived the scene, and every later
  game scene logged a duplicate-connect error.
- The targeting computer's looping bob tween was tree-owned ("Infinite loop
  detected" on scene change).
- RunStats counted the restored balance as credits earned on every Continue.

**Known limits:** mid-fight state is deliberately not saved (replay model).
Out-of-combat modifiers on the engine (e.g. a lockout applied outside a fight)
aren't saved. Offers are restored at their saved position, but their reveal
animation replays.

---

## 2026-09-22 — Cleanup pass

**Plan:** `~/.claude/plans/this-isn-t-the-cleanest-piped-wilkes.md` (audit
findings, Phases 1–4). Resume from the checklist below.

**Progress:**
- [x] Phase 1 — confirmed bugs (items 1–10)
- [x] Phase 2 — single engine accessor (item 11)
- [x] Phase 3 — combine duplicated systems (items 12–16)
- [x] Phase 4 — hygiene

**Notes:**
- Items 1–7 done (commit "Harden ScenarioEngine lifecycle"). Engine now has
  `shutdown()`/`is_shut_down()` and `event_canceled`; `ScenarioManager._jump`
  calls `shutdown()` before freeing. `_end_combat_queued` clears when the drain
  that holds the EndCombatEvent finishes (one-shot on
  `finished_processing_queue`), so cancel/drop/jump can't strand it.
  `EnemyManager.run_enemy_turn` won't emit `enemy_turn_over` for an engine
  that was shut down. Tile activation tween is now tree-owned (a tile-owned
  tween on a freed tile never emits `finished` → queue stall).
  Verified live: killing the last enemy via a queued DamageEvent ends combat
  and clears the flag; a queued JumpEvent with a trailing event jumps cleanly.

---

## 2026-09-20 — Enemies place themselves

**Built:** `EnemyFormation`, and the removal of every hand-authored spawn
position in the game.

Scenarios used to carry a `spawning_path_location` per ship — a number between
0 and 1 picked by eye. That only ever described one correct layout: the roster
the scenario happened to start with, on a screen with nothing else on it. The
opening ambusher sat at 0.3 because the tutorial's popups cover the right-hand
side, which meant a returning player who never sees a popup still got an enemy
hugging the left edge for no reason.

Position is derived now. A scenario says who shows up and in what order;
`EnemyFormation` decides where they stand, from how many there are and how much
of the screen is actually free:

- One ship centres itself. Two spread to thirds. Four spread to fifths. The
  survivors close ranks when one of them dies.
- Space is taken away by **reservations** — a screen-space x span claimed by
  something else on screen, keyed by its owner so it can be given back. The
  tutorial claims the strip its popups occupy for as long as it is narrating;
  the shop claims its panel's width while it is open. The formation re-expands
  the moment a key is dropped.
- A ship a scenario effect deliberately parked (`MoveShipEvent`) pins itself
  and reserves its own footprint, so the rest reflow around it rather than
  through it.
- `EnemyStateRewardResource.path_location_override` (default −1, "you decide")
  is the escape hatch for an encounter that is genuinely *about* where a ship
  is standing. Nothing in the game uses it yet.

`EnemyManager.move_ship_to_point_on_path()` now owns the whole move — stopping
the bob, flagging `moving_in_world`, parking the targeting reticle and putting
it back — so the formation's reflow and a scripted move are the same code
path. `MoveShipEvent` is nine lines shorter for it.

**Why:** The tutorial and a normal run play the same encounter, and should
differ only in what is on screen — not in a number baked into the scenario. The
same machinery that fixes that also fixes the shopkeeper standing behind the
shop panel and the hole left in a wing when you kill its middle ship.

**Verified:** Live, against the real scenes. No tutorial: opening ambusher at
x=160, dead centre. Tutorial active: x=96 (the old authored 0.3 was x≈97).
Shop opened: the shopkeeper slid from 160 to 229.5 and back on close. Three
drones spawned at 106/160/214; killing the middle one closed the other two to
124/196. A scripted move to the centre pinned that ship and pushed its
squadmate out to 96. Screen-x → path-proportion inversion round-trips to
within 0.0002 across the whole curve.

**Snag:** A new `class_name` is invisible to `validate_script` until Godot's
global class cache knows about it, and the cache only rebuilds on a successful
parse — so the first script to reference `EnemyFormation` can't compile, which
stops the cache from ever learning the name. Broke the deadlock by adding the
entry to `.godot/global_script_class_cache.cfg` by hand. The editor will
generate `enemy_formation.gd.uid` on its next open; nothing references the
script by uid, so its absence is harmless until then.

---

## 2026-09-18 — The game starts in the middle of a fight

**Built:** A cold open, and a tutorial rebuilt on top of it.

**The opening.** A new run used to fade up from black onto an empty encounter
and boot the cockpit panel by panel — roughly three seconds of nothing, with no
stakes on screen. Now it cuts straight in: the cockpit snaps on fully lit, a
klaxon sounds, the vignette pulses red, and the player is already under fire.
One raider at 12 of 18 hull, the player at 14 of 32, holding a Dice Cannon and a
Bump and nothing else. The ambush is just sector one's arrival encounter, so
everything after it — the map, the sectors, the jump gates — runs exactly as
before.

- `EnemyStateRewardResource.starting_health_fraction` lets a scenario author a
  ship that arrives already hurt. Max health is untouched, so the damage reads
  on its health bar rather than looking like a weak enemy.
- `Events.cockpit_snap_online` finishes every reveal overlay instantly;
  `Events.red_alert` drives a sustained vignette pulse, distinct from the
  one-shot flashes damage already triggers.
- The alarm is a two-tone square-wave klaxon generated to match the sfxr
  palette the rest of the game uses.

**The tutorial.** It used to run on its own save, with its own hand-authored
sector list, and end by fading back to the main menu — so finishing the tutorial
meant starting over. Six of its steps were spent booting the cockpit, a sequence
that no longer exists. Now it narrates the ambush the game already opens on and
then hands the run back: when the last step closes, the player is in sector one
of a real run with the hull, tiles and credits they just earned.

Four beats, each one something the first encounter actually contains: fire a
tile, watch the enemy spend the die you just handed it, claim the salvage, jump
out. The opening is scripted so none of them can be skipped — a new
`opening_setup` step seeds the player's hand and the raider's intent table
before anything spawns, which an ordinary step can't do because both are
generated during scene setup. The hand is 4/2/1 and Bump caps at three uses per
combat, so turn one tops out at 10 damage against 12 hull: the raider always
survives to answer. Turn two deals 5/6/4 against a raider that wastes 5s and
6s, so "hand over the values they can't use" has something to pay off on.

**Found while testing:** `EnemyManager.run_enemy_turn()` awaited
`finished_processing_queue` unconditionally, but that signal only fires at the
end of a queue drain. An enemy turn where nobody was handed a die queues
nothing, so the await never resumed — and `enemy_turn_over` is what starts the
player's next turn. Ending a turn without firing a Dice Cannon hung the game,
silently, with no way forward. Long-standing; the new tutorial just made it a
button press away, since its first prompt is "use your dice, then end turn."

**Also folded in the TutorialManager cleanup plan:** gameplay code no longer
reads tutorial internals (`Globals.tutorial_active` and
`Globals.tutorial_controls_enemy_turns` replace the direct field reads), the
duplicated forced-dice/actions/rewards block is one helper, `_ready()` asserts
every `TutorialFunctions` value is actually wired, and a step whose closing
signal never arrives now times out and advances instead of hanging forever.

---

## 2026-09-17 — Two tiles that charge you for the privilege

**Built:** Tiles 24 → 26. Both are archetypes the game had none of: effects
that cost you something other than a die.

- **Ablative Charge** (red, die 6, 2 uses, rare) — 12 damage to your target,
  and your own hull takes 3. The biggest single hit available to the player.
  The self-damage runs through shields like any other damage, so a defensive
  turn can fire it for free — which quietly gives the shield tiles an
  *offensive* use they didn't have before.
- **Overdraw Coil** (purple, die 1, 1 use, rare) — deals damage equal to your
  current engine charge, then drains the engine to zero. Engine charge was
  purely a gate for jumping and fleeing; this is the only tile that makes it
  ammunition. Activating on a **1** is the point: it turns the worst die in your
  hand into your biggest hit, and takes your ability to leave with it.

Both drawn in the established tile chrome; the Overdraw Coil is the first tile
in the purple (engine) family that isn't the engine charger itself.

**Verified live:** engine 9 → 0 dealing exactly 9 damage (18 → 9 on a Venom
Fighter). Then Ablative Charge finished that 9 HP fighter with its 12 and took
the player 20 → 17.

**Design note on the "1" activation:** the game rolls dice you can't choose, so
a hand of low values is the standard bad turn. A rare, expensive tile that only
eats 1s converts that bad luck into the turn's best play — which is a much more
interesting answer to variance than a reroll.

---

## 2026-09-17 — The Siege Mortar: a gun with a ship attached

**Built:** Two new actions, a new enemy, a new fight, and the art for all of it.

- **Charge Bore** (new intent icon + info art) — spools up, gains 3–5 shields,
  and telegraphs that it fires next turn.
- **Siege Shot** (new intent icon + info art) — 8–13 damage, the biggest single
  hit any non-boss enemy has.
- **Siege Mortar** (22 HP, new 32×32 sprite) — a squat braced artillery
  platform with orange charge capacitors on its shoulders and a bore aimed
  straight down at the player. Two pools on `TURN_CYCLE`: loading (mostly blank
  faces, one guaranteed Charge Bore) then loaded (two of six faces are the big
  shot).
- **COMBAT_SiegeBattery** — Mortar + Defender.

**Why `TURN_CYCLE` and not the new `COMBAT_ROUNDS`:** `turns_alive` only
advances on turns the mortar was actually *fed*, which turns out to be the
better mechanic. The loaded shot just sits there waiting for you — you can see
it's charged and choose not to hand it a die, but that's also a turn you didn't
spend killing it, and it's wearing the shields it gained while charging. The
Defender escort exists to make that choice expensive: it soaks the dice you'd
rather be spending on the Mortar.

Using the "wrong" mode gave a better fight than the obvious one. Worth
remembering that `TURN_CYCLE` means *turns acted*, not rounds elapsed — that
distinction is a design lever, not just a gotcha.

**Verified live:** stepped `turns_alive` 0→3 — pools alternate 0, 1, 0, 1, with
the loading pool producing four blanks and a Charge Bore, and the loaded pool
producing two Siege Shots at 8 then 12.

**Content targets from DEMO_PLAN, now met:** combat scenario templates 3 → 11
(target 6–8), combat-capable enemies 5 → 10 (target 8–10), event scenarios
2 → 5 (target 4–6), tiles 14 → 24 (target ~21), bosses 1 kit with 3 sector
variants.

---

## 2026-09-17 — The Bounty Runner, and a timer that actually ticks

**Built:** `PoolSelection.COMBAT_ROUNDS` — a fourth mode, indexing the action
pool by how many combat rounds have elapsed *whether or not this ship got to
act*.

This was necessary rather than nice: `TURN_CYCLE` advances on
`turns_alive`, which only increments inside `Enemy.run_turn()` — and
`EnemyManager` skips `run_turn()` entirely for an enemy with no dice. So a ship
the player ignores never leaves pool 0, which makes `TURN_CYCLE` unusable for
any real timer. `rounds_in_combat` increments on `enemy_turn_over` instead
(deliberately *not* `player_turn_start`, because `generate_turn_actions` also
runs off that signal and relying on connection order for correctness is a trap).

**Bounty Runner** (24 HP / 6 shields) — a smuggler with three pools:
- **Round 1** — evasive. A guaranteed 4–7 shield, mostly blank faces.
- **Round 2** — engines spooling. Shields harder, shoots a bit.
- **Round 3** — *every one of its six faces is Flee.* Any die at all sends it out.

The encounter is: put 24 HP through a shielded hull in two rounds, knowing the
dice you spend on it are the dice it shields with, while an Ion Lance escort
competes for those same dice. And the clock runs whether you engage or not.

**Bug caught before committing:** I first put the 60–95 credit bounty on the
scenario's `rewards` dictionary. `ScenarioManager._handle_enemy_leaving()` pays
faction rewards out when a faction *leaves the fight by any means* — including
fleeing. The player would have collected the full payday for failing to stop
the escape, which inverts the entire encounter. Moved it to the Runner's own
`reward_resource`, which `Enemy._on_death()` only spawns on an actual kill.

Worth generalising: **scenario faction rewards are for clearing a faction;
per-enemy reward resources are for killing a specific ship.** They are not
interchangeable, and the difference only shows up in encounters where something
can leave alive.

**Verified live:** jumped in, stepped `rounds_in_combat` 0→3 and regenerated
the turn each time — pools 0, 1, 2, 2, with round 3 producing six Flees.

---

## 2026-09-17 — Rarity actually means something now

**Found while auditing tonight's content:** `TileResource.rarity` only affected
**shop pricing**. Both combat rewards and shop stock were picked with a flat
`pick_random`, so a Grudge Cannon showed up exactly as often as a plain Shield
— it just cost more when it did. With 24 tiles now split 9 common / 8 uncommon
/ 7 rare, that meant a rare tile was a ~29% draw.

**Built:** `RewardManager.pick_weighted_tile_reward()` — rarity-weighted
selection (common 1.0, uncommon 0.45, rare 0.18), used by both combat rewards
and shop stock. Price still scales with rarity on top of it.

Measured over 3000 draws against the live pool: 65% common / 26% uncommon / 8%
rare. Finding an Overclock Coil is now an event.

**Why this mattered enough to stop and fix:** I spent the night adding tiles
and marking the strong ones rare, on the assumption rarity gated availability.
It didn't. Every powerful thing I'd built was as common as the baseline ones,
which quietly flattens the reward curve *and* makes the deliberately-strong
tiles feel unremarkable. Worth checking that a data field is actually read
before authoring content that depends on it.

---

## 2026-09-17 — Fate finally does something

**Built:** Fate is the game's story hook and had almost no encounter content —
one 1-HP ship that attacks for 1, plus a map-corruption mechanic that eats
tiles. It now has a set piece.

- **Fate Rift** (hazard) — every 2 turns, inverts every 1 and 6 on the board and
  tears 3 out of your hull. Reuses the existing `FLIP_ONES_AND_SIXES` verb,
  which was previously only a player tile effect.
- **FATE_Rift** (encounter) — four 1-HP Fate Echoes under the Rift, on the
  fate-infection background. Added to `fate_scenarios`, so it can be the
  corrupted tile that opens a sector.

**The design, and why it needed the hazard to work:** dice only reach an enemy
through the targeting computer, so an enemy you aren't attacking does nothing.
That makes a swarm useless as a *damage* threat — it's a pile of HP that only
ever acts one ship at a time. But it's an excellent *time* threat, and the Rift
is what makes time cost something. Bring AOE (Chaos Explosion finally has a
reason to exist) or bleed for three turns while reality scrambles your hand.

Flipping 1s and 6s is also the most on-theme thing Fate can do: unlike damage
it can't be shielded against, only routed around, and it specifically punishes
a turn that was already carefully planned.

**Verified live:** jumped in — four glitching echoes, "FATE RIFT IN 2 TURNS" in
purple over the infection background. Ran two player turns: dice went
[1, 6, 3] → [6, 1, 3] (the 3 untouched), hull 20 → 17, countdown reset to 2.

---

## 2026-09-17 — Architecture overview brought up to date

**Built:** Documentation, not code. `ARCHITECTURE_OVERVIEW.md` is the file
that explains this project to someone arriving cold, and a night of systems
work had left it describing a game that no longer exists.

Added or corrected:
- `JumpManager`, `HazardManager`, `RunStats` in the systems table; the two new
  UI readouts in the UI table; `ScenarioHazardResource` in the content table.
- A new **Run Progression** section — sector layout, the gate-not-boss trigger,
  the advance/win path, and the two difficulty multipliers with a note on *why*
  damage scales slower than health.
- A new **Scenario Hazards** section, including why the countdown banner is the
  feature's justification rather than decoration.
- Save system: `sector_index`, deletion on victory, and the fact that nothing
  writes during a sector transition (so quitting mid-jump reloads at the gate
  with its fight intact).
- Signal tables: `sector_advanced`, `victory`, the three hazard signals,
  `player_shields_broken`, and the two new `TileEvent` hooks.
- `EnemyResource.pool_selection` documented as a table, with the note that none
  of the three modes costs anything from the perfect-information pillar.

Two warnings written in as blockquotes because both are silent-failure traps I
hit or nearly hit tonight:
- **Subtype numbering is load-bearing** — `.tres` stores category/subtype as
  raw ints, so inserting mid-enum rewires authored content with no error.
- **Runaway chains** — the new `_MAX_EVENTS_PER_RUN` ceiling and what it's for.

**Why now rather than at the end:** the reasoning behind a decision is only
cheap to write down while it's still in your head. A list of what changed is
recoverable from git; *why damage scales at 0.20 and health at 0.35* is not.

---

## 2026-09-17 — Juice: the handover has weight, and a shield break is a moment

Two feel changes, both aimed at things BRAINSTORMING §8 calls underplayed.

**1. The handover is weighted by die value.** The die flying out in front of an
enemy before it acts is the most repeated moment in the game and the whole
thesis of it — you armed them, now watch what you armed them with. It was a
flat 0.75s float regardless of what you'd handed over.

Now a 1 skips across in 0.45s and shrinks slightly; a 6 drags for 0.95s and
grows as it arrives; the beat before the action fires scales the same way
(0.15s → 0.45s). A turn's worth of handovers now has a felt threat-texture
before the player re-reads a single intent. Two constants and a `lerpf`.

**2. Shield break got its own signal.** `Health.shields_broken` fires only on
the transition from protected to exposed — `shields_damaged` was covering both
the chip damage and the moment the floor drops out, which flattened the more
dramatic of the two.

- Player: escalates from the small shake to the large one.
- Vignette: cyan instead of blue, nearly double the brightness, and a 1.4s fade
  instead of 0.75s, so the screen stays lit while it sinks in.

Enemies get the signal too; nothing listens yet, but the hook is there.

**Verified live:** ran an enemy turn with a 1 and a 6 handed over, and
triggered a shield break directly — the screenshot shows the cyan wash across
the whole frame with the camera visibly kicked.

**Also did a full QA pass** on a real fight rather than synthetic calls: spent
three dice through the actual drop handler, ended the turn, let the enemy act,
and confirmed damage, die handover, the return of dice, and an idle engine with
an empty queue afterwards. Zero game errors in the log (everything in there is
warnings from my own eval snippets).

**A design thing I hadn't appreciated until watching it play:** dice only reach
an enemy through `GIVE_DIE_TO_TARGET`, which follows the targeting computer. So
*whoever you attack is who attacks you back*, and an enemy you ignore does
nothing at all. That makes the Field Tender better than I designed it — you
cannot kill the medic without handing it the dice it heals with.

---

## 2026-09-17 — Relay tiles, and a circuit breaker so they can't freeze the game

**Built two things, in this order on purpose.**

**1. `ScenarioEngine` event ceiling.** `process_event_queue()` drains until the
queue is empty, and nothing stopped a chain from refilling it forever — two
tiles activating each other would hard-freeze the game with no error anywhere.
Added `_MAX_EVENTS_PER_RUN = 2000`: past that, the queue is dropped and a
`push_error` names the likely cause. Nothing legitimate comes near it (a full
three-enemy turn is a few hundred events; one tile activation a couple of
dozen), so this only ever fires on a genuine runaway. This is worth having
whether or not relays exist — I may well have hit an unguarded version of it
earlier tonight.

**2. `TILE_CONTROL/PASS_DIE_TO_TILE` + the Signal Relay.** `ACTIVATE_TARGETED_TILES`
fires the next tile with *no* die, so anything carrying `REQUIRES_ACTIVATOR_DIE`
— most of the game's tiles — silently refuses. The new verb passes the die
itself, which is what makes a relay actually able to feed a cannon.

**Signal Relay** (green, any die): deal 2 damage, then pass the die one cell
right; that tile activates with it. Chain them and a single die walks the row,
firing everything it lands on. This is the closest the game gets to letting the
player build a *machine* rather than pick a loadout.

**Verified live:** three relays in a row feeding a Damage tile — one 4 fed in at
the left end dealt 2+2+2 from the relays and 4 from the cannon, 10 total, engine
idle and queue empty afterwards. Then a relay at the right edge with nowhere to
pass to: 2 damage dealt and the die handed to the targeted ship, **0 orphaned
dice** on the board.

**That orphan case is the whole reason the fallback exists.** `TileActivationEvent`
pulls the die out of the source tile's queue before the chain runs, so a relay
that simply found no target would leave a die floating in open space owned by
nobody. `PassDieToTileEvent._hand_die_off()` gives it to the targeted ship
instead, exactly like a normal tile would. Same class of bug as the earlier
`KEEP_DIE_WITH_ACTOR` one — worth remembering that *every* chain ending has to
account for where the die goes.

---

## 2026-09-17 — One boss kit, three escalating fights

**Built:** The sector boss is now picked *by sector index* rather than at
random, clamped so the list can be shorter than `demo_sector_count`. Two new
encounters built from the same Sector Warden, per DEMO_PLAN's "1 kit, 2–3
escalation variants":

- **Sector 1** — the Warden alone, Solar Flare overhead.
- **Sector 2** — Warden + Field Tender. The Warden's own turtle phase (66–34%)
  shields but doesn't heal; the Tender does. That window can now genuinely stall
  out if you don't deal with the barge first.
- **Sector 3** — Warden + two Ion Lances. The enraged phase eats your dice while
  the Lances drain the engine charge you would have fled on. And killing one
  Lance flips the other into its vengeance pool — so the escort escalates too.

Everything here is reuse: same boss enemy, same phases, same hazard, new
compositions. The only code change is four lines choosing `[sector]` instead of
`pick_random`.

**Why indexed rather than random:** the boss is the one encounter a player is
guaranteed to meet exactly once per sector. That makes it the clearest possible
place to show a run getting harder — a random pick would have made sector 3
sometimes easier than sector 1, which is the opposite of the point.

**Verified live:** generated sectors 1–4 and confirmed boss/gate ordering with
correct clamping past the end of the list, then jumped into the sector-3
variant: 64 HP Warden flanked by two Lances with the flare counting down.

---

## 2026-09-17 — Tiles that react instead of consuming dice

**Built:** Two new `TileEvent.EventType` hooks and the first tiles that take no
dice at all. Tile count 21 → 23.

New hooks (appended; `ON_PLAYER_FATAL_DAMAGE` is pinned at `= 100` so the gap
absorbs additions safely):
- `ON_ENEMY_TURN_OVER` — every enemy has finished acting.
- `ON_PLAYER_HEALTH_HIT` — the hull, not the shields, just took damage.

Both wire straight to `Events` signals that already existed; `tile.gd` just had
to listen.

- **Counterweight Battery** (blue) — at the end of every enemy turn, gain 3
  shields. Takes no dice, ever.
- **Spite Coil** (red) — whenever your hull is hit, deal 3 damage to a random
  enemy. Takes no dice, and pairs *badly* with shields on purpose: it only pays
  out once damage is actually reaching the hull, so it rewards a build that
  stops trying to block everything.

**Why this is a new class, not two more tiles:** every tile in the game until
now converts dice into effects. These convert *board space* into effects. The
3×5 grid is the scarcest thing the player owns, so "a whole cell that never
takes a die" is a real cost paid in a currency nothing else charges. It also
gives the game somewhere to put passive/reactive design that doesn't compete
for the dice economy.

Their plate art carries a crossed-out die instead of an activation face — one
glance says "don't bother dragging anything here."

**Verified live:** `Events.enemy_turn_over` gave +3 shields; player hull damage
14 → 12 on a Venom Fighter via the Spite Coil.

**Testing note:** the Spite Coil appeared not to fire on my first attempt. It
had fired — the engine was still mid-`await` on the Battery's chain from the
previous eval, so the retaliation was queued but unresolved when I read the HP
one eval later. Chained effects need a beat before you measure them; reading
engine state (`currently_processing_queue`, `event_queue.size()`) is the way to
tell "didn't happen" from "hasn't happened yet."

---

## 2026-09-17 — Squads notice when one of them dies

**Built:** A third `PoolSelection` mode, `SQUAD_LOSSES`. `Enemy.squad_losses`
counts ships of its own faction that have died since it arrived, and the pool
index follows that count — intact squad draws from the first pool, sole
survivor from the last.

Careful about what counts: `Events.enemy_left` also fires when a ship flees or
when combat ends peacefully, so only ships actually at 0 HP increment it.
Nothing to get angry about otherwise.

Authored on the **Ion Lance**, which now has two pools:
- **Wing intact** — measured. One siphon (3–5), one quake, some pressure, and a
  wasted face.
- **Wingman down** — no wasted faces at all, siphons deepen to 5–8, attacks to
  4–7, and a second quake enters the pool.

**Why:** BRAINSTORMING calls enemy reactivity the biggest opportunity in the
codebase, and this is the cheapest honest version of it. It costs nothing from
the perfect-information pillar — the six slots are still fully resolved and
visible before you commit a die — but it makes *kill order* matter in the
two-Lance fight. Leaving one alive on low HP is now worse than it looks.

It's also pure `PoolSelection` reuse: one enum value, one counter, one match
arm. Any enemy can opt in by authoring a second pool.

**Verified live:** jumped into the two-Lance fight, recorded the survivor's
intents (Siphon 5 / Quake / Cannon 3,3,2,3 — pool 0 ranges, with a gap), killed
its wingman, regenerated: 3× Quake / Cannon 6,6 / Siphon 6 — pool 1 ranges, no
blank face.

**Test I got wrong first:** read `_current_pool_index()` inside the same return
dictionary that also contained the kill, so the "before" value was measured
after. GDScript evaluates dictionary values in order — capture comparison state
into a variable *before* the mutating line, not in the same expression.

---

## 2026-09-17 — Runs end with something to say about themselves

**Built:** `RunStats` (`Systems/RunStats`) — a small tracker listening to four
signals that already existed:
- `sector_advanced` → sectors reached
- `combat_finished` → encounters cleared
- `enemy_left` → ships destroyed (only counting ones actually at 0 HP; that
  signal also fires when a ship flees or when combat ends peacefully)
- `set_money` → credits *earned*, counting increases only so shop spending
  doesn't erase the total

One arcade-style line on both end screens, under the big label:
`SECTOR 2/3   11 ENCOUNTERS   19 SHIPS DOWN   142 CREDITS`

**Why:** DEMO_PLAN lists "no post-run loop" as a must-fix. Four numbers is the
right size — a player can read them in one glance and compare against their
last attempt. A run that ends with nothing to say about it doesn't invite
another one, and until tonight this game's runs didn't even end.

**Verified live:** seeded the tracker, fired `Events.victory`, and the line
renders correctly between the VICTORY label and the buttons.

---

## 2026-09-17 — Later sectors don't open on the same encounter every time

**Built:** `GameStateManager._pick_arrival_scenario()`. Sector 1 still uses the
authored `starting_scenario`, so a new run always opens on the same deliberate
first impression. Sectors 2 and 3 now arrive at a random question scenario
that isn't already somewhere in that sector.

**How I found it:** while testing the new events I saw
`EVENT_pirate_attacking_civilian` appear twice in one generated sector and
assumed `Utils.array_while_excluding` was broken. It isn't — the arrival
scenario is `insert()`ed separately after the shuffle, with no exclusion check,
and it happens to *be* that event. Not a duplication bug.

The real problem it exposed was worse and quieter: with sectors chained, the
player now drops out of hyperspace into the *identical* encounter at the start
of all three sectors. That makes a jump gate feel like a reset rather than
progress — exactly the opposite of what the gate is for.

**Verified live:** generated sector 1 (authored start) then sampled 12 sector-2
generations; arrivals spread across mercy call / sleeping drone / tollkeeper,
and never landed on an encounter already placed in that same sector.

---

## 2026-09-17 — Three new event encounters, built on state-entry effects

**Built:** Event scenarios went 2 → 5. DEMO_PLAN wants 4–6, and two was very
thin across ~54 tile-pulls in a three-sector run.

The interesting discovery: `ScenarioShipState.effects_on_enter` was only ever
used by the shop (to open the shop UI). It's a full `EffectChain` that fires
the instant a ship enters a state — which means an encounter can *do* something
to you on arrival, before a single die is placed. All three new events are built
on that.

- **Mercy Call** — a civilian Field Tender patches your hull for 6 the moment
  you drop out of hyperspace, for free. Then it just sits there, friendly, worth
  25–45 credits and three rewards if you shoot it. The heal is already banked;
  the game is only asking whether you'll take the gift and then take the ship.
- **The Tollkeeper** — a pirate Ion Lance deducts 6 engine charge on arrival and
  waves you through. Refusing means a fight you could have walked away from —
  except engine charge is exactly what lets you walk away from anything.
- **Wreck Salvage** — a venting hauler hands you two holographic dice and is
  genuinely harmless. Its escort watches, neutral, and treats an attack on
  *either* ship as an attack on itself.

**Verified live:** Mercy Call healed 12 → 18 on arrival with a friendly (green)
attitude indicator and a hidden intent row. Tollkeeper drained engine charge
10 → 4 and left the game out of combat with a neutral ship on screen.

**Noted, not fixed:** `ScenarioEvent.PLAYER_LEFT_SCENARIO` is declared in
`ScenarioManager` and never emitted anywhere. Any event that wants to pay out
for *leaving peacefully* needs that hook wired up first — worth doing, since
"the reward for not shooting" is currently unexpressible.

Also visible while testing: the sector generator rolled
`EVENT_pirate_attacking_civilian` twice into one sector. `Utils.array_while_excluding`
is meant to prevent that; worth a look separately.

---

## 2026-09-17 — The Field Tender, and a fight that's a decision instead of a race

**Built:** `repair_ally` and `aegis_ally` were authored earlier tonight and had
no owner. They do now.

**Field Tender** (12 HP / 8 shields) — a repair barge, drawn from scratch: a
boxy utility hull with a green sensor band, a repair cross stencilled on its
face, and two emitter pods on side arms. Against two gray Venom Fighters it
reads as "the medic" from across the screen with no UI help at all.

Two of its six faces are *always* support (Repair Beam 4–8, Aegis Link 4–8,
both `force_include` at weight 0). It barely attacks — 1–3 damage. The point
isn't the Tender's threat, it's that killing it first is a real decision rather
than an obvious one: every turn you spend on a soft 12 HP barge is a free turn
for the two ships that actually hurt you.

New fight: **COMBAT_TenderEscort** — Venom Fighter / Tender / Venom Fighter.
Combat templates now 8 → 9.

**Verified live:** dropped an ally to 5 HP, fed the Tender a 1 and a 5. Ally
healed 5 → 13, a *different* ally gained 4 shields, and the Tender's own 12/8
never moved. `TARGET_RANDOM_OTHER_ENEMY` correctly refuses to pick the actor.

---

## 2026-09-17 — Enemy damage scales with the run, not just enemy health

**Built:** `GameStateManager.get_damage_multiplier()`, applied in
`EnemyActionOptionResource.get_action()` — the single place a turn's intent
amounts are rolled.

Two separate knobs now:
- `difficulty_scale_per_sector` = 0.35 → health/shields ×1.0 / ×1.35 / ×1.70
- `damage_scale_per_sector` = 0.20 → intent amounts ×1.0 / ×1.20 / ×1.40

Damage scales *slower* than health on purpose. A tankier enemy only lengthens a
fight; a harder-hitting one can invalidate a defensive build outright, and the
player's damage output grows faster over a run than their max health does.

**Why:** DEMO_PLAN lists this as a must-fix blindspot, and it's the right call —
with only health scaling, sector 3 was strictly *longer* than sector 1, not
harder, while the player's deck got better the whole way. Fights that take more
turns without being more dangerous are the worst version of difficulty.

**Verified live:** regenerated the same enemy's turn at sector_index 0/1/2 and
confirmed the multipliers land at 1.0 / 1.2 / 1.4 against 1.0 / 1.35 / 1.7 for
health.

---

## 2026-09-17 — Three new player tiles (and a near-miss that would have broken every .tres)

**Built:** The player side hadn't gained anything all session, so: two new
effect verbs and three tiles that need them. Tile count 18 → 21.

New verbs:
- `AMOUNT_MODIFIER/ADD_EMPTY_ADJACENT_CELLS` — the exact inverse of
  `ADD_ADJACENT_TILES`.
- `CONDITIONAL/IF_TARGET_HOLDS_MATCHING_DIE` — true when the target is already
  holding a die showing the activator's value.

Tiles (art drawn to match the existing chrome exactly — frame, dark icon panel,
chamfered plate, activation die face):
- **Solar Sail** (blue, die 2) — 2 shields per *empty* cell touching it. Every
  adjacency effect in the game so far rewards packing the grid; this one pays
  for clearance, so a sparse board becomes a build rather than an unfinished
  one, and the two philosophies now compete for the same cells.
- **Overclock Coil** (red, any die) — 2 damage, +2 for every time it already
  fired *this turn*, reset at turn start. The counterweight to every
  spread-your-dice-around synergy tile: this one wants the whole hand dumped
  into one cell.
- **Grudge Cannon** (green, die 5) — 4 damage, or **9** if the target is already
  holding a 5. Then it gives them the die. So feeding it one 5 sets up the next
  5 for more than double, in the same turn, by your own hand. This is the most
  on-theme thing in the game: it pays you for tracking which numbers you've
  already handed away.

**Verified live:** Solar Sail with 1 empty neighbour gave exactly 2 shields.
Grudge Cannon dealt 4 (18 → 14), handed over the die, then dealt 9 (14 → 5) on
the follow-up 5. Overclock dealt 2 then 4 with its counter at 2 then 4, and
`Events.player_turn_start` zeroed it.

**The near-miss, and the rule that comes out of it:** I first added
`ADD_EMPTY_ADJACENT_CELLS` in the *middle* of `AmountModifierSubtype`, right
after `ADD_ADJACENT_TILES`. `.tres` files store `subtype` as a raw int, so that
one line silently renumbered `ADD_TILE_DATA` 4 → 5, `SET_TO_ENGINE_CHARGE`
5 → 6, `SET_TO_DIE_VALUE` 6 → 7 and `SET_TO_ENEMY_INTENT` 7 → 8 — which would
have quietly rewired every enemy attack and half the tiles in the game into the
wrong effect, with no error anywhere. Caught it while authoring the next tile.

Moved it to the end and wrote the rule into `effect_enums.gd`'s header so the
next person hits it as documentation instead of as a bug: **append new subtypes,
never insert.** Same applies to `Category` itself.

---

## 2026-09-17 — Scenario hazards: the environment gets a turn too

**Built:** A new system for recurring environmental events attached to a
scenario.

- `ScenarioHazardResource` — name, description, colour, a first-trigger delay,
  a repeat interval, and an `EffectChain`. Hangs off `ScenarioResource.hazard`
  (null = a plain quiet fight).
- `HazardManager` (`Systems/HazardManager`) — arms on `Events.load_scenario`,
  counts down on `Events.player_turn_start`, and queues a `HazardEvent` onto the
  live scenario engine when it lands. Because it goes through the engine, a
  flare's damage passes the same modifier pipeline as everything else.
- `HazardIndicator` — a countdown banner across the top of the sky, red at one
  turn out, shaking when it fires.

Three hazards, attached to four encounters:
- **Solar Flare** (Wolfpack, boss fight) — every 3 turns, wipes *all* shields on
  the board and burns every ship for 3. It hits the enemies too, which is the
  interesting part: the strongest play is timing your big swing for the turn
  right after the flare, when nothing on screen has any shields left.
- **Ion Storm** (Ion Lances) — every 2 turns, rerolls every die on the board.
  Damages nobody, and is far worse for a carefully-planned turn than 3 damage.
- **Asteroid Impact** (Drone Battery) — every 2 turns, locks a random tile.

**Why the countdown matters:** the banner isn't decoration, it's the entire
justification for the feature. A flare that wipes the board without warning is
a dice roll. One you watched count down for two turns while deciding whether to
spend on shields is a decision. Same rule the intent telegraph already follows.

**Verified live:** jumped into the Wolfpack fight, gave both Venom Fighters 6
shields, ran three player turns. Shields 6 → 0 on both, HP 18 → 15 on both,
player 20 → 17, countdown reset to 3. Banner read "SOLAR FLARE IN 3 TURNS"
throughout.

---

## 2026-09-17 — Revived the four dead tiles, and killed every boot error with them

**Built:** `ComplicatedTileResources/` held four fully-designed tiles —
Tactical Boomerang, Shield Attractor, Inertial Feedback, Unstable Shield Array
— that still referenced the deleted pre-V2 effect system. They had finished
art, finished descriptions, and were completely unloadable. Ported all four to
EffectChain, moved them into `TileResources/`, and deleted the broken
originals. Tile count 14 → 18.

- **Tactical Boomerang** (2 uses) — 5 damage to your target, then kicks *itself*
  one cell: left on a 3, right on a 4. Using it twice in a row means planning
  where it lands.
- **Shield Attractor** (2 uses) — tears 6 shields off the target instead of
  dealing damage, hands them the die as payment, and drags every tile in its row
  toward itself.
- **Inertial Feedback** — counts every tile that moved anywhere on the grid this
  combat and dumps that number into *every other ship* at once, then resets.
  Listens for both pushes and manual moves now, not just pushes.
- **Unstable Shield Array** — takes no dice at all. It pays out only when
  something else shoves it: 2 shields, +1 per push since you last picked it up.
  Repositioning it by hand wipes the stack.

**Why the errors mattered:** `RewardManager`, `ContentRegistry`, and the dev
console all scanned that directory on startup, so every single boot logged ~184
errors trying to load four files. Real problems had nowhere to hide in that
noise. Boot is now zero errors — only the project's pre-existing untyped-var
warnings remain.

**Bug I authored and caught:** the shield array's stack grew 0 → 2 → 6 → 14 → 30
instead of 0 → 1 → 2 → 3. `IncrementTileDataHandler` uses `context.running_amount`
as the step size (falling back to 1 only when it's zero), and running_amount was
still holding the shield total from two steps earlier. Needed an explicit
`AMOUNT/SET 0` before the increment. Verified the fix live: pushes gave +2, +3,
+4 shields with the stack at 1, 2, 3, and a manual move reset it to 0.

**Snag:** a live eval that set `Globals.player.health.shields` directly wedged
the game's main thread — second time an eval has done that tonight (the first
was constructing `EffectData` by hand). Both times normal gameplay was
unaffected. Rule of thumb going forward: drive tests through signals and public
methods (`Events.tile_pushed.emit(t)`, `enemy.run_turn()`), never by poking
component state directly.

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
Worth porting to EffectChain — they have good ideas in them.
