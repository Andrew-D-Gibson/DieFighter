# Die Fighter — Dev Log

Newest entries at the top.

---

## 2026-10-23 — Opening cutscene pass and music

- **A pursuit before the black hole.** The cutscene now opens tight on the
  player's ship, jinking out of two dice fired from off screen, then pulls
  back to show both Attackers on its tail, and on again until Fate comes
  into view with a pulse. Fate's own lightning waits for that reveal. The
  rest of the story (one Attacker taken, the jump, the ambush) follows as
  before, 2.6 s later.
- **Longer fade in.** The picture holds black for a second and fades over
  three, so the music's 4 s fade has started before anything is seen.
- **Push in on the player.** After the player's ship turns to face the
  Survivor, the shot closes in on it under the lock-on brackets before
  cutting to the fight, so it is clear which ship is yours.
- **Shots without mixels.** `view_zoom` / `view_center` on
  `opening_cutscene.gd` are keyed like the rest of the timeline. They scale
  the finished 320x180 picture and the starfield together rather than
  zooming a camera inside the SubViewport, so art pixels stay even (at worst
  one screen pixel apart mid-zoom), and every held zoom (3, 1.5, 2.5) is a
  whole number of screen pixels per art pixel.
- **The enemy spools up too.** The Survivor charges its jump the way the
  player does, hull flickering and motes drawn in, in its own red.
- **Hyperspace edges.** The thin streakless bands down both sides of the
  screen came from the clear border round each streak frame, stretched
  across the screen; the frames are cropped now. The screen-filling layers
  (hyperspace, flash, fade, alert) also reach 8 px past the frame, so a
  camera shake can't show their edges.
- **Trailer once.** Tracks can be marked `repeats`. The start theme is, so
  after the cutscene's Trailer 1 the playlist comes back to the start theme
  and holds it rather than alternating. The menu now loops the start theme
  too.

---

## 2026-10-23 — Tutorial layout and dev text boxes

- **Cards left, enemy right.** The tutorial's cards moved to the left of the
  screen and the opening raider now waits off to the right, with the enemy
  highlights mirrored to match.
- **Systems you can see.** Cards that say "system" now show it: the
  read-a-system card shows the three starting systems (Dice Cannon, Bump,
  Shield Burst), and the salvage card shows the Deflector Array. Inline icon
  tokens can now name one frame of a sprite sheet, which Bump needed. Both
  cards were trimmed to stay at three lines.
- **Second fight in the middle.** The tutorial gives the formation its room
  back at the jump, so the ships in the next fight fly straight to the
  centre instead of off to the side and sliding over later.
- **No locked arrows on the map tour.** The jump arrows stay hidden while the
  tutorial explains the map. The right arrow appears with the "drag a die
  onto the arrow" card; the left one comes back when the tutorial ends.
- **Dev text boxes.** The console's command bar and the tile search share one
  `DevTextBox`: the same style, a taller field and an X button to clear it.
  Pressing ` in the tile search now closes the dev tools instead of typing
  a backtick.

---

## 2026-10-21 — Shader planets and stars

- **Planets instead of stickers.** The backgrounds' set pieces are now
  drawn live by `pixel_planet.gdshader`, the main menu's planet shader.
  Eleven `CelestialBody` designs turn slowly, with drifting clouds and
  atmospheres: ice, ocean, lava, dead and barren worlds, a banded gas
  giant and a blue storm giant, two moons, a blue star and a red dwarf. They
  replace the ice shards (cryo belt) and the derelict hulk (boneyard), and
  give the nebulae, star field, debris field and solar corona a world each.
  Every copy turns to a random face, so a region met twice looks different.
- **The flare star.** Now a shader star too: a boiling surface from
  counter-rotating noise, a corona stepping from orange to deep red, and
  prominences that lick off the limb. When its flare is imminent the
  prominences climb as the star throbs; when it fires, it whites out.
- **Shader fixes.** The shader overwrote `COLOR`, so `modulate` was ignored
  and far copies couldn't be dimmed; it now multiplies the node colour back
  in. Clouds shade toward `shade_colour` instead of black, and a new
  `atmosphere_fades_at_night` lets stars show through a planet's unlit
  atmosphere instead of a dark ring. The main menu planet is unchanged.

---

## 2026-10-21 — Fate's weather

- **Shards Fate is eating.** The fate pieces were loud purple sprites with
  white highlights. They are now quiet indigo obsidian, flat like the
  triangle debris, with black where Fate has bitten in. A shader does the
  rest, in the map icon's corruption language. The void crawls with static,
  a ragged seam chews in from a corner and back, rows tear and colours
  split, and now and then a shard blinks out. The wisp became a spire, and
  a broken die face joins the large pieces.
- **A storm over Fate.** Both Fate backgrounds get sheet lightning, double
  strike bolts and bands of void tearing through the sky. Each flash
  silhouettes the shards and rims them in Fate's purple, and bolts throw a
  faint wash over the whole screen. The storm quickens as the Fate Rift
  readies and breaks into a barrage when it opens.
- **The opening matches.** Its Fate shards are corrupted the same way and
  the storm hangs behind them. Fate's pulses crack arcs across its disk,
  and the surge and the Attacker's death tear the sky.

---

## 2026-10-21 — Palette pass, a new Siege Mortar, and a wreck site

- **One palette.** Every PNG the game loads now uses only the 33 colours in
  `aseprite_palette_final.aseprite`, and the matching `.aseprite` sources
  were remapped the same way. 215 textures changed. Most drift came from the
  old palette's navy `#070326` (tiles, dice, cockpit cracks), which became
  the outline navy `#040217`. The rest came from off-palette greys, slate
  blues and soft effect gradients. Colours snap by perceptual distance with
  extra weight on hue, so pale tints keep their colour. A few snap by role
  instead: the engine-charge bar is purple with a white head, and cinders
  ramp into dark red. Tinted white masks are left alone. The Fate pieces
  were redrawn separately.
- **Siege Mortar.** Redrawn from flat blocks into a heavy gun ship with
  engine nacelles, an ammo drum, stabiliser blades and a banded barrel,
  shaded like the rest of the fleet.
- **Ship scrap.** The boneyard was a grid of identical grey capsules. Its
  15 pieces (5 new) now have torn, irregular silhouettes, sizes from bolts
  to hull sections, and paint, glass, rust and hazard stripes. Each piece
  is baked at several angles because in-engine rotation would tilt the
  6x pixels. `PieceVariant` picks one, and the new `random_flip` mirrors it.

---

## 2026-10-21 — Four new combats, four new events

Every enemy already appeared somewhere, but Carrier, Cutpurse and Bounty
Runner had one encounter each, and Venom Raider never fought outside the
pirate-and-civilian event and an elite. The pools are now 17 combats and 9
events.

- **Combats.** Loose Wing (four Interceptors, no carrier), Smash and Grab
  (Carrier screening a Cutpurse), Blockade Runner (Field Tender patching a
  Bounty Runner, which carries the pick as in Bounty Run), Spotter (Ion
  Lance draining the drive while a Siege Mortar loads).
- **Ghost Carrier.** Salvage (UNCOMMON floor) beside a dormant Carrier.
  Taking a tile wakes it 2 times in 3, credits 1 in 3; shooting it always
  does.
- **Black Market.** A Bounty Runner sells one of a three-tile crate on
  credit, then bills 14-22 (shop prices run 10-35). Coming up short, or
  shooting, turns it and its silent Ion Lance escort.
- **Pickpocket.** A Cutpurse lifts 8-14 credits on arrival. Chasing it
  pays 20-32, but it bolts after three rounds with any dice it holds.
- **Mayday.** A Venom Raider at 40% hull, flying as a civilian, begs for
  help beside its salvage. Taking it is a coin flip: grateful, or a decoy
  that turns pirate and repairs 12 hull. Shooting first is a coin flip too:
  the decoy unmasked, or a wronged civilian.

The events' credits paths change state through `STEAL_MONEY` and
`PLAYER_COULDNT_PAY`, as Tollkeeper does. Each branch was driven live,
with scenario seeds varied to reach both sides of each roll. Seed 21 (the
tutorial) keeps its sector shape; only which encounter fills each slot
changed, and the jumps out of the opening fight still reach a shop, the
elite and an event.

---

## 2026-10-21 — Opening cutscene: the escape from Fate

