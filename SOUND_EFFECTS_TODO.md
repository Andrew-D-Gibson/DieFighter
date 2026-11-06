# Missing SFX — production and integration checklist

Audited against the repository on **2026-11-04**, using
[SOUND_EFFECTS.md](SOUND_EFFECTS.md) as the creative starting point. Style:
**keep the existing synth/arcade sound**. These are production recommendations,
not a claim that every animation needs an audible layer. No audio or game code
has been changed. Coverage is based on static source/resource inspection, not
a listening pass through every encounter.

## How to use this list

- **P1:** make first: frequent interactions, readable game rules, major transitions.
- **P2:** finish the game's vocabulary: enemies, hazards, economy, unusual mechanics.
- **P3:** optional character and polish. Shared P1/P2 sounds cover these first.
- **Missing:** no dedicated cue at that hook. Existing attack/hit/UI layers may
  still be audible during the same moment.
- **Replace:** the hook already plays a borrowed or placeholder sound.
- **Optional:** the event is already adequately covered; a new sample is a taste call.

Each backticked cue name below is a proposed **filename without `.wav`** and
future `SoundEffectResource` basename. Check a row off when the sample is made;
integration is a separate step. Multiple names in a row mean separate exports.
Put completed files in any one folder and give me its path; matching these names
will let me place them without guessing. Suffix alternate takes `_01`, `_02`.
You do not need to create a directory tree or Godot `.tres` files yourself.

Suggested exports: WAV, trimmed leading silence, preserve useful tails, avoid
clipping. Mono is sufficient for most short cues; stereo is fine for larger
transitions. Durations below are creative targets, not engine requirements.
Keep frequent cues dry and compact; pitch variation/escalation can happen in
Godot. Avoid baking a whole volley or multi-target sequence into one sample
unless the row explicitly calls for it.

## First recording session

Start with these **16 files**, in approximately this order. They provide a useful
first batch without committing to the whole wishlist:

1. `tile_activate`, `upgrade_trigger`, `relay_zap`, `tile_refused`.
2. `shot_light`, `shot_heavy`, `shot_energy`, `shot_flak`.
3. `burn_apply`, `scrambled_apply`, `jammed_apply`, `exposed_apply`.
4. `engine_gain`, `engine_ready`, `shield_break`, `hologram_spawn`.

The existing cannon, shield, hit, explosion, money and text sounds remain useful.
There is no need to remake those before filling the gaps below.

## P1 — interactions and combat clarity

| Made | Proposed file | State / sound brief | Integration destination and timing |
|---|---|---|---|
| [ ] | `tile_activate` | Missing. 50–120 ms chunky digital slot/clack; satisfying at low volume. | `TileActivationEvent.resolve` → `Tile.play_activation_feedback()`, at the committed activation. Once per activation, not every sub-effect. |
| [ ] | `upgrade_trigger` | Replace reroll sample. 100–220 ms bright proc ding, distinct from a die roll. | Swap stream in existing `upgrade_trigger.tres`; keep escalation. Used by `Tile.play_trigger_feedback`, tile upgrades, unlock popup, Outrigger and region feedback today; split those uses as dedicated cues arrive. |
| [ ] | `relay_zap` | Missing. 80–160 ms compact electrical hand-off. | Feed chains: before `PASS_DIE_TO_TILE`, aligned with authored `ZAP`; shared by Signal/Afterburner/Echo/Scatter relays, etc. One owner: chain or semantic Feed hook. |
| [ ] | `tile_refused` | Missing dedicated cue. 60–120 ms soft descending denial; less harsh than `error`. | `Tile.play_refusal_feedback()`, when a die is bounced. Avoid also playing a second generic refusal for the same attempt. |
| [ ] | `shot_light` | Replace generic cannon on light/repeating weapons. 60–140 ms crisp pew/pop. | `PLAY_SOUND` before projectile departure, or before `DAMAGE` on an instant shot. Chain/Swarm/Pulse Repeater; one report per actual shot. |
| [ ] | `shot_heavy` | Replace cannon on heavy weapons. 150–350 ms low digital cannon with a punchy onset. | Countdown Cannon payout, Deadweight Drive, Ablative Charge, Overpressure Lance, Grudge payoff, Siege Shot. Impact layers remain separate. |
| [ ] | `shot_energy` | Replace cannon on energy/lance weapons. 100–250 ms sharp tonal discharge. | Arc Tap, Lone Wolf Lance, Sweeping Battery, Sunlance, Hex/Spark/Spite Coils; before `LASER`/`ZAP` or instant damage as appropriate. |
| [ ] | `shot_flak` | Replace cannon. 120–250 ms noisy splatter of small digital transients. | Flak Cannon and Broadside; use one short report per authored shot, not a fixed-count recording. |
| [ ] | `shield_gain` | Optional replacement family: `player_shield` already works. 150–300 ms rising shimmer. | Shared `HealthBarController._play_shields_gained_feedback()`, only on actual gain. If centralized, remove redundant authored shield sounds. Existing `player_shield` can fill this slot immediately. |
| [ ] | `hull_repair` | Missing dedicated cue; repair actions borrow shield/money sounds. 200–450 ms arcade weld/build chirp. | `HealthBarController._play_health_gained_feedback()` on successful healing, including Repair Ally and station repair. Don't fire for a full-hull refusal. |
| [ ] | `shield_break` | Missing. 180–350 ms digital shatter followed by power collapse. | `Events.player_shields_broken`, on shield loss to a hit. Spending shields is a separate semantic cue, not a break. |
| [ ] | `engine_gain` | Missing. 100–220 ms rising power pulse. | Actual positive charge changes; `EngineCharger`/`Events.engine_charge_changed` with tracked previous value, not every UI refresh. Ram Scoop, Cinder Turbine, Slipstream Vane, etc. |
| [ ] | `engine_spend` | Missing. 100–250 ms clean downward power sweep. | Actual deliberate charge expenditure (`SpendEngineChargeEvent`); boost branches, engine-funded tiles. Suppress duplicate generic loss cue. |
| [ ] | `engine_drain` | Replace reroll on Siphon Engine; otherwise missing dedicated theft cue. 150–350 ms hostile suction/down-bend. | Siphon action before `CHANGE_ENGINE_CHARGE`; `Events.engine_charge_drained` is available for actual theft. Don't play merely because charge resets at combat start. |
| [ ] | `engine_ready` | Missing. 200–400 ms clear positive two-note ready signal. | First crossing from below full to jump-ready; `EngineCharger._update_ui` can observe it. Suppress on loading/restoring a save and repeated redraws. |
| [ ] | `hologram_spawn` | Missing. 120–250 ms digital materialisation shimmer. | `SpawnHolographicDieEvent.resolve`, plus ally/Feed hologram creation paths. Fabricator, Holo-Duplicator, Phantom Squadron, Beam Splitter, Pilot Light, Blood Valve. Once per creation or a capped batch cue. |
| [ ] | `evasion_miss` | Missing. 120–220 ms nimble stereo-feeling swish/arcade dodge. | `EvasionModifier.announce_triggered()` or `Events.player_evaded`; at a confirmed miss. Distinct from a shield impact and from Phased. |
| [ ] | `turn_player` | Missing. 50–120 ms restrained “your move” tick. | `player_turn_start` and the first-turn presentation path; one cue after the hand/arrival is ready. Shared cue for opening turn, not two simultaneous event listeners. |
| [ ] | `turn_end` | Generic button click only. 70–150 ms firm commit clack. | `Player.end_turn()` after the turn is accepted, including confirmed end-turn flow. Don't fire on opening/cancelling confirmation or automated state cleanup. |

### All six statuses

Applied and triggered are different meanings. Start with the four harmful apply
cues above; lighter/shorter variants can cover triggers until dedicated takes exist.
The player and enemies share each status's sound. No separate faction recordings.

| Made | Proposed files | Sound brief | Integration destination and timing |
|---|---|---|---|
| [ ] | `burn_apply`, `burn_tick` | Ignition fwoomp; quieter short sizzle. | `StatusModifier.play_applied_feedback()` dispatch by status id; Burn's actual tick/`announce_triggered` path. One per damage tick, not per stack. |
| [ ] | `scrambled_apply`, `scrambled_trigger` | Static warble; quick glitch/pitch flip. | Shared applied-feedback dispatch; `ScrambledStatus.on_die_arriving`/its actual trigger announcement when the die is changed. |
| [ ] | `jammed_apply`, `jammed_trigger` | Digital mechanism catching; grinding failed-action clunk. | Applied dispatch; Jammed consumption/refusal/action-cancellation path. Avoid stacking with `tile_refused` for one jammed refusal. |
| [ ] | `exposed_apply`, `exposed_trigger` | Target paint beep; sharp critical shink. | Applied dispatch; Exposed's damage modifier when it is consumed. Keep the ordinary hit sound. |
| [ ] | `phased_apply`, `phased_miss` | Phase-out shimmer; hollow pass-through whoosh. | Applied dispatch; `PhasedStatus.announce_triggered()` on a cancelled hit. Do not play an impact for the ship the hit missed. |
| [ ] | `weakened_apply`, `weakened_trigger` | Falling power droop; muted compression blip. | Applied dispatch; Weakened's actual modified-hit announcement. Trigger can reuse a softened apply cue initially. |

