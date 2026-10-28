# Content Build Guide

How to add content by hand. Each section is the exact workflow, from files to
registration to testing. For how the systems work underneath, see
`ARCHITECTURE_OVERVIEW.md`.

---

## 0. Rules that apply everywhere

- **Enums stored in `.tres` are append-only.** These include
  `EffectEnums.*Subtype`, `TileEvent.EventType`, `ScenarioManager.ScenarioEvent`,
  `BackgroundModifierResource.Effect` and `ActivationResource.ActivationType`.
  Inserting a value mid-enum silently rewires every authored file below it.
  Count ordinals carefully when hand-editing a `.tres`. Better still, author in
  the inspector, where you pick by name.
- **EffectData: set `category` before `subtype`.** The category setter resets
  the subtype.
- **After adding a script with a new `class_name`**, rebuild the class cache:
  `/Users/drew/Documents/Godot/Godot_4.7_stable.app/Contents/MacOS/Godot --headless --path . --import`.
- **Art uses only the approved palette**, the 33 colours in
  `Assets/aseprite_palette_final.aseprite`. Outlines are `#040217` (never
  pure black). Alpha is free. The exceptions are white masks that get tinted
  in-engine (particle pixels, stars, smoke, shader masks), which stay pure
  white.
- **Before committing**, run the GUT suite:
  `.../Godot --headless --path . -s addons/gut/gut_cmdln.gd`.
  `test/content/test_authored_content.gd` loads every `.tres` under
  `Source/Content`. It catches stale effect ordinals, unknown status ids and
  empty chain slots. `test_effect_catalog.gd` pins every enum's ordinals.
- **Text conventions.** Keep descriptions terse. Say what happens, in order,
  and nothing else. Players work out strategy themselves, so there is no hint
  or flavour line.
  - Shape: `TRIGGER -> effect. effect. hand-off`. Sentences end with a full
    stop except the last. Verbs are imperative (`Deal`, `Gain`, `Apply`,
    `Spend`, `Give`).
  - The trigger is yellow: `Any die`, a die icon, or an event
    (`Hull hit`, `Enemy turn ends`, `Your turn starts`, `Adjacent tile
    activates`). A condition follows it with `while`
    (`Any die while fully charged`). Passive tiles use the same arrow.
  - Order: cost (`Spend`), main effect, side effects, then where the die goes.
    The standard ending is `Give die`, which means to `target`. Name any other
    destination (`Give die to random enemy`), or use `Return`, `Keep`.
  - Branches read `Label: effect`, as in `Odd: Feed up. Even: Feed down`.
  - `per` is for scaling (`2 shields per burn`). `equal to` is for copying a
    value (`damage to target equal to die`). `adjacent` is the four
    orthogonal tiles, `surrounding` is all eight.
  - Colours: `red` damage, hull and enemy intents that hurt, `blue` shields and
    holograms, `green` heals, re-rolls and tile movement, `purple` engine
    charge and targets (`target`, `random enemy`, `all ships`), `orange` dice
    hand-offs (`Give`, `Return`, `Keep`) and keywords, `yellow` triggers and
    die faces. Colour the number with its unit (`5 damage`, `2 shields`).
    Status amounts, `+N` and counts stay plain.
  - Tokens: `(die_N)` draws a die face.
  - `(amount)` and `(target)` fill in an enemy intent's rolled value and its
    bound ship. An enemy action reads like a tile minus the trigger, and the
    panel prefixes `Uses (die_N) ->`.
  - Keyword tokens like `(feed_right)` and `(burn)` render styled and
    underlined. Hovering one in the info panel pops up its rule (§9).

---

## 1. Tiles

**Files**
- Art: `Assets/Textures/Tiles/<Colour>Tiles/<name>.png` (keep the `.aseprite`
  beside it).
  - Colour by role: Red attack, Blue defence, Green die tricks/movement,
    Purple engine, Yellow support/buffs.
  - Tiles are 24×24. An unlimited tile is a single frame, `<name>.png`.
  - **The lower panel shows which dice the tile takes**, matching its
    `activation_checks`. The marker is a 7×7 slot in the darkest shade of the
    tile's ramp, with pips in the panel's mid shade:
    - any die (including checks that aren't about the value, like charge,
      combat or holograms): a blank slot;
    - one value: that die face (Flashpoint 6, Chaff Pod 1);
    - two values: both faces side by side, slots at x=3 and x=11
      (Chaos Explosion 5+6, Leeching Shot 1+2);
    - a run: a 4×7 `<` or `>` chevron before the face (Bump `<6` for 1-5).
    - `CANT_BE_ACTIVATED_WITH_DIE`: no lower panel at all, only the
      coloured outline, with the art centred in the tile (Emergency Shield).
  - **A limited-use tile must show its uses.** It is a horizontal strip,
    `<name>-Sheet.png`, of `uses_per_turn + 1` frames. `Tile` shows frame
    `uses_remaining`, so frame *k* has *k* white lights lit and frame 0 has
    none. Bump is the reference. The lights are 2×2 slots on the right edge
    of the lower panel, stacked up from the bottom, lit `#cef0f1` and unlit
    `#070326`, outlined in the tile's own border colour. There is room for
    three, so uses top out at 3.
  - Don't draw the lights by hand. Draw the tile as one frame, then run
    `tools/add_use_lights.lua` (usage at the top of the script). It turns the
    `.aseprite` into the frames and exports the sheet. Then import
    (`Godot --headless --path . --import`) to get the sheet's uid, and
    `git rm` the old single-frame png and its `.import`.
  - If a tile's uses change later, rebuild its sheet from the single-frame
    art (`git show` the old png, or frame 0 with the lights painted out). The
    script refuses an already-multi-frame file.
- Resource: `Source/Content/Tiles/TileResources/<name>.tres` (a
  `TileResource`). It must sit **directly** in that folder, not in a
  subfolder.

**Registration:** none. Any `TileResource` in that folder is automatically:
- in the reward and shop pools (`RewardManager`), weighted by `rarity`;
- saved by its filename id (`ContentRegistry`). Filenames must be unique, and
  renaming one breaks existing saves that hold it.

