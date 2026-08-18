# Plan for Fun — One Month to a Testable Run

## Mission

Find out if Die Fighter is fun *before* spending more time on polish. That means, in order: (1) a full playable run exists start-to-finish, (2) the combat/shop loop that run is built from has enough real content and enemy texture to actually judge, (3) only then — and only if 1 and 2 earn it — juice.

This file is the scoped, checkbox-able month plan. It doesn't re-derive design work that's already done:
- **[DEMO_PLAN.md](DEMO_PLAN.md)** has the full technical spec for Phase 1 (exact files, functions, line numbers). Phase 1 below is just that plan's phases as checkboxes.
- **[BRAINSTORMING.md](BRAINSTORMING.md)** has a large menu of ideas for enemy AI (§1), new enemy verbs (§4), location modifiers (§5), new tiles (§3), and juice (§8-9). Phase 2 and 3 below pick a scoped subset out of that menu with a numeric target — treat the rest of that doc as the backlog for after this month.
- Code-health cleanup (`CLEAN_UP_PLAN.md`, `GLOBAL_CLEANUP_PLAN.md`, `CLEANUP_PROGRESS.md`) is orthogonal to this plan. Fine to fix things opportunistically as you touch files, but it's not a blocker for any phase below.

## Timeline at a glance

| Phase | Target window | Gate to move on |
|---|---|---|
| 1 — Close the loop | This weekend | You've played one full run, sector 1 → 3 → win |
| 2.0 — Enemy action rework | Week 1 (before new enemies) | Existing 4 enemies rebuilt on new system |
| 2.1 — Location modifiers | Week 1-2 | All 6 backgrounds have a mechanical hook (or a deliberate "baseline") |
| 2.2 — Tile/enemy content | Weeks 1-4, ongoing | Numbers table below, roughly |
| 3 — Juice | Whatever's left, only if 1+2 feel fun | N/A — explicit checkpoint, see bottom |

---

## Phase 1 — Close the Loop (target: this weekend)

Goal: start a new game and play sector 1 → sector 2 → sector 3 → a win screen, without a crash. Balance doesn't matter yet — reachability does.

This is [DEMO_PLAN.md](DEMO_PLAN.md) turned into checkboxes. It already found that the scaffolding for this is mostly built and unused (`ScenarioResource.sector_gate_scenario`, the orphaned `JumpGate` scenario, a single choke point for enemy stats) — this is finishing something half-started, not building from scratch.