Status expiry/cleansing can reuse a quiet reverse shimmer (P3); natural expiry
does not need another loud cue. An application that adds no stacks should not
announce success.

## P1 — travel and stakes

| Made | Proposed files | State / sound brief | Integration destination and timing |
|---|---|---|---|
| [ ] | `jump_spool`, `jump_depart`, `jump_arrive` | Missing. Rising synth spool; short bass punch; descending arrival release. Supply separate files so timing follows gameplay. | `JumpManager.jump_to_scenario`, `BackgroundManager.play_jump_intro`/`play_jump_outro`; departure at entry to hyperspace, arrival at re-entry. Reuse for opening cutscene `_charge_jump`, `_hyperspace_punch`, `_hyperspace_exit`. |
| [ ] | `combat_start`, `combat_clear` | Missing dedicated stings. Short danger alert / resolved all-clear, 250–600 ms. | Combat presentation around `start_combat`/`enemies_arrived` and `combat_finished`. Music is separate; don't stack a clear, ready, reward and turn sting at full volume. |
| [ ] | `death_save` | Missing dedicated sound; generic upgrade proc currently supplies tile feedback. 400–800 ms huge emergency power dump with a decisive end. | `EngineDeathSaveModifier.on_before_event`, only after it actually cancels fatal damage and empties the drive. Replace/suppress that event's generic proc layer. |
| [ ] | `redline_strain` | Missing dedicated cue, hull hits already sound. 150–350 ms unstable overdriven whine. | `Player._bleed_for_redline` before the queued hull cost. Also optional short warning when entering overcharge; don't loop continuously. |
| [ ] | `dice_lost` | Replace borrowed `die_dread_thunk`. 250–500 ms hollow descending loss sting. | `Player._announce_lost_dice(count)` on permanent loss when departing; once for the batch, not per die. Also review die-theft/departure callers. |

## P2 — dice, grid and machine vocabulary

| Made | Proposed files | State / sound brief | Integration destination and timing |
|---|---|---|---|
| [ ] | `die_rattle` | Missing physical/arcade rattle; existing reroll blip can be reused first. 100–220 ms. | `Dice.reroll_with_tween` at the face change. That method and `play_pop` are visual-only today: don't assume every reroll already sounds. Remove duplicate chain/Player roll cues if centralized. |
| [ ] | `die_hold`, `die_release` | Missing dedicated cues; Holding Bay borrows tractor lock. Clamp click / release click. | `KeepDieWithTileEvent`, Holding Bay's `HeldDieDelay._on_due`, twin-die hold branches and held-die return. Pair Lock/Twin Barrel/Lucky Seven. |
| [ ] | `die_split`, `die_merge` | Missing; Welder uses reroll. Cutter/fission chirp / weld-fuse chirp. | Before `SPLIT_ACTIVATOR` and `MERGE_HELD_DIE`; don't add an extra hologram layer for the same split unless intentionally quiet. |
| [ ] | `die_value_up`, `die_value_down`, `die_value_swap` | Missing dedicated distinctions; some tiles borrow reroll or `bump`. Tiny rising/falling ticks and a two-way flip. | Bump/Doubler/Nudge Down/Crosslink/Flywheel; Inverter/Polarizer/Value Exchange/Value Sorter. At committed face change, not preview. |
| [ ] | `hologram_fizzle` | Missing. 80–200 ms soft static dissolution. | `Player._dissolve_hologram` on jumping; review spent hologram cleanup too. Reuse for disappearance, not real-die loss. |
| [ ] | `grid_slide` | Missing dedicated cue, Grid Quake borrows placement click. 100–250 ms digital ratchet/scrape. | Push/pull/move effect events, on actual movement; Shield Attractor, Tactical Boomerang, Grid Quake. Cap multi-tile bursts. |
| [ ] | `tile_burnout` | Missing. 150–300 ms overload/fizzle with a hard cutoff. | `DestroySourceEvent` at tile destruction; Emergency Shield. Keep distinct from selling/removing a tile through UI. |
| [ ] | `lock_apply`, `lock_release` | Apply borrows tractor lock; release lacks a dedicated cue. Padlock chunk / small unlock. | `LockoutModifierVisual` currently emits `_LOCK_SFX`; replace there. Release at real modifier removal, not scene teardown. Includes asteroid lockouts. |
| [ ] | `uses_refill` | Missing. 80–150 ms “reload” click with a bright tail. | `ADD_USES_REMAINING` (Reloader/Leech Relay) and `TileUseLights.show_lit`. Ordinary whole-board turn refresh should be silent or a single capped batch, not one per light. |
| [ ] | `countdown_tick`, `countdown_ready` | Missing tile-count cues. Small rising charge tick / discharge cue. | `COUNT_DOWN` changes in Countdown Cannon, Capacitor Bank, Pulse Repeater, Fabricator, Fuse Payload/Fuse Cutter; ready only on crossing to payout. Weapon/shield/hologram cue handles the payout itself. |
| [ ] | `echo_arm` | Missing. 100–250 ms ping with a short repeat. | `ARM_ECHO`, Echo Relay and Opening Salvo; arm once. Repeated activation should sound like its actual effect rather than a new echo alarm. |
| [ ] | `amplifier_gain` | Missing dedicated cue; generic proc may overlap. Rising amplifier/power chime. | `ADD_AMPLIFIER_MODIFIER`, Booster Stage/Amplifier. Can also cover War Footing's family-boost increase. |
| [ ] | `bomb_arm`, `bomb_tick` | Arm borrows tractor lock; no dedicated timer tick. Clamp-beep / compact pulse. | Time Bomb `DelayedPayload.play_armed_feedback` and `_on_turns_changed`; detonation reuses `shot_heavy`/explosion, not a mandatory third new file. |
| [ ] | `shield_spend` | Missing dedicated cue. Downward energy collapse that does not sound like damage. | `SpendShieldsEvent`, including Discharge Plate. No `shield_break` cue here. |
| [ ] | `energy_transfer` | Missing dedicated transfer. 180–350 ms suction/pour with a positive end. | Shield Siphon/Emergency Transfer/Leeching Shot/Leech Relay streams. Shared `JuiceEvent._stream` only if it owns the cue; otherwise put `PLAY_SOUND` in the chain. `engine_drain` remains the hostile engine-theft variant. |
| [ ] | `ion_freeze` | Cryo Lance borrows `glass_tinkle`. 100–250 ms crystalline digital freeze. | Before `SET_TARGETS_HIGHEST_DIE`/the face landing; Counter-Battery can reuse `lock_apply` for face silencing. |

## P2 — enemy actions

These are shared action sounds, not a request for a complete bespoke set per
enemy ship. Every action resource is indexed at the end of this document.

| Made | Proposed files | State / sound brief | Integration destination and timing |
|---|---|---|---|
| [ ] | `enemy_shot` | Replace player cannon. 80–200 ms hostile, raspier report. | `attack_player.tres` and `raid.tres` before shot departure/instant damage. Same sample initially; raiders don't require a third faction cue. |
| [ ] | `enemy_charge` | Charge Weapon borrows shield. 200–450 ms capacitor wind-up. | `charge_weapon.tres` before `KEEP_DIE_WITH_ACTOR`; also Siege Shot wind-up, followed by `shot_heavy`. |
| [ ] | `ion_shot` | Replace cannon. 120–250 ms fizzing ion discharge. | `ion_shot.tres` before `ION_BOLT`; existing shield hit remains at impact. |
| [ ] | `incendiary_launch` | Replace cannon. 120–250 ms noisy flame/projectile launch. | `incendiary_shot.tres` before `MISSILE`; also Incendiary Round/Flashpoint/Blowtorch when suitable. Burn application owns the ignition-at-target cue. |
| [ ] | `jammer_pulse` | Missing dedicated action cue. 120–250 ms buzzy interference sweep. | `jamming_pulse.tres` before `ZAP`; can cover Sabotage Charge, Dampener, Suppression Pulse. Don't double with `jammed_apply` at the same instant. |
| [ ] | `scrambler_bolt` | Missing dedicated action cue. Static laser/wobble. | `scrambler.tres` before `ZAP`; reuse `scrambled_apply` if the bolt and application are too close to distinguish. |
| [ ] | `target_lock` | Missing dedicated cue. Short rising acquisition beep. | `target_lock.tres` before `LASER`; Sensor Spike/Spotter Drone/Target Painter can share it. Target application can reuse `exposed_apply`. |
| [ ] | `vent_burst` | Missing. 150–350 ms synth exhaust hiss. | `purge_vents.tres` before `STREAM`; Fume Vent/Napalm Vent/Heat Sink/Countermeasures can reuse. |
| [ ] | `ship_launch` | Replace `bump`. Klaxon chirp + catapult whoosh. | `launch_interceptor.tres` before `LAUNCH_SHIP`; sound launch once, not again when the ship's arrival signal fires. |
| [ ] | `ship_flee` | Flee missing; Getaway borrows die thunk. 200–450 ms retreating engine sweep. | `flee.tres` before `FLEE`, `getaway.tres` before `ESCAPE_WITH_DICE`; optionally layer theft sting once. |
| [ ] | `enemy_fizzle` | Replace `error`. 100–200 ms sputter/cough. | `do_nothing.tres`, at the wasted action; avoid implying a player input error. |
| [ ] | `ally_feed` | Missing. 100–220 ms toss/catch signal. | `relay.tres` before `FEED_ALLY`; can reuse a softer `relay_zap`. Aegis Ally can reuse `energy_transfer` + shield gain, Repair Ally uses hull repair, Holo Loader uses hologram spawn. |
| [ ] | `die_seize` | Replace tractor-lock grapple if desired. Harsh claw clamp with a short reel-in. | `seize.tres` `GRAPPLE.sound_resource`, which fires on clamp contact. Repo Beam can reuse reversed transfer/tractor texture. |
| [ ] | `thief_snicker` | Missing; specifically requested in original notes. 250–600 ms mischievous synthesized/radio-filtered snicker, no intelligible words needed. | `seize.tres` immediately after STOLEN `CALLOUT`. One generic take first; faction variants are P3, not a blocker. |