The opening now sets up the first fight. The player's ship claws away from
Fate with two Attackers on its tail. Fate surges and swallows one; the other
is clipped and trails smoke from then on, which is where the ambush
Attacker's missing 35% of hull went. Both jump, the chase carries on through
hyperspace, and they drop out into star_field (the ambush's background). The
Attacker arrives a beat after the player, the alarm sounds, it locks on, and
the moment the player has flipped round to face it the cutscene cuts
straight into the fight. The old cockpit cutscene that sat in between is
gone.

The Attackers drop in from above and below and hold well clear of Fate's
disk, straining against it with sparks spitting from their drives. Only the
surge reaches them: it clips one, and the other's drive dies and Fate reels
it across the disk, smoking, into the core.

- **Two resolutions.** Ships, Fate, debris and effects render in a 320x180
  SubViewport scaled 6x, so nothing rotates or scales into mixels. The
  starfield stays in the 1080p viewport behind it, so it glides and streaks
  smoothly. The container blends premultiplied, or half-faded pixels (nebula,
  smoke, flashes) composite muddy grey, as in `JuicePixelated`.
- **The jump** is the game's, turned horizontal: stars speed up and streak,
  then hyperspace and the game's streak sheet punch in under a flash. Each
  ship also stretches along its heading and leaves a streak, and drops out of
  one. Hyperspace has its own shader, `hyperspace_horizontal.gdshader`:
  `jump_hyperspace` pixelates into screen-sized cells before it scrolls, which
  pinned a cell edge to the middle of the screen as a hard seam. The new one
  scrolls continuously and snaps to the art grid only where it reads.
- **Juice:** speed lines, debris that tumbles at random angles (in unrotated
  holders, so Fate still stretches it along the pull) and spins up near the
  hole, Fate's pulses jolting the debris, muzzle rings, an RCS burst before
  the turn, and `TimeDirector` hitstops on hits, the kill and the punch into
  hyperspace, with a breath of slow motion as the player jumps.
- **Background** borrows rift_space: the black hole, its purple nebula
  (darkened, since the shader stacks it up to 3x and clips to grey-white),
  and fate shards plus scrap, dragged into the hole and stretched as they go.
- **New player ship** (`Assets/Textures/Player/Ship/`), drawn from
  tinyShip12 in the game palette, with cruise, boost and fire frames.
- Timing lives in `cutscene_anim`, so it can be scrubbed and retimed in the
  editor; its method track calls the one-shot effects in
  `opening_cutscene.gd`.

Checked by rendering it frame by frame with `--write-movie`, and live at
full resolution through the hand-off into the ambush. How it plays at speed, with the music, still needs a
watch.

---

## 2026-10-21 — Music: MusicDirector

The game had a `Music` bus and volume slider but no music; `main.tscn`'s
`MusicPlayer` autoplayed an empty stream. A `MusicDirector` autoload now owns
it, built for dynamic music but authored with two songs for now:
GameStartTheme and Trailer 1, alternating forever.

- **Playlists and cues.** A `MusicPlaylistResource` plays back to back,
  wrapping when `loop` is on. Scenes cue a track by id with `play_track()`;
  the playlist then carries on from that track. The menu cues the start
  theme with `restart` (from the top after a run, but not at boot, where it
  only just started). The opening cutscene crossfades to Trailer 1 over 4 s
  from a method key at 0 s, so skipping can't beat it. Continue cues Trailer 1
  itself, since it skips the cutscenes.
- **Decks.** Each playing track gets a new `MusicDeck` (an AudioStreamPlayer)
  that frees itself once faded out, so a cue landing mid-fade adds a third
  deck instead of cutting off an audible tail. The plan said two fixed A/B
  decks; that would have had to cut one.
- **Layers.** A deck plays its track's layers as one `AudioStreamSynchronized`.
  `set_layer_enabled()` tweens `set_sync_stream_volume()`, which 4.7.1 does
  apply to a stream that is already playing: muting the one layer took the
  Music bus peak from -12 dB to -91 dB, and turning it back on restored it.
- **Fades** are equal-power (sine ease in and out: 0.71 on each deck halfway)
  and ignore `Engine.time_scale`, which hitstop sets to 0.
- `GameStartTheme.wav.import` looped (`loop_mode=2`), so it never emitted
  `finished`; now off. A test pins both shipped tracks to not looping.

Checked live from the menu: boot on the start theme, handover at the end of
each song and the wrap back, a crossfade and a second cue mid-fade, the
cutscene fade, Trailer 1 continuing through the cockpit scene into the run
without restarting, back to the menu restarting the start theme, and Continue.
How the fades and handovers actually sound still needs a listen.

Next: stems for a battle theme driven by combat events, combat/explore state
transitions, and transitions that wait for the next bar (tracks already have
`bpm` and `beats_per_bar`, unused so far).

---

## 2026-10-21 — Playtest tweaks, built in parallel

Eighteen tweaks from a playtest list, split into six groups and built at the
same time by separate agents, each in its own git worktree, then merged:
repair stations (F), enemy actions that can't happen and Jammed (C), UI polish
(E), lockouts and rounding (D), targeting (B) and dice handoffs (A). Their
notes follow.

Each group's note mentions one failing test,
`test_tutorial.gd::test_main_scene_plays_every_step_file`. The tutorial
rework's commit had dropped the uid from `map_explanation.tres`'s header while
`main.tscn` still referred to it by uid; restored in 61d41a9. After the
merges the full suite is 605/605. The only conflict was `translations.csv`,
where D and F each appended rows; both kept.

---

## 2026-10-21 — Repair stations: buy hull, sell tiles

Hull was the one thing a run couldn't buy. Two tiles heal and a cleared
gate pays back 12, so attrition, not skill, ended most runs. A **repair
station** is a new map stop under the green "+" icon
(`healing_encounter.png`, map hint "Repair"). A friendly Repair Dock pulls up
and opens a panel beside it, laid out like the shop:

- **REPAIR** (button): pay credits for hull, as often as you can pay and
  the hull has room. It greys out (the purple disabled frame) when the hull
  is full or the next repair is unaffordable. The line above it says
  "+6 HULL" or "HULL FULL", and the price turns red when you're short.
- **SELL** (a slot): drag a tile off your grid and let go over it. While
  you hold a tile, the slot shows what it would fetch, or why it won't sell.
  You can sell several.

Shooting the dock closes the panel and starts a fight, the same as at the
shop. Leave by jumping, like any stop.

**Economy.** Every number is an export on `RepairStation`
(`repair_station.gd` defaults, overridable on `repair_station.tscn`):

| Knob | Value | Why |
|---|---|---|
| `hull_per_repair` | 6 | A sixth of the starting 32. One repair is worth the stop, a full patch-up takes several. A repair that would overfill heals only what's missing, at full price. |
| `base_repair_cost` | 10 | Under the cheapest shop tile (10-20), so a thin wallet can still buy one. One fight's bounty (12-20) buys one or two. |
| `repair_cost_growth` | +5 per repair at that station | 10, 15, 20, 25, 30: 0→30 hull costs 100, so topping off a wreck costs real money and competes with the shop. The next station starts at 10 again. |
| `sell_fraction` | 0.5 of `Shop.base_price(rarity)` | COMMON 7, UNCOMMON 10, RARE 15. Half the average shelf price, so selling and buying back always loses. The price is fixed (the midpoint), not rolled. |
| `min_tiles_kept` | 1 | The last tile can't be sold ("LAST TILE"). |
| `unsellable_tiles` | Engine Charger | It lives off the grid and can't be dragged, so it can't reach the slot anyway. Listed in case that changes. Undraggable tiles are refused too. |
| `repair_stations_per_sector` (GameStateManager) | 1-2 | Shops get 2-3; hull is the scarcer thing to buy. |

Shop prices now come from `Shop.PRICE_RANGES`, and `Shop.base_price()` is
the midpoint. The rolls are unchanged.

**Placement.** Measured over 600 seeds with the real `main.tscn` settings,
there are 1.16 stations a sector on average: none in 10%, one in 64%, two
in 26%. Each station always sits 7-10 stops past the arrival, before the
gate. `place_repair_stations()` runs after the sector is otherwise built.
It swaps out combats or events that sit beyond a die's reach (6) of the
arrival, never shops, elites, the arrival or the gate. It uses its own
generator, seeded from the RUN stream's *state*. Drawing from RUN instead
would have reshuffled every seeded map: the tutorial's seed 21, which
promises a shop beside the opening fight and a plain fight at distances 4,
5 and 6, and every AutoPilot transcript. Now only the replaced slots
differ. Seed 21 changes in exactly one slot (11, Cannon Drone → station).
The 10% of sectors with no station are the ones with nothing replaceable
past a jump. Allowing stations closer to the arrival would mean changing
the tutorial's map.

**What changed.**
- `RepairStation` (`Source/Systems/Game/RepairStation/`), instanced in
  `main.tscn` beside the Shop, and `Globals.repair_station`.
- `ScenarioControlSubtype.OPEN_REPAIR_STATION` / `CLOSE_REPAIR_STATION`
  (appended; handlers, events, catalog rows, pinned in
  `test_effect_catalog.gd`), and `Events.open_repair_station` /
  `close_repair_station`.
- Content: `Scenarios/RepairStation/` (`repair_station.tres`,
  `repair_dock_default.tres` opens the panel, `repair_dock_angry.tres` closes
  it and turns AGGRESSIVE), `EnemyResources/repair_dock.tres`. The dock has
  the shop's table (does nothing, flees, hidden 4-10 shot at dice handed to
  it) and the Field Tender's hull art. It pays 20-30 credits if destroyed.
- `TileGrid`: `tile_lifted` and `tile_dropped_off_grid` signals (a grid tile
  let go off the grid used to just float home), and `remove_tile()`. That
  releases held dice, forgets the cell, drops the tile's engine modifiers
  and frees it.
- Saves: `scenario_progress.repair_station = {repairs}` while open, so a
  Continue keeps the climbing price. Repairs and sales take the same
  mid-scenario checkpoint as a shop purchase (`Events.reward_picked`).
- Localization: `REPAIR_*`, `SELL_*` and `DIALOGUE_REPAIR_*` rows, with all
  seven other columns drafted. `EnemyDialogueManager.show_dialogue()` now
  `tr()`s the line before timing its reveal, so a ship state's `dialogue`
  can be a key. Plain English passes through unchanged. Without this a key
  shorter than its line cut the line off.
- Art: `Assets/Textures/RepairStation/repair_station_background.{aseprite,png}`,
  derived from the shop's tabbed panel with the shelf dividers taken out, a
  REPAIR | SELL divider and a bracketed 26×26 slot.

**AutoPilot.** `AutoPilotMove.Kind` gains `REPAIR` and `SELL` (appended).
Both use the player's own entry points: the button's handler, and a grid
tile's `drag_ended` let go over the slot. The random bot repairs at weight
0.5 and sells at 0.05, enough to exercise the path without stripping its
grid. The heuristic bot never sells. It repairs while its hull share is
under 0.5 + 0.3 × the persona's heal (smart 0.77, turtle 0.89, aggressive
0.68). It values a station stop at 0.5 + 10 × missing-hull share × heal
when it has 10 credits. Visits count `repairs` and `sold`, and replays print
both. No autoplay batch was run (it boots `main.tscn`); worth one before
trusting the balance.

**Testing.** 34 new GUT tests (`test_repair_station.gd`,
`test_auto_pilot_repair_station.gd`). They cover repairs, price growth, the
cap, refusals, sale prices, what can't be sold, selling by drop, the lift
preview, a Continue keeping the price, placement, and the bot's moves and
thresholds. Suite: 537/538. The one failure is the known
`test_tutorial::test_main_scene_plays_every_step_file` (missing uid in
`map_explanation.tres`), already failing on the base commit. A windowed
one-off render of the panel scene (not `main.tscn`) checked the three
states: prompt, a tile held over the slot showing "+15", and full hull
greyed out.

---

## 2026-10-21 — Enemy actions that can't happen, and Jammed

**Why.** Jammed swallowed the next die a ship used, even one that was going
to do nothing anyway, so a jam could be wasted on a Do Nothing face. And a
Repair Beam aimed at a ship that died quietly moved to another ally: the
player had read "Repair Viper" and watched it heal someone else.

**One question.** `EnemyActionResource.get_outcome()` (and the null-safe
`outcome_of()`) asks whether spending a die on an action would change
anything right now:
- `ACTS`: something happens.
- `IDLE`: it was never going to do anything (Do Nothing, an empty slot, a
  chain of only visuals and a hand-off).
- `BLOCKED`: it means to, but nothing it does can happen now. Steps aimed at
  the bound ship (after `TARGET_BOUND_ALLY` / `TARGET_BOUND_HOSTILE_SHIP`,
  plus `FEED_ALLY` and `SPAWN_HOLOGRAM_FOR_ALLY`) can't happen once that ship
  is dead or gone. A heal on an undamaged bound ship can't either, and
  neither can `LAUNCH_SHIP` with the hangar full.

It's read from the chain each time, not cached, because it depends on the
board. A Relay whose ally died still `ACTS`: its own shield goes up and the
Feed hands the die back, as before.

**What changed.**
- Jammed only takes a stack from an `ACTS` action. `IDLE` and `BLOCKED` dice
  pass through and the stacks wait. The keyword now says so.
- Bindings never move. `EnemyTargetBinder.rebind_departed()` is gone, and
  so is its call in `EnemyManager`'s `enemy_left` handler. A slot keeps
  pointing at the ship the player saw it aimed at.
