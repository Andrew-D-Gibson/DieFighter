# Die Fighter — Brainstorm: New Systems, Tiles, Enemies, Story & Juice

## Context

This is a pure ideation document, not an implementation plan — nothing here gets built until you pick favorites. It's grounded in what actually exists in the codebase today (verified via exploration, not guesswork), so every idea below notes which real system it would hook into. The goal: give you a big menu of "yes, and" ideas across mechanics, AI, story, content, and *feel*, organized so you can grab a handful and ignore the rest.

**The engine is in great shape for this.** The EffectChainV2 / EffectData / EffectHandler / EffectRegistry pipeline (`Source/Behavior/EffectsV2/`) is a genuinely clean, data-driven verb library — 10 categories, ~50 subtypes already. Most ideas below are "new subtype + new handler," not "rewrite a system." I've flagged the few ideas that *are* bigger swings so you can weigh them differently.

## The Core Tension (the thing every idea should serve)

> **Use dice now vs. deny dice to enemies.**

Every enemy sees exactly what you gave them and does exactly what you'd expect — the tension is entirely about resource allocation, not hidden information. The strongest new ideas *sharpen* this tradeoff rather than route around it. I tried to filter for that.

**A second lens worth naming: the handover is your signature moment.** No other game has "and now I physically hand my weapon to my enemy" as its core verb. Several ideas below (and most of the Juice section) exist to make that one moment — the die leaving your hand and arriving in theirs — feel as dramatic as it actually is mechanically.

---

## 1. Enemy AI — From Static Tables to Reactive Intent

Right now enemy "AI" is 100% authored: each enemy has 1–2 weighted action pools (`EnemyResource.action_options`), the active pool is picked by `turns_alive % len(pools)`, and 6 slots (one per die face) are filled by weighted random draw, seeded once per scenario. There is **no reactivity to the player at all** — an enemy behaves identically whether you're at full HP or one hit from death. That's the single biggest opportunity in the codebase, and it's low-risk to add because the *telegraph* stays perfectly honest (you always see the resolved 6 slots before you act) — only the *table those slots are drawn from* gets smarter.

