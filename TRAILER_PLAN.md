# Die Fighter — Trailer Plan

Rewritten 2026-11-05 against the game as it is today (code, not older docs).
The capture toolkit described in §3 is built; §2 is the edit to shoot for,
§4 is what's still worth building, and §5 is the shot list with its status.

**The one thing to optimise for:** a stranger understands "**you arm your
enemy with the dice you spend**" within ~8 seconds, without text. Every
other beat earns its place by showing what that rule leads to.

---

## 1. What the trailer has to sell

| Pillar | The claim | What proves it on screen |
|---|---|---|
| **Hook** | Every die you spend is handed to your enemy and loads its guns. | `thesis`: a 6 fires a big hit, then the tractor beam drags that same 6 onto the enemy's 6-slot, which lights up. `tithe` shows it reversed: a Seize claw snatches a die. |
| **Depth** | One die can run a whole machine. | `machine`: a 6 Fed through Signal Relay > Polarizer > Toll Relay > Relay Terminal, yellow arcs between tiles and rings that grow each hop, Spark Gap zapping, then the Crescendo Cannon cashing in the busy turn. |
| **Fun** | It's loud, fast and juicy. | Overkill slow-mo, kill cams, hazards (solar flare, ion storm, asteroids), Carrier launching interceptors, Holo-Duplicator dice, the Arc Dynamo overloading. |
| **Story** | A lone ship outrunning Fate through a fleet in flight, picking sides as it goes. | The opening cutscene (Fate eating the galaxy), pirates on a civilian ("Please help us!"), a Fate Wisp ("...your dice... were our bones..."), three faction warlords guarding the gates. |

The world in one line: *Fate, a black hole, is eating the galaxy; everyone
is fleeing in one vast fleet, the Long Retreat, and you have to fight your
way up it: the Tail, the Belly, the Spine.*

---

## 2. Beat sheet

Cut to `Assets/Music/Trailer/Trailer_1/Trailer_1_updated.wav` (96 s). Its
shape, measured from the file: a quiet intro (0–9 s), the first drop at
**0:09**, an accent at **0:27**, the loudest stretch 0:43–1:03, a
**breakdown 1:04–1:16**, a rebuild to a spike at **1:24**, and the outro
from 1:32. Beats sit on those marks.

| Time | Music | Beat | Shots (§5) | What the viewer learns |
|---|---|---|---|---|
| 0:00–0:09 | intro | **Cold open (story)**: Fate swallowing wreckage, your ship clawing away, a pursuer lost to the hole, the jump, the ambush. | Opening cutscene (New Game, see §3.6) | Something enormous is eating everything; you're running. |
| 0:09–0:16 | **drop** | **Thesis (hook)**: the 6 is dragged onto the Dice Cannon on the drop, hits, then is dragged across to the enemy's big gun. Hold on the lit slot. | `thesis` | Spend a die → it arms the enemy. |
| 0:16–0:20 | | **Reversed hook**: the Seize claw rips a die out of reach. | `tithe` (retake seeds until it Seizes) | Dice are the whole economy, and they fight over them. |
| 0:20–0:27 | build | **Depth**: one die through the machine. Cut the Crescendo hit onto the **0:27** accent. | `machine` | One die, many effects; there's a build to make. |
| 0:27–0:43 | main | **Fun montage**, 1–2 s per cut, a new sky every cut: overkill slow-mo; ion storm lightning; the solar flare stripping every shield; the Carrier launching; Holo-Duplicator ghosts; the Dynamo's breaker blowing. | `overkill`, `ion_storm`, `boss_warden` (flare), `machine` (carrier), `sandbox`, `dynamo` | It's spectacular, and every fight looks different. |
| 0:43–1:03 | peak | **Escalation: the warlords.** Three boss cards slammed in a row (SECTOR WARDEN / ARC DYNAMO / THE BASTION), each answered by its fight's best second. | `boss_warden`, `dynamo`, `bastion` | There's a run with bosses, and it gets bigger. |
| 1:04–1:16 | **breakdown** | **Story and stakes.** Pirates on a civilian ("Please help us!" / "Our kill. Back off!"), the Fate Wisp's line, then the hull drops into critical: klaxon, red heartbeat, the music muffles (duck the trailer music the same way). | `civilian`, `signal`, `stakes` | Choices, a strange world, and real danger. |
| 1:16–1:31 | rebuild | **Climax.** The Bastion coming apart in chained blasts; the Fate Maw under the black hole; the last overkill; the **jump's white frame on the 1:24 spike**, cut to black. | `bastion`, `fate`, `overkill`, `jump` | You can win, and Fate is waiting. |
| 1:32–1:36 | outro | **Button**: logo, "Wishlist on Steam". | Logo sting (not built, §4.1) | Where to get it. |