- `EnemyActionEvent.settle_action()` runs just before the pop-up. A
  `BLOCKED` action is swapped for a copy of Do Nothing, as Jammed does, so
  it plays the "..." callout and error buzz and hands the die back. A new
  24×24 "?" (`IntentIndicator/blocked_info.png`, pale die on a dark
  outline) pops up instead of the action's own icon.
- The Carrier's Launch pop-up (`launch_info.png`) used to be the whole
  Interceptor sprite, filling all 24×24. It's now a 13×12 cut-down
  Interceptor with the cyan "+" of its 7×7 intent, the same scale as the
  other icons. The `.aseprite` sources sit beside both PNGs.
- AutoPilot's forecast follows the new Jammed rule: an arriving die is
  swallowed only if its face acts and the stacks outnumber the held dice
  that act.

**Testing.** The new `test/unit/enemies/test_enemy_action_outcome.gd` has 16
tests: every outcome case, the "?" swap, icon sizes, and that `enemy_left`
on a real EnemyManager leaves a binding alone. `test_statuses.gd` checks
that Jammed keeps its stacks through Do Nothing, a blocked Repair Beam and
an empty slot, then spends them on an attack. `test_auto_pilot_forecast.gd`
checks the bot's version of the same rule. The three rebind tests were
removed. Suite: 519 tests, 518 pass. The one failure is
`test_tutorial.gd::test_main_scene_plays_every_step_file`, which already
failed on the base commit (stale `map_explanation.tres` uid in
`main.tscn`). None of this was played live.

---

## 2026-10-20 — UI polish: death blasts on the grid, pause over the glitch, Esc, shields

**Death explosions at 320x180.** The game doesn't render into a 320x180
buffer. The viewport is 1920x1080 (`stretch/mode="viewport"`) and the
`Graphics/Camera2D` zooms 6x, so world art only stays pixel-true at whole
scales and whole-pixel positions, and nothing snaps it there
(`snap_2d_transforms_to_pixel` is off). The death explosions weren't on another
layer. `CockpitDestruction._explosion()` scaled the enemy-death blast by
0.35–1.1 and spun it to any angle, which resampled it into pixels finer than
the art around it, and skewed. Each blast now plays at native size, like an
enemy's, varies only by a quarter turn and a mirror, and is centred with
`pixel_aligned_centre()` so its pixels land on whole world pixels (37px frames
centre on a half pixel). The rupture used to grow its blasts from 0.35 to 0.7
as it built up. They're all full size now, so the rupture fills more of the
screen, sooner.

**The hit glitch no longer warps the pause menu.** `UI/GlitchShader` is a
full-screen `hint_screen_texture` shader on the UI canvas layer (1). The pause
menu was a world node (layer 0, z 25), so it was drawn before the glitch and
warped with everything else. It now sits in its own `PauseLayer` CanvasLayer
(layer 100, `follow_viewport_enabled`, so it still draws through the camera's
6x zoom). That puts it above the glitch and above Juice's ripple and flash
(layer 90), as `juice_screen_ripple.gd` already said would be ideal. Layer 100
would also have covered the custom cursor (`UI/MouseCursor`, layer 1), so the
cursor moves to its own `CursorLayer` (128). It now draws over the ripple too.
`test_screen_layers.gd` reads main.tscn's text and pins this order.

**Esc in the info shower.** Esc used to open the pause menu, which closed the
info on its way up (`close_info`). The info shower now takes the `PauseMenu` action in
`_unhandled_input` while it's visible and marks it handled. `InputManager` (an
autoload) opens the pause menu from `_unhandled_input` too, and autoloads sit
ahead of the game scene under root, so they hear unhandled input after it does.
Esc closes the info the same way a click does, with `info_graphic_closed`, which
the tutorial waits on.

**Shield sprite.** `PlayerHealthBar.shield_frame()`: full from half the hull,
medium from a quarter, low below that (it was full only at max, medium from
half). Zero shields still hides the sprite (`HealthBarController._set_shields`).
Enemies have no equivalent: their `Shields` is a single-texture Sprite2D that's
only shown or hidden.

**Testing.** Headless GUT: 518 tests, 517 pass. The one failure,
`test_tutorial.gd::test_main_scene_plays_every_step_file`, is already there on
the base commit (b4296f6). `map_explanation.tres` has no uid in its header, but
main.tscn refers to it by `uid://cjs5pb8b7yx5b`. New tests:
`test_shield_frame.gd`, `test_info_shower_input.gd` (pushes a real Esc through
the root viewport, with a probe node ahead of the autoloads standing in for
InputManager; it fails without the fix), `test_screen_layers.gd`, and three
pixel-grid tests in `test_cockpit_damage.gd`. Nothing was checked in a live
window. The pause menu's look and clicks on its new layer, the cursor over it,
and how the death sequence reads now all still need an eyeball.

---

## 2026-10-20 — Lockouts explain themselves; half always rounds up

**A locked tile says so.** Clicking a locked-out tile used to show its
ordinary description, so the player had no way to learn why it kept handing
dice back. Its info panel now adds a line, `(locked): dice given to this tile
return to your hand until a (die_2) unlocks it.` (`INFO_TILE_LOCKED`, written
by `LockoutModifier.get_info_text()`, en plus machine drafts with
`_status = machine`). `Locked` is a new keyword (`(locked)`, `(lock)`), so
hovering it pops the full rule up: a 2 unlocks the tile instead of activating
it and goes to a random enemy, the lock lasts until then or until you jump,
and the Engine Charger can't be locked. A lockout has no turn counter (it is
not temporary; only a 2 or the engine shutting down on a jump lifts it), so
there's no countdown to show. A tile locked twice still shows one line. The
Grid Lockout intent ("Lock a grid cell") and Asteroid Impact now read
`(lock) a random tile`, so they get the hover too.

**The Engine Charger can't be locked out.** It's the only way to charge the
drive, so a lock on it could strand the player. `TileResource` has a new
`can_be_locked_out` (on by default, off in `engine_charger.tres`), read
through `Tile.can_be_locked_out()`. `AddLockoutModifierEvent` is the one
door every lockout goes through (enemy action, hazard, anything future), and
it skips such a tile. Random lockouts (`TARGET_RANDOM_TILE`) draw only from
`TileGrid.tile_locations`, and the Engine Charger sits on the main viewer,
never the grid, so they always pick an eligible tile. A test pins that every
grid tile stays lockable. If a grid tile is ever made immune, random
lockouts would need a lockable-only pick, or they'd fizzle on it (and the
zap would still hit it).

**Half of always rounds up.** Deadweight Drive ("half your missing engine
charge") used `MULTIPLY 0.5`, which truncated: 5 missing dealt 2. `MULTIPLY`
now rounds any fraction up, away from zero (`MultiplyAmountHandler.
rounded_product()`), with a small epsilon so a whole product like 10 x 0.3
isn't bumped to 4 by float error. Deadweight Drive is the only authored
content with a fractional multiplier, but every future "half of" gets the
rule for free. The other gameplay halving was the redline bleed,
`over / 2` in integer maths (+3 cost 1 hull); it is now
`Player.redline_hull_cost()`, which rounds up. The redline headroom
(`roundi(max * 0.5)`) already rounded half up.

The audit covered every `/ 2`, `/ 2.0`, `* 0.5`, `>> 1` and "half" in
`.gd`, `.tres` and the CSV. Everything else was layout, tweens, AutoPilot
estimates, juice multipliers (ripple, ship movement) or the shield sprite
threshold, all left alone. No text said "rounded down".

**Tests.** `test_lockout.gd` (the Engine Charger refuses a lock while the
rest of the lockout lands, every grid tile is lockable, the info line, one
line for a double lock, the key resolves, the keyword renders) and
`test_half_rounds_up.gd` (odd, even, zero, negative and float-error products,
Deadweight Drive's own amount steps at 5 missing charge give 3, redline cost
at 0/1/3/5/10, headroom at 21 gives 11). `test_multiply_truncates_toward_zero`
became `test_multiply_rounds_a_fraction_up` (5 x 1.5 = 8). Suite: 516/517;
the one failure, `test_main_scene_plays_every_step_file`, is pre-existing
(`main.tscn` references `map_explanation.tres` by a uid the file's header
doesn't carry).

**Found, then fixed after the merge.** Two lockouts could stack on one tile,
and a 2 then fired both: the die went to a random enemy twice and two
`TileActivationCompleteEvent`s were injected. Random lockouts (Grid Lockout,
Asteroid Impact) now use a new `TARGET_RANDOM_LOCKABLE_TILE`, which draws
only grid tiles that allow a lock and aren't locked already
(`Tile.accepts_lockout()`), and fizzles only when every tile is locked.
`AddLockoutModifierEvent` refuses an already-locked tile as a backstop
(`Tile.is_locked_out()`).

**Panels clear for the death sequence.** The shop and repair panels used to
stay drawn over the player's destruction. On `player_destroyed` they fade out
in 0.15 s of real time (`Utils.fade_out_panel`), clear before the first
blast. The formation keeps its gap, so the shopkeeper doesn't slide to centre
mid-explosion.

---

## 2026-10-20 — Queued dice keep their target; everything follows a sliding ship

**Why.** A die dropped on a busy tile (a chain resolving, the tile's queue
backed up) used to act on whatever was targeted *when it resolved*, so
switching target while it waited quietly redirected it. And when a ship died
and the survivors slid over, three things lagged the slide: a die already in
flight flew to the target's old spot, the targeting reticle vanished for the
slide and reappeared, and a target switch could leave a half-played intent
pulse running on the new ship's icons.

**A die remembers its target.** `Tile._on_die_accepted()` stamps
`Dice.aimed_at` with the ship targeted at drop time.
`TargetingComputer.target_for(die)` answers "who should this die hit": that
ship if it's still in the fight (alive and on the roster), otherwise the
current target, which may be nothing (the effects already handle no target;
`GiveDieToTargetEvent` already re-homes a die whose target is dead). Readers:
`TARGET_WITH_TARGETING_COMPUTER`, a Feed's leftover hand-off
(`PassDieToTileEvent._hand_die_off`), and the `SHIP_TARGETED` /
`TARGETED_SHIP_HAS_SHIELDS` activation checks, so a check and the shot it
gates ask about the same ship. A die fed on through a machine keeps its aim
(it never re-joins a queue), and a hologram from `FEED_HOLOGRAM` inherits the
source tile's die's aim. `DiceQueue.add()` clears the aim, so it lives only
between the drop and the die landing somewhere (a hand, an enemy, a tile
holding it), and a stale aim never follows a die into its next drop. A tile
fired with no die (`ACTIVATE_SELF`, the dev console) or a reactive tile's
`event_responses` chain still uses the current target.

**Following a moving ship.** `AttackTweenEvent` tweens a progress value and
re-reads the target's position every frame (the spring overshoot carries
through it). If the target is freed mid-flight the die finishes at its last
known spot. Held dice and the tractor beam already followed a sliding ship
(`moving_in_world` updates `home_position`), so those were left alone.

**The reticle** is now placed every frame in `TargetingComputer._process()`
from the targeted ship's live position: a 0.3 s cubic glide from wherever it
was, then the same (4, 4) hover on a 1.5 s cycle. `_move_indicator()` does
nothing if the reticle is already on that ship, so the many same-target
redraws (turn start, `enemy_turn_over`) no longer restart the glide. The
glide tween is owned by the computer and killed on every switch; before,
each redraw started a new tree-owned move tween without killing the last.
`EnemyManager._slide_ship_to()` no longer calls
`hide_indicator_while_moving()` / `show_indicator_after_move()`, both gone.

**Icons on a target switch.** `check_target_is_valid()` and
`_target_nothing()` compare old and new targets; on a real change
`_reset_icon_tweens()` kills every intent pulse and puts the icons back to
scale 1. A redraw for the same target lets a running pulse finish. The scan
fill's `await animation_looped` now checks a redraw counter, so a stale scan
can't drop the fill behind the panel after a newer redraw cleared the target.

**Testing.** `test/unit/systems/test_targeting_computer.gd` (17 tests):
aim set on drop and cleared on landing; fallback when the aim died, fled,
was freed, or there's no target at all; the handler and both activation
checks reading the aim; the reticle staying on a ship moved while settled
and while mid-glide; an attack tween landing on a moved ship and on the spot
a freed one left; pulses cut by a switch, not by a same-target redraw. The
old reticle test in `test_departures.gd` went with the API it tested. Full
suite 519/520. The one failure is on the base commit too:
`test_tutorial.gd::test_main_scene_plays_every_step_file`, because
`map_explanation.tres` has no uid in its header but `main.tscn` refers to it
by `uid://cjs5pb8b7yx5b`.

---

## 2026-10-20 — Dice square up when they change hands

**Why.** Dice handed on sometimes kept a transform their last holder gave
them. A die coming back to the hand could stay at a ship's 0.75 scale, a
dying ship's dice could reach the next ship tilted, and every die rerolled by
an Ion Storm ended upside down, so the ship using it did an odd half-flip
putting it right. The user liked the flip, so it's now deliberate.

**One reset point.** `DiceQueue` has a new `die_received(die)` signal, fired
from `add()` before `die_added`. `die_added` has no argument, which is why
the hand used to guess with `queue[-1]`. The player's hand and every
`EnemyDiceManager` answer `die_received` with `Dice.reset_visual_state()`:
rotation 0, scale `Dice.rest_scale()` (`HELD_SCALE` 0.75 with a ship or a
tile, 1.0 in hand or between queues), and any running *flourish* tween is
killed. A die being dragged is left alone. This replaces the player's
`_reset_newest_die_transform()` and the scale-only line in
`EnemyDiceManager.add()`.

**Flourish tweens.** `Dice.create_flourish_tween()` is for cosmetic scale or
angle tweens that nothing awaits. The tractor beam's landing slam uses it
now, so a die passed on just after it's caught doesn't finish the slam at the
old ship's size. Awaited tweens (rerolls, a ship's spend) aren't flourishes.
Killing one would hang whatever awaits it, so they end by squaring
themselves up instead.