- **HP-threshold phases.** Swap `turns_alive % len(pools)` for HP-based phase triggers (e.g. Sector Boss: 100–66% "Guns Hot," 66–33% "Shields Up," <33% "Enraged" with a forced high-damage slot). This is a tiny change to `Enemy.generate_turn_actions()` — same weighted-pool machinery, just a different index function — but it makes every boss feel like it's actually losing the fight.
- **Grudge memory.** An enemy remembers the die value you hit it hardest with last turn and biases its next pool toward punishing that same value (e.g. "if the player gave me a 6 for massive damage, my next '6' slot becomes a forced heavy counter"). Creates a real "don't feed them the same number twice" metagame that's still 100% visible before you commit.
- **Squad vengeance.** Faction-linked weight shifts: when one pirate in a wolfpack dies, its squadmates' pools shift toward `attack` for N turns. Cheap to implement (a signal listener that temporarily swaps which `action_options` pool is active), and it makes multi-enemy pirate fights feel like a real gang rather than independent HP bars.
- **Player-board-aware weighting.** When an enemy rolls its 6 slots, let it glance at player state (shields high → weight shifts toward shield-piercing/drain actions; player low HP → weight shifts toward lethal burst). Still fully telegraphed, still fair — just makes "who am I fighting" feel distinct fight to fight instead of every attacker playing the same script.
- **Split-component bosses.** Give a boss 2–3 independently targetable subsystems (Weapon Array / Shield Generator / Engine), each with its **own** 6-slot intent bank. A die handed to "the boss" resolves against whichever subsystem you targeted. Turns one big HP bar into a target-prioritization puzzle — kill the shield generator first, or burn the weapon array to reduce incoming damage? This is a bigger swing (new targeting layer on `Enemy`), but it's additive, not a rewrite.
- **Fate-corrupted "flickering" intents.** Thematically free win: the game already has a Fate corruption visual language (`FateOrbParticles`, fate-infection background). A Fate-touched enemy's intent slot could visually flicker between two possible outcomes until the die actually lands, collapsing to one — mechanically it's just "this slot's action swaps on a timer," but it reads as the corruption literally destabilizing reality.
- **Mimic/mirror enemy.** An intent slot that copies whatever *effect category* (damage/shield/heal) the player most recently triggered with that same die value. An enemy that visibly "learns from you" mid-fight, still fully deterministic and pre-rolled each turn so it stays fair.
- **Coward logic.** An enemy whose pool swaps to `flee`-heavy the moment it drops below 30% HP or watches an ally die. You then face a genuinely new decision: burn dice finishing off a fleeing ship (that's barely a threat anymore) or let it go — knowing that with reputation/rival systems (§2), *letting it go has consequences later*. The `flee` verb already exists; this is purely a pool-swap trigger.
- **Dice-trading squads.** Two linked enemies that visibly pass dice between themselves at the start of their turn — the support ship hands its high dice to the gunship. Suddenly *which enemy you give the die to* matters even more, because it might not stay there. Reuses the exact give-away machinery the player already uses (great thematic symmetry), and the telegraph can show the post-trade result so it stays honest.
- **Overload thresholds.** An enemy that gets *too much* total dice value in one turn (say, 15+) overloads — skips its next turn, venting steam. Creates a fascinating inverted line of play: deliberately *stuffing* an enemy with big dice to trip its breaker. The core tension gets a third option: use dice, deny dice… or weaponize the gift itself.
- **The Auctioneer.** An enemy that opens each turn by publicly "bidding" on a specific die value: "I want a 4. Give me a 4 and I'll leave / drop loot / turn on my allies. Give me anything else and eat a counterattack." A pure information-and-temptation mechanic that costs almost nothing (one forced slot + dialogue) and creates table-talk moments streamers will love.

## 2. Faction, Reputation & Story

There's more here than it looks like at first glance. You already have a **dead `FactionSystem` class** (`Source/Content/Enemies/faction_system.gd`, defines PLAYER/PIRATE/CIVILIAN/SOLDIER, entirely unused), a **working per-scenario ship-state machine** (`ScenarioShipState` — attitude FSM: FRIENDLY/NEUTRAL/AGGRESSIVE, dialogue, weighted probabilistic transitions), and a **working typewriter dialogue system** (`EnemyDialogueManager`) already driving nice little vignettes like the Pirates-Attacking-Civilian event (help the civilian → grateful; attack the civilian → betrayed). None of this state persists past a single scenario. That's the gap and the opportunity.

- **Persistent reputation.** Revive `FactionSystem`, add a `Dictionary[Faction, int]` to `GameSaveResource`. Sparing civilians, sinking traders, or killing surrendering pirates nudges reputation, which then modifies: shop prices, ambush frequency, whether "help me" events trust you by default, and which dialogue branch plays first. Small write surface (save resource + a few `Events` listeners), big narrative payoff.
- **Recurring rival captain.** A specific named pirate `.tres` that uses the existing `flee` action (which already redistributes its dice away) — but instead of despawning for good, it reappears later in the sector, remembering the prior encounter. Spare it enough times and it might eventually *ask to talk* instead of attack. This reuses machinery you already built for a completely different narrative payoff.
- **Ship-vs-ship encounters.** Extend `ScenarioShipState` transitions so Pirates and Civilians can be hostile *to each other*, not just to the player — a scenario where you can let a pirate and a civilian trade blows while you conserve dice, or intervene on either side. The attitude FSM and scenario-event plumbing (`PLAYER_ATTACKED_PIRATE`, etc.) already generalizes to this; it just needs enemy-vs-enemy targeting added to the same event vocabulary.
- **Multi-scenario escort chain.** A civilian transport that persists across several sector jumps instead of one encounter — protect it through 3 map nodes for a large reputation/loot payout at the end, with real risk of losing it to a Fate zone or ambush at any jump. Turns the existing linear map into a mini side-quest thread.
- **Give the Fate Cult a face.** Right now "Fate" is pure hazard (a 1-HP punching bag enemy, corruption zones eating map nodes). Make it a faction with a doctrine: cultists who *want* the corruption to spread, and who offer the player a pact — take a powerful but "corrupted" tile (huge upside, a quiet permanent downside) in exchange for reputation or loot. Meaningfully raises the stakes of the existing Fate mechanic without inventing new systems, just new content on top of what's there.
- **Reputation-gated boss aftermath.** The sector boss encounter's outcome dialogue (and maybe reinforcements) could vary by accumulated reputation — a civilian coalition shows up to help if you protected them all sector, or you get flanked by military if you went full pirate. Pure content work once reputation exists.
- **In-grid dialogue choices.** Instead of breaking to a menu popup, some events could spawn a temporary "choice tile" directly on the 3x5 grid — placing a die on it *is* the choice. Keeps the story layer inside the game's central spatial-dice metaphor instead of feeling bolted on.
- **The gossip network.** Your deeds travel ahead of you via radio chatter. Jump into a new node and the first line of dialogue references something you actually did two nodes ago ("You're the one who let Krell's crew burn"). Mechanically this is just persistent reputation (above) plus a small library of conditional dialogue lines keyed to recorded events — but it's the single cheapest way to make the sector feel like a *place that's watching you* rather than a series of disconnected rooms.
- **Faction shops & the black market.** Shop inventory and prices keyed to reputation: military-aligned players see precision/defense tiles at fair prices; pirate-aligned players get a black market with sacrifice/glass-cannon tiles (§3) cheap and civilian-friendly tiles marked way up. One `RewardManager`/shop filter, big "my run has an identity" payoff.
- **The pacifist channel.** A talk-your-way-out path: some encounters can be defused by *giving specific dice as tribute* with zero tiles activated — the dice go to the enemy, they act (shield, posture), and then leave satisfied. Suddenly "spend nothing, survive the storm" is a real strategy, it's 100% inside the dice economy, and it gives reputation/story systems a nonviolent lever. A "ghost run" (finish the sector with zero kills) becomes an achievable challenge run.
- **Distress beacons with liars.** A map node broadcasting an SOS. Usually it's a real civilian (help → reputation + reward). Sometimes — telegraphed by subtle tells the player can learn to read (wrong faction ID, signal too clean, cargo manifest oddities via the scan verb) — it's a pirate trap. Teaches players to *read* the world, and the tells respect perfect-information philosophy: the truth is knowable if you pay attention.

## 3. New Tile Archetypes

You have 13 live tiles plus 4 broken-but-designed legacy tiles (`ComplicatedTileResources/`: Tactical Boomerang, Shield Attractor, Inertial Feedback, Unstable Shield Array) still referencing the deleted pre-V2 effect system. **Porting those four to EffectChainV2 is itself a great source of new archetypes** — they already have interesting ideas (self-pushing on hit, row-pulling, movement-scaled damage, stacking-shields-on-being-pushed) that just need new `TILE_CONTROL` handlers. Beyond reviving those, here are fresh archetypes grouped by the kind of decision they create:

- **Momentum/Movement.** Tiles that reward keeping the grid in motion — e.g. a tile that gains stacking damage per tile pushed this combat, resetting if the board goes static for a turn. Builds directly on the push/pull machinery already partially built for the legacy tiles.
- **Denial-focused.** Tiles that punish the *enemy* for the specific die value they're currently holding rather than just scaling off player stats — e.g. bonus damage if the target already holds a die matching the activator's value. This is the most on-theme archetype possible: it makes you actively track what you've already handed away and stack punishment on it.
- **Engine-economy expansion.** Right now only one tile (`Emergency Transfer`) really uses engine charge as a spendable resource. More tiles built around banking/spending charge — e.g. a coil that drains half your current charge for a big damage burst — would make the "gate for jumping/fleeing" resource into a real build-around axis instead of a side gauge.
- **Holographic fleet.** `Holo-Duplicator` already spawns one-use ghost dice; extend into a whole sub-archetype — tiles that scale off how many holographic dice are currently in play, a tile that "upgrades" a holo die into a real one, an ultimate that detonates every holographic die on the board at once for AOE.
- **Sacrifice/glass-cannon.** Tiles that cost you hull or shields for outsized effect (e.g. a cannon that deals big damage but also dings your own hull) — high-risk-high-reward content for aggressive builds, fitting a game already built around spending power at a cost.
- **Run-persistent "signature weapon."** Using the existing per-tile `effect_data: Dictionary` (already used for tracked counters like activation count), a tile could permanently gain +1 damage every time it's activated *across the whole run*, not just per-combat. Makes a specific early tile feel like it's growing into a signature weapon by the boss fight — no new system needed, just a different scope for a counter that already exists.
- **Adjacency-adaptive.** A tile whose behavior (damage vs. shield vs. heal) is determined by whichever effect type is most common among its neighbors, at reduced potency — rewards deliberate grid layout, deepens the puzzle-layer that adjacency-counting tiles (Flak Cannon, Amplifier) already hint at.
- **Deeper dice manipulation.** New `DICE_CONTROL` subtypes to sit alongside reroll/flip/duplicate: a "weighted reroll" that biases toward high values, a "split die" that turns one die into two half-value dice, a "fuse" that combines two dice into their summed value (capped at 6). Same category, more verbs.
- **Turn-scoped overclock.** The mirror image of the run-persistent tile above: a tile that gets stronger with each activation *this turn only*, resetting at turn start — rewards dumping many dice into one tile in a single turn, as a counterweight to the spread-your-dice-around synergy tiles you already have.
- **Reactive/retaliation tiles.** Currently `TileEvent` only covers `ON_TURN_START`, `ON_TILE_PUSHED`, `ON_TILE_MANUALLY_MOVED`, `ON_PLAYER_FATAL_DAMAGE`. Adding an `ON_ENEMY_ACTION_RESOLVED` hook would unlock a whole class of "if an enemy attacks you this turn, gain shields at end of enemy turn" tiles — small engine addition (one new TileEvent + a fire-point), broad content payoff.
- **Anchor tiles.** A tile immune to push/pull that instead redirects incoming push effects to an adjacent tile — gives the emerging spatial-puzzle layer a defensive counter-play option.
- **Tile fusion.** A shop or event service that welds two tiles you own into one hybrid: it inherits one tile's activation criteria and the other's effect chain (literally concatenate the two `EffectChainV2` arrays with a shared targeting prefix). Every fusion is a small design surprise the *player* authored, it frees grid space (spatially precious on a 3x5 board), and it turns end-of-run inventories into crafting material. The data-driven chain format makes this almost eerily cheap to build for how deep it plays.
- **Row/column set bonuses.** A tile family that gets +N per same-family tile in its row ("Laser Bank: +2 damage per Laser Bank in this row"). The grid already knows coordinates (`tile_locations: Dictionary[Vector2i, Tile]`); this creates deliberate *formation-building* — players arranging a gun deck along the top row — and makes the push/lock enemy verbs sting in a new way (breaking your formation, not just disabling one tile).
- **Conveyor / relay tiles.** A tile that performs a small effect, then *passes the die* to the next tile in a direction (which activates if criteria match). Chain three relays and the player builds a literal Rube Goldberg machine on the grid — self-expression through layout, and a spectacular thing to watch resolve (see Juice). `ACTIVATE_TARGETED_TILES` + a directional target selector is most of the machinery already.
- **Empty-space tiles.** A tile that scales off *empty cells* adjacent to it (solar sails need clearance). The exact inverse of the amplifier-adjacency pattern you already have — suddenly a sparse board is a build, tile placement has real tension against "just fill everything," and grid real estate becomes a resource with two competing philosophies.
- **Cursed Fate tiles.** The Fate Cult pact (§2) needs merchandise: tiles with a huge upside and an *honest, visible* drawback — "Deal 12. On activation, corrupt the die (it becomes value 6 in the enemy's hands regardless of face)," or "Massive shield, but this tile drifts one cell in a random direction each turn." Corrupted tiles get the glitch-shader visual treatment (see Juice §8) so your board *looks* increasingly haunted as you take more pacts. Build-around identity + visual storytelling in one.
- **Dice bank vault.** A tile that *swallows* a die this turn and returns it (same value) at the start of your next turn. It respects the letter of "all dice get given away" loosely enough to be spicy: you denied the enemy a die entirely, at the cost of your own tempo. Probably wants a steep cost (uses per combat, or the vault can be attacked/locked). Flagging like the Wild Die: this one bends a core rule, so treat as a rare, legendary-tier effect if at all.

## 4. New Enemy Verbs & Types

Only **5 action verbs exist in the entire game**: attack, shield, flee, lock a grid tile, do nothing. That's a strikingly small surface for how much texture the intent-telegraph system could support — this is probably the highest-leverage content category in the whole brainstorm.

- **Dice Thief.** A new verb that steals a die directly out of your queue before you can spend it — the first enemy action that attacks the dice economy itself rather than your HP/shields, which is exactly the resource the whole game revolves around.
- **Support/buffer enemy.** Heals or shields *other* enemies instead of itself (needs a `TARGET_RANDOM_OTHER_ENEMY` targeting option for enemy actions, which slots into the existing Targeting category). Turns multi-enemy fights into "kill the medic first" prioritization.
- **Charging bomber.** A 2-turn telegraphed action — a visually distinct "charging" intent state that detonates for big AOE if not interrupted. Introduces real "deal with this now or eat the consequences" pressure, using the existing intent-slot visuals plus a new charge-tracking flag.
- **Dice-duplicator enemy.** The enemy-side mirror of your own Holo-Duplicator tile — spawns extra holographic dice into its own queue so it gets more actions per turn. Nice thematic symmetry (an enemy that fights with your own tricks).
- **Parasite enemy.** Attaches to and disables a specific player *tile* (not the ship) until destroyed — pulls enemy aggression into the grid-puzzle layer instead of only ever being an HP/shield race.
- **Swarm type.** Many 1-HP enemies sharing a single intent list. Great contrast to tanky single bosses and finally gives your AOE tile (Chaos Explosion) a moment to shine outside pure single-target math.
- **The Reflector.** An intent that *returns the die to your next turn's pool* — with a nasty rider (it comes back corrupted, locked to its value, or trailing a debuff modifier). The only verb that sends dice *backward* through the economy, which reads as genuinely alien the first time a player sees it, and it sets up "wait, can I exploit this?" plays (feeding it a die you *want* back).
- **The Bounty Clock.** An enemy carrying visible loot that flees automatically after N turns (a countdown on its portrait). It barely attacks — the entire fight is "can I afford to spend enough dice to kill it before it leaves, given what those dice will feed the *other* enemies on screen." A timer, a treasure, and the core tension all in one cheap package (`flee` verb + a turn counter).
- **Engine Siphon.** An attack verb that drains player *engine charge* instead of HP — the first enemy that threatens your escape/jump resource. Terrifying in Fate zones specifically (where jumping away matters most), and it instantly makes the engine-economy tiles (§3) defensively relevant.
- **Grid Quaker.** A verb that *pushes* one of your tiles a cell in a random direction (reusing `TileGrid.push_tile()`, which already exists). Weaponizes your own spatial layer against you — formations (§3 set bonuses) and adjacency builds suddenly have a natural predator, and Anchor tiles get their reason to exist.
- **The Gambler.** Every slot in its intent bank is all-or-nothing: "6: attack for 10 *or* do nothing — coin flip, revealed on resolve." A deliberately rare exception to determinism (like Sensor-Dark zones) — but note the flip can be *pre-rolled and hidden* rather than random-at-resolve, so a future "scanner" upgrade could reveal it. Casino-ship flavor, memorable table moments.
- **The Mirror Hull.** A defensive verb: "this turn, reflect X% of damage back at the attacker." The player *sees* it telegraphed on specific values, so it becomes a routing puzzle — you must plan which dice to spend on damage *before* those values land in the reflect slots. Pure counterplay texture with one new verb.

## 5. Sector / Location Modifiers

`GameStateManager._randomize_sector_scenarios()` already procedurally shuffles combat/shop/event/boss/fate slots, and `BackgroundManager` already has themed presets (nebula, debris field, star field, fate infection). Neither currently carries *mechanical* weight — they're purely visual. Tying a mechanical modifier to the region you're in is a cheap, high-atmosphere addition:

- **Asteroid Field** — periodic "incoming asteroid" events lock a random grid tile for a turn unless dealt with (reuses the existing `LOCKOUT_TILE` mechanic, just aimed at the player for once).
- **Ion Storm** — dice have a chance to flip ±1 when rolled, rewarding tiles that thrive on unpredictable values or that manipulate dice post-roll.
- **Derelict/Salvage zone** — a non-combat puzzle node: spend dice to "hack" tiles for loot before a creeping corruption timer runs out, reusing Fate's existing encroachment visuals for tension.
- **Gravity Well** — push effects are doubled in strength/distance, making Anchor-style tiles (see §3) suddenly much more valuable.
- **Sensor-Dark zone** — some intent slots stay hidden until you spend a turn "scanning." This one directly touches the perfect-information pillar, so I'd treat it as a rare, clearly-telegraphed special encounter type rather than a common modifier — a deliberate exception to the rule, not a dilution of it.
- **Solar Flare zone** — a visible countdown ticks at the top of combat: every 3rd turn, a flare washes the board (small damage to *every* ship, player and enemy alike, and all shields wiped). Fights develop a rhythm — shield turn, burst turn, brace turn — and clever players time big plays to land right after the flare strips enemy shields. `BackgroundManager` sells it with a screen-wide white-out (see Juice).
- **Merchant Convoy lane** — a "safe" high-traffic zone: encounters skew civilian/trader, a traveling shop can appear mid-node, but pirate ambushes (for you *or* for the convoy, §2 ship-vs-ship) are more dramatic when they hit. Gives the map a "civilization vs. frontier" gradient rather than uniform danger.
- **Ship Graveyard** — combat nodes strewn with dead hulks that act as *neutral objects in the enemy lineup*: spend a die on a wreck to salvage (loot roll), or ignore them. Occasionally one is *not quite dead*. Atmosphere is nearly free (debris `BackgroundManager` preset already exists); the salvage verb reuses die-spending machinery.
- **Fate Rift epicenter** — the deepest corruption tier, where the modifier is: *your own tiles* have a small chance per turn of being temporarily fate-touched (glitch visual + effect twisted for one activation — damage becomes random target, shield becomes half). The corruption stops being scenery and starts reaching into your cockpit. Rare, endgame-adjacent, and the strongest possible motivation to care about the Fate storyline.

## 6. Meta-Progression & Replayability

There's currently no persistent progression between runs at all (confirmed — no unlock tree, no cross-run currency). That's a legitimate design choice for a roguelike, but if you ever want more replay hooks:

- **Ascension-style modifiers** unlocked after a first sector clear (Slay-the-Spire style): harder enemy tables, more aggressive Fate encroachment, alternate starting loadouts — all pure content/config, no new systems.
- **Signature-weapon tiles** (§3) double as a soft meta-progression hook even within a single run, if you want to hold off on true cross-run unlocks.
- **Starting captains / ship variants.** 3–4 named starts that change the *shape* of the run rather than its power: different dice counts (4 big-value dice vs. 7 small), a different starting tile kit, a faction reputation head-start (the Ex-Pirate starts hostile with soldiers but with black-market access). Since `num_of_dice` already drives max engine charge, dice-count variants automatically play differently at the map layer too — most of this is config, not code.
- **Ship's log / codex.** Every enemy type, tile, and faction gets a log entry that unlocks on first encounter, written in-universe (your ship's AI annotating the targeting computer). Cheap lore delivery that doubles as a bestiary — and a natural home for the Fate mystery to be drip-fed across runs instead of dumped in dialogue.
- **Daily seed.** The RNG is already seeded per scenario (`Events.load_scenario` → seed), so a date-derived seed with a fixed loadout is genuinely close to free — and it's the single best community/streamer feature per unit of effort: everyone fights the same run, compares outcomes.
- **Run epilogue cards.** On death or victory, a short generated "where they ended up" epilogue based on run facts — factions wronged, rivals spared, pacts taken ("The Krell syndicate renamed a cargo lane after the captain who let them live"). Reuses reputation data (§2) for an emotional button on every run, win or lose.
- **Graveyard echoes** *(wilder)* — your previous run's dead ship can appear as a derelict (§5 Ship Graveyard) in a later run, salvageable for one tile it was carrying when it died. Roguelike tradition (à la corpse runs), zero narrative cost since the sector canonically eats ships, and it makes losing sting a little sweeter.