**Text.** Optional, three supers at most, white on black between cuts:
"SPEND DICE." (before the thesis) / "ARM YOUR ENEMY." (after it) /
"OUTRUN FATE." (before the climax). The thesis shot must still read
without them.

**Shorter cuts.** A 30 s cut is 0:09–0:27 (hook + depth), three montage
cuts and the button. A 15 s vertical (Shorts/TikTok) is the thesis alone,
then the machine, from `--vertical` takes (§3.5).

---

## 3. Capture toolkit (built)

Everything lives in `Source/Debug/Trailer/` and the `TrailerDirector`
autoload (`Source/Systems/Autoloads/trailer_director.gd`). Dev builds only.

### 3.1 Trailer mode

**F1** (or `trailer on` in the dev console) hides the debug and bookkeeping
overlays (FPS counter, "Saving...", the dev console and Scenario Lab) and
turns the hotkeys on. The game UI stays: the cockpit *is* the HUD.

| Key | Does |
|---|---|
| F1 | trailer mode on/off (always works) |
| F2 | hide/show the cursor |
| F3 | speed 1× → 0.5× → 0.25× (slow-mo captured in-engine, full frame rate) |
| F4 | freeze frame (again to resume) |
| F5 | retake the current shot from the top |
| F6 | drop a marker in the take log |
| 1 | `overkill` the targeted ship |
| 2 | `kill` the targeted ship |
| 3 | `shield_break` (gain shields, then a hit breaks them) |
| 4 | `critical` (hit down to critical hull) |
| 5 | `hazard` strikes now (needs a hazard sky, in a fight) |
| 6 | `jump` one place forward |
| 7 | `death` (the cockpit comes apart, game over) |
| 8 | `red_alert` |
| 9 | `glitch` burst |
| 0 | `reroll` the hand, die by die |

`boss_card` (replay the boss intro) and `hit <n>` are in the console:
`fx` lists them all. Every set piece runs through the game's own events, so
it looks and sounds exactly like the real thing.

### 3.2 Shots

A shot (`Source/Debug/Trailer/Shots/<id>.tres`, a `TrailerShotResource`) sets
a run up exactly: ship, scenario, run seed, sector, sky (and so its hazard
or rule), tiles by cell, dice, hull, money, charge, the faces of the first
rolls, god mode, clean HUD, cursor, music on/off, game speed. The same shot
comes out the same on every take.

- `shot` lists them, `shot <id>` plays one, `shot restart` (or F5) retakes it,
  `shot stop` leaves it, and `shot check` says if any no longer load (a
  renamed tile or scenario).
- New shot: duplicate one in the FileSystem dock and edit it in the
  inspector. `notes` says what it's for.
- A shot runs on its own save file; it never touches the player's run.

### 3.3 Beats

A shot's `beats` play once it's up, one command a line (full list in
`Source/Debug/Trailer/trailer_script.gd`). Dice are carried by a puppet of
the game's own cursor (it glides to the die, grabs it, arcs it over the
grid, lets go), and dropped through the same code a real drag ends in.