**Fields**
- **Info**
  - `tile_name`: bbcode-coloured to match the tile's colour.
  - `activation_description`, `description`: say what the die does,
    e.g. `[color=yellow]Any die[/color] -> ...` (see the text conventions at
    the top).
- **`rarity`** sets both drop weight (COMMON 1.0 / UNCOMMON 0.45 / RARE 0.18)
  and shop price.
- **`textures`**: a SpriteFrames whose `default` animation holds AtlasTexture
  frames cut from the png (24×24 regions). A limited tile lists one
  AtlasTexture per sheet frame, in order: `Rect2(0, 0, 24, 24)`,
  `Rect2(24, 0, 24, 24)`, ... The frame count must equal
  `uses_per_turn + 1`, otherwise the lights show the wrong count.
- **`uses_per_turn`**: -1 for unlimited. Uses are a per-turn budget. Strong
  payoffs should cost something else (charge, hull, a die). Changing it
  means rebuilding the sheet (see Art above).
- **`activation_checks`**: `ActivationResource`s, e.g. `REQUIRES_ACTIVATOR_DIE`,
  `VALUE` with `acceptable_values`, `IN_COMBAT`, `SHIP_TARGETED`,
  `CHARGE_AT_LEAST`, `TILE_DATA_AT_LEAST` (the tile's own `effect_data`
  under `data_key`; Slingshot waits for a ring step). A refused die goes back
  to the hand. A tile whose payoff can come to nothing (a count at 0, no
  shields to spend) should refuse rather than eat the die.
- **`effect_chain`**: see §7 for authoring.
  - The standard ending is `TARGET_WITH_TARGETING_COMPUTER` then
    `GIVE_DIE_TO_TARGET`. The die always goes to the targeted ship, which is
    the core trade of the game.
  - Feed tiles end with `PASS_DIE_TO_TILE` instead.
  - Holding tiles end with `KEEP_DIE_WITH_TILE`.
  - **Boost** (an optional charge cost): an `IF_CHARGE_AT_LEAST` conditional
    (`amount` = cost) whose true branch spends it (`TARGET_PLAYER`, an Engine
    `STREAM`, `SPEND_ENGINE_CHARGE`) then does the extra. The tile still works
    without the charge, so it takes no `CHARGE_AT_LEAST` check. Text:
    `(boost) [color=purple]3 charge[/color]: Apply 3 (burn)` (Sunlance).
  - **Rows**: `IF_SOURCE_IN_ROW` (`range_min`-`range_max`, 0 = top) for a tile
    that does more in part of the grid. On the Carousel's turning ring that's
    part of each lap (Apex Cannon, Keel Plating). Text: `[color=yellow]Top
    row[/color]: +3`.
- **`event_responses`**: `TileEvent` → `EffectChain` for reactive tiles
  (`ON_TURN_START`, `ON_ENEMY_TURN_OVER`, `ON_PLAYER_HEALTH_HIT`, ...). A tile
  can take no dice at all and live only on these. `ON_TURN_START` also fires
  for a fight's opening turn, but only after `Events.enemies_arrived` (every
  ship landed and targeted), so it is safe to target enemies from it.
  - Event responses skip `activation_checks`. A response that can fire
    outside combat (`ON_PLAYER_SHIELDS_GAINED`, since shield tiles work
    anywhere) and hits a random enemy must wrap its chain in `IF_IN_COMBAT`,
    or it can attack a merchant (Repulsor Field).
  - A tile that spends or cashes in shields gates on `SHIELDS_AT_LEAST`, and
    pays with `SPEND_SHIELDS`, not a negative `SHIELD`: that would read as a
    hit and set off anything listening for one.
- **`dragging_allowed`, `max_dice_in_queue`**: rarely touched.

**Loop rule for Feed tiles:** a tile with unlimited uses may only Feed
**right**. Feeding up, down, left or randomly needs limited uses, so every loop
on the grid runs dry.

**Relays are always limited, to 1 or 2 uses.** A relay takes any die, acts and
Feeds it on, so with unlimited uses one die chains through every relay for
free. Use 2 for modest effects (Signal, Surge, Toll, Afterburner Relay, and
Relay Terminal) and 1 for the biggest per-die hit (Leech Relay).

**Test:** run the game and get the tile onto the grid, then open the dev console
with `` ` ``. `set_dice 1 2 3`, `reset_uses` and `charge_engines` help set up a case.

---

## 2. Enemy actions (intents)

**Files**
- Art: `Assets/Textures/Enemies/IntentIndicator/<name>.png` (7×7 intent) and
  `<name>_info.png` (24×24 info panel).
  - Palette: pale die `#CEF0F1`, pips `#343330`, shadow `#8E8B85`, plus the
    action's accent.
- Resource: `Source/Content/Enemies/EnemyActions/EnemyActionResources/<name>.tres`
  (an `EnemyActionResource`).

**Fields**
- `name`, `description` (use `(amount)` and, for bound actions, `(target)`).
- `indicator_texture`, `info_texture`, `effect_chain`.
- `intent_amount` here is only a placeholder. The option that rolls the action
  sets the real value.

**Chain shape:**
1. Visuals and sound.
2. Targeting.
3. `SET_TO_ENEMY_INTENT` (puts the rolled amount into the running amount).
4. The effect.
5. A die hand-off.

Every action must end the die's life one of these ways:

| End step | The die... |
|---|---|
| `GIVE_DIE_TO_TARGET` (after `TARGET_PLAYER`) | goes to the player, as in attacks |
| `GIVE_DIE_TO_PLAYER` | goes back home |
| `KEEP_DIE_WITH_ACTOR` | is held for next turn (Impound) |
| `FEED_ALLY` | is passed to the bound ally, who uses it at once (Relay) |
| `SPAWN_HOLOGRAM_FOR_ALLY` | hologram goes to an ally (Holo Loader); still return the real die |
| `ESCAPE_WITH_DICE` | leaves with the ship, with every other die it holds; the player loses them for good (Getaway) |