## 7. Wild Card Ideas (Nothing Off-Limits)

These are genuine big swings — flagging them clearly as such, since they cut against the project's stated "minimize over-building" philosophy and would be real structural additions, not weekend content patches.

- **Dice-duel rival captain.** A boss who plays by *your* ruleset — trading dice back and forth with you turn over turn, using the same give-away mechanic against you. A mirror-match final boss archetype unique to this game's core loop; no other roguelike could really do this fight.
- **Subsystem hull model.** Replace single HP with 3 subsystems (Weapons/Shields/Engines) à la FTL — engine damage shrinks max engine charge, weapon damage disables tile categories. Would meaningfully deepen combat texture but touches the `Health` component and a lot of downstream logic — a "next chapter" idea, not a patch.
- **Wild die.** A rare die face (a symbol instead of a number) that satisfies any tile's activation condition — but when handed to an enemy, *they* choose which of their 6 intents fires instead of it being value-locked. Extremely spicy because it's the one idea that would knowingly break the perfect-information pillar for a single high-risk resource — flagging as optional/risky rather than a clear recommendation.
- **One-time turn rewind tile.** Stores the current turn's state and lets you undo it once per run at a steep cost. Powerful enough that it'd need very careful tuning to not undermine the game's core "commit to your choice" tension.
- **Custom die faces.** The Dicey Dungeons / Slice & Dice direction: rare upgrades that permanently modify *one face of one specific die* — a die whose 1 is now a 3, a die with a "shield pip" face that auto-shields when rolled, a heavier die whose 6 face appears twice. Dice stop being interchangeable and become *characters* ("old reliable," "the cursed one"). Big swing: dice are currently identical by design, so this touches rolling, UI, and the enemy-value handoff — but it's also the most natural place for this game to grow, because the dice are already the emotional center.
- **Physics dice rolling.** Turn-start rolls become real 2D physics tosses across the cockpit dashboard — dice tumble, collide, clatter, and settle (values still decided by the seeded RNG; the physics is theater, the die "lands" on the predetermined face). Pure juice at heavy cost, but it's the kind of thing that makes a trailer: this game is about *dice*, and right now they never actually roll.
- **The die IS the ship** *(deep-lore endgame)* — a final-act reveal/mechanic where your ship itself is revealed to be a die of Fate, and the last boss fight adds a 7th "ship die" that rolls each turn and modifies the whole board (its value sets a global modifier via the existing Modifier priority system). Mostly a narrative-mechanical flourish, but it would tie the Fate storyline directly into the core mechanic instead of beside it.
- **Boss rush & endless.** Post-victory modes assembled from existing parts: boss rush (the scenario randomizer pinned to boss slots), endless (sector loops with escalating enemy stat multipliers + deeper Fate corruption). Cheap to build once ascensions exist; gives the wiki/leaderboard crowd something to chew.