**Rerolls.** The second half of `reroll_with_tween()` restarted from 0 to
180°, so every reroll ended at 180°. It now runs 180→360° and then calls
`reset_visual_state()`, which reads the holder *when the die lands*: a die
passed on mid-roll ends at its new holder's size.

**The spin.** `EnemyActionEvent` now gives the die one full turn
(`_USE_SPIN = TAU`, cubic ease-out) as it flies out in front of the ship. A
chained callback then sets rotation back to exactly 0, because a die left at
TAU looks upright but would spin back next time something tweens it.
`Enemy._on_death()` already steps that tween to its end, so a ship killed
mid-spend hands its die on at 0 too.

**Found while testing.** Dice aren't children of ships (they all live under
the Player node), so the death launch's spin never rotated them directly.
The tilt came from a tractor beam released mid-yank in `give_away_dice()`,
and the receiving queue reset the scale but not the angle. Tiles don't reset
on receive: a die dropped on a tile stays at the 1.0 the drop gives it, but a
reroll on a tile lands it at 0.75, as before. That's left alone.

Tests: `test/unit/components/test_die_handoff.gd` (9).

---

## 2026-10-18 — AutoPilot step 6: replays, and step 5's bugs fixed

**Fixes.**
- A tile bought or claimed onto a full grid used to take the money and
  float with no cell. The shop and salvage now refuse it ("GRID FULL") and it
  drifts back (`TileGrid.has_free_cell()`). The AutoPilot doesn't list
  those moves, as a player can see the grid is full.
- `Enemy._on_death()` no longer hands a freed die to `give_away_dice()`. The
  die was a hologram, spent and gone. 424 sector 1 gauntlet runs (random and
  smart) and 40 runs across all five policies came back with no errors or
  violations.

**Replays.** `tools/autoplay.sh --replay <batch>` plays the batch's flagged
runs again in a window, worst first, photographing the board before every
turn, arrival and won fight, at each error, and at the end. Each replay is
checked against its original transcript, and `shots/index.html` pairs every
picture with that turn's moves. A replayed run and a gauntlet cell both
came back REPRODUCED. A forced loop (`-- --max-loop-moves=12`) was found,
replayed and reproduced too. `--stop-at-turn N` stops there and leaves the
game open.

So that a replay can take its picture before the first move without
changing the run, every run now spends a frame looking at the board at each
turn start. Older transcripts won't replay exactly for that reason, and
gauntlet ones also lack the spec path their header now records.

---

## 2026-10-18 — AutoPilot step 5: a smart bot

`--policy smart` plays like a player who knows the basics. Each die-on-tile
is worth what the tile does, read off its effect chain without running it,
less what the die will cost once the ship it's handed to spends it. It aims
the targeting computer at whichever ship makes that trade best, finishes
ships off, banks shields against the hits it can see, takes salvage, shops,
and jumps toward good stops. Hidden intents cost a flat average, so it never
reads what a player can't. `aggressive`, `turtle` and `synergy` reweigh the
same sums. `autoplay.sh --policy random,smart` plays both on the same seeds,
and the report adds a skill-gap matrix.

**Sector 1 gauntlet, random → smart** (6 seeds a cell, smart's hull lost in
brackets). Smart clears 81% of runs, random 20%:

| Fight | starter | 4th die | 2nd cannon | 2nd shield |
|---|---|---|---|---|
| Opening Ambush | 50% → 100% (−0) | 83% → 100% (−0) | 66% → 100% (−0) | 50% → 100% (−0) |
| Attacker | 16% → 100% (−4) | 66% → 100% (−1) | 66% → 100% (−4) | 16% → 100% (−4) |
| Ion Lances | 50% → 100% (−1) | 16% → 100% (−0) | 66% → 100% (−1) | 66% → 100% (−1) |
| Wolfpack | 16% → 100% (−3) | 16% → 100% (−2) | 50% → 100% (−3) | 16% → 100% (−3) |
| Cutpurse | 0% → 100% (−9) | 16% → 100% (−11) | 0% → 100% (−8) | 0% → 100% (−10) |
| Cannon Drone | 0% → 100% (−9) | 0% → 100% (−13) | 0% → 100% (−8) | 0% → 100% (−9) |
| Tithe Escort | 0% → 100% (−11) | 0% → 83% (−6) | 0% → 100% (−10) | 0% → 100% (−10) |
| Mortar Nest (elite) | 0% → 16% (−5) | 0% → 33% (−2) | 0% → 66% (−3) | 0% → 0% |
| Sector Warden (boss) | 0% → 0% | 0% → 0% | 0% → 0% | 0% → 0% |

- Every ordinary fight is a skill check, not a wall. Played sensibly each one
  is a sure win; Cutpurse, Cannon Drone and Tithe Escort just cost 8–13 hull.
- Mortar Nest rewards offence: a second cannon wins two in three, a second
  shield never.
- No sector-1 loadout beats the Sector Warden, even played well.

**Whole runs** (24 seeds each): smart wins 2.2 real fights a run against
random's 1.3 (random's 6.7 "wins" are mostly the one-hull Fate ships it keeps
jumping back into). It reaches the Warden in 17 of 24 runs (random: 9), and
dies there. Neither got out of sector 1. The map is part of why: a run starts
on stop 4, the gate is stop 13, and a jump goes exactly a die's face, so a
player sees about three stops before the boss. Smart arrives with the starter
kit plus a die or a tile.

**Game bugs it found, not yet fixed:**
- A tile bought or claimed onto a full grid takes the money but never gets a
  cell (`TileGrid.receive_tile()` finds no free cell and does nothing). It
  floats, unplayable and unsaved.
- `Enemy._on_death()` passes `spending_die` to `give_away_dice()` after the
  die has been freed: a hologram a Field Tender's Holo Loader conjured and
  the Siege Mortar spent. Script error at `enemy.gd:238` (Mortar Nest).

**Fixed in the bot on the way.** A boss Lockout cancels a tile without
`activation_refusal()` knowing, so the die bounces back. Out of combat the hand
never empties, since a die given to nobody comes home. The bot also bought
from the shop while its jump was already underway.

---

## 2026-10-18 — AutoPilot step 4: gauntlets

`tools/autoplay.sh --gauntlet tools/gauntlets/sector1.json` plays chosen
scenarios with chosen loadouts on the same seeds, and the report opens with
a scenario × loadout matrix. A run starts from a loadout-only save, so the
sector around it is generated as usual, and the chosen fight takes the
starting slot. The bot holds its ground until the fight is decided.

First gauntlet: sector 1's nine fights × four loadouts × 10 seeds, 360 runs
in under 4 minutes, no errors or violations. The loadouts are the starter
kit, the kit plus a 4th die, plus a 2nd Dice Cannon, and plus a 2nd Shield
Burst. Share of runs that cleared the fight:

| Fight | starter | 4th die | 2nd cannon | 2nd shield |
|---|---|---|---|---|
| Opening Ambush | 50% | 90% | 80% | 50% |
| Attacker | 30% | 70% | 80% | 30% |
| Ion Lances | 40% | 10% | 80% | 40% |
| Wolfpack | 20% | 10% | 60% | 20% |
| Cutpurse | 0% | 10% | 0% | 10% |
| Cannon Drone | 0% | 0% | 10% | 0% |
| Tithe Escort, Mortar Nest, Sector Warden | 0% | 0% | 0% | 0% |

It's the random bot, so read these as how forgiving a fight is of careless
play, not as a player's odds:
- A second Dice Cannon is the strongest single addition across the board.
- A 4th die helps against lone ships but hurts against Ion Lances and the
  Wolfpack: a careless player just hands the enemies one more die.