**Targeting another ship:** use `TARGET_BOUND_ALLY` or
`TARGET_BOUND_HOSTILE_SHIP`, never the random ones. The ship is then picked
when the slot is rolled, named in the intent, and marked under the ship, and
the action is only rolled when such a ship exists. A relay needs no targeting
step; its ally is bound automatically. The binding never moves: if that ship
leaves, the action can't happen, and a die spent on it pops a "?" and does
nothing (`EnemyActionResource.get_outcome()` is `BLOCKED`). Jammed isn't spent
on such a die, or on any die whose action does nothing.

**Damage kinds:** `DAMAGE` goes through shields into the hull.
`ION_DAMAGE` (Ion Shot) takes twice the amount off the shields and never
reaches the hull; what the shields can't absorb is lost. Write it as
`Deal [color=blue](amount)[/color] (ion_damage)`.

**Drains:** an enemy taking engine charge uses `SIPHON_ENGINE_CHARGE` (amount
= running_amount, `color` = the motes), not a STREAM plus a negative
`CHANGE_ENGINE_CHARGE`: it drops the gauge before each spurt of motes, so the
loss reads first. Any other drain-and-stream chain should likewise change the
value before its STREAM.

**Derived automatically, nothing to set:**
- Threat (tractor-beam colour). Damage aimed at the player is DANGEROUS
  (ion damage too).
  Damage aimed at a bound ship is not.
- Hidden-safety: anything that flees or jumps is never rolled while intents
  read "?".
- Binding kind.

---

## 3. Enemies

**Files**
- Art: `Assets/Textures/Enemies/<Name>/`.
  - Hull sprite: ~32×32 (wider for capital ships).
  - `<name>_targeting_image.png`: 16×16. It is also the enemy's portrait in
    the main menu's codex, drawn grey until the player meets the ship.
- Ship graphics scene: `Source/Content/Enemies/EnemyShipGraphicScenes/<name>_ship_graphics.tscn`.
  Copy `attacker_ship_graphics.tscn`.
  - The root **must** be a `Sprite2D` whose material is a
    `resource_local_to_scene` ShaderMaterial using `enemy_shader.gdshader`.
    The flash, fade and cloak effects drive its parameters.
  - Add `engine_particles.tscn` children at the exhausts.
- Resource: `Source/Content/Enemies/EnemyResources/<name>.tres` (an
  `EnemyResource`).

**Fields**
- `enemy_name`, `description`.
- `in_codex`: untick for a ship that isn't a foe (the shop, the repair dock,
  the civilian transport), so the codex leaves it out of its enemy list.
- `max_health`, `starting_shields`. Both are scaled +35% per sector.
- **`action_options`**: one or more `EnemyTurnActionList` pools. Each holds
  `EnemyActionOptionResource`s:
  - `base_action`, `weight`.
  - `min_amount`/`max_amount`: the rolled intent. Scaled +20% per sector,
    except a Holo Loader's face.
  - `force_include`: always present once. Weight 0 plus `force_include` means
    exactly one. Except under the sector's variety cap (see below), which
    can leave its kind out of a turn entirely.
  - `fills_kept_faces`: never rolled normally (`weight` and `force_include`
    are ignored). One copy goes on the face of each die the ship kept itself
    last turn with `Keep Die with Actor`, and it appears nowhere else. For a
    payoff the player only faces after loading it (Charge Bore → Siege Shot).
  - `conditions`: `EnemyActionCondition`s, all of which must hold. Types:
    `ALLY_EXISTS`, `HOSTILE_SHIP_EXISTS`, `ALLY_HURT`, `SELF_HURT` (with
    `hull_fraction`), `ATTITUDE_IS`, `ALLIES_AT_MOST` (with `count`; gate a
    launcher on it so it can't fill the board), `SELF_HAS_STATUS` (with an
    optional `status_id`; gates Purge Vents), plus `invert`.
  - `situational_weights`: `EnemyActionWeightRule` = a condition and a
    multiplier.
  - `strength_tier_override`: how strong the action counts as for
    `face_bias`, on the threat scale (0 nothing, 1 something, 2 damage).
    -1 reads it off the chain. Raise it for actions the chain undersells
    (Lockout, Impound, a Relay into a heavy hitter).
- **Variety cap:** a table mixes at most 2 kinds of action in sector 1 and
  3 in sector 2, any number after (`GameStateManager.action_kinds_per_sector`).
  A kind is the action's `name`; Do Nothing and kept-face payoffs don't
  count. Each turn the kept kinds are drawn weighted by how many slots each
  would fill, so heavy weights are a ship's identity in early sectors. A
  ship whose `force_include` options alone name more kinds than the cap won't
  always show them all (the Ion Lance's Siphon + Quake, the Tender's Repair +
  Aegis): check how it reads in sector 1. Boss ships (the boss faction,
  i.e. every part of a gate fight) get one more kind wherever there's a cap
  (`boss_bonus_action_kinds`), so a sector-1 boss mixes 3.
- **`face_bias`**: which faces the strong actions lean toward. Defaults to
  0.5, a gentle lean toward high faces for every enemy; leave it there unless
  the ship should break the rule. Positive pushes strong actions onto high
  faces, so the 6 is the die to fear; negative onto low faces; 0 places them
  at random. ±1 is a clear lean. A pool can set its own with
  `override_face_bias`.
- **`pool_selection`**: which pool a turn uses.
  - `TURN_CYCLE`: rhythm, e.g. charge then fire.
  - `HEALTH_THRESHOLD`: escalates as it's hurt.
  - `SQUAD_LOSSES`: reacts to its side dying.
  - `COMBAT_ROUNDS`: a timer.
- **Graphics:** `ship_graphics_scene`, `graphics_scene_offset`,
  `dialogue_offset`, `targeting_computer_image`, `health_bar_position`,
  `dice_queue_position`, and `formation_width` (real hull width for big
  ships). The formation spaces ships by hull *and* health bar, so a bar can
  hang off the side without landing on a neighbour; when a crowded board
  can't fit that, every bar moves to `compact_health_bar_position` (default
  just above a 32px hull). Set it for a ship whose hull is much taller.