---

## 8. JUICE — Making Every Moment Feel Incredible

You already have real bones here, more than most projects at this stage: a reusable `Shakeable` component (small/large shake, editor test buttons), camera shake wired to damage signals, a **glitch shader that triggers on large shakes**, a `Vignette` flash layer, `WorldEnvironment` glow enabled, a pulsing shader on the dice area, particle events (`SPAWN_HIT_PARTICLES` / `SPAWN_EXPLOSION_PARTICLES`) in the effect system, money particles, a `JumpTransition`, and — quietly the best juice asset in the codebase — **`SFXPlayer` already supports pitch escalation and pitch randomness per sound resource**. The opportunity isn't "add juice"; it's *aim* the juice at the moments that define the game, and make it authorable.

### 8.0 The one structural idea that multiplies everything else

**Make juice data-driven, like everything else in your engine.** The `AUDIO_VISUAL` category already has 7 subtypes (`SPAWN_HIT_PARTICLES`, `ATTACK_TWEEN`, `SHAKE_DICE`, `PLAY_SOUND`, `WAIT`…). Add a small set of new subtypes and *every tile and enemy action can be individually choreographed in the inspector, no code*:

| New AudioVisualSubtype | What it does |
|---|---|
| `HITSTOP` | Freeze `Engine.time_scale` for 40–80ms on impact |
| `ZOOM_PUNCH` | Camera zoom kick (+2–3%) with fast ease-out return |
| `FLASH_TARGET` | Target sprite flashes white for 1–2 frames (shader `flash_amount` uniform) |
| `SLOW_MO` | `time_scale` 0.3 for N ms (killing blows, ultimates) |
| `SPAWN_DAMAGE_NUMBER` | Floating number popup, size/color scaled to amount |
| `SCREEN_SHAKE` | Trigger the existing camera `Shakeable` (small/large/custom) from a chain |
| `VIGNETTE_PULSE` | Fire the existing `Vignette` flash with a color |
| `GLITCH_BURST` | Fire the existing glitch shader for N ms (reserve for Fate content) |
| `BACKGROUND_FLASH` | One-frame lighting change in `BackgroundManager` (muzzle-flash on the nebula) |

This is the same insight as EffectChainV2 itself: one week of handler-writing buys you *permanently free* per-content choreography. A big cannon tile can be authored as `WAIT(100) → SLOW_MO → SPAWN_EXPLOSION → HITSTOP → SCREEN_SHAKE(large) → damage`, all in a `.tres`.

### 8.1 The Roll (turn start — the "shuffle and draw" moment)

- The current `reroll_with_tween` (flip + hop, 0.2s) is a good skeleton. Add **staggered starts** (each die begins 40–60ms after the previous, left to right) so the reroll reads as a *cascade* instead of a simultaneous blink — this is the single cheapest perceived-quality upgrade in the game.
- **Clatter audio**: one randomized dice-click per die as it lands, using the pitch-randomness support `SFXPlayer` already has. Six slightly-different clicks in a rippling row is deeply satisfying and costs one sound resource.
- **Land with squash**: on the settle, overshoot scale to (1.1, 0.9) then spring back (`TRANS_BACK`/`TRANS_ELASTIC` ease-out). Dice should feel like they have *weight*.
- **High-roll celebration**: when the roll totals unusually high (or a die lands a 6), a brief glint/sparkle on that die. Players will start feeling lucky *before* they've analyzed anything — that's the tabletop feeling you're chasing.
- **Anticipation beat**: 100–150ms of all dice quivering *before* the reroll starts. Anticipation → action → settle is the animation-principles triad that makes the same tween read as twice as expensive.

### 8.2 Placement & Activation (the drag-drop verb)

- **Magnetic snap with confidence**: when a dragged die crosses a valid tile's snap radius, the die scales up ~5% and the tile lifts/brightens — a physical "click into place" with a soft thunk SFX on drop. The `Draggable` component already has the hooks (`drag_ended`, `reached_new_home`).
- **Live validity language**: valid tiles get a subtle breathing glow while a die is airborne (the dice-area pulse shader already proves the pattern); invalid tiles stay dark. On an invalid drop, the die does a quick head-shake wobble (±6°, 3 oscillations, 150ms) as it returns — a "no" the player *feels* without reading anything.
- **Charged placement for big plays**: when a die activates a tile at its maximum (a 6 on a scales-with-value tile), insert one extra beat — die glows, tile inhales (scale down 3%), *then* fires. Big inputs deserve bigger wind-ups.
- **Chain choreography**: when tiles trigger other tiles (Amplifier, relays §3, `ACTIVATE_TARGETED_TILES`), draw a fast energy arc from source tile to triggered tile and add a per-hop `WAIT(80)`. The cascade is your depth on display — *make the player watch the dominoes fall*, don't resolve it invisibly. This is also your best trailer material (see §9).
- **Combo pitch ladder**: `SFXPlayer.get_pitch_escalation()` exists — use it so each tile activation in a single turn plays its sound a semitone higher than the last, resetting each turn. Ten activations in one turn should *sound* like a slot machine paying out. This is nearly free and it's the most addictive trick in the genre (Balatro runs its whole feel on it).