- Tithe Escort, Mortar Nest and the Sector Warden were never beaten. The
  Warden kills a full-hull ship in 1–3 turns when handed every die (its
  faces are mostly 8–10 damage Dice Cannons).

Step 5's smarter bot is what turns these into balance numbers.

---

## 2026-10-18 — Shelf tiles, AutoPilot step 3: balance stats

**Fixes from step 2's findings.**
- Shop stock and salvage on offer were live tiles. A die dropped on one
  played it for free (the random bot did it about 150 times in 200 runs),
  and their passives worked from the shelf: an unbought Counterweight Battery
  shielded the player 214 times in one run, leaking a sparkle each time. Tiles
  are now `on_offer` until installed.
- The shop forgets an item that leaves the tree (a jump frees the die on
  offer), `Dice.reroll_with_tween()` copes with a die in no queue, and a
  zero-damage hit spawns no particles.
- New, found on the way: a turn could open with the hand already spent (the
  last die on a Welder) and no End Turn. It's re-checked at every turn start.

**The bot never actually skipped the tutorial.** Its switch hooked
`node_added`, but the main scene enters the tree before autoloads are ready.
Earlier batches only dodged the tutorial because Options had it off. With the
reworked, seeded tutorial on, every bot run played seed 21 with its dice
locked, and a run that finished the tutorial could have saved
`show_tutorial=false` to the player's options. Now it switches the tutorial
off from the tree, flags a run whose seed was overridden, and can't write
the options file at all.

**Step 3: stats.** The bot now takes salvage and buys from shops, so builds
vary. Every run tallies what each tile and enemy did and how each scenario
visit went, and `tools/autoplay_report.py` turns a batch into a sortable
`report.html`; `autoplay.sh` writes one after every batch.

First look, 200 random runs (seeds 1000–1199), all lost in sector 1, median
20 turns, 3.7 fights won per run:
- The Sector Warden ends 65% of the runs that reach it (89 visits), and Fate
  Attackers deal the most final blows (89), likely because the random bot
  keeps jumping onto Fate's tiles. Tithe Escort (47% of 17 visits) and Tollkeeper (33% of 12) are
  the deadliest ordinary encounters.
- Salvage with choices is rare at this level: 14 offers in 40 runs, every one
  taken.
- Tile numbers mostly measure the starter kit for now. Fixed loadouts (step
  4) and a smarter bot (step 5) will make per-tile comparisons mean
  something.

---

## 2026-10-18 — The tutorial, reworked for a complete novice

**Why.** A step-by-step review with screenshots, against a list of what a new
player has to know, found problems.
- The tutorial was switched off in main.tscn (`auto_start = false`), so nobody
  saw it.
- Its text claimed the hull was at 14 of 32 when it was full.
- It implied only the Dice Cannon hands its die to the enemy.
- It said "feed it the small rolls", which clashes with the Feed keyword.
- It never said how to read a tile, that every die must be used before End
  Turn, or that a die's value is how far you jump.
- The salvage was a second Shield Burst.
- The handoff closed itself after 5 s, over a new fight.

**Now.** Twelve short steps, most of them asking the player to do something.
Most of the learning is still left to play.

| # | Step | Teaches |
|---|---|---|
| 1 | ambush_intro | the raider, the hull, the goal (highlights both) |
| 2 | activate_tile | drag a die onto a system to fire it |
| 3 | enemy_keeps_die | used dice go to your target, who fights back with them |
| 4 | read_intents | the targeting computer: a value with no action is wasted |
| 5 | end_turn_prompt | click a system to read it; use every die, then End Turn |
| 6 | enemy_response | stays up for the whole enemy turn |
| 7 | finish_the_raider | dice come back each turn with new values |
| 8 | claim_salvage | credits buy upgrades; drag the new system into a slot |
| 9 | open_the_map | engines charge when a fight ends (gauge highlighted) |
| 10 | map_explanation | hover markers; the Boss Gate; corruption follows |
| 11 | jump_out | a die's value is how far you jump |
| 12 | tutorial_handoff | click a ship to target it; good luck (closed manually) |

- **Hard-seeded.** The whole first run uses seed 21: the same map,
  encounters and backgrounds for everyone. The hand (4/2/1, then 5/6/4), the
  raider's intents and the salvage (now a Deflector Array) are forced.
- **First run only.** `Globals.show_tutorial` is saved in the options file
  and cleared when the tutorial finishes. The Options menu has a new Show
  Tutorial box (Game tab) to see it again.
- New highlight masks: enemy plus hull, and map tab plus engine gauge.
- Deleted 26 unused step files, five unused masks, `tutorial_start.tres` and
  the old TUTORIAL_ scenarios and enemy.

**Found while testing:**
- *Eager players soft-locked it.* Pressing End Turn while reading an earlier
  popup left the End Turn prompt waiting 120 s for an event already passed.
  Steps now check whether their event already happened (`_already_satisfied`)
  and close once the text has shown.
- *Steps waiting on the player timed out.* After 120 s the End Turn prompt
  gave up, which ran the enemy turn without End Turn and never gave the turn
  back. Player-driven steps now have no deadline. Steps waiting on the game
  keep the backstop.
- *"Your dice come back" showed mid-enemy-turn* (the enemy turn step closed
  after a fixed 2 s). It now closes on the new `PLAYER_TURN_STARTED`.
- *Bump counted as handing over a die.* Step 3 now opens on the new
  `ENEMY_RECEIVED_DIE`, which a Bump doesn't send.
- *"Lambda capture at index 0 was freed" errors.* A step's deadline outlived
  its popup. It is now disconnected when the popup closes.
- *The handoff popup hid the second ship* in the next fight. It now sits over
  the systems grid.

**Verified:** Played through live, screenshotting every step. That covered
the eager End Turn, Bump-first and the map jump; the log was clean. 475 of
475 GUT tests pass, including 10 new ones in `test_tutorial.gd`.

**Open:**
- Seed 21 also fixes sectors two and three. A seed that only covered sector
  one would mean reseeding at the first jump.
- Almost every background carries a rule modifier, the tutorial's too.
- "Dice Cannon" wraps across lines in step 2.
- Corruption gets one line. Fate is left to play.
- Step text is still literal English in the .tres files, pending
  localization milestone 2.

---

## 2026-10-18 — Spare die, End Turn fixes, AutoPilot step 2: watchdogs

**The spare die.** A ship could take every die (a Cutpurse fleeing with the
haul, a Charge Bore keeping the last), leaving the player with nothing to
play, stuck in a fight or unable to jump out of a scenario at all. Now,
whenever a turn starts or a fight ends with nothing to play, the player gets
a spare: real if the Fleet owns a die nobody holds, a hologram if ships hold
them all. It also allows a nice play: hand a near-dead Cutpurse everything,
take the free hologram, shoot it down, and get your dice back.

**End Turn only on the player's turn.** It's off from the moment a jump is
committed (no more enemy turns in a scenario being torn down: 21 of 40 runs
hit that), from the press until the next turn, and while a fight's ships fly
in. The hotkey follows the button. Fixing it turned up two neighbours:
- A fight breaking out during an enemy turn run out of combat (a Burn tick on
  a civilian) got two player turns at once.
- A first-turn announcement could go out into the next scenario if the
  player jumped before the ships landed.

**AutoPilot step 2.** Runs now fail on any engine or script error
(captured with the move it followed) and on broken invariants: overlapping
turns, empty-handed fight turns, dice duplicated or missing, a limited tile
gone unlimited, values out of range. Hung runs are killed. A batch ends with
a grouped summary and seeds to replay. Each run keeps a DebugLogger
play-by-play, which turned up three logger crashes on freed ships, a freed
engine and a disarmed hazard (fixed).

200 random runs (seeds 1000–1199): no stalls, loops, hangs or violations.
Still open, found by the new checks (not fixed):
- `Dice.reroll_with_tween()` (dice.gd:89) calls `host_queue.get_parent()` on
  a die with no host queue: 10 times in 200 runs. Seeds 1090, 1131, 1191.
- `Shop._clear_stock()` (shop.gd:184) iterates a typed dictionary whose keys
  include freed items: 8 runs. Seeds 1051, 1096, 1112.
- `DamageEvent._spawn_hit_particles()` asks for zero particles (a 0-damage
  hit): seed 1051.
- Shop tiles leak particles: an unbought tile in the shop keeps running its
  event responses (Counterweight Battery's shields at every enemy turn end,
  214 times in seed 1133) and leaves a sparkle each time on a hidden panel,
  where it never finishes. That's a gameplay bug too: the player gets the
  shields from a tile they didn't buy. Seeds 1054, 1133 (memory warnings).

---

## 2026-10-18 — AutoPilot, step 1: fast, reproducible runs

The game can now play itself (`tools/autoplay.sh`). This first step is the
foundation: runs that are fast, isolated from the player's save, and
reproducible from a seed. The only policy so far plays at random.

- Headless with `--fixed-fps 60`, a full run takes 3–5 s; 40 runs take 45 s
  on 8 cores. Nothing is skipped, just compressed.
- 20 of 20 seeds replayed identically. The one divergence on the way was
  money: a payout only reaches the balance when its coin lands, and coin float
  times are cosmetic randomness. Snapshots now count coins in flight.
- See ARCHITECTURE_OVERVIEW, "AutoPilot".

Found in the first 40 random runs (not fixed yet):

- **End Turn during a jump.** `Map.jump()` pans the map before the jump
  starts. Spend your last die on a map arrow and End Turn is lit through the
  pan. Pressing it starts an enemy turn whose engine the jump then frees, and
  `EnemyTurn._engine_alive()` errors on the freed engine (typed parameter).
  21 of 40 runs hit it.
- **Turns that start with an empty hand.** Flee and leave dice behind, then
  have an enemy keep the last one (Charge Bore), and a turn starts with no
  dice. End Turn is only re-checked when a tile finishes activating, so it
  stays disabled; only the hotkey ends the turn. 6 of 40 runs.
- Possible, unconfirmed: checkpoints count every coin in the `Money` group as
  owned, including a Pilfer's coins flying away.

---

## 2026-10-17 — Cleanup pass

A sweep for flags and code that cost more than they gave: about 650 fewer
lines of GDScript (1,900 counting deleted scenes). Play is unchanged apart from
the fixes below.

Removed: flags nothing read (`Globals.tutorial_active`,
`display_close_button`), flags that copied another (`_sector_advancing` into
`_in_transit`, `_restoring_save`, the tutorial's `_dice_locked` and
`is_active`), Fate's vestigial
right-hand side on the map, two unused signals, and orphan scenes (Legend,
DiceReceptacle, title_screen, the pre-GUT engine test). Draggable's arrival
thump is now opt-in (`set_home()`), so four callers stopped switching it back
off. HealthBarController's countdowns became tweens. The options code stores
numbers instead of menu labels and lost three hidden placeholder rows, two of
them wired to the wrong handlers.

Fixed on the way:

- Tutorial pause tags now pause. The old position mapping put 6 of the 9
  authored `(delay=x)` pauses at the end of their line. `format_with_delays()`
  replaces it in a fraction of the code.
- A heal of 0 no longer reads as a hull hit (sound and big shake).
- The shop keeps prices as data instead of parsing its own labels.
- ContentRegistry, the reward pool and the tile palette list resources with
  `ResourceLoader.list_directory()`. `DirAccess` sees `*.tres.remap` in an
  exported build, so those lists could come up empty there.

Release and web: the dev console only exists in debug builds. On the web, Quit
buttons hide, the debug log and screenshots stay off, and options skip
window settings.

---

## 2026-10-16 — Glass that falls, cracks that fade

The canopy cracks were the best part of the cockpit damage, but they sat on
screen for good. Now a new crack holds for two seconds, then fades over six to
a ghost at 10%. The canopy remembers every hit without being hard to see
through. The torn seams and their smoke carry the lasting "hull is low"
signal. A new hit only brings in new cracks.

Cracks knock glass loose. Shards tumble down inside the cockpit and land on
whatever is under them: the dash, the top of the main viewer, the rim of the
hull gauge, the top of the targeting computer. Each one bounces once, glints
now and then, and fades, with a tinkle as they land. The floor is the art
itself: the first opaque pixel of the walls texture, or of any sprite in the
`cockpit_surface` group. No collision shapes to keep in step.

Smoke is now real puffs (three variants) that grow as they rise. The plume
scales smoothly with the size of the hit, and gets an extra push as the hull
runs out. A small big-hit at full hull gives a modest puff. A huge hit near
the end chokes the cabin. Open seams' lingering trails thicken as things get
dire too. The curve is tunable from CockpitDamage's exports.

On death, every crack drops to its ghost, then they come back one at a time
in the order they were taken, quickening, each with a glass crack (pitching up
as they come) and a spill of shards. Then the canopy blows out.

Both glass sounds are synthesised placeholders.

---

## 2026-10-15 — Cockpit damage and destruction

The cockpit now shows the hull. Nine damage sites (five canopy cracks, four
split frame seams) open one by one as hull falls, each popping in on a flash
with glass shards or sparks and debris. Healing closes them in reverse: the
break glows green and fades as green sparks pop out of it. A big hull hit
(15% of max or more) billows smoke out of the torn seams, and open seams
keep leaking a thin trail.

Dying is no longer a cut to the game-over panel. `player_destroyed` fires as
the hull goes: the scenario engine shuts down where it is, the hand locks
and End Turn disables, but the ships keep hovering and shots already in the
air land. The breaks rupture faster and faster, then the shell blows apart
into fragments and the panels tumble away past the camera, leaving the
ships in open space. `game_over` follows once the wreckage clears.

The crack and seam art was generated (cracks clipped to the glass, seams
drawn only on frame pixels) and lives as one layer per site in
`cockpit_damage.aseprite`.

---

## 2026-10-15 — Shield build

Eight tiles around shields, so defence can win a fight instead of only
delaying it, after Slay the Spire's Body Slam and Juggernaut.

**Builders.** Deflector Array (any die -> shields equal to die), Overshield
Relay (+3 shields, Feed right, 2 uses), Reactive Armor (hull hit -> 4
shields). **Multipliers.** Fortress Protocol (a 6 doubles your shields, 1
use, rare) and Shield Siphon (a 4 steals every shield off the target, 2
uses). **Payoffs.** Ram Plating (any die -> damage equal to shields, keeps
them, 1 use, rare), Discharge Plate (a 1 spends all shields for 2x that in
damage) and Repulsor Field (shields gained -> 2 damage to a random enemy,
rare).

Shields last the whole scenario, unlike Spire's block, so the payoffs that
keep shields are single-use and rare, and the one that can be used freely
spends them.

**Engine.** `SET_TO_TARGET_SHIELDS` reads shields (after `TARGET_PLAYER`,
your own). `SPEND_SHIELDS` pays a shield cost without counting as a hit, so
it plays no hit feedback and can't trip Repulsor-style listeners;
`SHIELDS_AT_LEAST` gates it. `ON_PLAYER_SHIELDS_GAINED` is a new tile event,
and `IF_IN_COMBAT` keeps a random-enemy response off civilians, since event
responses ignore activation checks. `Health.change_shields(0)` is now a no-op;
a tile that scaled to nothing (a boxed-in Solar Sail) used to play the shield
hit.

---

## 2026-10-14 — Review cleanup of the last two weeks

A code review of the fortnight's work, then the cleanup it suggested. No
gameplay changes intended.

**Bugs fixed.** A fleeing or escaping ship stopped listening to scenario
events only after announcing it was leaving, so `PIRATES_DEFEATED` could make
it react to its own exit; it now goes deaf first, as a dying ship already
did. A cut-short gate warp-in no longer leaves the ring over-bright on the
next quiet open. Damage-number callout stacking forgets old ships instead of
growing all run. A targeted ship that moved before its reticle had ever bobbed
crashed the reticle hand-off. Forced tutorial actions and Jammed's Do Nothing
were numbered and bound in place on shared resources; they are copied first.
Raising a ship for its kill flash cancels a hit bump that would undo its scale.

**Structure.** `EnemyManager` lost its hull and turn code to `HullMounts`
(hull lifetime, seating parts, the formation space they hold) and `EnemyTurn`
(rolling tables, playing the turn). `TargetingComputer` gained public
`hide_indicator_while_moving()` / `show_indicator_after_move()`, and
`EffectContext.relay_visited_with_actor()` replaced a borrowed private helper.
Node meta became fields (`Dice.transit_locked`, the hull's rest spot).

**Data.** `SPARK_BURST` and `STREAM` read a typed `juice_flags` bitmask
(Rise / Outward / Engine) instead of words in `string_param`; 23 authored
steps were migrated. Statuses carry a palette `color` rather than a colour
name. The never-filled `hazard_turns` save field is gone, since checkpoints
are never taken mid-fight. `Globals.SCREEN_SIZE` replaces four hardcoded
320x180s. `EnemyActionResource` keeps what it reads off its chain.

**Tests.** New: departures (dice stranded by a jump, flee, escape, launching,
the gate, the reticle), `HullMounts` and the Bastion through `EnemyManager`,
`EnemyTurn` always ending, tile neighbours, juice flags, and the action cache.

**Correction.** The review claimed Feed Hologram could mint a die face above
6. `Dice.value` already clamps, so the clamp added for it was removed again.

---

## 2026-10-14 — Elites, bosses on the gates, the gate ring, and two new bosses

**Map.** The purple boss icon now marks **elites** (`elite_encounter.png`).
These are optional three-ship fights: Mortar Nest, Lance Squadron, Tithe Fleet
and Hunter-Killers. One or two are shuffled into each sector
(`GameStateManager.elite_scenarios`, `elites_per_sector`). The lead ship's
salvage is rare-or-better, its wingmen's uncommon-or-better (new
`RewardResource.minimum_rarity`, which falls back to the whole pool when
nothing qualifies), and wiping the squad pays a credit bounty. The bounty is
credits only, because a fourth offer stacked on the last wreck buried the
others.

**Bosses guard the gates.** Each sector's boss now *is* its jump gate
(`gate_boss_scenarios`, indexed by sector): the Sector Warden, the Arc Dynamo,
then the Bastion. The old Attacker+Defender gate fight and the escorted Warden
variants are gone. Fate now stops one tile short of the gate
(`_pick_new_danger_ranges`), so the way out can never be corrupted or covered.
That also fixed a zero-width danger texture the map threw once Fate ran out of
room. The save format is v3: older sectors would have no gate.

**The gate ring.** Beating a gate's boss warps in a ring-shaped gate ship
(`JumpGate`). It rests where the window is clear of floating salvage, with
chasing rim lights and a swirling portal. Jumping forward from the gate (map
arrow, any die) flies through it: the portal crossfades to gold, the ring
rushes the camera until its hole swallows the window, the screen whites out,
and the ship cuts straight into gold hyperspace (`set_jump_tint`,
`cut_to_hyperspace`) under a **SECTOR N / OF 3** title. Forward from a
guarded gate says GATE LOCKED. A won gate becomes `GATE_open`, so leaving and
coming back finds the ring waiting rather than the boss. The final gate plays
the same passage and ends in victory, with gold hyperspace behind the screen.

**Boss intro card.** A scenario with a `boss_title` opens on a red band with
the boss's silhouette, its name stamped on with a shake and a glitch, and a
typed subtitle. It plays only while the boss is hostile and swallows input
while it's up (~2.3 s).

**Arc Dynamo and Overload (sector 2).** New `EnemyResource.overload_*`: if
the dice a ship holds at the start of its turn add up to its threshold, it
**overloads** instead of acting. It vents every die home, plays its
`overload_chain`, and the threshold rises. An `OverloadGauge` under the ship
shows held/threshold and flashes red once the next turn will trip it. The
Dynamo (58 hull) trips at 15, grows by 4, and jolts itself for 10, but its
biggest guns sit on its highest faces (`face_bias` 1.5). Stuffing it with
sixes is a bet you'll get there. It fights in the Ion Storm Front, whose storm
re-rolls held dice before the check.

**The Bastion (sector 3, split-component).** A scenario can carry a hull
(`ShipHullResource`) whose mounted ships (`EnemyStateRewardResource.mounted`,
`mount_offset`) are its parts. Each part is an ordinary Enemy, so targeting,
intents, dice and statuses need no changes. `EnemyManager` carries the parts on
the hull: they fly in, bob and fall away as one ship. A destroyed part scars
its socket, and the last one breaks the hull up. The parts are:
- **Core:** relays dice to the others while they stand, then escalates by
  squad losses.
- **Batteries:** the guns.
- **Aegis:** shields and repairs the rest.

**Art.** Gate ring, blue and gold portals, the Dynamo, and the Bastion's hull,
three parts, socket scar and silhouettes. All are drawn in the house palette,
with `.aseprite` sources beside each PNG.

**Verified live:**
- Generated sectors 1–3: elites present, the boss gate always last, Fate
  halting at the tile before it.
- Elite drops respected their rarity floors.
- GATE LOCKED with the boss alive. The ring warped in after the kill, clear of
  the salvage, and the caption read "Jump through!".
- Gate passage into sectors 2 and 3, and the final passage into victory.
- Leaving a won gate and coming back found the ring, not the boss.
- Intro card fired 7 s into the jump.
- Handed the Dynamo three 6s: it overloaded (58 → 48, threshold 19, dice home,
  no damage to the player).
- Bastion: killing the Aegis scarred its socket, and the Core's squad_losses
  went to 1. Killing the rest broke the hull up and opened the gate. Fleeing
  mid-fight took the hull with its parts.
- GUT 354/354. No script errors in the log.

---

## 2026-10-13 — Cutpurse and Carrier

Two enemies, each built on a new verb.