## P2 — hazards and region rules

| Made | Proposed files | State / sound brief | Integration destination and timing |
|---|---|---|---|
| [ ] | `hazard_tick`, `hazard_urgent` | Replace reroll/die-thunk. 60–140 ms warning pip / lower urgent beat. | `EnvironmentMonitor._on_hazard_countdown_changed` uses `_TICK_SFX`/`_URGENT_TICK_SFX`; `HazardWarning._beat` currently borrows die thunk. Reuse urgent sample for accelerating wind-up beats. |
| [ ] | `hazard_asteroid` | Replace die thunk. 200–450 ms crunchy impact. | `HazardThematicVFX.play_asteroid_impact` at rock contact, before lock applies. Don't play a second whole-screen impact for every tiny spark. |
| [ ] | `hazard_ion` | Replace upgrade blip. 250–500 ms broad electrical discharge. | `HazardThematicVFX.play_ion_storm_discharge` at strike. Keep distinct from the smaller `ion_shot`. |
| [ ] | `hazard_solar` | Replace cannon. 300–650 ms hot sweeping synth roar. | `HazardThematicVFX.play_solar_flare_sweep` at heat wash. Burn status cue can be lower underneath. |
| [ ] | `hazard_fate` | Missing dedicated cue. 200–500 ms reality-bending reverse/glitch sweep. | `HazardThematicVFX.play_fate_rift_strike` at strike; `play_fate_rift_die_flip` is per die, so cap/group playback. Use `hazard_struck` with hazard identity if centralized. |
| [ ] | `region_rule_trigger` | Replace generic upgrade chime. 100–250 ms low rule-warning tone. | `EnvironmentMonitor._play_trigger_feedback`; rules/hazards already support `trigger_sfx` overrides. Existing monitor cooldown should remain. |
| [ ] | `region_announce` | Missing dedicated announcement. 200–400 ms caution chime. | `RegionAlert._unfold`/monitor arrival presentation, once per shown region card. Reuse when possible rather than one file per permanent rule. |

## P2 — rewards, shops, map and progression

| Made | Proposed files | State / sound brief | Integration destination and timing |
|---|---|---|---|
| [ ] | `reward_reveal`, `reward_take` | Missing dedicated cues. Short loot sparkle / affirmative acquisition. | `Reward._present`/`_pop` and successful `_end_reward` (`reward_picked`). Money already ticks; tile placement already clicks, so acquisition is a quiet layer or replaces the redundant click. |
| [ ] | `shop_open`, `shop_close` | Replace placement click. Arcade shutter/panel open and shut. | `Shop._play_reveal` and `_play_close`, replacing `_PANEL_OPEN_SFX` (currently shared both ways). Can share takes with station panels. |
| [ ] | `shop_stock_pop` | Replace escalating reroll. 60–130 ms soft shelf pop. | Existing `shop_stock_pop.tres` stream; `Shop._pop_in`. Also used in tile-unlock reveal today. Keep escalation. |
| [ ] | `shop_buy`, `shop_sell` | Missing dedicated confirmation; money ticks exist. Register up-chirp / down-chirp. | Shop successful item purchase after payment/acceptance, `RepairStation._play_sale_feedback` for sell. Not on refused drags, previews, or refunds. |
| [ ] | `money_loss` | Borrowed money ticks currently cover coin loss too. Short descending arcade debit sting, clearly different from collecting credits. | `StealMoneyEvent.resolve` / `MoneyParticle.spawn_loss`, once when a positive amount is actually taken. Toll/extortion/theft encounters share it; ordinary shop payment uses buy confirmation. |
| [ ] | `shop_restock` | Reroll currently uses money tick. Shelf sweep/reset chirp. | `Shop.reroll` on successful paid restock, followed by existing per-item pops. |
| [ ] | `grid_cell_open` | Replace placement click. Chunky plate release + positive chirp. | `SealedCellPlates` uses `_CELL_OPENED_SFX`; successful Grid Slot install. Distinct from moving a tile. |
| [ ] | `tile_upgrade` | Replace shared proc blip. 200–400 ms stronger merge/rank-up chord. | `TileUpgradeLook.burst`/`Events.tile_upgraded`; separate from a passive firing. Keep quieter merge chirp if the incoming tile also lands. |
| [ ] | `family_unlock` | Replace shared proc. 400–800 ms discovery flourish. | `TileUnlockPopup.open` (`_OPEN_SFX`); per-tile reveal can keep `shop_stock_pop`. |
| [ ] | `map_open`, `map_close` | Missing dedicated panel cues. 100–250 ms holographic unfold/fold. | Actual map/systems tab change (`map_shown`, `systems_shown`), once per transition. Reuse quiet UI panel sounds if available. |
| [ ] | `map_plot` | Missing. 60–150 ms route-selection ping. | `Map.jump` once destination validation succeeds, before committing the jump. Not every hover or camera pan. |
| [ ] | `fate_advance` | Missing. 250–500 ms ominous creeping glitch. | `Map._animate_fate_advance`; once per border advance, not one per corrupted pip. |
| [ ] | `gate_open`, `gate_pass` | Missing dedicated cues. Unlocking portal chime / larger gold jump blast. | `JumpGate.open`/`_warp_in`, `play_passage` at passage/white-out. Normal `jump_depart` can cover passage first. |
| [ ] | `sector_arrive` | Missing dedicated sting. 350–750 ms expansive new-sector chord. | `JumpManager.jump_through_gate`, with sector-title reveal. Gate passage and arrival are separate beats; `sector_advanced` alone may fire before the visual reveal. |
| [ ] | `victory_sting`, `defeat_sting` | Missing dedicated SFX stings; music/death sequence already contribute. 0.6–1.5 s. | `GameOver._on_game_win` / `_on_game_over`, after outcome is settled. Coordinate with music and cockpit destruction; defeat can be just a quiet settling tail. |

## P2 — Fate's Die and the Reckoning

| Made | Proposed files | State / sound brief | Integration destination and timing |
|---|---|---|---|
| [ ] | `fate_carve` | Borrows `upgrade_trigger`. A stone chisel strike with a low purple shimmer: a face carved into bone. | `FateDieDisplay._on_carved` (`_CARVE_SFX`) as the hanging die lands on its new face; also the ally arrival in `ReckoningDirector._place_ally`. |
| [ ] | `fate_die_received` | Borrows `die_dread_thunk`. A bone die dropping onto a chain: one clack, a rattle. | `FateDieDisplay._on_received` as the die drops into the cockpit. |
| [ ] | `fate_roll` | Borrows `dice_reroll_blip`. A single heavy die thrown by something huge; a long tumble, a hard stop. | `FateDieDisplay._on_rolled` at the start of each Reckoning round; the banner (`ReckoningHud._show_roll`) lands with it. |
| [ ] | `horizon_swallow` | Borrows `die_dread_thunk`. A deep inward suck, tiles crunching, then silence. | `ReckoningDirector._swallow_column`, once per column. |
| [ ] | `fate_reveal_line` | Borrows `text_blip`. A distorted comms burst under each line of the dying Bastion. | `FateRevelation._next`, once per line, not per character. |
| [ ] | `escape_velocity` | Missing. A rising drive whine that tops out and tears free. | `ReckoningDirector._escape_the_hole` before the white-out; optionally a short tick on `add_escape_velocity`. |