### 8.3 The Payoff (damage lands)

- **The impact trio** on every hit, scaled by damage: 1–2 frame white flash on the target sprite + hitstop (40ms small, 80–100ms big) + shake (`Shakeable` small/large — already per-enemy capable). Right now hits spawn particles; flash + stop are the two missing thirds of "crunch."
- **Damage numbers**: floating popups, size/color scaled to amount, with slight random angular scatter so repeated hits pile up like debris. For your 480x270 pixel-art scale, chunky 5–7px digits in the existing palette. (Worth making a toggle — some devs hate them — but they're the clearest "number go up" dopamine channel and they make tile-synergy math *visible*.)
- **Overkill deserves spectacle**: when a hit exceeds the target's remaining HP by 2x+, escalate automatically — bigger explosion, longer slow-mo, screen-edge vignette flash, deeper boom. Players will start *chasing* overkills purely for the feedback, which quietly teaches optimal play.
- **Shield vs. hull vocabulary**: shield hits should read completely differently from hull hits — shields: hexagonal ripple shimmer + electric *tsss* + blue flash; hull: debris chunks + fire particles + brown/orange flash + heavier shake. The player should know which resource got hit with their eyes closed.
- **Enemy "pain" poses**: enemies currently bob idly; a hit should interrupt the bob with a knockback lurch (5–10px away from the impact, spring back) and, below 33% HP, a permanent listing tilt + smoke trail particles. HP bars lie about drama; a smoking, tilting ship doesn't.

### 8.4 The Handover (your signature moment — currently underplayed)

The die tweening to the enemy over 0.75s is the *most important repeated moment in the game* — it's the whole thesis: you're arming your enemy. Right now it's a polite float. Ideas, escalating:

- **Tractor beam treatment**: the enemy visibly *pulls* the die — a thin beam locks on, the die resists for a beat, then accelerates away with a trail. The player should feel the die being *taken*, not delivered.
- **The enemy reacts to what it gets**: on arrival, the receiving intent slot slams/flashes and the enemy does a micro-animation keyed to the action that value bought — gun barrels glow for an attack slot, shields shimmer for a shield slot, *nothing* (a dismissive blink) for a dead slot. Feeding an enemy a 6 that lands on their big-attack slot should feel like watching someone load a shell into a cannon *while looking at you*.
- **Dread audio**: a low, quiet "thunk-hum" when a die lands on a dangerous slot; a flat click when it lands on a harmless one. Train the player's ear so a turn's worth of handovers has a felt threat-texture before they re-read any intents.
- **Value-scaled gravity**: a 1 floats over weightlessly in 0.4s; a 6 travels slow and heavy (0.9s) with a deeper trail and a screen-corner rumble. The *value* of what you gave away should be legible in pure body language.

### 8.5 Getting Hit (enemy turn tension)

- **Incoming-fire anticipation**: before an enemy attack resolves, a 300ms wind-up — enemy lunges (the `ATTACK_TWEEN` subtype exists), a targeting bracket flashes on *your* cockpit edge, THEN impact with the existing shake/glitch stack. Anticipation makes the same damage feel fair *and* scarier.
- **Cockpit as body**: you have cockpit walls framing the screen — make them the player's pain skin. Hull hits: sparks fall from the cockpit frame, a brief interior light flicker. Low HP (<30%): persistent red emergency-light tint at the screen edges + slow alarm pulse + occasional spark drips until healed. FTL proved the ship-as-body feeling is what makes players *care*; you have the frame literally on screen already.
- **Near-death heartbeat**: below ~20% HP, add a low-pass filter dip on the music (one `AudioEffectLowPassFilter` on the music bus, tweened) plus a soft heartbeat layer. Cheap, and it transforms endgame turns into held-breath moments.
- **Shield break is a moment**: the last point of shield breaking should have its own event — glass-shatter ripple across the screen edge, distinct SFX, half-second of exposed-hull vulnerability vignette. Currently shields and hull damage share a "hit" vocabulary; the *transition* between them is the dramatic beat.

### 8.6 Kills, Combat End & Loot

- **Death sequences with stages**: small internal explosions popping across the enemy sprite (3–5 randomized micro-bursts over 0.5s) → hull flash → main explosion + shake + slow-mo (0.3 time_scale, 250ms) → debris and money particles fountain out (money particle scene already exists). The current death should never just be "sprite disappears + one explosion."
- **Last-kill camera**: the kill that *ends combat* gets the full treatment automatically — longer slow-mo, zoom punch toward the dying ship, glitch-free clean frame, then the combat-finished UI eases in a beat later. End every fight on a high note; the player's memory of the whole battle is disproportionately this frame (peak-end rule).
- **Loot fountains**: rewards should physically erupt from the wreck and arc toward the money indicator with trails, landing as individually-ticking counter increments (the escalating-pitch trick again — each coin tick a hair higher). Never `money += 30` in silence.
- **Victory breath**: after combat, one quiet beat — engine hum swells back up, dice-area glow warms, maybe your ship's frame subtly un-tenses (1px settle). A game about tension needs authored *release*.

### 8.7 Ambient Life (the game at rest)

- **Everything breathes**: enemies bob (already done ✔). Extend the same treatment: dice micro-settle when idle, tiles have a 1–2px idle hover with per-tile phase offset, background nebulae drift (parallax exists ✔). A screenshot should look *paused*, never *static*.
- **Idle dice fidgets**: after ~10s of no input, one random die does a tiny hop or spin-settle. Pure charm; also quietly signals "it's your turn" to a distracted player.
- **The cockpit hums**: a barely-audible engine-room loop that dips during enemy turns and swells on your turn — subliminal turn-state communication through sound alone.
- **Hyperspace jumps** (`JumpTransition` exists): worth a full set piece — dice rattle in place during the wind-up, stars streak (background preset swap), one hard white frame, arrival with the new node's palette blooming in. It's your scene transition *and* your "the galaxy is big" moment, dozens of times per run.

### 8.8 A Fate/glitch visual language (juice as storytelling)

You have a glitch shader, fate particles, and a fate background — currently used as alarm/damage feedback. Consider *reserving* glitch strictly for Fate content so it becomes a legible language: fate-touched enemies shimmer with chromatic aberration, corrupted tiles (§3) glitch-jitter their sprite a frame at a time, Fate map nodes bleed static into the UI itself (the map's edges corrupting is scarier than any dialogue), and the flickering-intent enemies (§1) use it on their slots. When the *interface itself* seems infected, the corruption stops being a mechanic and becomes horror. (Damage feedback can keep shake + vignette and drop the glitch, sharpening both languages.)

### 8.9 Sound & music direction (the missing half of juice)

- **Vertical music layering**: split combat tracks into stems (drums / bass / lead) and fade layers in by threat state — out-of-combat: pad only; combat: +drums; boss or <30% HP: everything. `MusicPlayer` is a single stream today; two more synced `AudioStreamPlayer`s with volume tweens is the whole implementation.
- **Stingers**: 1–2s musical hits on kill, on shield break, on combat victory, on Fate corruption spreading. Stingers are what make moments *quotable*.
- **A "turn passing" sound identity**: give player-turn-start and enemy-turn-start each a signature two-note motif. Turn rhythm is the game's heartbeat; let the player hear it.
- **Bus polish pass**: reverb-lite on explosions, the low-pass-at-low-HP trick (§8.5), and pitch families for dice sounds so all dice SFX feel like the same "material." The `SoundEffectResource` abstraction means most of this is data, not code.

### 8.10 Priority & sanity notes

- **Highest impact per hour**, in order: (1) impact trio (flash/hitstop/shake) on hits, (2) combo pitch ladder on activations, (3) staggered roll cascade + clatter, (4) the handover tractor-beam + slot-slam, (5) death sequences. Those five touch every single turn of every run.
- **The `AUDIO_VISUAL` subtype expansion (§8.0) should probably come first anyway**, since it makes the other nine sections authorable content instead of scattered code.
- **Accessibility from day one**: sliders/toggles for screen shake, flashes, hitstop, and damage numbers. Cheap now, painful later, and it lets you push the defaults *harder* knowing sensitive players can dial down.
- **Restraint is part of juice**: scale feedback to significance. If a 1-damage plink gets hitstop, a 20-damage overkill has nowhere to go. Reserve the top of the curve.

---

## 9. Trailer Moments & Audience "Wow" (what sells the game in 15 seconds)

Thinking explicitly about what a stranger sees in a gif/trailer, because it should influence which ideas above get priority:

- **The one-gif pitch is the handover.** A die glowing 6, dragged onto a cannon, huge hit — then the *same die* tractor-beamed to the enemy, landing on their big-attack slot as their guns light up. That 6-second loop explains the entire game wordlessly. Everything in §8.4 serves this gif.
- **The Rube Goldberg turn.** One die triggering a relay chain across the grid — arcs jumping tile to tile, pitch ladder climbing, five effects cascading from one placement (§3 relays + §8.2 chain choreography). This is your "look how deep it goes" shot.
- **The Fate glitch aesthetic.** UI-corrupting cosmic horror in a pixel-art dice game is a *strong* thumbnail identity (§8.8). Lean into it in key art — the die with a glitching face is a better logo than a spaceship.
- **The mirror-match boss** (§7) is the "wait, WHAT" beat for the back half of a trailer.
- **Streamer bait is decision-talk**: the Auctioneer (§1), the pacifist tribute channel (§2), and overload thresholds (§1) all generate out-loud agonizing — "do I give them the 4?!" — which is exactly what makes deckbuilder VODs watchable. Design for the narrated turn.

---

## 10. Onboarding — Shrinking Play-to-First-Choice

What the player actually experiences today

From "Play," the sequence is: opening cutscene → entering-cockpit cutscene (both skippable by click, but nothing tells the player that) → main game loads → intro_1 (2s forced delay + typewriter + manual close) → intro_2 (typewriter + manual close) → health bar reveal (3s auto) → health bar explanation (manual close) → systems reveal (3s auto) → systems explanation (waits for you to click a tile) → dice spawn (2s auto) → finally the first drag. That's two cutscenes and six popups before the first real decision, with the typewriter effect gating progress (all_text_displayed fires the step's function, so text speed literally delays the game). Realistically 60–90 seconds of watching before doing.

Ideas, bucketed by how much you're willing to restructure

Tier 1 — Tighten what exists (pure .tres re-authoring + tiny code, keeps your structure intact):
- Merge intro_1 + intro_2 into one line. "Reboot complete. Anomaly still in pursuit — threat critical." One popup, same information, same dread.
- Click-to-complete typewriter, click-anywhere-to-advance. Any click during typing instantly finishes the text; any click after closes manual popups. This is the single biggest win because it converts every popup from "wait, find button" into "click-click-click" for fast readers while changing nothing for slow ones.
- Run the reveals in parallel, not serial. health_bar_reveal and systems_reveal are 3-second blocking popups whose only job is to accompany an animation — but the animation is the communication. Fire both reveal animations together (or overlapping) with one line of text, and cut 6+ seconds.
- Kill the 2s time_delay on intro_1, or cut it to 0.5s. Dead air right after a scene load reads as "did it freeze?"
- Make cutscene skipping discoverable: a "click to skip ▸" hint fading in after ~2 seconds, or hold-to-skip with a progress ring (also prevents accidental skips from a stray double-click on Play).

Tier 2 — Reorder: act first, explain after (same TutorialStep system, new step order):
- Move the health bar lesson to when it matters. Nobody needs "hull damage = mission failure" before anything has shot at them. Reveal the health bar the first time the enemy hits you (add an ON_PLAYER_DAMAGED value to your open_on_signal enum — the signal already exists on the bus). Just-in-time teaching also makes the lesson land harder.
- Dice in hand within ~10 seconds. Open the cockpit with dice already spawning and one tile lit. First popup: one line — "Drag a die onto the cannon." Everything currently before that moment (vitals, anomaly, subsystem names) becomes reactions after their first actions, when the player has context to care.
- Turn the intro lore into a non-blocking ticker. Your typewriter system already exists — render the ship-AI status lines ("Reboot complete… anomaly in pursuit…") in a corner console that types away while the player can already touch dice. Story and play run concurrently instead of taking turns.
- Make the first action a choice, not an instruction. Spawn two dice with two tiles lit — Dice Cannon and Shield Burst — and say "Power a subsystem." Either drag is correct; the tutorial reacts to which they picked ("Aggressive. Noted."). The player's first input is now expressive, which is a pacing upgrade, not a cut.

Tier 3 — Structural: the cutscene becomes the first turn (bigger swing, biggest wow):                                

- Playable cold open. The opening cutscene's anomaly, your ship taking a hit — happens through the cockpit window after a hard cut into the cockpit. You get hit (that's your existing shake + glitch + red flash doing the storytelling), the hull bar just took damage, dice scatter across the dash, and the AI says one line: "Power something. Now." Every popup you currently have becomes an in-fiction event. This reuses the cutscene's assets and SFX