**Cutpurse (dice thief).** Its Pilfer intent deals a point or two and
**Steals** the die (new hover keyword). Pilfer keeps the die, and it's also the
ship's kept-face action, so a stolen die lands on Pilfer again every turn: it
stays stolen, and your hand stays a die short, until you kill the ship (it
drops its haul like any wreck) or take the die back (Repo Beam and friends).
Any other die you hand it on that face gets pocketed too. From its fourth
round the stolen faces read **Getaway** instead: if it's still alive on its
turn, it flies off the top of the screen with everything it holds, and those
dice are gone from the Fleet for good. That's the same loss as jumping away
from a ship holding them. New effect: `ESCAPE_WITH_DICE`
(`Player.lose_dice_to()` shares the jump's stranding code). It counts as
DANGEROUS for the tractor beam and is never rolled while hidden.

**Carrier + Interceptor.** A 30-hull, 6-shield flight deck whose signature
Launch intent puts an **Interceptor** (5 hull, small gun) into the formation
beside it. It also shields its fighters with Aegis Link. New effect:
`LAUNCH_SHIP` with a new `EffectData.ship_resource` field, via
`EnemyManager.launch_ship()`. A launched ship pays no reward of its own, isn't
saved, and can't push the board past `max_ships_in_combat` (5; at 6 the health
rings collide). Launch is also gated on a new condition, `ALLIES_AT_MOST` 3.

**Art.** Hulls cut from the tiny-spaceships pack (`Assets/tiny-spaceships/`):
flipped to face the player and remapped onto the enemy palette (house greys,
`#040217` outline, purple accent for the thief, orange for the carrier wing).
16×16 targeting silhouettes and the Pilfer / Getaway / Launch intent icons
are new.

**Encounters.** `COMBAT_Cutpurse` (thief between two Venom Fighters) and
`COMBAT_Carrier` (Carrier + one Interceptor).

**Verified live:** fed the Cutpurse a 1 and a 6 on Pilfer faces → both held,
hand down to 1, next table Pilfer on 1 and 6. Forced round 4 → Getaway on
those faces; ending the turn flew it off and the Fleet went 3 → 1. Two 1s into
the Carrier's Launch → two Interceptors slid out beside it; killing a launched
one dropped nothing; launches stop at 5 ships. No script errors in the log.

---

## 2026-10-13 — Playtest tweaks

- **Tile text:** the trailing `Give die` is gone from every tile. Giving the
  die to the target is the default and the words read as unclear. Tiles that
  hand it somewhere else (`to random enemy`, `as (die_1)`) keep theirs.
- **Hazard info:** the panel says only when the hazard next hits. "Repeats
  every N turns" is gone; the countdown resets after it fires and shows that.
- **Intent highlights:** an enemy's die leaves its hand as the action starts,
  which dimmed the intent before anything had happened. The targeting computer
  now holds the acting slot lit until the action has played out, meaning the
  engine queue drains or the next action takes over. `enemy_used_die` now
  fires before the die is removed, so the intent never blinks dim in between.
- **Blank intents:** slots with no action (or not yet scanned) turn off their
  `Clickable` entirely, so the info cursor doesn't appear over them.
  `hover_for_info` used to be set true and never cleared for a blank slot.
- **Exposed:** every single-target tile hit gets +Exposed and spends 1,
  instead of one hit spending the whole stack. Stacks no longer build up into
  one huge hit, but a stack now pays out over several hits, so Spotter Drone
  and Flare Burst are worth watching for balance.

---

## 2026-10-13 — Charge Bore loads the shot

