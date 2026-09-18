# Die Fighter — Dev Log

Newest entries at the top.

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

The interesting discovery: `ScenarioShipState.effects_on_enter_v2` was only ever
used by the shop (to open the shop UI). It's a full `EffectChainV2` that fires
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
  a repeat interval, and an `EffectChainV2`. Hangs off `ScenarioResource.hazard`
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
EffectChainV2, moved them into `TileResources/`, and deleted the broken
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
Worth porting to EffectChainV2 — they have good ideas in them.