```
ready                 # until the player could act (hand dealt, nothing resolving)
wait 0.8
mark drag             # note this frame in the take log
drag f6 1,1 0.9       # the first die showing a 6, to the tile at cell 1,1, in 0.9 s
ready
foe_hull 2            # stage the targeted ship for a finisher
fx overkill
time 0.25             # slow-mo from here
quit                  # end the take (and the recording)
```

Try a line live with `beat <command>` in the console (`beat drag 0 2,1`).

### 3.4 Recording: Movie Maker

```bash
GODOT=/path/to/Godot_4.7.1 tools/trailer_capture.sh thesis machine
```

Godot's Movie Maker renders every frame at exactly 1/60 s of game time,
however slowly the machine draws it, so takes are frame-perfect, 1920×1080,
with the game's audio, and identical every time. Each shot opens in a
window, plays its beats and quits. `--all` records every shot; `--png` writes
a lossless PNG sequence plus WAV for the final cut (the default AVI is
MJPEG at 0.95 quality, fine for the offline edit); `--fps 30` halves the
size. Shots with no beats (`civilian`, `pact`, `sandbox`) stay up for you to
play, until you close the window or `--max-seconds` (default 120).

Each take has a marker log beside it (`<shot>_<time>.txt`): the frame and
second of every `mark` beat and F6 press, so the edit can find the moments.

Takes go to `captures/<timestamp>/` (git-ignored, Godot-ignored).

### 3.5 Vertical (Shorts / TikTok)

`--vertical` also cuts a 1080×1920 MP4 from each take: a 608×1080 crop centred
on the tile grid (`--crop-x` moves it), scaled up nearest-neighbour. The grid
reads well at that size; the enemies above it are cropped tight, so a
vertical cut favours the thesis and machine shots.

### 3.6 What isn't a shot

- **The opening cutscene** isn't a shot (it plays before any save exists),
  but `tools/trailer_capture.sh cold_open` records it, straight into the
  ambush fight, until `--max-seconds` or you close the window.
- **The main menu diorama** (the Caravan streaming past, a Pilgrim heading
  for Fate, now and then a Mayday hooked into the glow): `tools/trailer_capture.sh
  menu --max-seconds 120` for B-roll behind the end card. The Mayday comes
  every 50–100 s, so give it two minutes.

### 3.7 Tips

- Keep the real mouse outside the window during a scripted take: its
  hover still shows tooltips where it rests.
