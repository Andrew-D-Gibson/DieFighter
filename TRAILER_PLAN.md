# Die Fighter — Trailer Build-Out Brainstorm

## Context

You want a trailer that sells Die Fighter, and you're asking what to build so there's footage worth cutting. This builds on Brainstorming.md §8 (juice) and §9 (trailer moments) and PLAN_FOR_FUN Phase 3. It's based on what's in the repo today, not on what those docs predicted.

**Already in the game (trailer-usable today):** the cold-open ambush with klaxon and red alert, handover timing weighted by die value, shield-break cyan flash, glitch shader, vignette, camera `Shakeable`, the JumpTransition, the opening and entering-cockpit cutscenes, 4 hazards (Solar Flare, Ion Storm, Asteroid Field, Fate Rift), 9 backgrounds (black holes, pulsar field, derelict boneyard, cryo belt, Fate infection…), a boss that changes phase, the handover tractor beam, 20 Feed/machine tiles that pass one die through several tiles, and a finished track at `Assets/Music/Trailer/Trailer_1_updated.wav`.

**Status (2026-09-30):** the juice verbs have landed. `AudioVisualSubtype` now has `HITSTOP`, `SLOW_MO`, `ZOOM_PUNCH`, `FLASH_TARGET`, `SCREEN_SHAKE`, `VIGNETTE_PULSE` and `GLITCH_BURST`, and every Dice Cannon-style hit uses flash + hitstop + zoom. Still missing: damage numbers (`SPAWN_DAMAGE_NUMBER`), chain arcs between tiles, and staged deaths.

**The one thing to optimize for:** a stranger must understand "**you arm your enemy with the dice you spend**" within ~8 seconds and without text. Everything below is ranked by how much it helps that shot and the 3–4 shots after it.

---

## 1. Trailer shape (≈60–75s, cut to Trailer_1)

| Beat | Time | Shot | What it needs |
|---|---|---|---|
| Hook | 0–5s | Cold open: klaxon, red alert, cockpit already under fire | ✅ exists. Add a zoom punch and a hard cut on the first hit |
| Thesis | 5–15s | A die rolls a 6 → dragged onto a cannon → huge hit → **the same 6 is pulled across to the enemy and lands on its big-gun slot, and the guns light up** | Tractor-beam handover and slot reaction (§3A) |
| Depth | 15–25s | One die sets off a relay chain: arcs jump from tile to tile, pitch climbs, 4–6 effects fire | Chain arcs and pitch ladder (§3B) |
| Variety | 25–40s | Rapid montage, 1–2s per shot: every enemy archetype, each hazard hitting, a new background each cut | Signature enemy moments (§4) and hazard set pieces (§6) |
| Stakes | 40–50s | Low HP: sparks, red cockpit, heartbeat; a narrow survival | Cockpit-as-body (§3E) |
| Escalation | 50–62s | Fate corruption bleeds into the UI → boss phase change → hyperspace jump | Fate glitch language (§3F), boss set piece (§4) |
| Button | 62–70s | Glitching-die logo → "Wishlist on Steam" | Logo sting and end card (§7) |

---

## 2. Tier 1: build these first (they carry the trailer)

1. ✅ **Juice verbs as effect subtypes** (Brainstorming §8.0) — built, except `SPAWN_DAMAGE_NUMBER`: `HITSTOP`, `SLOW_MO`, `ZOOM_PUNCH`, `FLASH_TARGET`, `SCREEN_SHAKE`, `VIGNETTE_PULSE`, `SPAWN_DAMAGE_NUMBER`, `GLITCH_BURST`. Every shot below uses them, and once added they can be set per tile or enemy in the inspector.
   - Files: `Source/Behavior/Effects/effect_enums.gd`, `effect_catalog.gd`, and a new handler under `Source/Behavior/Effects/EffectHandlers/`
   - Reuse: the camera `Shakeable`, `Vignette`, `GlitchController` and the enemy shader's `flash_amount`, which the opening cutscene already tweens