- In medias res escape. Variant of the above: the tutorial fight is framed as "survive one exchange, then jump" — which teaches dice → tiles → handover → enemy in one motivated sequence instead of six disclosures.                                                                                                        
Two supporting fixes regardless of tier:                                                                            
- Retry must not repeat the intro. — if a player dies or quitsmid-tutorial, restart them at the first drag, not at the cutscenes. Repeated forced intros are where new players quit for good.
- Set a budget and measure it. Pick targets — first input < 15s, first real decision < 30s — and stopwatch a build. Tier 1 alone probably gets you from ~75s to ~35s; Tier 2 gets under 20.

One thing I'd not do: cut the atmospheric beats -- writer-in-the-dark opening is good tone. The fix is concurrency (atmosphere plays while hands are free), not deletion.  

---

## How I'd bucket these if you want a starting point

- **Cheapest, highest payoff:** HP-threshold boss phases, grudge memory, new enemy verbs (esp. Dice Thief, Engine Siphon, Grid Quaker), porting the 4 broken legacy tiles, sector mechanical modifiers, and the top-five juice list in §8.10.
- **One structural key that unlocks a category:** the `AUDIO_VISUAL` subtype expansion (§8.0) — a week of plumbing that converts all future juice into inspector-authorable content.
- **Medium lift, big narrative payoff:** persistent reputation + gossip network, recurring rival captain, Fate Cult faction with cursed tiles, faction shops, coward/flee-and-remember AI.
- **Medium lift, big replay payoff:** starting captains, daily seed, tile fusion, run epilogue cards.
- **Bigger structural swings, worth a dedicated design pass before touching code:** split-component bosses, subsystem hull model, dice-duel rival boss, custom die faces, physics dice rolling.

---

## 11. Tile Machines — Building Contraptions Out of Grid Geometry

The seed for this is already in §3 (Conveyor/relay tiles, Row/column set bonuses, Anchor tiles, Adjacency-adaptive, Empty-space tiles) and the engine backs it well: `tile_locations: Dictionary[Vector2i, Tile]` gives you real coordinates, `ACTIVATE_TARGETED_TILES` already lets one activation trigger another, `push_tile()`/pull already move tiles around, and `TileEvent` gives hook points (`ON_TILE_PUSHED`, `ON_TILE_MANUALLY_MOVED`) that fire *because of* geometry changes. Nothing below needs a new core system — it's about treating the 3x5 grid less like a hand of independent cards and more like a breadboard: signal in, signal routed, signal out, with the *player's layout choice* as the circuit diagram. A few organizing principles first, then concrete machines.

**Why this direction is strong for this game specifically:** the core tension is "use dice now vs. deny dice to enemies," and machines add a third axis — *where* you commit a die matters as much as *which* tile gets it, because the die's energy propagates through your layout. It also solves a real problem good deckbuilders eventually hit: once you have ~15 tiles, most builds become "pick the five best standalone tiles." Machines make weaker individual tiles *worth including* because of what they're wired next to — pushing the metagame from "best tiles" toward "best floorplan."

### 11.1 Core machine primitives (the "parts bin")