**Faction** isn't on the enemy; it's on the scenario's ship state (§4). Who
allies with whom, and who raids whom, is `FactionRelations`
(`Source/Systems/Game/ScenarioManager/faction_relations.gd`). Behaviour that
only makes sense in some encounters, like raiding, should go on a variant
enemy resource (e.g. `raider.tres`), not on a shared one.

**Launched ships** (the Carrier's Interceptors): `SCENARIO_CONTROL /
LAUNCH_SHIP` with `ship_resource` set brings that enemy in beside the actor,
on its side and in its scenario state. It drops no reward of its own (its
side's bounty still waits on it), isn't saved (a Continue rebuilds the
authored roster). Once `EnemyManager.max_ships_in_combat` ships are up, a
die spent on a launch pops a "?" and does nothing ("HANGAR JAMMED" is the
backstop if two launches race).

**Overload** (optional): `overload_threshold` (held-dice total that trips
it; 0 = never), `overload_threshold_growth`, `overload_chain` (what tripping
does to the ship, usually TARGET_SELF + DAMAGE), `overload_gauge_position`.

**Registration:** none. An enemy exists once a scenario spawns it.

---

## 4. Scenarios (encounters)

**Files**
- Folder: `Source/Content/ScenarioResources/Scenarios/<KIND>_<Name>/`, where
  KIND is `COMBAT`, `EVENT`, `ELITE`, `GATE`, ... Subfolders are fine here, unlike tiles.
- `<name>.tres` (a `ScenarioResource`) plus one `.tres` per ship state it
  uses. `0GenericShipStates/pirate_combatant.tres` is a reusable plain
  aggressive pirate.

**ScenarioResource fields**
- **`map_icon`**: from `Assets/Textures/Map/EncounterIcons/` (enemy, elite,
  unknown, shop, healing...). An elite uses `elite_encounter.png`, a boss gate
  `jump_gate.png`.
- **`background_resource`**: a `RandomBackgroundResource` pool, usually
  `RandomBackgroundResources/all_basic_backgrounds.tres`. An encounter built
  around a hazard points at a one-background pool instead
  (`solar_corona_only.tres`, `ion_storm_front_only.tres`, ...). A place
  whose rule contradicts it uses a variant pool: `includes_pool` the basic
  one and list the clash in `excluded_backgrounds`
  (`repair_station_backgrounds.tres` drops Bloodhaze's Red Nebula).
- **`starting_enemies`**: one `EnemyStateRewardResource` per ship:
  - `enemy_resource`, `starting_state`, `reward_resource`.
  - `starting_health_fraction`: start it pre-damaged.
  - `path_location_override`: leave at -1; the formation places ships.
  - `mounted` / `mount_offset`: this ship is a part of the scenario's `hull`
    (below), seated at that offset from the hull's centre.
- **`rewards`**: Faction → `RewardResource`, paid when the player destroys a
  faction's last ship. A last ship that flees or escapes takes it along.
- **`starting_reward`**: an optional pickup floating on arrival, at
  `starting_reward_position` (default `(160, 60)`, clear of the systems
  panel). It reserves its stretch of the formation, so a lone ship beside a
  centred offer is squeezed toward the screen edge with no room to speak:
  move the offer aside (Mayday's sits at `(230, 60)`).
- **`sector_gate_scenario`**: only for a boss gate (and `GATE_open`). Fate
  never takes these, and winning one opens the gate instead of emptying it.
- **`boss_title` / `boss_subtitle`**: set on a boss fight to play the intro
  card. The portrait is the toughest starting ship's targeting image.
- **`announce_region`**: leave on. Off for a stop whose own panel opens on
  arrival (shop, repair station): its region card is skipped.
- **`hull`**: a `ShipHullResource` (`hull_scene` whose root is a `ShipHull`,
  `path_location`, `offset`, `width`) for a boss built from parts. See
  `GATE_Bastion` and `Source/Content/Enemies/ShipHull/`. Each part is an
  ordinary enemy with its own art, resource and table.

**Ship states** (`ScenarioShipState`, one `.tres` each)
- `dialogue`. The speech box holds four lines of about ten characters, and
  three read best, so keep a line to roughly 35 characters. A fifth line
  spills out the bottom.
  - **One voice per side.** Allied ships don't talk over each other: give
    one ship the line and leave its allies' `dialogue` empty (e.g.
    `FateScenario/fate_attacker_silent.tres` for the Rift's extra ships).
    Two ships speak at once only when they're on opposite sides, each
    telling its half of the story (the pirate and the civilian in
    `EVENT_PiratesAttackingCivilian`).
- `faction`: PIRATE, CIVILIAN or BOSS. Also picks the speech-box colour.
- `attitude`: an AGGRESSIVE ship puts the scenario in combat, and intents are
  only readable while one is present. With only FRIENDLY or NEUTRAL ships,
  every table reads "?" and is rolled hidden-safe.
- `effects_on_enter`: a chain run on entering the state, e.g. heal the
  player, open the shop. A starting state's chain (and its dialogue) runs
  once the ship has flown in, not on arrival.
- `transitions`: `ScenarioEvent` → next state. Events:

| # | Event |
|---|---|
| 0 | `PLAYER_ATTACKED_PIRATE` |
| 1 | `PLAYER_ATTACKED_CIVILIAN` |
| 2 | `PLAYER_LEFT_SCENARIO` |
| 3 | `COMBAT_ENDED` |
| 4 | `PIRATES_DEFEATED` |
| 5 | `CIVILIANS_DEFEATED` |
| 6 | `BOSS_DEFEATED` |
| 7 | `PLAYER_TOOK_REWARD_TILE` |
| 8 | `PLAYER_TOOK_REWARD_MONEY` |
| 9 | `PIRATE_ATTACKED_CIVILIAN` |
| 10 | `PLAYER_COULDNT_PAY` (a STEAL_MONEY came up short) |

- For a random branch, point a transition at a
  `ScenarioShipStateProbabilityTransition` (`weighted_probabilities`).
- **Never let two state files reference each other**, A→B and B→A. Godot
  can't load circular `.tres` references. Route around it with a third state.

**RewardResource:** `min_money`/`max_money`, `num_of_rewards` (tile offers),
`dice_probability` (chance an offer is a die instead),
`min/max_money_pickup` with `money_pickup_probability` (chance that money
option shows up), and `minimum_rarity`.

Tiles come from one pick per fight, not one per kill, so the grid fills slowly:
- Combats and elites put the pick on the PIRATE faction bounty, and every ship
  pays credits only (`num_of_rewards = 0`). Combat bounty: `dice_probability`
  0.25 and a 12-20 money option at 0.5. Elite bounty: RARE floor, 0.25 dice and
  a 25-40 money option at 0.5. Bosses keep a RARE pick on the boss itself.
- Bounty Run is the exception: the runner carries the pick, so letting it
  escape costs the tile.
- Only one of a ship's reward and its faction's bounty may offer picks.
  `test_no_ship_and_faction_reward_both_offer_picks` enforces it, because
  both offers would open on the same wreck.

**Registration** (required): open `Source/Scenes/main.tscn`, select
**GameStateManager**, and add the scenario to the right list:
- `combat_scenarios` or `question_scenarios` (events): the random sector mix.
- `elite_scenarios`: the elite pool (`elites_per_sector` per sector).
- `gate_boss_scenarios`: the boss guarding each sector's gate, in order.
- Fate's encounters go on the **Map** instead (`main_viewer.tscn`):
  `fate_scenario` and `fate_variants`. (GameStateManager's `fate_scenarios`
  is unused.)
- Or set the single slots: `starting_scenario`, `shop_scenario`,
  `repair_scenario` (1-2 a sector, swapped in past a jump from the arrival),
  `empty_scenario`. The open gate is `Map.open_gate_scenario`
  (`main_viewer.tscn`).

`ContentRegistry` picks up every ScenarioResource under `Scenarios/` for
saves, keyed by filename, which must be unique.

**Test:** temporarily set `starting_scenario` to it (don't commit that), or
use `Source/Content/ScenarioResources/Scenarios/TEST/test.tres` as a scratch
encounter.

---

## 5. Backgrounds and background rules

**Background** (`Source/Resources/BackgroundResources/<name>.tres`, a
`BackgroundResource`)
- `background_color`.
- Nebula and star toggles and counts. `nebula_material` swaps the
  standard one-colour nebula for a place whose sky is its own weather (the
  Ion Storm Front's `IonStorm/ion_nebula.tres`). Its shader must take
  `sprite_nebula.gdshader`'s `uv_offset` and `nebula_color`.
- `scrolling_objects`: what drifts past at varying depths, with
  `num_of_med_pieces` / `num_of_large_pieces`. Pick a set from
  `ScrollingObjects/` (`triangle_debris`, `asteroids`, `ice`, `ship_scrap`,
  `fate_shards`, `solar_embers`, `ion_motes`), or make a new
  `ScrollingObjectsResource`: medium and large piece-scene lists, plus whether
  pieces keep their own colours or become flat silhouettes, and whether they
  take random quarter turns (off for art lit from a fixed side) or mirror
  flips.
- A piece is a small scene under
  `BackgroundManager/BackgroundObjects/ScrollingPieces/<set>/`. A plain one
  is just a `Sprite2D` root with the texture; animate it or add particles
  freely. Every node without its own material takes the depth fade, so the
  whole piece dims with distance; give a node a material only to opt it out
  (a light that should glow at any depth). Sprites and `AnimatedSprite2D`s
  set the piece's size for wrapping; particles don't, so keep them close.
  A piece is freed when it wraps, so particles never streak across the
  screen; set `preprocess` if an emitter shouldn't start empty. Particles
  left in world space (`local_coords` off) hang behind a falling piece as a
  trail, like the embers'.
- Two scripts in `ScrollingPieces/` animate a piece without code:
  `PieceFrames` on a `Sprite2D` sheet steps its frames (a `sequence` can hold
  frames, e.g. a run of blanks between rare lightning), and `PiecePulse`
  throbs a sprite's brightness (the cinders' cracks). Both start each copy at
  a random point, so a field of pieces never pulses in step.
- **Shader per set.** A set's `shader` replaces the plain depth fade for all
  its pieces. It must take `scrolling_object.gdshader`'s uniforms, and gets a
  fresh `seed` per piece. `fate_shards` uses `fate_corruption.gdshader`,
  which animates Fate eating the piece. Fate pieces follow its rules:
  single-frame textures with a 1px clear border (the seam spans the whole
  texture, and the rim light needs empty neighbours), dark indigo stone, and
  pure `#000000` wherever Fate has already eaten in. The shader fills that
  void with crawling static, so paint the bite, not the static.
- **Angles.** The game draws at 6x zoom, so a sprite turned in-engine tilts
  its big pixels. For any angle finer than a quarter turn, bake the angles
  into a sheet and put `PieceVariant` on the `Sprite2D`. It shows one random
  frame and holds it (the ship-scrap girders, plates and containers). The
  set's `random_flip` mirrors pieces left to right, and is pixel-clean. Light
  such art from straight above so a flip keeps it lit from above, and turn
  `random_quarter_turns` off.
- `static_objects` (`StaticBackgroundObjectResource`: a scene + position, e.g.
  the pulsar). Only for placed set pieces; anything that just drifts by
  belongs in `scrolling_objects`. `FateStorm` (placed at `(0, 0)`) is Fate's
  weather: sheet lightning, bolts and void tears. Each flash sets the global
  shader uniform `fate_flash`, which rims the fate shards. It quickens and
  fires a barrage with a Fate Rift hazard. Use it only near Fate.
  `IonStorm` (also at `(0, 0)`) is the Ion Storm Front's: bolts in view, or
  unseen strikes just off screen that only light the near cloud. Each
  writes the global `ion_flash` (centre, strength, reach), which
  `ion_nebula.gdshader` reads to light the cloud from where the lightning
  is. Both storms grow their bolts with `LightningBolt`. Lightning stays
  photosensitivity-safe: strikes at least `IonStorm.MIN_GAP` (1 s) apart,
  flicker that never drops fully dark, and a faint full-screen wash at
  most.
- Planets, moons and stars are `CelestialBody` scenes in
  `BackgroundObjects/CelestialBodies/`, drawn live by
  `pixel_planet.gdshader` (the main menu's planet). Make a new one by
  duplicating the closest design and editing its `Body` material: palettes
  are inline `GradientTexture1D`s, ordered low to high noise; a gas giant's
  bands come from a striped `surface_bump_map`. Stars use shading mode Max
  Brightness so the corona isn't shaded like a lit sphere. Each copy turns to
  a random face. Put far copies at a dimmer `modulate`, and flip
  (`scale = (-1, 1)`) to light one from the other side, e.g. toward the
  solar corona's star.
- **Planets go in `set_piece_compositions`, not `static_objects`.** Give a
  planet background three or four `SetPieceComposition`s (e.g. planet and
  moon on the left, the planet on the right with a different moon, a lone
  far body), each a list of `StaticBackgroundObjectResource`s plus a
  `weight`. The game picks one per visit, slides it by `offset_jitter`,
  may mirror it (`mirrorable`), and varies each body by its `size_jitter`
  (0.1 for planets, 0.15-0.2 for moons) and `position_jitter`. Author it
  for one side only. Keep bodies in the top corners, out of x 112-208 and
  with centres no lower than y 64 at full jitter
  (`test_background_set_pieces.gd` checks). Light every body in a
  composition from the same side: toward the screen centre, or toward the
  composition's star (shader planets are lit from the right, the dead world
  from the left; flip to swap). Vary only shape, place and light, never the
  palette. An empty composition is open space, where the stars drift.
- **Stars.** Where anything is on screen besides stars and nebula (set
  pieces or scrolling objects), the stars hold still between jumps; only
  open space drifts. Nothing to set: `BackgroundResource.anchors_the_view()`
  works it out.
- `global_modifier`: an optional permanent rule that suits the place
  (the pulsar strips shields, shrapnel doubles damage; see
  `test_background_rules.gd`, which pins the pairings), **or**
- `hazard`: an optional timed event (§6). Never both: the environment monitor
  has one screen.

To make a background appear, add it to a pool's `eligible_backgrounds`
(`RandomBackgroundResources/all_basic_backgrounds.tres`), or make a new pool
for specific scenarios. A pool can also take in another (`includes_pool`)
minus some backgrounds (`excluded_backgrounds`).

**Rule from an existing effect:** create a `BackgroundModifierResource` in
`BackgroundModifiers/`:
- `modifier_name` (a place name, caps on the banner), `description`, `color`,
  optional `icon`.
- `effect`: SHIELD_BLACKOUT, DOUBLE_DAMAGE, REPAIR_BLACKOUT, ENGINE_BLACKOUT,
  REROLL_BLACKOUT, NO_REPETITION or AMOUNT_CAP (with `amount_cap`).

**New kind of rule:**
1. Write a `Modifier` subclass in `Source/Behavior/Modifiers/BackgroundModifiers/`.
   Copy `shield_blackout_modifier.gd`. Use `on_before_event()` to cancel or
   adjust, and call `announce_triggered()` when it changes something.
2. **Append** a value to `BackgroundModifierResource.Effect`.
3. Return the new modifier from `create_modifier()`.

---

## 6. Hazards (timed backgrounds)

A hazard belongs to a background, not a scenario: the place itself goes off.
`Source/Resources/BackgroundResources/BackgroundHazards/<name>.tres` (a
`BackgroundHazardResource`):
- `hazard_name`, `description`, `color`.
- `icon`: 9x9 at most, from `Assets/Textures/TargetingComputer/HazardIcons/`.
  It sits beside the countdown digit on the environment monitor.
- `timing`: `YOUR_TURN_STARTS` (after the hand is rolled) or
  `YOUR_TURN_ENDS` (once the dice the player spent have landed with the
  ships, before any ship uses them). Anything that changes dice belongs at
  turn end: at turn start the hand is freshly rolled, so re-rolling or
  flipping it changes nothing the player has committed. Aim those at
  `TARGET_ENEMIES` → `REROLL_TARGETS_DICE` / `FLIP_TARGETS_ONES_AND_SIXES`.
- `turns_until_first`, `turns_between`: counted in the hazard's own trigger
  points. Start the description with that trigger (`Your turn starts ->`).
- `effect_chain`: what fires, e.g. `TARGET_ALL_SHIPS` → amount → `DAMAGE`. It
  runs with the player as actor and no die.

Assign it to a background's `hazard`, and give that background art that shows
it coming. The countdown on the environment monitor is automatic; background
objects that should react to it extend `HazardTelegraph`
(`BackgroundObjects/hazard_telegraph.gd`) and override `_urgency_changed()`
(the hazard fires next turn, or has calmed) and `_fired()`. See the flare star,
ion storm, meteor shower and rift tear for examples. Drive their visuals with
`self_modulate`: `BackgroundManager` owns `modulate`.

---

## 7. Effects

**Authoring a chain (inspector):**
- An `EffectChain` is an ordered list of `EffectData`. Pick `category`, then
  `subtype`; only the fields that effect reads are shown.
- Conditionals must be **`ConditionalEffectData`** (with
  `if_true_effects`/`if_false_effects`), not plain EffectData.
- The running amount is reset each repetition. AMOUNT_MODIFIER steps build it
  (SET, ADD, MULTIPLY, SET_TO_DIE_VALUE, SET_TO_ENEMY_INTENT, ...) and the
  ATTRIBUTE_CHANGE steps consume it.
- Visual flourishes (`AUDIO_VISUAL`: SHOCKWAVE, SPARK_BURST, CALLOUT, ZAP,
  STREAM, LASER, MISSILE, ION_BOLT, ...) play at the current targets. ZAP,
  STREAM, LASER, MISSILE and ION_BOLT hold the chain until they land.
  ION_BOLT aims at the target's shields (the player's shield counter). Tick `juice_flags` for
  how they move: Rise (sparks drift up, for gains), Outward (a stream flows
  out of the source), Engine (the player's end of a stream or callout is the
  engine gauge), Hull Hub / Engine Hub (the stream's own end is the player's
  health bar / engine gauge instead of the tile, e.g. a drain that heals).