2. ✅ **Tractor-beam handover and intent-slot reaction** (`TractorBeam`, with lock and dread-thunk sounds). This is the thesis shot. The beam locks on, the die resists for a moment, then leaves fast with a trail. The slot it lands on slams, and the enemy's weapon glows if the slot is an attack.
3. **Staged deaths.** 3–5 small explosions, then a hull flash, 250ms of slow-mo and a big boom, then debris and money arcing to the counter. The kill that ends a fight also gets a zoom punch toward the dying ship.
4. **Trailer capture mode** (§8). Without it you'll spend hours reshooting.

---

## 3. Visual & feel improvements

**A. Handover (thesis):** described in Tier 1. Also add a low "dread" thunk when a die lands on a dangerous slot and a flat click when it lands on a dead one. The trailer's sound mix will carry this.

**B. Chain choreography:** energy arcs from tile to tile with an 80ms gap per hop, plus the combo pitch ladder (`SFXPlayer.get_pitch_escalation()` already exists). Pair this with the Feed tiles, which pass one die through several tiles in a turn. A strong single shot: Polarizer → Toll Relay → Toll Relay → Relay Terminal with a Spark Gap underneath, where one die makes four activations, a spark, and a 12-damage finish. `TileGrid.activations_this_turn` and `Events.tile_activated` are the hooks for the pitch ladder and the per-hop arcs.

**C. Impact trio:** target flash + hitstop + shake, scaled by damage. Add floating damage numbers in 5–7px pixel digits. Overkill (2× remaining HP or more) automatically escalates to a bigger boom and slow-mo. That's your "number go up" close-up.

**D. The roll:** staggered cascade (40–60ms per die), squash on landing, a clatter per die, and a glint on 6s. It gives the turn opening real texture.

**E. Cockpit as body:** hull hits make sparks fall from the cockpit frame. Below 30% HP: red emergency light at the screen edges, an alarm pulse, and a low-pass filter plus heartbeat on the music bus. This is the whole stakes beat.

**F. Fate glitch language:** reserve glitch for Fate content only. Fate enemies get chromatic shimmer, Fate map nodes bleed static into the UI frame, and corrupted tiles jitter frame by frame. This is your thumbnail identity: pixel-art cosmic horror in a dice game.

**G. Hyperspace jump set piece:** dice rattle during wind-up, star streaks, one hard white frame, and the new background blooming in. It's a natural transition for the trailer edit, so shoot several.

**H. Ambient life:** tiles bob gently at offset phases, idle dice fidget, nebulae drift. B-roll behind the title cards should never look paused.

**I. Hull vs shield vocabulary:** shields get a hex ripple and a blue *tsss*; hull gets debris, fire and an orange flash. Viewers read what happened without any UI.

---

## 4. Enemies & signature moments

Give each existing enemy **one 1.5-second hero moment** for the variety montage. That's cheaper than new enemies and cuts better.

| Enemy | Hero moment to build |
|---|---|
| Siege Mortar | Visible charge-up across turns (barrel glow grows) → screen-filling arcing shell → cockpit hit |
| Ion Lance | Long beam that sweeps the tile grid and knocks tiles offline with sparks |
| Tithe Collector | Pulls a die *out of your hand* (tractor beam in reverse) |
| Field Tender | Heal beam to an ally; you kill the ally and the Tender visibly panics |
| Bounty Runner | Countdown ticks, then it jumps away with a streak if you're too slow |
| Disabler / Defender | Shield bubble snaps over its partner; your shot shatters it |
| Sector Boss | **Phase-change set piece:** armor plates blow off, the sprite swaps, glitch burst, music layer kicks in |

**New enemies worth building for the trailer (pick 1–2):**
- **Mirror / Echo boss** (BRAINSTORMING §7): it uses *your* tile layout against you. That's the "wait, WHAT" beat.
- **Carrier:** launches small drones that each take a die. It fills the screen and shows scale.
- **Fate Leviathan:** a huge, partly off-screen horror whose intents flicker between values. It's a strong closing shot.

---

## 5. Tiles that film well