- [ ] **Phase 1 (save):** add `sector_index: int` to `GameSaveResource`; add a difficulty-multiplier getter to `GameStateManager`
- [ ] **Phase 2 (reusable generator):** make `_randomize_sector_scenarios()` end with the `JumpGate` scenario as the sector's true final tile, after the boss
- [ ] **Phase 3 (scaling):** apply the difficulty multiplier to enemy health/shields at spawn in `enemy.gd`
- [ ] **Phase 4 (transition):** detect "cleared the last tile in the sector" and branch into `_advance_to_next_sector()` instead of the normal checkpoint flow
- [ ] **Phase 5 (win state):** add `GameState.VICTORY`, `Events.victory`, wire `game_over.gd`'s "VICTORY!" to only fire on the real ending, not every sector clear
- [ ] **Phase 6 (playtest):** play one full 3-sector run end-to-end; note (don't fix yet) where it drags or spikes

**One open call from the brainstorm, worth deciding before Phase 6:** with the plan above, sector 2 and 3's "boss" is the same Sector Boss enemy, just scaled up by the difficulty multiplier. That satisfies "a boss fight to close each sector" cheaply. Whether the *very last* encounter (your "cap things off" final boss) should be this same scaled boss, or something bespoke, is a real choice:
- [ ] **Decide:** ship the weekend goal with the scaled-reused boss as the final encounter (fast, keeps Phase 1 small) — **recommended**, so you don't block the whole loop on new content
- [ ] (optional, park for Phase 2/3 if picked) author a distinct final encounter/final boss once you know the loop is fun enough to be worth the content investment

---

## Phase 2 — Make the Middle Interesting (target: rest of the month)

### 2.0 — Enemy action system rework (do this first, before writing new enemies)

Today, every enemy picks one of 1-2 weighted action pools by `turns_alive % len(pools)` (`enemy.gd:184`) — zero reactivity to player state or other enemies. `BRAINSTORMING.md` §1 has ~12 ideas for this; scoping to three for this month so new enemies have something to actually be built against:

- [ ] **HP-threshold phases** — swap the `turns_alive % len(pools)` index for an HP-based one (e.g. 100-66% / 66-33% / <33% phases). Small change, same weighted-pool machinery, makes every enemy feel like it's actually losing.
- [ ] **Squad vengeance** — when one enemy in a multi-enemy scenario dies, its allies' pools shift toward `attack` for N turns. This is the minimum viable version of the "enemy synergy" you asked for — cheap (a signal listener), and it's the one that most needs to exist before you write multi-enemy scenarios.
- [ ] (stretch, only if the above feels too thin) **player-board-aware weighting** — enemy weights shift based on player shields/HP when it rolls its slots
- [ ] Rebuild the 4 existing combat enemies (Attacker, Cannon Drone, Defender, Disabler) on the new system first, as validation, before writing new enemies against it
- [ ] Add 2-3 new base action verbs before/while adding new enemies — currently only 5 exist (attack/shield/flee/lockout/do-nothing). Per BRAINSTORMING §4's own "cheapest, highest payoff" pick: **Dice Thief** (steals a die from your queue — attacks the resource the whole game is about), **Engine Siphon** (drains engine charge, not HP), **Grid Quaker** (pushes a player tile, reusing existing `push_tile()`)

Explicitly **not** this month (bigger swings, flagged as such in the brainstorm itself): split-component bosses, dice-trading squads, overload thresholds. Revisit once the above is live and content is being built on it.

### 2.1 — Location-based modifiers

`BackgroundManager` already has 6 presets with zero mechanical weight. Cheap, high-leverage — wiring effects onto backgrounds that already exist multiplies every tile/enemy you add afterward. Using your own examples from earlier plus BRAINSTORMING §5:

- [ ] Design the hook point (per-turn tick vs. per-scenario-start; probably a field on the background resource + a handler read at combat start/turn end)
- [ ] `debris_field` → **Asteroid Field**: chance per turn to lock a random grid tile for a turn (reuses existing `LOCKOUT_TILE`, just aimed at the player)
- [ ] `red_nebula` → **2x damage** modifier (decide: both sides, or just whichever deals it — pick whichever reads as more "danger zone")
- [ ] `blue_nebula` → **+3 shields** to the player every turn
- [ ] `fate_infection` → tie into the existing corruption visual language — even a small effect twist (BRAINSTORMING's "Fate Rift" idea, scoped down) fits here for free thematically
- [ ] `star_field` / `empty_space` → confirm as deliberate baseline (no modifier) — not everything needs a mechanic, and the calm zones make the dangerous ones read as dangerous by contrast
- [ ] Surface the active modifier clearly in UI (icon + short tooltip) — the whole point is the player can *plan* around it, so it can't be a surprise

### 2.2 — Tile & enemy content cadence

Numbers below are a starting point to check your own instincts against, not a hard requirement — adjust by feel as you go.

| Content | Current | Target (end of month) |
|---|---|---|
| Basic tiles | 14 | 24 (+10) |
| "Complicated" tiles | 4 (broken, pre-V2) | 4 working (ported, not net-new) |
| Combat enemies | 4 | 7-8 (+3-4) |
| Boss encounters | 1 | 1 reused+scaled, or up to 3 distinct — per Phase 1 decision |
| Enemy base actions/verbs | 5 | 8 (+3, from 2.0) |
| Location modifiers | 0 | 6 (1 per background, from 2.1) |

- [ ] **Port the 4 legacy tiles first** (Tactical Boomerang, Shield Attractor, Inertial Feedback, Unstable Shield Array) to EffectChainV2 — the designs already exist, they're the cheapest tiles on this list, and BRAINSTORMING §3 notes they already hint at push/pull and stacking archetypes worth reusing elsewhere
- [ ] New basic tile #1: ___
- [ ] New basic tile #2: ___
- [ ] New basic tile #3: ___
- [ ] New basic tile #4: ___
- [ ] New basic tile #5: ___
- [ ] New basic tile #6: ___
- [ ] New basic tile #7: ___
- [ ] New basic tile #8: ___
- [ ] New basic tile #9: ___
- [ ] New basic tile #10: ___
- [ ] New combat enemy #1 (built on the 2.0 system): ___
- [ ] New combat enemy #2: ___
- [ ] New combat enemy #3: ___
- [ ] New combat enemy #4: ___

(Pull archetypes from BRAINSTORMING §3 for tiles and §4 for enemy verbs/types when you're stuck for an idea — both are organized as grab-bags specifically for this.)

---

## Phase 3 — Juice (only after Phase 1 is fully played and Phase 2 feels good)

- [ ] **Checkpoint before starting this phase at all:** played several full runs, and the honest answer to "is the core loop fun, even rough?" is yes. If it's "meh," stay in Phase 2 — don't juice an unclear signal.

Curated from BRAINSTORMING §8 (which has ~40 ideas across 10 subsections) — this is the subset I'd actually spend a month's remaining time on, roughly in order:

- [ ] **§8.0 — Data-driven `AUDIO_VISUAL` subtypes** (`HITSTOP`, `ZOOM_PUNCH`, `FLASH_TARGET`, `SLOW_MO`, `SPAWN_DAMAGE_NUMBER`, `SCREEN_SHAKE`, `VIGNETTE_PULSE`). Do this **first** even though it's not itself a "feel" moment — it's a week of plumbing that turns every item below into inspector-authorable content instead of one-off code, same payoff pattern as EffectChainV2 itself.
- [ ] **§8.3 — The impact trio** (flash + hitstop + shake, scaled to damage). The brainstorm's own #1 highest-impact-per-hour pick — touches every single hit in every fight.
- [ ] **§8.2 — Combo pitch ladder** on tile activations. Nearly free (`SFXPlayer.get_pitch_escalation()` already exists), and it's the Balatro trick — climbing pitch as a turn's activations cascade.
- [ ] **§8.1 — Staggered roll cascade + per-die clatter.** Cheapest perceived-quality win in the whole list; dice currently all move at once.
- [ ] **§8.4 — Handover tractor-beam + intent-slot reaction.** Your signature repeated moment (arming your own enemy) is currently a polite float. This is also, per BRAINSTORMING §9, your single best gif/trailer pitch — "die glows 6 → dragged onto cannon → huge hit → same die tractor-beamed to the enemy, landing on their attack slot as their guns light up" is a 6-second loop that explains the whole game.
- [ ] **§8.6 — Staged death sequences.** Also flagged in §9 as strong trailer/gif material; current death is one explosion + despawn.
- [ ] **§8.10 — Accessibility toggles** (shake/flash/hitstop/damage numbers). Do this *alongside* whichever of the above ships first, not saved for last — cheap now, and it lets you push defaults harder knowing sensitive players can dial down.

**Deliberately parked, not dropped** — revisit after this month if you want more juice runway: vertical music layering (§8.9), the Fate/glitch-as-language pass (§8.8), ambient idle life (§8.7), cockpit-as-body low-HP treatment (§8.5). The brainstorm itself flags these as real but not top-of-queue.

If you want a second trailer-worthy set piece beyond the handover gif, BRAINSTORMING §9 also calls out **the Rube Goldberg chain** (one die triggering a relay cascade across the grid, §8.2's "chain choreography") as the "look how deep it goes" shot — worth keeping in mind if any of the tiles you build in 2.2 end up chain-triggering others.

---

## How you'll know it's working

- [ ] End of weekend: one full run played, sector 1 → 3 → win screen, no crash
- [ ] End of week 1: enemy action rework live, existing enemies rebuilt on it, at least one location modifier in the game
- [ ] End of month: numbers table above roughly hit, multiple full runs played, and you can list what's overpowered/underpowered/boring without me prompting you
- [ ] Before Phase 3 starts at all: the honest "is this fun yet" checkpoint above says yes