These are small, reusable concepts a lot of the specific machines below combine. Worth building 2-3 of these as actual new subtypes before designing individual "named" machines, since they compose.

- **Signal tiles vs. payload tiles.** A signal only carries direction/trigger (no die value needed) vs. a payload that carries a die's actual value forward. Most existing relay ideas conflate these; splitting them lets you build machines where a cheap 1 "pulls the lever" on a chain that a big 6 elsewhere pays into.
- **Directional routing.** A tile has an explicit output direction (N/S/E/W, or "next in row/column") baked into its data, not just "adjacent tiles" — this is what turns a pile of relays into an actual *circuit* the player draws with placement, rather than a blast radius.
- **Capacity/overflow.** A machine part that only fires once it's received N total value (a capacitor) — banking multiple small activations into one large payoff. Distinct from "amount modifiers" because the *state* persists tile-to-tile across turns, not just within one chain resolution.
- **Geometry-conditional criteria.** Activation criteria that check board shape, not just "a die landed here" — "fires only if this tile has an empty cell on both sides," "fires only if it's the corner of an L," "fires only if 3+ same-family tiles form a line." This is the piece that makes layout itself a puzzle rather than a flavor detail.

### 11.2 Named machine concepts

- **The Assembly Line.** A straight row of 3-5 tiles, each doing a *small* effect and passing the die one cell over (direction baked in, per 11.1). Individually each tile is weak — deliberately so — but the full line resolves as one cascading combo: shield, then a small heal, then a small damage tick, then a burn stacker at the end. The player's "build" *is* the row they assemble in the shop. Visually this is your best Rube-Goldberg trailer material (§8.2/§9) — a die literally rolling down a conveyor of tiles, lighting each one in sequence.
- **The Distributor / Manifold.** One intake tile in the center of a cluster that, on activation, fans a *reduced-value* copy of the die out to every orthogonally adjacent tile simultaneously (instead of one linear relay). Turns a single die into a burst across a whole neighborhood — the counterpoint to the Assembly Line's serial chain, this one's parallel. Rewards clustering cheap utility tiles (small heals, small shields) around it so one die "waters the garden."
- **The Capacitor Bank.** A tile that does nothing on its own — it just banks a fraction of the value of any die spent on an *adjacent* tile (via the capacity primitive above). Once full, it auto-discharges next turn for one big burst (damage, shield, whatever its type is). This gives "spend dice everywhere around one anchor tile" a payoff distinct from spending them directly, and it's a natural home for the Fate-corrupted variant (§3 Cursed Fate tiles): a corrupted capacitor that also *leaks* a little damage to you each turn it's charging.
- **The Gear Train.** A line of tiles where activating one *physically rotates/shifts* its neighbors by one cell (reusing `push_tile()`), and each tile's effect depends on what's now sitting where in the train — e.g. "whatever tile is currently in the 3rd gear position deals double." The player is deliberately re-sequencing their own machine mid-combat, which is a different kind of puzzle than static layout: timing *when* to fire the gear vs. when to cash in the current arrangement.
- **The Junction Box.** A tile with two or more incoming relay directions (from 11.1) that only fires when it's received signal from *both* this turn — an AND-gate. Forces the player to plan two separate dice into two separate feeder tiles in the same turn to unlock one payoff tile, which is a genuinely new kind of commitment (spending two dice on setup for one big hit, in one turn, no banking across turns).
- **The Overflow Valve / Safety Release.** Paired with capacity tiles: if a capacitor would overfill, instead of wasting the excess it vents into a *different*, cheaper effect on an adjacent "relief" tile — e.g. excess damage-bank charge bleeds off as a small shield elsewhere. Rewards deliberately overfeeding your machine and gives overflow (currently a pure downside concept in §1's Overload thresholds, mirrored here for the player) a constructive use.
- **The Formation Turret.** Combines Row/column set bonuses (§3) with directional routing: a turret tile at the end of a row that gets +N per same-family tile "feeding" it from behind in that row, but *only* counts tiles that haven't been pushed/locked out of formation. Makes enemy Grid Quaker / lockout verbs (§1, §4) into genuine machine sabotage rather than just "one tile is briefly useless" — they're breaking your production line, which reads very differently.
- **The Loop.** A closed rectangle of 4 relay tiles (2x2 or larger) that, once formed, lets a die circle the loop multiple times before resolving, gaining a small compounding bonus per lap (capped). This is the purest "layout as combo" idea in the set — it only exists if the player deliberately builds a closed shape, which the 3x5 grid is just barely roomy enough to make an interesting spatial-packing problem (a loop eats real estate other machines want).
- **The Empty-Socket Amplifier.** Pairs Empty-space tiles (§3) with routing: a relay tile's payload gains value for every empty cell *along its direct path* to the next tile, so spacing your machine out (not just clustering it) is sometimes correct — directly working against the instinct to always pack tiles tight, which keeps the grid-real-estate tension (already present via Empty-space tiles) alive inside machines specifically, not just standalone tiles.
- **Machine kits as a shop category.** Rather than always improvising machines from a general tile pool, sell explicit 2-3-tile "kit" bundles in the shop (a matched relay pair, a capacitor + its designated feeder) so new players discover the pattern language fast, while advanced players can still hand-wire novel combinations from loose parts. Mirrors how Tile fusion (§3) already treats the shop as a construction-kit vendor, and gives machines an on-ramp instead of requiring the player to reverse-engineer the system from tooltips alone.

### 11.3 What this changes about the grid's role

Right now the 3x5 grid is mostly a container — tiles are largely independent, and adjacency/position matters to a handful of tiles (Flak Cannon, Amplifier). Machines flip that: position becomes a *first-class resource* competing directly with tile power level. That has one real cost worth flagging honestly — it raises the skill floor (a new player who just drops good tiles wherever will underperform a player who wires them deliberately), so if you pursue this, the shop/tooltip UI needs to *show* the wiring (arrows between tiles, a highlighted "this direction feeds that tile" overlay) rather than expect the player to infer it from text, or the depth will read as confusion instead of mastery.

### 11.4 Soup-to-Nuts Examples — Every 11.2 Machine, Worked

Grid coordinates below use `(col, row)` on the 3x5 board (3 wide, 5 tall), matching `tile_locations: Dictionary[Vector2i, Tile]`. Each example names concrete tiles, states their exact criteria/effect numbers, and walks one real turn.

**The Assembly Line — "Coolant Row"**
Layout: three tiles in row 2, left to right — `Coolant Vent (1,2)` → `Pressure Relief (2,2)` → `Ignition Chamber (3,2)`. Each has activation criteria "die value 2-6" and, on top of its own small effect, a `PASS_DIE_EAST` payload step that hands the *same die* to the next tile in the row if one exists.
- `Coolant Vent`: on activation, Shield +1. Passes die east.
- `Pressure Relief`: on activation, Heal 1. Passes die east.
- `Ignition Chamber`: on activation, Damage = die value × 2 (no further pass — end of line).
*Turn example:* you roll a 5. Drop it on `Coolant Vent`. It fires (Shield +1), forwards the 5 east; `Pressure Relief` fires (Heal 1), forwards it again; `Ignition Chamber` fires last, dealing 10 damage. One die, one placement click, three effects — and the combo pitch ladder (§8.2) makes it *sound* like a three-note run as it cascades left to right, which is exactly the trailer beat from §9's "Rube Goldberg turn."
*Why it's a build:* none of the three tiles is worth taking alone (a Shield+1 tile and a Heal+1 tile are shop chaff on their own) — the line is the payoff, so it rewards buying the *set*, not the strongest individual piece.

**The Distributor — "Repair Manifold"**
Layout: `Manifold Core (2,3)` in the middle of row 3, with `Patch Coil (1,3)`, `Patch Coil (3,3)`, and `Patch Coil (2,4)` on three of its four orthogonal sides (the fourth, north, is left empty — see the Empty-Socket Amplifier below for why that matters).
- `Manifold Core`: criteria "die value ≥ 4." On activation, sends a reduced-value copy (die value ÷ 2, rounded down) to *every* adjacent tile that shares its `AUDIO_VISUAL`-tagged "manifold-compatible" flag, simultaneously.
- Each `Patch Coil`: receives a value, no direct player-drop needed this turn, converts received value into Shield equal to that value.
*Turn example:* you drop a 6 on `Manifold Core`. It fans out value-3 pulses to the two side coils and the south coil simultaneously — three visible energy arcs firing at once (§8.2 chain choreography), for +3/+3/+3 shield total from one die, versus the 6 shield you'd get dropping it on one shield tile directly. You're trading raw efficiency for board-wide coverage — useful when three separate enemies are about to hit three separate resource pools, bad when you just need one big block.

**The Capacitor Bank — "Overcharge Coil"**
Layout: `Overcharge Coil (2,1)` sits with `Laser Bank (1,1)` and `Laser Bank (3,1)` adjacent on either side.
- `Overcharge Coil` itself has no direct activation criteria — it can't be targeted by a die directly. Instead it has a passive rule: whenever an *adjacent* tile is activated, it banks 25% of that die's value (rounded down) into an internal `effect_data["charge"]` counter (reusing the existing per-tile persistent-counter pattern from §3's signature-weapon idea).
- At 6+ banked charge, it auto-discharges at the *start* of your next turn for Damage = banked charge × 3, then resets to 0.
*Turn example, spread across two turns:* Turn 1 you feed both Laser Banks a 4 and a 5 (9 total spent on them directly, each dealing their normal damage) — the Coil quietly banks 1 + 1 = 2 charge. Turn 2 you feed them a 6 and a 4 again — Coil banks another 1 + 1 = 2, now at 4. Turn 3 you feed a 5 — banks another 1, hits 5, still short. Turn 4 any activation nudges it past 6 and it discharges *before* your turn's dice even land, for 18 free damage, no die spent. The Coil rewards a laser-heavy build you were already running anyway — it's found damage, not a new decision each turn, which makes it a good "set and forget" machine for a row you're already committed to.

**The Gear Train — "Rotary Battery"**
Layout: a horizontal 3-tile train at `(1,0)-(2,0)-(3,0)`, each socket holding a *swappable* small module: currently `Attack Cell` (west), `Shield Cell` (center), `Heal Cell` (east).
- Activating whichever tile currently sits in the **center gear position** fires that module's effect at 2x strength, but also triggers `push_tile()` on the whole train one step east (wrapping the east tile back to west) — the train literally rotates.
*Turn example:* Center currently holds `Shield Cell`. You drop a 3 on it — Shield +6 (doubled), and the train rotates: `Heal Cell` is now center, `Attack Cell` is now east, `Shield Cell` cycles to west. Next turn, if you want doubled healing you drop on the *new* center — but the enemy telegraph (fully visible, per the core tension) might tell you you'd rather have doubled attack in center for the next hit, so you might instead spend a die on the west or east socket at normal strength just to *rotate without maximizing this turn*, deliberately setting up next turn's center. That's a genuinely new tempo decision: overclock now, or spend a "wasted" cheap die purely to reposition for later.

**The Junction Box — "Twin-Key Vault"**
Layout: `Feeder Coil A (1,4)` and `Feeder Coil B (3,4)` flank `Vault Door (2,4)`.
- `Feeder Coil A` / `B`: normal small tiles (Shield +1 each) that, on activation, additionally flag "signal sent" to the Vault for this turn only.
- `Vault Door`: criteria is *not* a die value at all — it activates automatically at end-of-turn *only if* both Feeder signals were sent this turn, and its effect is a flat Damage 15, no die spent on it directly.
*Turn example:* you have three dice left: a 2, a 3, and a 6. You spend the 2 on Feeder A and the 3 on Feeder B (2 small shields, easy to afford), and the Vault silently unlocks and fires for 15 at turn's end — leaving your 6 completely free to spend elsewhere (or hand away). Miss either feeder in a turn and the Vault does nothing that turn, banking no partial credit — it's a hard AND-gate, which makes it a "did you set up your economy tiles before your turn ends" check rather than a damage tile you interact with directly.

**The Overflow Valve — "Bleed Relief"**
Layout: pairs with any capacitor-style tile — reusing the Overcharge Coil above, add `Bleed Relief (2,2)` adjacent to it.
- `Overcharge Coil` cap is 6 charge (as above); any charge that *would* push it past 6 in a single banking event instead diverts straight to `Bleed Relief`.
- `Bleed Relief`: converts diverted overflow 1:1 into Shield instead of letting it evaporate.
*Turn example:* Coil sits at 5 charge. You activate a Laser Bank with a 6 — normally banks 1 more charge (→6, primed to discharge next turn start), but this activation's banking math actually generates 2 raw charge-points from that big a die, so 1 goes into the Coil (hitting cap) and the other 1 overflows into `Bleed Relief` as +1 Shield, same trigger, same click. Nothing is wasted — it just reframes "I overfed my machine" from a shrug into a small bonus, which makes bigger dice always feel *safe* to dump into a capacitor build instead of making the player do mental math about whether they're about to "waste" the die.

**The Formation Turret — "Gun Deck"**
Layout: top row entirely `Gun Deck` tiles at `(1,0)`, `(2,0)`, `(3,0)`, all same family ("Gun Deck").
- Each Gun Deck: base Damage 3, +2 damage for every *other* Gun Deck tile currently in the same row that hasn't been pushed out of row 0 or locked this turn.
*Turn example (healthy formation):* all three still in row 0. Drop a 4 on the leftmost — base 3, +2 +2 for the other two present = 7 damage from a 4. *Turn example (sabotaged formation):* an enemy's Grid Quaker action (§4) pushed the center Gun Deck down into row 1 last enemy turn. Now the leftmost only sees one formation-mate left in row 0 — same die, same tile, only 5 damage. The tile itself didn't change; the enemy broke your gun line, and you *felt* it as a smaller number without reading a debuff icon, which is exactly the "sabotage a production line, not a stat" flavor this archetype is for. It also creates a real repair decision: spend a die *manually moving* the displaced tile back into row 0 (costing you tempo) versus accepting reduced formation damage this turn.

**The Loop — "Feedback Ring"**
Layout: a closed 2x2 ring at `(1,3)-(2,3)-(2,4)-(1,4)`, four `Ring Conduit` tiles wired clockwise (each passes its die to the next conduit in the loop instead of resolving immediately).
- Each lap around the loop adds +1 to the die's effective value (capped at +4, i.e. 4 laps max) before it finally resolves against the *last* conduit's effect (Damage = final boosted value × 3).
*Turn example:* you drop a 2 into the entry conduit. It's tagged to loop twice before resolving (a per-tile "laps" setting you configure implicitly by which conduit you drop on — dropping on the conduit two steps ahead of the "exit" means fewer laps). Two full laps later it resolves at value 4 (2 + 2 laps), for 12 damage. This is the slowest machine in the set to pay off (you watch four separate arc-and-wait beats per lap, deliberately drawn out per §8.2's chain choreography) and it eats a full 2x2 block of your 3x5 board doing it — real estate other machines desperately want — so it's the highest-commitment, highest-spectacle build in the family, not a tile you casually splash.

**The Empty-Socket Amplifier — "Open Bay Emitter"**
Layout: `Open Bay Emitter (2,2)` in dead center of the grid, deliberately kept clear on its north side (nothing placed at `(2,1)`), with `Collector (2,3)` two cells south connected by a routing path through the empty cell.
- `Open Bay Emitter`'s relay to `Collector` gains +1 value per empty cell strictly between them along the path (here, one empty cell if you'd filled `(2,1)` and routed differently — but routing *through* the deliberately-empty north side of the Emitter itself grants the bonus at the source instead).
- Concretely: Emitter base pass-through is die value unchanged; with the adjacent north cell empty, it passes die value +2 instead.
*Turn example:* you drop a 3 on the Emitter. With the north socket kept empty, `Collector` receives a 5 (3 + 2) and converts it straight to Shield 5. If you'd been tempted to cram a cheap utility tile into that empty north cell for "efficiency," you'd have knocked the Emitter's bonus down to +0 — so the machine actively punishes the instinct to fill every socket, which is the direct counter-pressure to every other machine in this list (all of which want you to pack tiles close together).

---