Tiles that already exist and film well include Chain Cannon, Runaway Reactor, Holographic Duplicator, Tactical Boomerang, Chaos Explosion, Signal Relay, Arc Tap, and the machine tiles (Beam Splitter splitting a die in two, Scatter Router, Relay Terminal's finish, Crescendo Cannon at the end of a busy turn). Each needs its own custom animation chain once the Tier 1 verbs exist:
- **Tactical Boomerang:** the projectile arcs out and back and hits twice.
- **Runaway Reactor:** glows hotter each use, then a meltdown flash.
- **Holographic Duplicator:** a ghost copy of the die splits off with hologram particles (`holographic_dice_particles.tscn` exists).
- **Chain Cannon:** fires in a burst with rising pitch.

New tiles, only if they film well:
- **Orbital Strike:** a 1-turn delay, then a beam from off-screen top.
- **Black Hole Generator:** pulls enemies' dice toward the center and ties into the existing black hole shader.
- **Overload Core:** consumes all adjacent dice for one huge hit. It's the ideal overkill slow-mo shot.

---

## 6. Scenarios built as trailer set pieces

Build these as real content, since they double as good fights:
- **Asteroid Field fight in the Derelict Boneyard:** debris crossing the foreground parallax, plus a rock that smashes a tile.
- **Solar Flare in the Pulsar Field:** a white-out sweep wipes every shield, followed by a shield-shatter chorus.
- **Ion Storm in the Blue Nebula:** lightning flashes light up the ships from behind (background flash verb).
- **Fate Rift finale:** the UI corrupts, the map bleeds, and the Fate Leviathan emerges.
- **Pirates attacking a civilian:** a readable story shot in which you pick a side.
- **Wolfpack:** 4–5 ships on screen at once, the biggest visual chaos shot.

---

## 7. Cutscenes & menus

- **Opening cutscene:** add a cockpit POV reveal. The camera pushes through the canopy and the dice spill into the tray. It works as a trailer opener and in-game.
- **Boss intro card:** freeze frame, portrait slide-in, name stamp ("THE TOLLKEEPER"), a glitch tear, then the fight. It's a classic trailer beat and cheap.
- **Sector title cards:** "SECTOR 2: THE CRYO BELT" wipe in during the jump arrival.
- **Victory and game-over:** a slow-mo final kill, then run stats ticking up with the pitch ladder.
- **Main menu:** a living diorama behind the title (ships dogfighting in the background, an idle die spinning). Make the logo a die with a glitching face, and use it as the trailer's closing shot.
- **Logo sting:** a 2s animated die roll ending on the logo, reused as the trailer's end card.

---

## 8. Trailer tooling (what makes the shots achievable)

- **Trailer mode flag** (in the options, or a DevConsole command): hides debug UI, the cursor, the tutorial and the save indicator. Toggles for a clean HUD versus the full HUD.
- **Scripted shots:** use `RNGManager` seeding and the DevConsole to load a named scenario with a fixed seed, forced dice (the `forced_*` statics already exist), and a chosen background and hazard. The same shot comes out the same every take.
- **Time-scale control:** a hotkey for 0.5× and 0.25× to capture slow-mo in-engine at full frame rate.
- **Hotkeys that fire effects on demand:** shield break, boss phase, jump, death sequence. Use them for B-roll takes.
- **Resolution:** the viewport is 1920×1080. Capture at native resolution with integer scaling, and also shoot a vertical 1080×1920 crop of the tile grid for Shorts/TikTok.

---

## 9. Recommended order

1. Juice effect subtypes (§2.1) → impact trio + damage numbers → staged deaths
2. Tractor-beam handover + slot reaction (thesis shot)
3. Trailer capture mode + scripted shot loader
4. Chain arcs + pitch ladder; roll cascade
5. Boss phase set piece + boss intro card; hyperspace jump polish
6. Fate glitch language + one Fate finale scenario
7. Hero moments for each enemy; 2–3 set-piece scenarios
8. Main menu diorama, logo sting, sector title cards
9. Stretch: Mirror boss or Fate Leviathan

## 10. Next step once approved

Save this brainstorm to the repo as `TRAILER_PLAN.md`, alongside BRAINSTORMING.md. Then pick the first item (probably the juice subtypes) and plan its implementation separately. That includes the AGENTS.md checks: validate every script, and verify live with `game_eval` and `game_screenshot`.