## P3 — ship, cockpit, UI and cinematic polish

| Made | Proposed files | State / sound brief | Integration destination and timing |
|---|---|---|---|
| [ ] | `carousel_step`, `carousel_land` | Replace tractor lock / placement click. Geared rotation / landing ratchet. | `CarouselBehavior._animate` and `_land`; cap per-tile land sounds. Ring rewind can pitch/reverse the step; `_play_hold` uses a quiet lock click. |
| [ ] | `carousel_ignite` | Missing dedicated ignition. Brief reactor kick. | `CarouselBehavior.play_ignition`, when reactor triggers. Reuse engine/energy cues first. |
| [ ] | `sail_catch` | Replace upgrade proc. Light, airy rising synth pluck. | `SailCatchEvent.resolve` (`_SAIL_SFX`) as each die's light climbs the Outrigger mast; preserve rising/batched feel. |
| [ ] | `console_down`, `console_up` | Missing. 200–450 ms synth servo with a soft seat clunk. | `OverheadConsole._drop`/`_rise`; same sample reversed is acceptable. Interrupt with the motion rather than letting a long motor continue. |
| [ ] | `flap_open`, `flap_close` | Missing. 80–180 ms light hinge ticks. | `EnvironmentMonitor._deploy`/`_stow`; shorter/lighter than the whole console. |
| [ ] | `ui_open`, `ui_close` | Missing dedicated generic panel cues; some UI borrows hover/click. 60–150 ms swish. | `InfoShower._show_info`/`_close`, pause/options/confirm/ship select/codex transitions, `RegionAlert._unfold`/`_fold`. Only actual opening/closing, not content refresh. Shared pair suffices. |
| [ ] | `ui_confirm`, `ui_cancel` | Replace generic placement click where useful. Two short complementary blips. | Successful menu choice / explicit cancellation; global Button already emits click, so replace it or choose one owner. Existing hover sound can stay. |
| [ ] | `target_select` | Target arrows use placement/hover cues; no dedicated acquisition. Quiet two-tone scan. | `TargetingComputer._after_retarget(previous)` on actual target change; avoid automatic refresh chatter. |
| [ ] | `comms_open`, `comms_close` | Missing dedicated transmission framing; text blips already exist. Radio chirp / squelch. | `EnemyDialogueManager._unfold`/`_stow`; at transmission open/end, not each typed character. Can reuse UI panel pair initially. |
| [ ] | `glass_tinkle`, `glass_crack` | Replace synthesized placeholders if desired. Small arcade glass cascade / sharp escalating crack. | Existing resources already wired: `CockpitGlassShards` once per spill, `CockpitDamageSite.flare_back` during death. Preserve pitch escalation and restrained levels. |
| [ ] | `cockpit_rupture`, `player_explosion` | Replace borrowed enemy pre-death / explosion layers if desired. Straining digital chassis / large ship breakup. | `CockpitDestruction._rupture`/`_break_apart`; preserve existing klaxon and final-hit timing. |
| [ ] | `kill_confirm` | Optional extra weight: **kill is not silent**. A compact low thump only if the existing pre-death feels insufficient. | `Enemy._play_kill_confirm` at hitstop; `_on_death` already plays `enemy_pre_death`, wreck fragments play explosion. Replace/enhance that layer before adding a third full boom. |
| [ ] | `fate_pulse`, `fate_consume` | Cutscene borrows die thunk/explosion. Pulsing corruption / engulfing digital distortion. | `OpeningCutscene._fate_pulse` / `_consumed`; can reuse `hazard_fate` first. |
| [ ] | `engine_fail`, `rcs_burst` | Cutscene engine failure borrows pre-death; small thruster bursts lack dedicated cue. Broken power chirp / tiny jet puffs. | `OpeningCutscene._engines_out`, `_rcs_burst`; jump sequence shares the P1 travel files. |
| [ ] | `status_clear` | Optional. Tiny reverse shimmer for active cleansing. | Successful `CLEAR_STATUS` / `TRANSFER_STATUSES` in Heat Sink and Countermeasures. Natural end-of-turn decay stays quiet; transfer can reuse `energy_transfer`. |

Individual weapon signatures from the original file are all **P3**: valve hiss,
torch jet, chaff pop, concussion ring, pendulum clunk, magnetic snap, feedback
screech, fuse burn, heavy inertia rumble, lone-wolf overdrive, lucky-seven ding,
pair-lock clunk, ratchet tightening, boomerang throw/return, reactor meltdown,
wobbly shield, and toll ding. Use the matching base resource in the index below
and the original table's effect slot if making any of these. They are alternate
textures for the shared bank, not extra mandatory layers on top of every shot.

Ambient cockpit hum, environmental beds, and menu-caravan flybys are optional
last-pass experiments, not missing gameplay feedback. If made, deliver short
seamless loops separately (`ambience_cockpit`, `ambience_ion`, `ambience_fate`).
They need loop lifetime/fade handling beyond the current fire-and-forget SFX
player; do not wire an infinite loop through `Events.play_sound`.
Saving can remain silent; the existing save indicator is sufficient.

## Integration rules for the future wiring pass

1. Resources live in `Source/Resources/SoundEffectResources/SoundEffects/`;
   streams live under `Assets/Sounds/`. Existing `SoundEffectResource` exposes
   volume, base pitch, pitch randomness, simultaneous limit and pitch escalation.
   Give each resource a unique `name`: limits are counted by that name.
2. Code hook: preload the resource, then `Events.play_sound.emit(resource)`.
   Chain hook: `AUDIO_VISUAL / PLAY_SOUND` with `sound_resource` assigned.
   Projectile launch goes **before** `LASER`/`MISSILE`/`ION_BOLT`/`ZAP`;
   impact goes **after** that awaited flight and immediately before damage.
3. A semantic action owns its cue. Do not independently attach a relay sound
   to its Feed, ZAP, die landing, and generic spark. Shared hooks should replace
   redundant chain sounds. One blast per action, not one blast per target.
4. The original “nine flourishes” are no longer the whole set:
   `JuiceEvent` also has LASER, MISSILE, ION_BOLT and BIG LASER discharge;
   GRAPPLE resolves separately. They are useful timing hooks, **not** permission
   to sonify every visual. Generic CALLOUT, SPARK_BURST and BUMP can stay silent.