- Music is muted in most shots so a take's audio is the game's sound
  effects alone, ready to lay under the trailer track. `music on` (or the
  shot's `mute_music`) brings it back.
- If a seed doesn't give you the moment (a Seize, a particular intent),
  change `run_seed` and retake: `ready`/`drag` beats adapt to any hand that
  has the faces they ask for, and `forced_rolls` pins the faces.

---

## 4. What's still worth building

Checked against the code on 2026-11-05. Ranked by how much the trailer
needs it.

1. **A logo and end card.** There's no logo: the title is "DIE FIGHTER" set
   in Jersey 25 (`Source/Systems/UI/MainMenu/main_menu.tscn`), and
   `Assets/SteamCapsules` holds only an icon. The button beat needs a 2 s
   sting: a die rolling to a stop on a glitching face, resolving into the
   wordmark. Art first; then it can be a scene the end card and the main
   menu share.
2. **Sector names on the jump.** Gate jumps show "SECTOR 2 / OF 3" only
   (`JumpGate.show_sector_title`). Adding "THE BELLY" under it (Tail, Belly,
   Spine are already the sectors' layers, `ScenarioResource.sectors`) gives
   the story beat its geography for one label.
3. **A visible boss phase change.** No boss changes phase on screen. The
   Sector Warden (3 pools) and Arc Dynamo (2 pools) already switch action
   pools at hull thresholds (`EnemyResource.pool_selection`), silently. Give
   that switch a beat: glitch burst, a callout ("ENRAGED"), a sprite tint or
   swap, and a music layer (`MusicDirector.set_layer_enabled`). That's the
   escalation shot the old plan wanted, built on logic that exists.
4. **Boss music, or a boss layer.** ROADMAP: there's none. The gate fights
   are the trailer's peak section; in-game they currently play the run's
   ordinary track.
5. **Two sounds.** A heartbeat for critical hull (the visual half is built:
   `HullAlarm`), and a tile-activation sound for the combo pitch ladder
   (`SoundEffectResource.enable_pitch_escalation` is ready). Both are the
   stakes and depth beats' audio.
6. **An animated run tally.** The victory/game-over screen is one static
   line (`RunStats.get_summary_text`). Stats ticking up with the pitch ladder
   would give the climax a payoff shot.
7. **Fate glitch language.** Still open (ROADMAP). The finale's Fate shots
   would read as horror rather than as another sky with it: corrupted tiles
   jittering, static bleeding into the frame on Fate nodes.
8. **Hand dice at low frame rates.** `Draggable` follows with
   `lerp(..., follow_strength * delta)`, which diverges on frames over
   ~100 ms. Movie Maker never hits it (fixed 1/60 s), but a slow laptop doing
   a live demo would.

Hero moments from the old plan, as they stand:

| Enemy | Moment | Status |
|---|---|---|
| Tithe Collector, Cutpurse, Gaff | Seize claw snatches a die | ✅ built (`juice_grapple.gd`) |
| Carrier | Launches interceptors | ✅ built |
| Arc Dynamo, Zealot | Breaker overloads, vents dice back | ✅ built |
| The Bastion | Parts break off, hull blows in 6 chained blasts | ✅ built |
| Siege Mortar | Visible charge-up, screen-filling shell | ❌ loads silently for a turn |
| Ion Lance | Beam sweeping the grid, tiles knocked offline | ❌ |
| Bounty Runner | Countdown, then jumps away | ⚠ ships jump away in faction colour; no countdown |
| Field Tender | Heal beam; panics when its ally dies | ⚠ co-op arcs exist; no panic |

The Outrigger and Carousel are "coming soon". A shot can fly them
(`ship_id`), and the Carousel's turning ring would make a striking tease,
but only once they're finished.

---

## 5. Shot list

All in `Source/Debug/Trailer/Shots/`. "Recorded" means a Movie Maker take was
made and checked frame by frame on 2026-11-05.

| Shot | Beat | Scenario | Status |
|---|---|---|---|
| `thesis` | Hook | COMBAT_attacker | ✅ recorded: drag, hit (16→10), the 6 beamed onto the 6-slot |
| `machine` | Depth | COMBAT_carrier, sector 2 | see below |
| `tithe` | Hook reversed | COMBAT_tithe_collector | see below |
| `overkill` | Fun | COMBAT_wolfpack | see below |
| `ion_storm` | Fun | ELITE_lance_squadron | see below |
| `boss_warden` | Escalation | GATE_sector_warden | see below |
| `dynamo` | Escalation | GATE_arc_dynamo | see below |
| `bastion` | Escalation / climax | GATE_bastion, sector 3 | see below |
| `civilian` | Story | EVENT_pirate_attacking_civilian | by hand |
| `signal` | Story | EVENT_signal | see below |
| `pact` | Story | EVENT_pact | by hand |
| `stakes` | Stakes | COMBAT_wolfpack | see below |
| `fate` | Climax | FATE_maw | see below |
| `jump` | Transition | COMBAT_cannon_drone | see below |
| `sandbox` | B-roll | COMBAT_wolfpack, Phantom Fleet build | by hand |

### Capture session, in order

1. `tools/trailer_capture.sh --all` once, and watch the takes: it's the
   fastest way to see which seeds give good moments.
2. Retake the hook (`thesis`, `tithe`) and depth (`machine`) until they're
   perfect; they carry the trailer.
3. Play `sandbox`, `civilian` and `pact` by hand under Movie Maker for the
   montage, with the hotkeys and F3 slow-mo; F6 marks the keepers.
4. Record the cold open and the menu (§3.6).
5. Final takes with `--png` for the cuts that made the edit.