- **Only throw a die at a ship that keeps it.** ATTACK_TWEEN flies the die at
  the target, which reads as handing it over, so use it only when the chain
  then gives the die to that target. A tile that hits but keeps or passes its
  die (relays, recoil, return-to-hand) fires a LASER or MISSILE instead
  (`amount` = beam hold / flight in msec, 0 = default; `color`). A content
  test enforces this. Enemy actions follow the same rule: the Ion Shot
  fires an ION_BOLT and ends `GIVE_DIE_TO_PLAYER`.

**Adding a new effect type:**
1. **Append** a value to the right enum in
   `Source/Behavior/Effects/effect_enums.gd`.
2. **Event** (if it changes game state):
   `Source/Behavior/Effects/EffectEvents/<Category>/<name>_event.gd`.
   - `extends EffectEvent`, with typed fields for its data and
     `resolve(engine)` doing the work.
   - Override `is_amplifiable()` → false if `amount` isn't an output, e.g. a
     face value, duration or price.
3. **Handler:**
   `Source/Behavior/Effects/EffectHandlers/<Category>/<name>_handler.gd`.
   - `extends EffectHandler`, `apply(data, context, engine)`.
   - Build the event, `_stamp(event, context)`, copy
     `context.targets.duplicate()` and the amount, then
     `engine.inject_event(event)`.
   - Handlers don't mutate state themselves.
   - Die hand-offs should only act when `context.repetitions == 0` (the last
     repetition).