Charge Bore and Siege Shot were never actually linked. Charge Bore gave its
die back, and the loaded table scattered two Siege Shots at random, so the
face that triggered the charge said nothing about where the shot would land.
`KeepDieWithActorEvent` and a comment in `EnemyDiceManager` ("Charge Bore
keeping its shot") show it was meant to keep the die. The chain just never
used it.

**Now:** Charge Bore ends with `Keep Die with Actor`, and the Siege Shot
options are flagged `place_on_held_faces`. When the Mortar rolls its loaded
table, a Siege Shot goes on the face of each die it's holding. Feed a 3 into
Charge Bore and your 3 sits in its queue, with Siege Shot on slot 3 lit in
the targeting computer. The second Siege Shot still lands wherever face bias
puts it.

**What changes in play:** the Mortar's loaded turn isn't optional anymore,
since it's holding a die and will act. You're also a die down for that turn.
The answers are to kill it through the shields it just gained, or to tamper
with the loaded die (reroll it, flip it, or take it back) so it misses the
shot. Readability: the callout reads `LOADED: 3` (new `{die}` callout
token), and the text is `Gain 3 shields. Load die`, where Load is a hover
keyword.

**Verified live:** fed a 3 into Charge Bore → 4 shields, die held, next
table had Siege Shot (10) on 3 → hull 14 → 4, die back in hand, loading
table again. Repeated with a 5 and a 6. 344 tests pass (6 new for pinning).

**Follow-up, same day: Siege Shot only ever follows a loaded Charge Bore.**
The first pass also kept two force-included Siege Shots in the loaded pool,
so one always landed at random, and the pin read any die the Mortar held,
including ones a dying ally passed it. That punished the player for a
choice they didn't make. Now the option is `fills_kept_faces`: never rolled,
one copy on the face of each die the ship *kept itself* (`Enemy.kept_dice`,
recorded by `KeepDieWithActorEvent`, cleared when it next acts). With nothing
loaded, the loaded table is just small attacks and blanks. Verified live:
fed a non-Bore die → no Siege Shot. Loaded a 6 → exactly one Siege Shot, on
6, which hit for 9, and then the kept memory cleared. 347 tests pass.

**To playtest:** it was very punishing in the first pass. That's deliberate for the
moment. Knobs to watch are the second unpinned Siege Shot, the 8–13
damage, and whether shields stacking across cycles makes the Mortar too
tanky to burst.

---

## 2026-10-12 — Face bias: where an enemy's strong actions land

A table's six actions used to be shuffled onto the faces at random, so the
value of a die said nothing about how bad it was to hand over. Now an enemy
can lean its strong actions toward high or low faces: `EnemyResource.face_bias`,
overridable per pool (`EnemyTurnActionList.override_face_bias`). A boss that
turns erratic in its last pool can drop back to 0.

**How.** `EnemyActionSelector` still rolls the six actions the same way. Only
the final shuffle changes: each action sorts on `randf() + face_bias × rank`,
where rank is its place in the table by strength. Strength is read off the
chain (threat tier, then rolled amount), so a 6-damage attack outranks a
3-damage one and both outrank any shield. `strength_tier_override` on an
option covers what the chain undersells. At bias 0 the old shuffle runs draw
for draw, so every existing enemy and seeded run rolls exactly as before.

**Feel.** Sector Boss pool 0, 500 rolls, share of each face (1→6) that deals damage:

| bias | 1 | 2 | 3 | 4 | 5 | 6 |
|---|---|---|---|---|---|---|
| −1 | 96% | 85% | 65% | 50% | 29% | 9% |
| 0 | 54% | 55% | 60% | 54% | 54% | 55% |
| +0.5 | 24% | 49% | 56% | 56% | 69% | 82% |
| +1 | 9% | 27% | 42% | 64% | 85% | 93% |
| +2 | 2% | 17% | 43% | 76% | 92% | 99% |

The average hit on a damaging face climbs too (+1: 5.0 on a 1 up to 8.0 on a 6).
With positive bias, Do Nothing collects on the low faces, so 1s become safe
dumps for that ship: the tension moves onto the high dice, and the table is
still shown in full before the player commits.

The default is +0.5, so every enemy leans gently high unless it's tuned to do
otherwise. It's the script default rather than a value in each `.tres`, so
changing the house rule is one line. Tutorial tables are fully forced and
never placed, so they're unaffected.

---

## 2026-10-12 — Timed backgrounds, Napalm Vent per hop, player numbers on screen

**Hazards are backgrounds now.** Solar flares, ion storms, asteroid impacts and
the Fate Rift used to sit on a scenario, layered over whatever background the
pool rolled, announced by a banner. They read as random punishment. Each is now
a background of its own (`BackgroundResource.hazard`, a
`BackgroundHazardResource`, mutually exclusive with `global_modifier`):
Solar Corona (a big star, top left), Ion Storm Front (charged clouds), Asteroid
Field (drifting rocks plus a meteor shower) and Rift Space (a tear beside the
black hole). The general three joined `all_basic_backgrounds`; the six
encounters that had hazards point at one-background pools, so the boss still
fights you beside a flaring star.

**Telegraphing.** The countdown moved into the EnvironmentMonitor: the hazard's
icon with the turns left beside it. Each tick down flashes the unit and pops
the digit; at one turn left it goes red and the lamp won't stop blinking; when
it fires the monitor calls out the hazard's name. The art warns too, through
`HazardTelegraph`: the star's corona throbs hot when a flare is a turn out and
whites out when it lands, the clouds strike constantly before a discharge,
rocks streak overhead more often before an impact and one comes down at the
cockpit when it hits, the rift quickens. `HazardManager` arms on
`start_combat`, so a hazard region you pass through out of combat never counts
down to nothing. The banner (`HazardIndicator`) is gone.

**Napalm Vent** answered a relay chain once. Its `ON_ADJACENT_TILE_ACTIVATED`
responses were appended to the back of the queue, so they all resolved after
the chain, back to back inside the callout cooldown, and looked like one proc.
They're injected right behind each neighbour's activation now, one visible
burn per hop. It also listens wider: a new `ON_SURROUNDING_TILE_ACTIVATED`
event covers all eight cells, diagonals included (Spark Gap keeps the
orthogonal `ON_ADJACENT_TILE_ACTIVATED`).

**Hazard text** follows the tile conventions now: imperative, terse, with the
established phrasings (`Re-roll all dice`, `Flip all (die_1) and (die_6)`,
`Take 3 damage`). Asteroid Impact's "for the turn" was wrong (a lock cancels
the tile's next activation, whenever it comes) and is gone. The monitor's
panel puts the timing on two short lines (`Next in 2 turns` / `Repeats every
3 turns`), and the Solar Flare is yellow rather than the near-white it shared
with the UI.

**Ion Storm and Fate Rift go off as your turn ends.** At turn start they did
next to nothing: the hand had just been rolled, so re-rolling it gave another
random hand, and swapping its 1s and 6s left a hand just as random. Hazards now
have a `timing`. These two fire on `enemy_turn_starting`, once your dice have
landed with the ships and before any ship uses them, and act only on those
dice (`REROLL_TARGETS_DICE`, `FLIP_TARGETS_ONES_AND_SIXES`). On a storm turn
you can't buy a ship's weak action with a 1; on a rift turn a 6 handed over
plays as a 1. Verified live: 1-1-1 handed over came out 5-2-6 and the ship
played 5-2-6; 1-6-3 under the rift played 6-1-3. Every hazard description now
opens with its trigger, and at one turn left the monitor spells out "Hits as
you end this turn" or "Hits at start of next turn".

**Player damage numbers** fell sideways out of the bottom-left corner. They
now start anywhere in a patch over the hull bar and rise at a random angle,
and every label's whole flight (start, drift and pop overshoot) is clamped to
the screen. The first pass only randomised the side, and the left side always
clamped to the same spot against the edge, so they looked fixed.

---

## 2026-10-07 — Enemies that read the board, pass dice and raid civilians

**Goal:** enemy intent tables were rolled ship by ship with no idea what else
was on the board. Three problems came out of that: a friendly ship whose
intents read "?" could still hold Flee, so firing on it with a 4 could make
it leave on that very die; a pirate medic could patch up a civilian; and
ships couldn't work together. Now every ship rolls together against a
picture of the board, picks cooperative or predatory actions accordingly,
and the perfect-information pillar holds: the six slots, and now the ship
each one acts on, are shown before the player commits a die.

**Hidden tables can't flee.** Actions say whether they're safe to roll while
intents are hidden, read off their chain (anything with `FLEE` or `JUMP`
isn't). Visibility is read off the roster, since `state` still says
`IN_COMBAT` from the last fight while a new scenario's ships roll; I caught
that live, rolling a Flee into a hidden table after a jump. When a fight
ends with friendlies still around, any table holding a Flee is rerolled
safe, and the targeting computer now reveals tables the moment a fight
breaks out.

**Rolling** moved out of `Enemy` into `EnemyActionSelector`, and
`EnemyManager` rolls everyone together. `FactionRelations` is one small
table: pirates and their boss are one side, civilians another, and pirates
prey on civilians. Options can carry authored conditions and weight rules
(Repair ×3 while an ally is hurt); actions that need another ship are gated
on one existing, read off their chain.

**Bound targets.** A slot that acts on another ship picks it when rolled.
`TARGET_BOUND_ALLY` / `TARGET_BOUND_HOSTILE_SHIP` read the binding,
descriptions can say `(target)`, and the targeting computer hangs a green
(ally) or red (prey) die face under each ship the targeted enemy's slots
point at. That came out of live testing: both Tender escorts are called
"Venom Fighter", so the name alone couldn't say which one. Repair Beam and
Aegis Link moved onto it. If the bound ship leaves, the slot re-points.

**Relays, and why they can't loop.** Relay shields a little and hands its die
to an ally, who spends it at once; Holo Loader hands your die back and
conjures a hologram (face = intent amount) for an ally. The Field Tender
carries both. Loops are ruled out at selection, as asked: each (ship, face)
is a node with at most one edge out, so "would this binding loop?" is a
walk forward. A relay is only bound where the walk can't come back; if no
ally qualifies, that one slot is rerolled relay-free. No retry loop, no
dice rerolled in flight, nothing else the player can see moves. Rerolling
whole tables until valid was the alternative; with two or three ships and
relay-heavy pools it fails repeatedly and churns slots for no reason. A
300-seed fuzz test (2–4 ships, relay-heavy pools, holograms on every face)
finds no loops, and a `relay_visited` list on the events is the backstop.
A slot's threat follows its relay, so the tractor beam colours a die by
what it finally does.

**Raids.** Raid fires on a bound civilian and hands the die back; its threat
reads neutral (its damage isn't aimed at you). It lives on the Venom Raider,
a raiding loadout of the Venom Fighter used in Pirates Attacking Civilian,
not on the plain fighter, which escorts its own hauler in Wreck Salvage.
Ship-on-ship damage is announced (`ship_attacked_ship` →
`PIRATE_ATTACKED_CIVILIAN`), and a ship killed by another drops no reward,
gets no kill-confirm, pays no faction bounty and isn't the player's kill.
The event reacts: a civilian under fire cries for help, and a pirate that
makes the kill itself doesn't thank you for it.

**Caught by the content test:** I authored Relay with Holo Loader's ordinal
(miscounted `DiceControlSubtype` by one). `test_authored_content` flagged the
loader's dangling ordinal, and a new test pins both shipped relays to what
they say they do.

**Tests:** 311 (+49): `unit/enemies/` covers the selector, gates, factions,
conditions, binding, relays (including the fuzz) and raids, using a shared
`helpers/ships.gd`.

---

## 2026-10-07 — The background rule swings out of the targeting computer

**Goal:** the background-rule badge borrowed the map's "!?" glyph and floated
in clear sky with nothing holding it up. It should be part of the cockpit.

**The monitor.** `EnvironmentMonitor` is a small hinged screen, drawn in the
targeting computer's palette, that lives folded away behind the computer
(`z_index -3`, so the computer's body hides it). When the background carries
a rule it rises leaning over and swings upright on its mast with an elastic
settle; in plain space it drops back out of sight, so the monitor appearing at
all is still the signal.

- **Screen:** a hazard triangle tinted to the rule's `color`. A rule that
  ships its own `icon` shows that untinted instead.
- **Lamp:** blinks in the rule's colour (the screen dims with it) until the
  monitor is clicked, then stays lit. This replaces the old alpha pulse.
- **Click:** the same InfoShower panel as before. The panel gets a
  self-coloured `environment_rule_icon.png`, since a tinted white glyph
  can't carry its colour into another scene.
- **Rule bites:** the monitor jolts on its hinge and its screen flares.
- It isn't clickable while stowed or in transit, so it never catches a click
  aimed at the targeting computer.

Named "environment" rather than "sector" because a sector is a stretch of the
run, and this rule belongs to the background.

---

## 2026-10-07 — Dice ride the jump, and the ones you hand over stay behind

**Goal:** dice used to vanish when a jump started and respawn at the start of
the next scenario. Now they're physical and persistent: the dice you still
have ride the jump with you, and any die an enemy is holding is left behind
with that ship, for good. Jumping takes a die, and that die is never on an
enemy, so the hand can't empty this way. Keeping hold of your dice is now a
decision, and because nothing pops in or out of existence, a player watches
the die get left behind.

**The rule.** If a die is in the player's inventory (hand, held by a tile, or
sitting on the tile that fired the jump), it comes along. If it's in an
enemy's queue, including one impounded across turns, it's lost. On
`Events.jump`, `Player._carry_dice_through_jump()`:

- brings the kept dice home and locks them until arrival (the scenario engine
  a tile would fire through is already shut down);
- **strands** enemy-held dice: pulls them out of every queue and the `Dice`
  group so nothing can hand them back, reparents them to their ship so they
  ride it off the bottom of the screen and behind the cockpit, flares each
  one with a red "LOST", and announces "-1 DIE" over the hand with a dread
  thunk and a small shake;
- fizzles holograms (they're borrowed light, not owned dice).

On arrival the carried dice are rerolled, and the hand only spawns new dice to
reach `num_of_dice`: the first scenario of a run, a Continue, or a die bought
since the last arrival.

**Saving.** Only the count is run-level state. The loss lands in
`num_of_dice` when the jump starts, but nothing is written until the
destination's arrival checkpoint, so quitting mid-jump reloads the fight being
fled with every die still owned. A mid-scenario restore tops the saved hand up
to `num_of_dice`, so a die on a tile when the save was taken isn't lost to it.

**Knock-on fixes:**
- Losing a die with a full drive pushed charge into the redline (the gate
  shrinks, the old charge stays), which bleeds hull every turn. A drive that
  wasn't redlined now stops at the new gate.
- `max_engine_charge` went to -1 at a single die, which a jump can now leave
  you with, and the engine bar divides by it. Floored at 1.
- Ships that survive a fight (civilians, shopkeepers) passed their dice to
  each other, not to the player, so those dice would now be lost on the next
  jump. They hand them home instead, and a sector advance waits two frames
  for them before jumping.

**Then content: seven tiles about how many dice you own.** "Fleet" is a new
keyword: every die you own wherever it is, plus the holograms you're holding.

| Tile | Colour, rarity, uses | Does | Juice |
|---|---|---|---|
| Swarm Battery | red, uncommon, 1 | A 2 damage shot per die in your Fleet | One zap, spark and ring per shot |
| Broadside | red, uncommon, 1 | 3 damage per die still in hand; fire it first | "BROADSIDE", screen ripple, big shake |
| Lone Wolf Lance | red, rare, 2 | X damage, tripled with a Fleet of 2 or fewer | Tripled: "LONE WOLF", glitch, red vignette, screen ripple, long hitstop |
| Skeleton Crew | blue, uncommon, passive | Turn start: 2 shields per die your Fleet is short of 5 | Shield motes stream from the tile to the hull |
| Phantom Squadron | yellow, rare, 1 | With a Fleet of 4 or fewer, holograms of the die until your Fleet reaches 5 | Cyan die flare and glitch per hologram |
| Debt Collector | green, uncommon, 2 | 4 damage per die the target is holding | Gold motes stream out of the ship, "PAY UP" |
| Repo Beam | purple, uncommon, 1 | 4 charge: pull back the target's newest die; both dice return | Closing lock-on ring, cyan beam, "REPO'D" |

They pull in different directions on purpose. Swarm and Broadside want a big
Fleet; Lone Wolf and Skeleton Crew want a small one; Phantom Squadron refills a
small one with holograms, which then turn Lone Wolf off. Debt Collector wants
you to pile dice onto one ship, exactly the dice a jump would strand, and Repo
Beam is the way to get one back before you leave.

New effects (appended): `SET_TO_DICE_OWNED`, `SET_TO_DICE_IN_HAND`,
`SET_TO_TARGET_DICE_HELD`, `IF_DICE_OWNED_IN_RANGE`, the `DICE_OWNED_AT_MOST`
activation check, and `RECEIVE_DIE_FROM_TARGET`, the ordinal the catalog had
kept reserved and unbuilt. Art is drawn on each colour's tile template.

**Found while testing:**
- The first callouts landed on the ship, under the damage number they were
  explaining. Callouts now float off the tile that fired.
- `ReceiveDieFromTargetHandler` didn't pass the chain's targets to its event
  (`_stamp()` doesn't copy them), so Repo Beam did nothing. Fixed, with a
  regression test.
- The dev console's `give` command broke into the debugger every time (an
  untyped array returned as `Array[String]`). Fixed separately.

**Verified live:** a die handed to the raider rode it off screen behind the
cockpit with "LOST" and "-1 DIE"; the count went 3 → 2 and the gate 10 → 4
with no redline; the save on disk stayed at 3 dice mid-jump and became 2 on
arrival; a Continue rebuilt 2 dice with the same faces as the live arrival; a
hologram fizzled on a jump without costing a die. Each tile fired against a
300-HP raider: Swarm 3×2, Lone Wolf tripled to 6 at a Fleet of 2, Broadside 6
with 2 in hand, Debt Collector 16 against 4 held dice, Phantom two 2-holograms
for a Fleet of 3, Repo Beam pulled a die back for 4 charge, Skeleton Crew +4
shields at turn start. 249 GUT tests pass.

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