5. If a default flourish bank is wanted: SHOCKWAVE uses a soft impact/lock cue,
   ZAP uses `relay_zap` only for Feed (otherwise the action's own cue), GRID_RIPPLE
   uses `grid_slide`, SCREEN_RIPPLE can use a short optional `screen_whump`,
   STREAM uses transfer/drain, DIE_FLARE uses the relevant die cue. Use
   `screen_whump` (P3) for Chaos Explosion/Emergency Shield/Overdraw/Siege
   only if their existing heavy shot or power cue leaves room. Their custom
   explosion/charge design notes remain in the original document.
6. Deduplicate batch events and cap rapid repeats. Start with little pitch
   randomness and modest limits for frequent cues; preserve upgrade/shop
   escalation. Do not delay gameplay just to finish an audio tail.
7. Charge refresh, save restoration, scene setup/teardown and full-hull/no-op
   effects must not sound like earned gains, unlocks, repairs or status cleanses.
8. Once audio is wired: validate every edited script, run an appropriate
   headless behavior check, and listen to a short activation chain, a busy
   enemy turn, travel, and player death. Static inspection cannot settle mix,
   masking or fatigue. Release any runtime started for these checks.

## Content placement index

The tables below index **all current base tile resources and enemy actions**.
“Current” is the direct SFX resource reference in the authored `.tres`, not
every systemic sound that can be heard during its effect. `—` means no direct
reference. Upgrades use the same sound family; exceptions are listed separately.
All paths are relative to the repository root. The older document's per-tile
sound sketches remain optional P3 variants: e.g. ratchet, lucky-seven chime,
magnetic snap, valve hiss, chaff pop, feedback screech, lone-wolf howl. Make a
variant only when the shared cue below doesn't give that tile enough identity.

### Tiles

Base folder: `Source/Content/Tiles/TileResources/`. The base filename below
also identifies its `_plus.tres` upgrade where one exists. All activatable
tiles also use shared activation/refusal hooks; passive/reactive tiles use
proc feedback. Cues below are additional semantic identities.

| Tile | Resource | Current direct SFX | Shared cue(s) to use |
|---|---|---|---|
| Ablative Charge | [ablative_charge.tres](Source/Content/Tiles/TileResources/ablative_charge.tres) | `dice_cannon` | shot_heavy |
| Afterburner Relay | [afterburner_relay.tres](Source/Content/Tiles/TileResources/afterburner_relay.tres) | `dice_cannon` | relay_zap + relay_zap |
| Afterimage | [afterimage.tres](Source/Content/Tiles/TileResources/afterimage.tres) | `player_shield` | shield_gain |
| Amplifier | [amplifier.tres](Source/Content/Tiles/TileResources/amplifier.tres) | — | amplifier_gain |
| Apex Cannon | [apex_cannon.tres](Source/Content/Tiles/TileResources/apex_cannon.tres) | `dice_cannon` | shot_light |
| Arc Tap | [arc_tap.tres](Source/Content/Tiles/TileResources/arc_tap.tres) | `dice_cannon` | shot_energy |
| Ballast Tanks | [ballast_tanks.tres](Source/Content/Tiles/TileResources/ballast_tanks.tres) | `player_shield` | shield_gain + relay_zap |
| Beam Splitter | [beam_splitter.tres](Source/Content/Tiles/TileResources/beam_splitter.tres) | — | hologram_spawn + relay_zap |
| Blood Valve | [blood_valve.tres](Source/Content/Tiles/TileResources/blood_valve.tres) | — | hologram_spawn (hull cost retains existing hit) |
| Blowtorch | [blowtorch.tres](Source/Content/Tiles/TileResources/blowtorch.tres) | `dice_cannon` | burn_apply |
| Booster Stage | [booster_stage.tres](Source/Content/Tiles/TileResources/booster_stage.tres) | — | amplifier_gain |
| Bootstrap Injector | [bootstrap_injector.tres](Source/Content/Tiles/TileResources/bootstrap_injector.tres) | — | hologram_spawn |
| Bounty Scanner | [bounty_scanner.tres](Source/Content/Tiles/TileResources/bounty_scanner.tres) | `dice_cannon` | shop_buy (bounty payout) / shot_light |
| Broadside | [broadside.tres](Source/Content/Tiles/TileResources/broadside.tres) | `dice_cannon` | shot_flak |
| Brownout Plating | [brownout_plating.tres](Source/Content/Tiles/TileResources/brownout_plating.tres) | — | shield_gain |
| Bump | [bump.tres](Source/Content/Tiles/TileResources/bump.tres) | `bump` | die_value_up |
| Capacitor Bank | [capacitor_bank.tres](Source/Content/Tiles/TileResources/capacitor_bank.tres) | `player_shield` | countdown_tick / countdown_ready / shield_gain |
| Chaff Pod | [chaff_pod.tres](Source/Content/Tiles/TileResources/chaff_pod.tres) | `error` | jammer_pulse |
| Chain Cannon | [chain_cannon.tres](Source/Content/Tiles/TileResources/chain_cannon.tres) | `dice_cannon` | shot_light |
| Chaos Explosion | [chaos_explosion.tres](Source/Content/Tiles/TileResources/chaos_explosion.tres) | — | shot_heavy (optional chaos-blast variant) |
| Cinder Turbine | [cinder_turbine.tres](Source/Content/Tiles/TileResources/cinder_turbine.tres) | `dice_cannon` | engine_gain |
| Concussion Round | [concussion_round.tres](Source/Content/Tiles/TileResources/concussion_round.tres) | `dice_cannon` | shot_heavy |
| Countdown Cannon | [countdown_cannon.tres](Source/Content/Tiles/TileResources/countdown_cannon.tres) | `dice_cannon` | shot_heavy / countdown_tick / countdown_ready |
| Counter-Battery | [counter_battery.tres](Source/Content/Tiles/TileResources/counter_battery.tres) | `tractor_lock` | lock_apply |
| Countermeasures | [countermeasures.tres](Source/Content/Tiles/TileResources/countermeasures.tres) | `dice_cannon` | vent_burst |
| Crescendo Cannon | [crescendo_cannon.tres](Source/Content/Tiles/TileResources/crescendo_cannon.tres) | `dice_cannon` | shot_light |
| Crossed Wires | [crossed_wires.tres](Source/Content/Tiles/TileResources/crossed_wires.tres) | `dice_reroll_blip` | scrambled_apply |
| Crosslink | [crosslink.tres](Source/Content/Tiles/TileResources/crosslink.tres) | `bump` | die_value_up + relay_zap |
| Cryo Lance | [cryo_lance.tres](Source/Content/Tiles/TileResources/cryo_lance.tres) | `glass_tinkle` | ion_freeze |
| Dice Cannon | [damage.tres](Source/Content/Tiles/TileResources/damage.tres) | `dice_cannon` | Keep existing dice_cannon |
| Dampener | [dampener.tres](Source/Content/Tiles/TileResources/dampener.tres) | `error` | weakened_apply / weakened_trigger |
| Dead Man's Switch | [dead_mans_switch.tres](Source/Content/Tiles/TileResources/dead_mans_switch.tres) | — | death_save |
| Deadweight Drive | [deadweight_drive.tres](Source/Content/Tiles/TileResources/deadweight_drive.tres) | `dice_cannon` | shot_heavy |
| Debt Collector | [debt_collector.tres](Source/Content/Tiles/TileResources/debt_collector.tres) | `dice_cannon` | shop_buy (bounty payout) / shot_light |
| Deflector Array | [deflector_array.tres](Source/Content/Tiles/TileResources/deflector_array.tres) | `player_shield` | shield_gain |
| Die Splitter | [die_splitter.tres](Source/Content/Tiles/TileResources/die_splitter.tres) | `dice_reroll_blip` | die_split |
| Discharge Plate | [discharge_plate.tres](Source/Content/Tiles/TileResources/discharge_plate.tres) | `dice_cannon` | shield_spend / shot_energy |
| Doubler | [doubler.tres](Source/Content/Tiles/TileResources/doubler.tres) | `bump` | die_value_up |
| Echo Relay | [echo_relay.tres](Source/Content/Tiles/TileResources/echo_relay.tres) | `dice_reroll_blip` | echo_arm + relay_zap |
| Emergency Shield | [emergency_shield.tres](Source/Content/Tiles/TileResources/emergency_shield.tres) | — | shot_heavy / tile_burnout / shield_gain / hull_repair |
| Emergency Transfer | [engines_to_shields.tres](Source/Content/Tiles/TileResources/engines_to_shields.tres) | — | energy_transfer |
| Fabricator | [fabricator.tres](Source/Content/Tiles/TileResources/fabricator.tres) | — | hologram_spawn / countdown_tick |
| Feedback Cowl | [feedback_cowl.tres](Source/Content/Tiles/TileResources/feedback_cowl.tres) | `dice_cannon` | shot_energy |
| Feint Cannon | [feint_cannon.tres](Source/Content/Tiles/TileResources/feint_cannon.tres) | `dice_cannon` | shot_light |
| Filter Gate | [filter_gate.tres](Source/Content/Tiles/TileResources/filter_gate.tres) | `dice_cannon` | lock_apply / relay_zap (pass vs filter) |
| Flak Cannon | [flak_cannon.tres](Source/Content/Tiles/TileResources/flak_cannon.tres) | `dice_cannon` | shot_flak |
| Flare Burst | [flare_burst.tres](Source/Content/Tiles/TileResources/flare_burst.tres) | `tile_dropped` | exposed_apply |
| Flashpoint | [flashpoint.tres](Source/Content/Tiles/TileResources/flashpoint.tres) | `dice_cannon` | burn_apply |
| Flywheel | [flywheel.tres](Source/Content/Tiles/TileResources/flywheel.tres) | `bump` | die_value_up |
| Fortress Protocol | [fortress_protocol.tres](Source/Content/Tiles/TileResources/fortress_protocol.tres) | `player_shield` | shield_gain |
| Fume Vent | [fume_vent.tres](Source/Content/Tiles/TileResources/fume_vent.tres) | — | vent_burst |
| Fuse Cutter | [fuse_cutter.tres](Source/Content/Tiles/TileResources/fuse_cutter.tres) | — | countdown_tick |
| Fuse Payload | [fuse_payload.tres](Source/Content/Tiles/TileResources/fuse_payload.tres) | `dice_cannon` | burn_apply / countdown_tick |
| Gearbox | [gearbox.tres](Source/Content/Tiles/TileResources/gearbox.tres) | `tractor_lock` | carousel_step (hold/rewind variants) |
| Governor Coil | [governor_coil.tres](Source/Content/Tiles/TileResources/governor_coil.tres) | — | engine_spend |
| Grounding Rod | [grounding_rod.tres](Source/Content/Tiles/TileResources/grounding_rod.tres) | `dice_cannon` | shot_energy + die_value_down |
| Grudge Cannon | [grudge_cannon.tres](Source/Content/Tiles/TileResources/grudge_cannon.tres) | `dice_cannon` | shot_heavy |
| Heat Sink | [heat_sink.tres](Source/Content/Tiles/TileResources/heat_sink.tres) | `player_shield` | vent_burst |
| Hex Coil | [hex_coil.tres](Source/Content/Tiles/TileResources/hex_coil.tres) | — | shot_energy |
| Holding Bay | [holding_bay.tres](Source/Content/Tiles/TileResources/holding_bay.tres) | `tractor_lock` | die_hold / die_release |
| Holo-Duplicator | [holographic_duplicator.tres](Source/Content/Tiles/TileResources/holographic_duplicator.tres) | — | hologram_spawn |
| Incendiary Round | [incendiary_round.tres](Source/Content/Tiles/TileResources/incendiary_round.tres) | `dice_cannon` | burn_apply |
| Inertial Feedback | [inertial_feedback.tres](Source/Content/Tiles/TileResources/inertial_feedback.tres) | `dice_cannon` | shot_energy |
| Interdiction Net | [interdiction_net.tres](Source/Content/Tiles/TileResources/interdiction_net.tres) | — | jammer_pulse |
| Inverter | [inverter.tres](Source/Content/Tiles/TileResources/inverter.tres) | `dice_reroll_blip` | die_value_swap |
| Juke Thrusters | [juke_thrusters.tres](Source/Content/Tiles/TileResources/juke_thrusters.tres) | `bump` | evasion_miss (actual dodge; activation can reuse engine_gain) |
| Keel Plating | [keel_plating.tres](Source/Content/Tiles/TileResources/keel_plating.tres) | `player_shield` | shield_gain |
| Leech Relay | [leech_relay.tres](Source/Content/Tiles/TileResources/leech_relay.tres) | `dice_cannon` | uses_refill + energy_transfer |
| Leeching Shot | [leeching_shot.tres](Source/Content/Tiles/TileResources/leeching_shot.tres) | `dice_cannon` | energy_transfer |
| Lone Wolf Lance | [lone_wolf_lance.tres](Source/Content/Tiles/TileResources/lone_wolf_lance.tres) | `dice_cannon` | shot_energy |
| Lucky Seven | [lucky_seven.tres](Source/Content/Tiles/TileResources/lucky_seven.tres) | `dice_cannon` | die_hold / die_release |
| Napalm Vent | [napalm_vent.tres](Source/Content/Tiles/TileResources/napalm_vent.tres) | — | vent_burst |
| Nudge Down | [nudge_down.tres](Source/Content/Tiles/TileResources/nudge_down.tres) | `bump` | die_value_down |
| Opening Salvo | [opening_salvo.tres](Source/Content/Tiles/TileResources/opening_salvo.tres) | `dice_reroll_blip` | echo_arm |
| Overclock Coil | [overclock_coil.tres](Source/Content/Tiles/TileResources/overclock_coil.tres) | `dice_cannon` | shot_energy |
| Overdraw Coil | [overdraw_coil.tres](Source/Content/Tiles/TileResources/overdraw_coil.tres) | `dice_cannon` | energy_transfer / shot_heavy |
| Overpressure Lance | [overpressure_lance.tres](Source/Content/Tiles/TileResources/overpressure_lance.tres) | `dice_cannon` | shot_heavy |
| Overshield Relay | [overshield_relay.tres](Source/Content/Tiles/TileResources/overshield_relay.tres) | `player_shield` | shield_gain + relay_zap |
| Pair Lock | [pair_lock.tres](Source/Content/Tiles/TileResources/pair_lock.tres) | `dice_cannon` | die_hold / die_release |
| Parity Junction | [parity_junction.tres](Source/Content/Tiles/TileResources/parity_junction.tres) | `dice_cannon` | die_value_swap |
| Phantom Squadron | [phantom_squadron.tres](Source/Content/Tiles/TileResources/phantom_squadron.tres) | — | hologram_spawn |
| Phase Cloak | [phase_cloak.tres](Source/Content/Tiles/TileResources/phase_cloak.tres) | `player_shield` | phased_apply / phased_miss |
| Pilot Light | [pilot_light.tres](Source/Content/Tiles/TileResources/pilot_light.tres) | — | hologram_spawn |
| Polarizer | [polarizer.tres](Source/Content/Tiles/TileResources/polarizer.tres) | `dice_reroll_blip` | die_value_swap |
| Preflight Interlock | [preflight_interlock.tres](Source/Content/Tiles/TileResources/preflight_interlock.tres) | `dice_cannon` | shot_heavy (optional checklist prefix) |
| Pulse Repeater | [pulse_repeater.tres](Source/Content/Tiles/TileResources/pulse_repeater.tres) | `dice_cannon` | shot_light / countdown_tick / countdown_ready |
| Ram Scoop | [ram_scoop.tres](Source/Content/Tiles/TileResources/ram_scoop.tres) | — | engine_gain |
| Ratchet Cannon | [ratchet_cannon.tres](Source/Content/Tiles/TileResources/ratchet_cannon.tres) | `dice_cannon` | shot_light |
| Receiver Dish | [receiver_dish.tres](Source/Content/Tiles/TileResources/receiver_dish.tres) | `dice_cannon` | relay_zap (Fed branch) / shot_light |
| Redline Governor | [redline_governor.tres](Source/Content/Tiles/TileResources/redline_governor.tres) | — | redline_strain |
| Regenerative Brake | [regenerative_brake.tres](Source/Content/Tiles/TileResources/regenerative_brake.tres) | — | engine_gain |
| Relay Terminal | [relay_terminal.tres](Source/Content/Tiles/TileResources/relay_terminal.tres) | `dice_cannon` | shot_energy |
| Reloader | [reloader.tres](Source/Content/Tiles/TileResources/reloader.tres) | — | uses_refill |
| Repo Beam | [repo_beam.tres](Source/Content/Tiles/TileResources/repo_beam.tres) | `tractor_lock` | energy_transfer / die_seize |
| Repulsor Field | [repulsor_field.tres](Source/Content/Tiles/TileResources/repulsor_field.tres) | `dice_cannon` | shot_energy |
| Re-Roll | [reroll.tres](Source/Content/Tiles/TileResources/reroll.tres) | — | die_rattle (or existing dice_reroll_blip) |
| Runaway Reactor | [runaway_reactor.tres](Source/Content/Tiles/TileResources/runaway_reactor.tres) | `dice_cannon` | redline_strain |
| Sabotage Charge | [sabotage_charge.tres](Source/Content/Tiles/TileResources/sabotage_charge.tres) | `error` | jammer_pulse |
| Scatter Router | [scatter_router.tres](Source/Content/Tiles/TileResources/scatter_router.tres) | `dice_cannon` | relay_zap |
| Sensor Spike | [sensor_spike.tres](Source/Content/Tiles/TileResources/sensor_spike.tres) | `tile_dropped` | exposed_apply |
| Shield Burst | [shield.tres](Source/Content/Tiles/TileResources/shield.tres) | `player_shield` | shield_gain |
| Shield Attractor | [shield_attractor.tres](Source/Content/Tiles/TileResources/shield_attractor.tres) | `player_shield` | shield_gain + grid_slide |
| Shield Siphon | [shield_siphon.tres](Source/Content/Tiles/TileResources/shield_siphon.tres) | `player_shield` | energy_transfer + shield_gain |
| Signal Relay | [signal_relay.tres](Source/Content/Tiles/TileResources/signal_relay.tres) | `dice_cannon` | relay_zap |
| Skeleton Crew | [skeleton_crew.tres](Source/Content/Tiles/TileResources/skeleton_crew.tres) | `player_shield` | shield_gain |
| Slingshot | [slingshot.tres](Source/Content/Tiles/TileResources/slingshot.tres) | `dice_cannon` | shot_heavy |
| Slipstream Vane | [slipstream_vane.tres](Source/Content/Tiles/TileResources/slipstream_vane.tres) | — | engine_gain |
| Solar Sail | [solar_sail.tres](Source/Content/Tiles/TileResources/solar_sail.tres) | `player_shield` | shield_gain |
| Solar Shroud | [solar_shroud.tres](Source/Content/Tiles/TileResources/solar_shroud.tres) | `player_shield` | shield_gain |
| Spark Gap | [spark_gap.tres](Source/Content/Tiles/TileResources/spark_gap.tres) | — | shot_energy |
| Spiked Hull | [spiked_hull.tres](Source/Content/Tiles/TileResources/spiked_hull.tres) | `dice_cannon` | shot_light (optional metallic spike variant) |
| Spite Coil | [spite_coil.tres](Source/Content/Tiles/TileResources/spite_coil.tres) | `dice_cannon` | shot_energy |
| Spotter Drone | [spotter_drone.tres](Source/Content/Tiles/TileResources/spotter_drone.tres) | — | exposed_apply |
| Static Bloom | [static_bloom.tres](Source/Content/Tiles/TileResources/static_bloom.tres) | — | scrambled_apply |
| Status Catalyst | [status_catalyst.tres](Source/Content/Tiles/TileResources/status_catalyst.tres) | `tractor_lock` | energy_transfer |
| Sunlance | [sunlance.tres](Source/Content/Tiles/TileResources/sunlance.tres) | `dice_cannon` | shot_energy + burn_apply on Boost |
| Suppression Pulse | [suppression_pulse.tres](Source/Content/Tiles/TileResources/suppression_pulse.tres) | `tile_dropped` | weakened_apply / weakened_trigger |
| Surge Relay | [surge_relay.tres](Source/Content/Tiles/TileResources/surge_relay.tres) | `dice_reroll_blip` | die_rattle (or existing dice_reroll_blip) |
| Swarm Battery | [swarm_battery.tres](Source/Content/Tiles/TileResources/swarm_battery.tres) | `dice_cannon` | shot_light |
| Sweeping Battery | [sweeping_battery.tres](Source/Content/Tiles/TileResources/sweeping_battery.tres) | `dice_cannon` | shot_energy |
| Tactical Boomerang | [tactical_boomerang.tres](Source/Content/Tiles/TileResources/tactical_boomerang.tres) | `dice_cannon` | grid_slide |
| Target Painter | [target_painter.tres](Source/Content/Tiles/TileResources/target_painter.tres) | `tile_dropped` | exposed_apply |
| Time Bomb | [time_bomb.tres](Source/Content/Tiles/TileResources/time_bomb.tres) | `tractor_lock`, `dice_cannon` | bomb_arm / bomb_tick / shot_heavy |
| Toll Relay | [toll_relay.tres](Source/Content/Tiles/TileResources/toll_relay.tres) | — | shop_buy (toll chirp) |
| Turncoat Cannon | [turncoat_cannon.tres](Source/Content/Tiles/TileResources/turncoat_cannon.tres) | `dice_cannon` | shot_light / scrambled_trigger |
| Twin Barrel | [twin_barrel.tres](Source/Content/Tiles/TileResources/twin_barrel.tres) | `dice_cannon` | die_hold / die_release |
| Unstable Shield Array | [unstable_shield_array.tres](Source/Content/Tiles/TileResources/unstable_shield_array.tres) | `player_shield` | shield_gain |
| Value Exchange | [value_exchange.tres](Source/Content/Tiles/TileResources/value_exchange.tres) | — | die_value_swap |
| Value Sorter | [value_sorter.tres](Source/Content/Tiles/TileResources/value_sorter.tres) | `dice_cannon` | die_value_swap |
| War Footing | [war_footing.tres](Source/Content/Tiles/TileResources/war_footing.tres) | — | amplifier_gain |
| Welder | [welder.tres](Source/Content/Tiles/TileResources/welder.tres) | `dice_reroll_blip` | die_merge |

### Upgrade direct-reference exceptions

These currently differ from their base; use the same proposed family rather
than creating separate “plus” recordings. A missing direct reference does not
mean its systemic feedback is missing.

| Upgrade | Current direct SFX | Base direct SFX |
|---|---|---|
| None | Same direct SFX as base | — |

### Enemy actions

Folder: `Source/Content/Enemies/EnemyActions/EnemyActionResources/`.

| Resource | Current direct SFX | Cue and chain slot |
|---|---|---|
| [aegis_ally.tres](Source/Content/Enemies/EnemyActions/EnemyActionResources/aegis_ally.tres) | `player_shield` | energy_transfer → shield_gain; before SHIELD |
| [attack_player.tres](Source/Content/Enemies/EnemyActions/EnemyActionResources/attack_player.tres) | `dice_cannon` | enemy_shot; before projectile/instant DAMAGE |
| [charge_weapon.tres](Source/Content/Enemies/EnemyActions/EnemyActionResources/charge_weapon.tres) | `player_shield` | enemy_charge; before KEEP_DIE_WITH_ACTOR |
| [do_nothing.tres](Source/Content/Enemies/EnemyActions/EnemyActionResources/do_nothing.tres) | `error` | enemy_fizzle; wasted-action beat |
| [flee.tres](Source/Content/Enemies/EnemyActions/EnemyActionResources/flee.tres) | — | ship_flee; before FLEE |
| [getaway.tres](Source/Content/Enemies/EnemyActions/EnemyActionResources/getaway.tres) | `die_dread_thunk` | ship_flee + dice_lost; before ESCAPE_WITH_DICE, once |
| [grid_quake.tres](Source/Content/Enemies/EnemyActions/EnemyActionResources/grid_quake.tres) | `tile_dropped` | grid_slide; before PUSH_TARGETED_TILES |
| [holo_loader.tres](Source/Content/Enemies/EnemyActions/EnemyActionResources/holo_loader.tres) | — | hologram_spawn; SPAWN_HOLOGRAM_FOR_ALLY |
| [incendiary_shot.tres](Source/Content/Enemies/EnemyActions/EnemyActionResources/incendiary_shot.tres) | `dice_cannon` | incendiary_launch; before MISSILE, burn_apply on hit |
| [ion_shot.tres](Source/Content/Enemies/EnemyActions/EnemyActionResources/ion_shot.tres) | `dice_cannon` | ion_shot; before ION_BOLT |
| [jamming_pulse.tres](Source/Content/Enemies/EnemyActions/EnemyActionResources/jamming_pulse.tres) | — | jammer_pulse; before ZAP, jammed_apply on hit |
| [launch_interceptor.tres](Source/Content/Enemies/EnemyActions/EnemyActionResources/launch_interceptor.tres) | `bump` | ship_launch; before LAUNCH_SHIP |
| [lockout_grid_pos.tres](Source/Content/Enemies/EnemyActions/EnemyActionResources/lockout_grid_pos.tres) | — | lock_apply; LOCKOUT_TILE visual contact |
| [purge_vents.tres](Source/Content/Enemies/EnemyActions/EnemyActionResources/purge_vents.tres) | — | vent_burst; before STREAM |
| [raid.tres](Source/Content/Enemies/EnemyActions/EnemyActionResources/raid.tres) | `dice_cannon` | enemy_shot; before projectile/instant DAMAGE |
| [relay.tres](Source/Content/Enemies/EnemyActions/EnemyActionResources/relay.tres) | — | ally_feed; before FEED_ALLY |
| [repair_ally.tres](Source/Content/Enemies/EnemyActions/EnemyActionResources/repair_ally.tres) | `player_shield` | hull_repair; actual HEAL |
| [scrambler.tres](Source/Content/Enemies/EnemyActions/EnemyActionResources/scrambler.tres) | — | scrambler_bolt; before ZAP, scrambled_apply on hit |
| [seize.tres](Source/Content/Enemies/EnemyActions/EnemyActionResources/seize.tres) | `tractor_lock` | die_seize at GRAPPLE clamp; thief_snicker after STOLEN |
| [shield_self.tres](Source/Content/Enemies/EnemyActions/EnemyActionResources/shield_self.tres) | `player_shield` | shield_gain; actual SHIELD |
| [siege_shot.tres](Source/Content/Enemies/EnemyActions/EnemyActionResources/siege_shot.tres) | `dice_cannon` | enemy_charge at wind-up → shot_heavy at discharge |
| [siphon_engine.tres](Source/Content/Enemies/EnemyActions/EnemyActionResources/siphon_engine.tres) | `dice_reroll_blip` | engine_drain; CHANGE_ENGINE_CHARGE theft |
| [target_lock.tres](Source/Content/Enemies/EnemyActions/EnemyActionResources/target_lock.tres) | — | target_lock before LASER; exposed_apply on hit |

## Hook file lookup

These links locate the systemic hooks named above; method names refer to the
current source, not proposed new APIs. Chain-only effects use their named effect
slot in the linked tile/action resource.

- [steal_money_event](Source/Behavior/Effects/EffectEvents/AttributeChange/steal_money_event.gd)
- [juice_event](Source/Behavior/Effects/EffectEvents/AudioVisual/juice_event.gd)
- [spawn_holographic_die_event](Source/Behavior/Effects/EffectEvents/DiceControl/spawn_holographic_die_event.gd)
- [tile_activation_event](Source/Behavior/Effects/EffectEvents/TileControl/tile_activation_event.gd)
- [delayed_payload](Source/Behavior/Modifiers/DelayedEffects/delayed_payload.gd)
- [held_die_delay](Source/Behavior/Modifiers/DelayedEffects/held_die_delay.gd)
- [engine_death_save_modifier](Source/Behavior/Modifiers/EngineDeathSaveModifier/engine_death_save_modifier.gd)
- [evasion_modifier](Source/Behavior/Modifiers/EvasionModifier/evasion_modifier.gd)
- [phased_status](Source/Behavior/Modifiers/Statuses/phased_status.gd)
- [scrambled_status](Source/Behavior/Modifiers/Statuses/scrambled_status.gd)
- [status_modifier](Source/Behavior/Modifiers/Statuses/status_modifier.gd)
- [enemy](Source/Content/Enemies/enemy.gd)
- [carousel_behavior](Source/Content/Ships/Carousel/carousel_behavior.gd)
- [sail_catch_event](Source/Content/Ships/Outrigger/sail_catch_event.gd)
- [tile](Source/Content/Tiles/tile.gd)
- [tile_upgrade_look](Source/Content/Tiles/tile_upgrade_look.gd)
- [tile_use_lights](Source/Content/Tiles/tile_use_lights.gd)
- [opening_cutscene](Source/Scenes/Cutscenes/opening_cutscene.gd)
- [health_bar_controller](Source/Systems/Components/HealthBarController/health_bar_controller.gd)
- [dice](Source/Systems/Game/Dice/dice.gd)
- [enemy_dialogue_manager](Source/Systems/Game/EnemyDialogueManager/enemy_dialogue_manager.gd)
- [engine_charger](Source/Systems/Game/EngineCharger/engine_charger.gd)
- [jump_gate](Source/Systems/Game/JumpGate/jump_gate.gd)
- [jump_manager](Source/Systems/Game/JumpManager/jump_manager.gd)
- [map](Source/Systems/Game/Map/map.gd)
- [money_particle](Source/Systems/Game/MoneyParticles/money_particle.gd)
- [environment_monitor](Source/Systems/Game/OverheadConsole/EnvironmentMonitor/environment_monitor.gd)
- [region_alert](Source/Systems/Game/OverheadConsole/EnvironmentMonitor/region_alert.gd)
- [overhead_console](Source/Systems/Game/OverheadConsole/overhead_console.gd)
- [player](Source/Systems/Game/Player/player.gd)
- [repair_station](Source/Systems/Game/RepairStation/repair_station.gd)
- [reward](Source/Systems/Game/RewardManager/reward.gd)
- [shop](Source/Systems/Game/Shop/shop.gd)
- [targeting_computer](Source/Systems/Game/TargetingComputer/targeting_computer.gd)
- [background_manager](Source/Systems/Graphics/BackgroundManager/background_manager.gd)
- [cockpit_damage_site](Source/Systems/Graphics/Cockpit/CockpitDamage/cockpit_damage_site.gd)
- [cockpit_destruction](Source/Systems/Graphics/Cockpit/CockpitDamage/cockpit_destruction.gd)
- [hazard_thematic_vfx](Source/Systems/Graphics/HazardVFX/hazard_thematic_vfx.gd)
- [hazard_warning](Source/Systems/Graphics/HazardWarning/hazard_warning.gd)
- [game_over](Source/Systems/UI/GameOver/game_over.gd)
- [info_shower](Source/Systems/UI/InfoShower/info_shower.gd)
- [tile_unlock_popup](Source/Systems/UI/TileUnlockPopup/tile_unlock_popup.gd)

## Existing SFX inventory — keep or replace deliberately

All 23 current SFX resources are listed here. A resource is not necessarily a
unique recording: `upgrade_trigger` and `shop_stock_pop` share the reroll WAV;
`die_dead_click` shares the placement WAV. Extra sfxr/backup WAVs exist on disk
but are not evidence of a wired gameplay cue and have not been auditioned.

| Resource | Current stream | Production note |
|---|---|---|
| [alarm_klaxon](Source/Resources/SoundEffectResources/SoundEffects/alarm_klaxon.tres) | [alarm_klaxon.wav](Assets/Sounds/UI/Alarm/alarm_klaxon.wav) | Keep; reuse where it fits. |
| [bump](Source/Resources/SoundEffectResources/SoundEffects/bump.tres) | [PowerUp4.wav](Assets/Sounds/Tiles/Bump/PowerUp4.wav) | Already exists; usable for small value/power cues before making variants. |
| [dice_cannon](Source/Resources/SoundEffectResources/SoundEffects/dice_cannon.tres) | [DiceCannon.wav](Assets/Sounds/Tiles/DiceCannon/DiceCannon.wav) | Keep; reuse where it fits. |
| [dice_reroll_blip](Source/Resources/SoundEffectResources/SoundEffects/dice_reroll_blip.tres) | [Reroll.wav](Assets/Sounds/Dice/Reroll/Reroll.wav) | Keep; reuse where it fits. |
| [die_dead_click](Source/Resources/SoundEffectResources/SoundEffects/die_dead_click.tres) | [tile_dropped_click.wav](Assets/Sounds/Tiles/tile_dropped_click.wav) | Keep initially; placement sample with different playback settings. |
| [die_dread_thunk](Source/Resources/SoundEffectResources/SoundEffects/die_dread_thunk.tres) | [die_dread_thunk.wav](Assets/Sounds/Enemies/TractorBeam/die_dread_thunk.wav) | Keep; reuse where it fits. |
| [enemy_death_explosion](Source/Resources/SoundEffectResources/SoundEffects/enemy_death_explosion.tres) | [EnemyDeathExplosion.wav](Assets/Sounds/Enemies/EnemyDeathExplosion/EnemyDeathExplosion.wav) | Keep; reuse where it fits. |
| [enemy_health_hit](Source/Resources/SoundEffectResources/SoundEffects/enemy_health_hit.tres) | [EnemyHealthHit.wav](Assets/Sounds/Enemies/EnemyHealthHit/EnemyHealthHit.wav) | Keep; reuse where it fits. |
| [enemy_pre_death](Source/Resources/SoundEffectResources/SoundEffects/enemy_pre_death.tres) | [enemy_pre_death.wav](Assets/Sounds/Enemies/EnemyDeathExplosion/enemy_pre_death.wav) | Already covers the opening of ship death; kill is not silent. |
| [enemy_shields_hit](Source/Resources/SoundEffectResources/SoundEffects/enemy_shields_hit.tres) | [EnemyShieldsHit.wav](Assets/Sounds/Enemies/EnemyShieldsHit/EnemyShieldsHit.wav) | Keep; reuse where it fits. |
| [error](Source/Resources/SoundEffectResources/SoundEffects/error.tres) | [Error.wav](Assets/Sounds/UI/Error/Error.wav) | Keep; reuse where it fits. |
| [glass_crack](Source/Resources/SoundEffectResources/SoundEffects/glass_crack.tres) | [glass_crack.wav](Assets/Sounds/Player/Glass/glass_crack.wav) | Optional replacement of synthesized placeholder. |
| [glass_tinkle](Source/Resources/SoundEffectResources/SoundEffects/glass_tinkle.tres) | [glass_tinkle.wav](Assets/Sounds/Player/Glass/glass_tinkle.wav) | Optional replacement of synthesized placeholder. |
| [hover_thump](Source/Resources/SoundEffectResources/SoundEffects/hover_thump.tres) | [HoverThump.wav](Assets/Sounds/UI/HoverThump/HoverThump.wav) | Keep; reuse where it fits. |
| [money_tick](Source/Resources/SoundEffectResources/SoundEffects/money_tick.tres) | [MoneyTick.wav](Assets/Sounds/UI/MoneyTick/MoneyTick.wav) | Keep; reuse where it fits. |
| [player_health_hit](Source/Resources/SoundEffectResources/SoundEffects/player_health_hit.tres) | [PlayerHealthHit.wav](Assets/Sounds/Player/PlayerHealthHit/PlayerHealthHit.wav) | Keep; reuse where it fits. |
| [player_shield](Source/Resources/SoundEffectResources/SoundEffects/player_shield.tres) | [Shield.wav](Assets/Sounds/Tiles/Shield/Shield.wav) | Keep; reuse where it fits. |
| [player_shields_hit](Source/Resources/SoundEffectResources/SoundEffects/player_shields_hit.tres) | [PlayerShieldsHit.wav](Assets/Sounds/Player/PlayerShieldsHit/PlayerShieldsHit.wav) | Keep; reuse where it fits. |
| [shop_stock_pop](Source/Resources/SoundEffectResources/SoundEffects/shop_stock_pop.tres) | [Reroll.wav](Assets/Sounds/Dice/Reroll/Reroll.wav) | Replace; escalating reroll placeholder. |
| [text_blip](Source/Resources/SoundEffectResources/SoundEffects/text_blip.tres) | [TextBlip_new.wav](Assets/Sounds/UI/TextBlip_new/TextBlip_new.wav) | Keep; reuse where it fits. |
| [tile_dropped](Source/Resources/SoundEffectResources/SoundEffects/tile_dropped.tres) | [tile_dropped_click.wav](Assets/Sounds/Tiles/tile_dropped_click.wav) | Keep; reuse where it fits. |
| [tractor_lock](Source/Resources/SoundEffectResources/SoundEffects/tractor_lock.tres) | [tractor_lock.wav](Assets/Sounds/Enemies/TractorBeam/tractor_lock.wav) | Keep; reuse where it fits. |
| [upgrade_trigger](Source/Resources/SoundEffectResources/SoundEffects/upgrade_trigger.tres) | [Reroll.wav](Assets/Sounds/Dice/Reroll/Reroll.wav) | Replace first; pitched reroll placeholder. |