4. **Catalog row:** in `Source/Behavior/Effects/effect_catalog.gd`, at the same
   position as the enum value:
   `{category = ..., subtype = ..., label = "...", handler = MyHandler, fields = ["amount", ...]}`.
   - `fields` lists which EffectData fields the inspector shows. Choose from
     `KNOWN_FIELDS`.
5. **Pin it:** append the enum name to its list in
   `test/unit/effects/test_effect_catalog.gd`.
6. Rebuild the class cache, then run the tests. `EffectCatalog.validate()` also
   fails loudly at startup if the enum, catalog and handler disagree.

**Variations:**
- **New conditional:** append to `ConditionalSubtype`, add a match arm in
  `ConditionalHandler._evaluate_condition()`, and add a catalog row pointing at
  `ConditionalHandler`.
- **New amount modifier or targeting step:** handler only, no event. It just
  writes `context.running_amount` or `context.targets`.
- **Effect used by enemy actions:**
  - If it shouldn't count as a threat to the player, add it to the exclusion
    lists in `EnemyActionResource._has_consequence()`.
  - If it removes the ship from play, add it to `is_safe_while_hidden()`
    (`FLEE`, `JUMP` and `ESCAPE_WITH_DICE` are there).
- **Data a chain needs from its caller:** add a field to `EffectContext`
  (`effect_context.gd`).

