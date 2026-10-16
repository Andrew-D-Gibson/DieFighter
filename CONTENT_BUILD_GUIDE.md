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
  renaming one breaks existing saves that hold it;
- available to `give_tile` in the dev console.

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
  `CHARGE_AT_LEAST`. A refused die goes back to the hand.
- **`effect_chain`**: see §7 for authoring.
  - The standard ending is `TARGET_WITH_TARGETING_COMPUTER` then
    `GIVE_DIE_TO_TARGET`. The die always goes to the targeted ship, which is
    the core trade of the game.
  - Feed tiles end with `PASS_DIE_TO_TILE` instead.
  - Holding tiles end with `KEEP_DIE_WITH_TILE`.
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

**Test:** run the game, open the dev console with `` ` ``, then `give_tile <name>`.
`set_dice 1 2 3`, `reset_uses` and `charge_engines` help set up a case.

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
step; its ally is bound automatically.

**Derived automatically, nothing to set:**
- Threat (tractor-beam colour). Damage aimed at the player is DANGEROUS.
  Damage aimed at a bound ship is not.
- Hidden-safety: anything that flees or jumps is never rolled while intents
  read "?".
- Binding kind.

---

## 3. Enemies

**Files**
- Art: `Assets/Textures/Enemies/<Name>/`.
  - Hull sprite: ~32×32 (wider for capital ships).
  - `<name>_targeting_image.png`: 16×16.
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
- `max_health`, `starting_shields`. Both are scaled +35% per sector.
- **`action_options`**: one or more `EnemyTurnActionList` pools. Each holds
  `EnemyActionOptionResource`s:
  - `base_action`, `weight`.
  - `min_amount`/`max_amount`: the rolled intent. Scaled +20% per sector,
    except a Holo Loader's face.
  - `force_include`: always present once. Weight 0 plus `force_include` means
    exactly one.
  - `fills_kept_faces`: never rolled normally (`weight` and `force_include`
    are ignored). One copy goes on the face of each die the ship kept itself
    last turn with `Keep Die with Actor`, and it appears nowhere else. For a
    payoff the player only faces after loading it (Charge Bore → Siege Shot).
  - `conditions`: `EnemyActionCondition`s, all of which must hold. Types:
    `ALLY_EXISTS`, `HOSTILE_SHIP_EXISTS`, `ALLY_HURT`, `SELF_HURT` (with
    `hull_fraction`), `ATTITUDE_IS`, `ALLIES_AT_MOST` (with `count`; gate a
    launcher on it so it can't fill the board), plus `invert`.
  - `situational_weights`: `EnemyActionWeightRule` = a condition and a
    multiplier.
  - `strength_tier_override`: how strong the action counts as for
    `face_bias`, on the threat scale (0 nothing, 1 something, 2 damage).
    -1 reads it off the chain. Raise it for actions the chain undersells
    (Lockout, Impound, a Relay into a heavy hitter).
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
authored roster), and refuses with "HANGAR JAMMED" once
`EnemyManager.max_ships_in_combat` ships are up.

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
  (`solar_corona_only.tres`, `ion_storm_front_only.tres`, ...).
- **`starting_enemies`**: one `EnemyStateRewardResource` per ship:
  - `enemy_resource`, `starting_state`, `reward_resource`.
  - `starting_health_fraction`: start it pre-damaged.
  - `path_location_override`: leave at -1; the formation places ships.
  - `mounted` / `mount_offset`: this ship is a part of the scenario's `hull`
    (below), seated at that offset from the hull's centre.
- **`rewards`**: Faction → `RewardResource`, paid when the player destroys a
  faction's last ship. A last ship that flees or escapes takes it along.
- **`starting_reward`**: an optional pickup floating on arrival.
- **`sector_gate_scenario`**: only for a boss gate (and `GATE_open`). Fate
  never takes these, and winning one opens the gate instead of emptying it.
- **`boss_title` / `boss_subtitle`**: set on a boss fight to play the intro
  card. The portrait is the toughest starting ship's targeting image.
- **`hull`**: a `ShipHullResource` (`hull_scene` whose root is a `ShipHull`,
  `path_location`, `offset`, `width`) for a boss built from parts. See
  `GATE_Bastion` and `Source/Content/Enemies/ShipHull/`. Each part is an
  ordinary enemy with its own art, resource and table.

**Ship states** (`ScenarioShipState`, one `.tres` each)
- `dialogue`. The speech box holds five lines of about ten characters, so
  keep a line to roughly 50 characters; longer text spills out the bottom.
- `faction`: PIRATE, CIVILIAN or BOSS. Also picks the speech-box colour.
- `attitude`: an AGGRESSIVE ship puts the scenario in combat, and intents are
  only readable while one is present. With only FRIENDLY or NEUTRAL ships,
  every table reads "?" and is rolled hidden-safe.
- `effects_on_enter`: a chain run on entering the state, e.g. heal the
  player, open the shop.
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
- `fate_scenarios`.
- Or set the single slots: `starting_scenario`, `shop_scenario`,
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
- Nebula and star toggles and counts.
- `scrolling_objects`: what drifts past at varying depths, with
  `num_of_med_pieces` / `num_of_large_pieces`. Pick a set from
  `ScrollingObjects/` (`triangle_debris`, `asteroids`, `ice`, `ship_scrap`,
  `fate_shards`, `solar_embers`, `ion_motes`), or make a new
  `ScrollingObjectsResource`: medium and large piece-scene lists, plus whether
  pieces keep their own colours or become flat silhouettes, and whether they
  may spin (off for art lit from a fixed side).
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
  throbs a sprite's brightness (the fate die's fissure, the cinders' cracks).
  Both start each copy at a random point, so a field of pieces never pulses
  in step.
- `static_objects` (`StaticBackgroundObjectResource`: a scene + position, e.g.
  the pulsar). Only for placed set pieces; anything that just drifts by
  belongs in `scrolling_objects`.
- `global_modifier`: an optional permanent rule, **or**
- `hazard`: an optional timed event (§6). Never both: the environment monitor
  has one screen.

To make a background appear, add it to a pool's `eligible_backgrounds`
(`RandomBackgroundResources/all_basic_backgrounds.tres`), or make a new pool
for specific scenarios.

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
ion cloud, meteor shower and rift tear for examples. Drive their visuals with
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
  STREAM, ...) play at the current targets. ZAP and STREAM hold the chain
  until they land. Tick `juice_flags` for how they move: Rise (sparks drift
  up, for gains), Outward (a stream flows out of the source) and Engine (the
  player's end of a stream is the engine bar).

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

## 8. Statuses (stack-based enemy debuffs)

1. Subclass `StatusModifier` in `Source/Behavior/Modifiers/Statuses/`. Copy
   `burn_status.gd` or `exposed_status.gd`. Set `status_id`, `display_name`,
   `color` (a `Globals` palette colour), `icon`, `info_icon` and `priority`,
   and implement its hook.
2. Add it to `StatusCatalog._statuses` (`status_catalog.gd`), keyed by id.
3. Art: `Assets/Textures/Statuses/` (11×11 badge, 24×24 info).
4. Add a keyword for it (§9).
5. Apply it with `ATTRIBUTE_CHANGE / APPLY_STATUS`: `string_param` = id,
   running amount = stacks. Test with dev console `status <id> [stacks]` on a
   targeted enemy.

---

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

---

## 12. Checklist before committing content

- [ ] New scripts validated, class cache rebuilt if a `class_name` was added.
- [ ] GUT suite green (content tests load every new `.tres`).
- [ ] Scenarios added to GameStateManager in `main.tscn`; `starting_scenario`
      restored.
- [ ] Played it once: intents read correctly, nothing in the godot.log
      (`~/Library/Application Support/Godot/app_userdata/DieFighter/logs/godot.log`,
      grep `SCRIPT ERROR`).
- [ ] New sound slots noted in `SOUND_EFFECTS.md`; DEVLOG entry for anything
      sizable.
