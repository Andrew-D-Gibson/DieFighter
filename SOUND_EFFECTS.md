# Sound Effects — Where They Go

Every place in the game that wants a sound and doesn't have a fitting one yet,
plus what the game already has, so sounds can be found or made in one pass and
wired in afterwards.

## How to hook a sound up

A sound is a `SoundEffectResource` (`Source/Resources/SoundEffectResources/SoundEffects/*.tres`):
an `AudioStream` plus volume, pitch, pitch randomness, a simultaneous-play
limit, and optional **pitch escalation** (each quick repeat plays a step
higher; good for chains, ticks and combos).

- **In a tile or enemy-action chain:** add an `AUDIO_VISUAL / PLAY_SOUND`
  effect where it should land. Put it right before the effect it belongs to
  (e.g. just before `DAMAGE` for an impact, before `ZAP` for a bolt).
- **In code:** `Events.play_sound.emit(MY_SFX)` with a `preload`ed resource
  (see `tile.gd`'s `_TILE_DROPPED_SFX` for the pattern).
- **For the nine juice flourishes:** see "One hook, many sounds" below. That's
  the cheapest place to add a lot of sound at once.

## What exists today

| Sound | Used for |
|---|---|
| `dice_cannon` | Nearly **every** attack tile (≈35) and enemy attack. The most overloaded sound in the game. |
| `player_shield` | Shield tiles, and enemy shield/repair actions |
| `dice_reroll_blip` | Rerolls, plus die-changing relays (Inverter, Polarizer, Surge Relay, Welder, Crossed Wires) and Siphon Engine |
| `tile_dropped` | Tile placement, Flare Burst, Sensor Spike, Target Painter, Grid Quake, button clicks |
| `error` | Refusal popups, Chaff Pod, Sabotage Charge, Do Nothing |
| `enemy_health_hit` / `enemy_shields_hit` | Enemy damaged |
| `player_health_hit` / `player_shields_hit` | Player damaged |
| `enemy_death_explosion` | Ship destroyed |
| `tractor_lock`, `die_dread_thunk`, `die_dead_click` | Tractor beam handing a die to a ship. `tractor_lock` also plays for Repo Beam, and `die_dread_thunk` for dice left behind on a jump |
| `hover_thump`, `text_blip`, `money_tick`, `alarm_klaxon` | UI hover, dialogue/tutorial text, money counting, red alert |
| `upgrade_trigger` | **Placeholder** (the reroll blip, pitched up): an upgrade tile's modifier firing |
| `shop_stock_pop` | **Placeholder** (the reroll blip, escalating): each item popping onto the shop's shelves as it opens (`Shop._pop_in`); the panel unfolding plays `tile_dropped` |
| `glass_tinkle` | **Placeholder** (synthesised): cockpit glass shards landing inside the cockpit, once per spill (`CockpitGlassShards`) |
| `glass_crack` | **Placeholder** (synthesised): each canopy crack coming back during the death sequence, rising in pitch as they quicken (`CockpitDamageSite.flare_back`) |

## Highest-value additions

If only ten sounds get made, make these. Each one is heard constantly, or
marks a moment that currently plays silent or plays the wrong sound.

1. **Upgrade trigger.** A bright "ding/charge" for a passive tile paying off. Replace `upgrade_trigger.tres`'s stream; keep its pitch escalation.
2. **Tile activation slam.** The die landing in a tile (`TileActivationEvent`). Heard on every single play.
3. **Feed / relay zap.** An electrical crackle for a die passed tile-to-tile (`ZAP` before `PASS_DIE_TO_TILE`). Heard in every machine.
4. **Distinct attack sounds.** Break `dice_cannon` up: a light shot, a heavy shot, an energy beam, a shrapnel spray. See the tile table for which tile gets which.
5. **Status applied** (×4, one per status): a sizzle (Burn), a static warble (Scrambled), a clank/jam (Jammed), a target-lock beep (Exposed).
6. **Kill confirm.** A deep boom/whoomp under the existing death explosion, timed with the hitstop.
7. **Shield gain / hull repair.** A rising shimmer for gains (code: `HealthBarController`), so defence sounds different from attack.
8. **Engine charge in / out.** A power-up hum when charge rises, a draining whine when it's spent or siphoned.
9. **Tile refused.** A short "denied" buzz that's softer than `error`, since it plays often.
10. **Screen ripple / big moment.** A low "whump + reverse cymbal" for `SCREEN_RIPPLE` (Chaos Explosion, Siege Shot, Overdraw, Emergency Shield).

## One hook, many sounds

The nine authorable flourishes all resolve in one place,
`JuiceEvent.resolve()` (`Source/Behavior/Effects/EffectEvents/AudioVisual/juice_event.gd`).
Giving each kind a default sound there would put sound on ~150 authored moments
at once, with no per-tile authoring.

| Flourish | Suggested default sound |
|---|---|
| `SHOCKWAVE` (out) | Soft "thoom" ring-out |
| `SHOCKWAVE` (in, lock-on) | Rising target-lock beep |
| `SPARK_BURST` | Crackle/fizz; "rise" variant could be a softer shimmer |
| `CALLOUT` | Short UI blip (pitch varied per colour?) |
| `BUMP` | Rubbery "boing"/thud, very quiet |
| `ZAP` | Electric arc crackle, length matched to `amount` ms |
| `GRID_RIPPLE` | Rolling clatter that travels L→R |
| `SCREEN_RIPPLE` | Low whump + reverse swell |
| `STREAM` | Suction/whoosh (in) or pour/hum (out) |
| `DIE_FLARE` | Die spin-click + chime |

## Systemic moments (code)

| Moment | Where it fires | Sound idea |
|---|---|---|
| Die lands in a tile | `TileActivationEvent.resolve` → `tile.play_activation_feedback()` | Heavy mechanical slot "chunk" |
| Tile refuses a die | `Tile.play_refusal_feedback()` | Soft denied buzz |
| Upgrade tile's modifier fires | `Tile.play_trigger_feedback()` (`_TRIGGER_SFX`) | See #1 above |
| Reactive tile fires (event response) | `TileEventTriggeredEvent` → `play_trigger_feedback` | Same as above, or a lower "click-on" variant |
| Background rule bites | `EnvironmentMonitor._on_modifier_triggered` | Ominous low tone |
| Status applied | `StatusModifier.play_applied_feedback()` | One per status (see #5) |
| Status ticks / fires | `StatusModifier.announce_triggered()` | Burn tick sizzle, Jam clank, Scramble warble, Exposed crit "shink" |
| Die scrambled on arrival | `ScrambledStatus.on_die_arriving` | Glitchy pitch-bend |
| Enemy commits an action | `EnemyActionEvent.resolve` (wind-up bump) | Short charge-up "vwip" before the action |
| Ship killed | `Enemy._play_kill_confirm()` | See #6 |
| Player hull hit (hitstop) | `DamageEvent.resolve` | Existing `player_health_hit` is fine; consider a crunchier layer |
| Shields gained | `HealthBarController._play_shields_gained_feedback()` | Shimmer up |
| Shields broken | `Events.player_shields_broken` (vignette only today) | Glass-shatter / power-down |
| Hull repaired | `HealthBarController._play_health_gained_feedback()` | Welding hiss + chime |
| Engine charge changes | `Events.engine_charge_changed` | Hum up / hum down |
| Engine fully charged | `EngineCharger` charged indicator | "Ready" chime (big: it unlocks jumping) |
| Overcharge (Redline) | `Player._bleed_for_redline` | Strained whine |
| Dead Man's Switch saves you | `EngineDeathSaveModifier` | Huge: power-dump roar + glass, then silence |
| Die rerolled | `Dice.reroll_with_tween` (`play_pop`) | Existing blip, fine |
| Holographic die spawned | `SpawnHolographicDieEvent` | Digital "materialise" |
| Die held / merged on a tile | `KeepDieWithTileEvent`, `MergeHeldDieEvent` | Clamp click / weld fuse |
| Tile pushed / grid shifted | `PushTileInDirectionEvent`, `PullRowTilesToColumnEvent` | Heavy slide scrape |
| Tile destroyed (Emergency Shield) | `DestroySourceEvent` | Burn-out fizzle |
| Lockout applied / lifted | `LockoutModifier`, `LockoutEffectEvent` | Padlock clunk / unlock click |
| Hazard countdown ticks | `Events.hazard_countdown_changed` | Warning beep, faster as it nears |
| Hazard fires | `Events.hazard_triggered` | Per hazard: solar flare whoosh, ion crackle, asteroid impact |
| Combat starts / ends | `Events.start_combat` / `combat_finished` | Alert sting / all-clear |
| Player turn starts | `Events.player_turn_start` | Subtle "your move" tick |
| End Turn pressed | `Player.end_turn()` | Firm button clack |
| Reward offered / taken | `RewardManager`, `Events.reward_picked` | Loot reveal / pickup |
| Money gained | `money_tick` exists | Fine |
| Shop open / buy | `Events.open_shop`, `Shop` | Shop bell / register |
| Map open / waypoint chosen | `Events.show_map`, `Map` | Map unfold / plot beep |
| Hyperspace jump | `JumpManager.jump_to_scenario` | Spool-up, jump boom, arrival |
| Dice left behind on a jump | `Player._announce_lost_dice()` (plays `die_dread_thunk` today) | A falling, hollow "lost" sting: the one jump moment that costs something for good |
| Hologram fizzles on a jump | `Player._dissolve_hologram()` | Soft static fizzle |
| Carried dice rerolled on arrival | `Player._arrive_with_hand()` (plays `dice_reroll_blip` today) | Fine; maybe a heavier rattle than a mid-fight reroll |
| Sector advanced | `Events.sector_advanced` | Bigger arrival sting |
| Victory / game over | `GameOver` | Fanfare / defeat drone |
| Info panel open / close | `InfoShower` | Paper/hologram swish |
| Overhead console drops out of the ceiling / goes back up | `OverheadConsole._drop` / `_rise` | Servo whine and a soft clunk as it lands; the reverse going up |
| Environment flap flips down under the credit readout | `EnvironmentMonitor._deploy` | Hinge clack, then a warning chime |

## Tiles

"Now" is what plays today. "Slot" is where a `PLAY_SOUND` would go in the chain.

| Tile | Now | Suggested | Slot |
|---|---|---|---|
| Ablative Charge | dice_cannon | Heavy cannon + metal-tear recoil on the self-damage | before each `DAMAGE` |
| Afterburner Relay | dice_cannon | Jet-burner roar; feed zap | before `DAMAGE`; before `PASS_DIE_TO_TILE` |
| Amplifier | — | Power-up hum, twice | before each `ADD_AMPLIFIER_MODIFIER` |
| Arc Tap | dice_cannon | High-voltage arc snap | before `DAMAGE` |
| Beam Splitter | — | Prism split chime + hologram shimmer | before `PASS_DIE_TO_TILE`, `FEED_HOLOGRAM` |
| Blood Valve | — | Valve hiss + wet clunk as hull is paid, then a hologram shimmer | before `SPEND_HULL`; before `SPAWN_HOLOGRAPHIC_DIE` |
| Blowtorch | dice_cannon | A roaring torch jet, then a hiss of flame back on you | before `DAMAGE`; before `APPLY_STATUS` |
| Booster Stage | — | Rocket-stage ignition | before `ADD_AMPLIFIER_MODIFIER` |
| Bootstrap Injector | — | Digital materialise + engine drain | before `SPAWN_HOLOGRAPHIC_DIE` |
| Bounty Scanner | dice_cannon | Scanner chirp; a cash-register "ka-ching" on a bounty kill | before `BOUNTY_DAMAGE`; on payout |
| Broadside | dice_cannon | Rolling multi-gun volley, one report per die in hand | before `DAMAGE` |
| Brownout Plating | — | Flickering power-down + shield hum | before `SHIELD` |
| Bump | — | Little "tick-up" | before `CHANGE_ACTIVATOR_VALUE` |
| Capacitor Bank | player_shield (payout) | Capacitor charge whine on each count, discharge thump at 0 | before `COUNT_DOWN`; payout `SHIELD` |
| Chaff Pod | error | Chaff-pop burst | before `APPLY_STATUS` |
| Chain Cannon | dice_cannon | Rapid chained shot (escalating pitch) | before `DAMAGE` |
| Chaos Explosion | — | Massive slowed-down explosion | before `DAMAGE` |
| Cinder Turbine | — | A turbine spinning up on the heat | before `CHANGE_ENGINE_CHARGE` |
| Concussion Round | dice_cannon | Blunt thud + ringing shockwave | before `DAMAGE` |
| Countdown Cannon | dice_cannon (payout) | Rising tick per count, a heavy cannon at 0 | before `COUNT_DOWN`; payout `DAMAGE` |
| Counter-Battery | tractor_lock | Jamming "thunk" as the face locks | before `SILENCE_TARGETS_FACE` |
| Countermeasures | — | Countermeasure flares popping, a whoosh across | before `TRANSFER_STATUSES` |
| Counterweight Battery | player_shield | Pendulum clunk + shield | before `SHIELD` |
| Crescendo Cannon | dice_cannon | Shot whose pitch climbs with the crescendo (escalation) | before `DAMAGE` |
| Crossed Wires | reroll blip | Electrical short buzz | before `APPLY_STATUS` |
| Cryo Lance | glass_tinkle | Icy crackle as the die freezes down | before `SET_TARGETS_HIGHEST_DIE` |
| Dampener | error | Falling "wah" as the signal dies away | before `APPLY_STATUS` |
| Dead Man's Switch | — | Arming click (quiet; it re-arms every turn) | chain start |
| Deadweight Drive | dice_cannon | Very heavy, slow thud | before `DAMAGE` |
| Debt Collector | dice_cannon | Cash-register clunk as the motes land | before `DAMAGE` |
| Dice Cannon | dice_cannon | Keep (the baseline shot) | — |
| Die Splitter | — | Cutter whine, then a hologram shimmer | before `SPLIT_ACTIVATOR` |
| Doubler | — | Rising two-step chime | before `ADD_TO_ACTIVATOR_VALUE` |
| Echo Relay | — | Reverb "ping" as the echo arms | before `ARM_ECHO` |
| Emergency Shield | — | Klaxon → slowed shield slam → burn-out | before `HEAL`, `SHIELD`, `DESTROY_SOURCE` |
| Emergency Transfer | — | Power-transfer whine | before `SHIELD` |
| Fabricator | — | Fabrication hum, then a hologram shimmer at 0 | payout `SPAWN_HOLOGRAPHIC_DIE` |
| Feedback Cowl | dice_cannon | Feedback screech | before `DAMAGE` |
| Filter Gate | dice_cannon | Gate open (pass) / gate slam (filtered) | branch starts |
| Flak Cannon | dice_cannon | Shrapnel spray, more pops per neighbour | before `DAMAGE` |
| Flare Burst | tile_dropped | Flare ignition whoosh | before `APPLY_STATUS` |
| Flashpoint | dice_cannon | Ignition "fwoomp" | before `DAMAGE` |
| Fume Vent | — | Hissing vent at turn start | before `APPLY_STATUS` |
| Fuse Cutter | — | Fuse fizz running across the grid | before `COUNT_DOWN` |
| Fuse Payload | — | Fuse burn-down, then an incendiary pop | payout `APPLY_STATUS` |
| Governor Coil | — | Governor whirr winding down | before `CHANGE_ENGINE_CHARGE` |
| Grounding Rod | dice_cannon | Lightning strike + ground thunk | before `DAMAGE`; before `CHANGE_ACTIVATOR_VALUE` |
| Grudge Cannon | dice_cannon | Angry heavy shot on a grudge, normal otherwise | grudge branch |
| Heat Sink | player_shield | Hiss of heat being drawn off | before `TARGET_PLAYER` |
| Hex Coil | — | Crackle on each hit | before `DAMAGE` |
| Holding Bay | tractor_lock | Clamp lock / stasis hum; clamp release when the die returns | first step; `HeldDieDelay._on_due` |
| Holo-Duplicator | — | Holographic copy shimmer ×2 | before `SPAWN_HOLOGRAPHIC_DIE` |
| Incendiary Round | dice_cannon | Incendiary whoosh + crackle | before `APPLY_STATUS` |
| Inertial Feedback | dice_cannon | Rolling rumble release | before `DAMAGE` |
| Interdiction Net | — | Net launch + snare | before `APPLY_STATUS` |
| Inverter | reroll blip | Flip "fwip" | before `CHANGE_ACTIVATOR_VALUE` |
| Leech Relay | dice_cannon | Suction slurp ×2 | before each `ADD_USES_REMAINING` |
| Leeching Shot | dice_cannon | Shot + drain slurp | before `TARGET_PLAYER` |
| Lone Wolf Lance | dice_cannon | Thin lance; a howl or overdriven crack on the tripled shot | before `DAMAGE`; in the Fleet branch |
| Lucky Seven | dice_cannon | Slot-machine "ding" on a 7 | before `DAMAGE` |
| Napalm Vent | — | Vent hiss + flame | before `APPLY_STATUS` |
| Nudge Down | — | Little "tick-down" (Bump reversed) | before `ADD_TO_ACTIVATOR_VALUE` |
| Opening Salvo | — | Brass "ready" chime at turn start | before `ARM_ECHO` |
| Overclock Coil | dice_cannon | Coil whine rising with each use | chain start |
| Overdraw Coil | dice_cannon | Huge drain → discharge | before `DAMAGE` |
| Overpressure Lance | dice_cannon | Pressure hiss → lance blast | before `DAMAGE` |
| Pair Lock | dice_cannon | Lock "clunk" as the pair matches | before `DAMAGE` |
| Parity Junction | dice_cannon | Switch click (two pitches for odd/even) | each branch |
| Phantom Squadron | — | Ghostly shimmer per hologram | before each `SPAWN_HOLOGRAPHIC_DIE` |
| Phase Cloak | — | Phase-out shimmer; a whoosh as a hit passes through | before `APPLY_STATUS`; Phased miss |
| Pilot Light | — | Pilot flame "fwump" | before `FEED_HOLOGRAM` |
| Polarizer | reroll blip | Magnetic snap | before `CHANGE_ACTIVATOR_VALUE` |
| Preflight Interlock | dice_cannon | Checklist beeps → triple shot | before `DAMAGE` |
| Pulse Repeater | dice_cannon (payout) | Soft tick per count, a pulse shot at 0 | before `COUNT_DOWN`; payout `DAMAGE` |
| Ram Scoop | — | Intake whoosh | before `CHANGE_ENGINE_CHARGE` |
| Ratchet Cannon | dice_cannon | Ratchet click that tightens each use | before `DAMAGE` |
| Re-Roll | — | Dice rattle | before `REROLL_ACTIVATOR` |
| Receiver Dish | dice_cannon | Signal-received chirp when Fed | Fed branch |
| Redline Governor | — | Redline engine scream | before `ADD_OVERCHARGE` |
| Regenerative Brake | — | Regen whine | before `CHANGE_ENGINE_CHARGE` |
| Relay Terminal | dice_cannon | Relay hum stacking with depth | before `DAMAGE` |
| Reloader | — | Magazine reload clack | before `ADD_USES_REMAINING` |
| Repo Beam | tractor_lock | Reverse tractor whine, die yanked free | before `RECEIVE_DIE_FROM_TARGET` |
| Runaway Reactor | dice_cannon | Reactor alarm + meltdown | branch |
| Sabotage Charge | error | Sabotage beep-beep-clunk | before `APPLY_STATUS` |
| Scatter Router | dice_cannon | Ricochet ping | before `PASS_DIE_TO_TILE` |
| Sensor Spike | tile_dropped | Sonar ping / lock-on | before `APPLY_STATUS` |
| Shield Attractor | player_shield | Magnetic pull + grid slide | before `SHIELD`; before `PULL_ROW_TILES_TO_COLUMN` |
| Shield Burst | player_shield | Keep, maybe a bigger burst layer | — |
| Signal Relay | dice_cannon | Signal blip | before `PASS_DIE_TO_TILE` |
| Skeleton Crew | player_shield | Hollow, sparse shield hum | before `SHIELD` |
| Solar Sail | player_shield | Sail unfurl + shimmer | before `SHIELD` |
| Spark Gap | — | Spark snap | before `DAMAGE` |
| Spiked Hull | — | Metallic spike "shink" on the return hit | before `DAMAGE` |
| Spite Coil | dice_cannon | Snarling zap | before `DAMAGE` |
| Spotter Drone | — | Drone beep + lock | before `APPLY_STATUS` |
| Static Bloom | — | Static wash | before `APPLY_STATUS` |
| Status Catalyst | tractor_lock | Fizzing, bubbling reaction | before `MULTIPLY_STATUSES` |
| Suppression Pulse | tile_dropped | Deep pulse that ducks the mix | before `APPLY_STATUS` |
| Surge Relay | reroll blip | Surge buzz | before `REROLL_ACTIVATOR` |
| Swarm Battery | dice_cannon (every shot) | Small rapid pops, pitch escalating across the volley | before each `DAMAGE` |
| Sweeping Battery | dice_cannon | Wide sweeping beam | before `DAMAGE` |
| Tactical Boomerang | dice_cannon | Throw "whirr" out and back | before `PUSH_TILE_IN_DIRECTION` |
| Target Painter | tile_dropped | Laser-paint hum | before `APPLY_STATUS` |
| Time Bomb | tractor_lock (arm), dice_cannon (blast) | Magnetic clamp + arming beep, soft tick each turn, heavy delayed blast | before SHOCKWAVE; `DelayedPayload._on_turns_changed`; first payload step |
| Toll Relay | — | Coin-toll ding | chain start |
| Turncoat Cannon | dice_cannon | Betrayal sting on the scrambled hit | turncoat branch |
| Twin Barrel | dice_cannon | Double-barrel blast; a "hold" clack on the first die | before `DAMAGE`; hold step |
| Unstable Shield Array | player_shield | Shield hum that wobbles more each use | before `SHIELD` |
| Value Exchange | — | Swap "shwip" | before `FLIP_ONES_AND_SIXES` |
| Value Sorter | dice_cannon | Sorting click, three pitches | each branch |
| War Footing | — | Rank-up chime as the bonus builds | turn-start response |
| Welder | reroll blip | Arc-weld sizzle | before `MERGE_HELD_DIE` |

## Enemy actions

| Action | Now | Suggested | Slot |
|---|---|---|---|
| Aegis Ally | player_shield | Shield projected across (zap + hum) | before `SHIELD` |
| Attack Player | dice_cannon | An enemy-specific shot, distinct from the player's cannon | before `DAMAGE` |
| Charge Weapon | player_shield | Capacitor charging whine | before `SHIELD` |
| Do Nothing | error | Sputter / failed-ignition cough | chain start |
| Flee | — | Engine burn away | before `FLEE` |
| Getaway | die_dread_thunk | Afterburner snatch-and-run, a cackle of engines | before `ESCAPE_WITH_DICE` |
| Grid Quake | tile_dropped | Seismic rumble through the grid | before `PUSH_TARGETED_TILES` |
| Holo Loader | — | Hologram shimmer as a die is conjured for an ally | before `SPAWN_HOLOGRAM_FOR_ALLY` |
| Ion Shot | dice_cannon | An ion discharge: a rising crackle, then a fizzing shield hit | before `ION_BOLT` |
| Impound | dice_cannon | Clamp + hold (the die is taken) | before `KEEP_DIE_WITH_ACTOR` |
| Incendiary Shot | dice_cannon | A whooshing incendiary round that bursts into flame | before `MISSILE` |
| Jamming Pulse | — | A buzzing jammer squeal | before `ZAP` |
| Launch | bump | Hangar klaxon + catapult whoosh | before `LAUNCH_SHIP` |
| Lockout Grid Pos | — | Lock-on + clamp | before `LOCKOUT_TILE` |
| Pilfer | dice_cannon | Quick grab: a snap and a pocketed rattle | before `KEEP_DIE_WITH_ACTOR` |
| Purge Vents | — | Vents blowing hot exhaust across at you | before `STREAM` |
| Raid | dice_cannon | A meaner, ragged shot at another ship (not at you) | before `DAMAGE` |
| Relay | — | Toss-and-catch: the die flicked to an ally | before `FEED_ALLY` |
| Repair Ally | player_shield | Repair drones whirr | before `HEAL` |
| Scrambler | — | A warbling static bolt | before `ZAP` |
| Shield Self | — | Shield up | before `SHIELD` |
| Siege Shot | dice_cannon | Long wind-up → enormous slowed shot | chain start; before `DAMAGE` |
| Siphon Engine | reroll blip | Draining suction from your engine | before `CHANGE_ENGINE_CHARGE` |
| Target Lock | — | Rising lock-on tone | before `LASER` |

## Statuses

| Status | Applied | Fires |
|---|---|---|
| Burn | Ignition whoosh | Sizzle each tick, quieter as stacks fall |
| Scrambled | Static warble | Glitch pitch-bend as a die flips |
| Jammed | Clank / gears catching | Grinding stall as an action becomes nothing |
| Exposed | Target-lock beep | Critical "shink" when cashed in |
| Phased | Phase-out shimmer | Whoosh as the hit passes through |
| Weakened | Power-down droop | Muffled, flattened impact on a weakened hit |

The same statuses on the player use the same sounds. Jammed and Scrambled
fire on a tile there (a jammed tile's refusal, a die flipping as it lands).