---

## 8. Statuses (stack-based debuffs)

Statuses go on enemies and on the player. The same status works on both, so
a new one needs a rule for each side.

1. Subclass `StatusModifier` in `Source/Behavior/Modifiers/Statuses/`. Copy
   `burn_status.gd` or `exposed_status.gd`. Set `status_id`, `display_name`,
   `color` (a `Globals` palette colour), `icon`, `info_icon` and `priority`,
   and implement its hook. Where it touches dice, branch on
   `is_on_player()`: an enemy spends dice on its table, the player places
   them on tiles (`JammedStatus` and `ScrambledStatus` show both).
2. Add it to `StatusCatalog._statuses` (`status_catalog.gd`), keyed by id.
3. Art: `Assets/Textures/Statuses/` (11×11 badge, 24×24 info).
4. Add a keyword for it (§9). If it reads differently on the player, add a
   second term, `<Name> (you)`, and a token for it (`(jammed_you)`): the
   player's badge shows that rule, and enemy actions aimed at the player use
   that token.
5. Apply it with `ATTRIBUTE_CHANGE / APPLY_STATUS`: `string_param` = id,
   running amount = stacks. Test with dev console `status <id> [stacks]` on a
   targeted enemy, or `status <id> [stacks] me` on yourself.

**Enemy actions that put a status on the player** follow the usual chain
shape: `TARGET_PLAYER`, a shot that doesn't carry the die (ZAP, LASER,
MISSILE), `SET_TO_ENEMY_INTENT`, `APPLY_STATUS`, then `GIVE_DIE_TO_PLAYER`
(Incendiary Shot, Target Lock, Jamming Pulse, Scrambler). They read as
`DANGEROUS` without anything to set. Purge Vents moves the ship's own
statuses onto the player (`TRANSFER_STATUSES`); gate it on
`SELF_HAS_STATUS`. A tile that puts a status on its own ship (Blowtorch)
targets the player for that step; its Amplifier doesn't grow it.

## 9. Keywords

In `Source/Systems/keywords.gd`:
1. Add the rule text to `_DEFINITIONS` under its term.
2. Add each token spelling to `_TOKENS` (`"(my_kw)": {"label": ..., "term": ...}`).

Write `(my_kw)` in any description. It renders styled and underlined, and the
info panel shows its definition in a pop-up while the player hovers it. A token
row may set `"color"` where the word follows another colour rule (holograms are
blue). Keep the rule to a sentence or two in the same terse style.

---

## 10. New tile events and activation checks

- **TileEvent:**
  1. Add a value after `ON_SURROUNDING_TILE_ACTIVATED` in `TileEvent.EventType`
     (`Source/Content/Tiles/TileEventListener/tile_event.gd`). Values up to 99
     are free; `ON_PLAYER_FATAL_DAMAGE` is pinned at 100.
  2. Fire it from `tile.gd` by connecting the triggering signal to
     `handle_tile_event(self, TileEvent.EventType.MY_EVENT)` alongside the
     others (~line 85).
- **ActivationResource:** append to `ActivationType` and add its lambda to
  `activation_functions` (`Source/Content/Tiles/activation_resource.gd`).
  Add any new parameter as an `@export`.

---

## 11. Sound

Every slot still waiting for a sound is listed in `SOUND_EFFECTS.md`.
Sounds are `SoundEffectResource`s in
`Source/Resources/SoundEffectResources/SoundEffects/`. Hook one into a chain
with `AUDIO_VISUAL / PLAY_SOUND`, placed just before the step it belongs to.

### Music

Music goes through the `MusicDirector` autoload, never a scene's own
AudioStreamPlayer.

1. **Export** from FL Studio as WAV (or OGG). For a layered track, export
   every stem at exactly the same length from the same project, so they stay
   in time. Put them beside the `.flp` under `Assets/Music/`.
2. **Turn looping off** in the import (`edit/loop_mode=0` for WAV, `loop`
   off for OGG). A looping stream never ends, so its playlist never moves on.
3. **Make a track**: a `MusicTrackResource` in
   `Source/Resources/MusicResources/Tracks/`, with a unique `id` and one
   `MusicLayerResource` per stem (one layer, `id = full`, for a plain song).
   A layer with `starts_enabled` off still plays, silently. Tick `repeats`
   for a theme that should play again from the top rather than hand over
   to the next track (the start theme does, so the trailer only plays once).
4. **Add it to a playlist** in `MusicResources/Playlists/`.
   `default_playlist.tres` is the one that starts at boot.
5. **Cue it** from code: `MusicDirector.play_track(&"id", fade_seconds)`,
   or `set_layer_enabled(&"layer", on, fade_seconds)` for a stem. For a
   cutscene, call it from a method-track key so the timing lives in the
   AnimationPlayer (see `opening_cutscene.gd` `_start_music()`).

---

## 12. Player ships

1. Add `Source/Content/Ships/<id>.tres` (`ShipResource`). The `id` is written
   to saves: never rename one that has shipped. `sort_order` places its card.
2. Give it a starting kit: a `GameSaveResource` with hull, max hull, dice and
   `tile_locations` (every position must be one of the ship's cells;
   `test_ship_layouts.gd` checks).
3. Lay out the grid with `grid_cells` (holes allowed) or `grid_size`. Holes
   need no handler work: adjacency, pushes and Feeds stop at them.
4. Rules of its own go in a `behavior_scene` (child of the TileGrid) that
   listens to `Events`. Restyle the cockpit from it at runtime rather than
   editing `main.tscn` / `main_viewer.tscn`, which every ship shares.
5. Art, all in the approved palette: `cutscene_frames` (a "boost" animation,
   nose up, about the default hull's footprint) and `cutscene_exhaust_points`,
   `preview_texture`, `theme_color`, and `cockpit_palette` (map the default
   cockpit's #463c91 #251c6b #191347 #130f38 to the ship's ramp; leave #0f0c2e,
   the cockpit lights' "off" colour). The palette also repaints the
   instruments' frames (every Sprite2D in the `cockpit_surface` group).
6. **Its own cockpit** (optional, but it's most of a ship's look): a scene in
   `Source/Content/Ships/<Ship>/Cockpit/` set as `cockpit_scene`, art in the
   ship's texture folder under `Cockpit/`. `CockpitMount` (main.tscn) mounts
   it in place of the default `cockpit_ambience.tscn`. Copy
   `Outrigger/Cockpit/outrigger_cockpit.tscn`:
   - The root carries `cockpit.gd` with `walls_texture`: a 320x180 shell in
     screen pixels, drawn in its own colours (the palette doesn't touch it).
     Keep the dice tray's band (y 164-180, x ~70-250) solid, since the dice
     highlight sits on it, and leave the systems panel's area clear: anything
     opaque under it flies apart as debris on death.
   - `HudSlots`: a `Marker2D` per instrument the ship moves, named after its
     group (`hud_hull_gauge`, `hud_targeting_computer`, `hud_status_bar`;
     `Cockpit.HUD_GROUPS`). An instrument with no slot stays put.
   - A `CockpitDamage` with its own `CockpitDamageSite`s (full-screen
     overlays: GLASS cracks in the open view, FRAME splits on the shell, in
     the order they open) plus `GlassShards` and `Destruction` children.
   - Ambient life of its own: a `HangingDice` takes any twist sheet (the
     Carousel's gyroscope), `ChaseLights` runs lights along a track.
   - Keep it sci-fi: a ship's theme becomes hardware (rotation is gyro rings
     and bearings), never props.
   `test_ship_cockpits.gd` holds every cockpit to this.
7. Write a two-line card `description` in tile-text style.
8. Tiles only the ship should see live in `TileResources/` like any other (so
   saves can name them) with `offered_as_reward = false`. The codex still lists
   them, because a ship's starting kit is read from `ShipCatalog`.
9. Check balance against the Die Fighter on the same seeds:
   `tools/autoplay.sh --seed 1 --runs 24 --policy smart -- --ship=<id>`.
   Teach the bot the ship's rule if it plays it badly.

---

## 13. Checklist before committing content

- [ ] New scripts validated, class cache rebuilt if a `class_name` was added.
- [ ] GUT suite green (content tests load every new `.tres`).
- [ ] Scenarios added to GameStateManager in `main.tscn`; `starting_scenario`
      restored.
- [ ] Played it once: intents read correctly, nothing in the godot.log
      (`~/Library/Application Support/Godot/app_userdata/DieFighter/logs/godot.log`,
      grep `SCRIPT ERROR`).
- [ ] New sound slots noted in `SOUND_EFFECTS.md`; DEVLOG entry for anything
      sizable.
- [ ] Opened the codex (main menu): a new tile or enemy shows on its tab, in
      its colour group for a tile. The codex lists every tile offered as a
      reward or in a ship's kit, and every enemy with `in_codex`, with no
      registration step.
