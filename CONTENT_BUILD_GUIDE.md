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
- **Text conventions.** Descriptions use bbcode colour names: `red` damage,
  `blue` shields, `green` heal, `purple` engine/target, `orange` dice
  hand-offs, `yellow` die faces.
  - Tokens: `(die_N)` draws a die face.
  - `(amount)` and `(target)` fill in an enemy intent's rolled value and its
    bound ship.
  - Keyword tokens like `(feed_right)` and `(burn)` render styled and add a
    glossary line (§9).

---

## 1. Tiles

**Files**
- Art: `Assets/Textures/Tiles/<Colour>Tiles/<name>.png` (keep the `.aseprite`
  beside it).
  - Colour by role: Red attack, Blue defence, Green die tricks/movement,
    Purple engine, Yellow support/buffs.
  - Tiles are 24×24. A limited-use tile can be a horizontal strip
    (`<name>-Sheet.png`): frame *k* shows while *k* uses remain, and frame 0
    is used up. A single frame is fine too.
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
    e.g. `[color=yellow]Any die[/color] -> ...`.
  - `hint_text`: flavour line.
- **`rarity`** sets both drop weight (COMMON 1.0 / UNCOMMON 0.45 / RARE 0.18)
  and shop price.
- **`textures`**: a SpriteFrames whose `default` animation holds AtlasTexture
  frames cut from the png (24×24 regions).
- **`uses_per_turn`**: -1 for unlimited. Uses are a per-turn budget. Strong
  payoffs should cost something else (charge, hull, a die).
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
  can take no dice at all and live only on these.
- **`dragging_allowed`, `max_dice_in_queue`**: rarely touched.

**Loop rule for Feed tiles:** a tile with unlimited uses may only Feed
**right**. Feeding up, down, left or randomly needs limited uses, so every loop
on the grid runs dry.

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
  - `conditions`: `EnemyActionCondition`s, all of which must hold. Types:
    `ALLY_EXISTS`, `HOSTILE_SHIP_EXISTS`, `ALLY_HURT`, `SELF_HURT` (with
    `hull_fraction`), `ATTITUDE_IS`, plus `invert`.
  - `situational_weights`: `EnemyActionWeightRule` = a condition and a
    multiplier.
- **`pool_selection`**: which pool a turn uses.
  - `TURN_CYCLE`: rhythm, e.g. charge then fire.
  - `HEALTH_THRESHOLD`: escalates as it's hurt.
  - `SQUAD_LOSSES`: reacts to its side dying.
  - `COMBAT_ROUNDS`: a timer.
- **Graphics:** `ship_graphics_scene`, `graphics_scene_offset`,
  `dialogue_offset`, `targeting_computer_image`, `health_bar_position`,
  `dice_queue_position`, and `formation_width` (real hull width for big
  ships).

**Faction** isn't on the enemy; it's on the scenario's ship state (§4). Who
allies with whom, and who raids whom, is `FactionRelations`
(`Source/Systems/Game/ScenarioManager/faction_relations.gd`). Behaviour that
only makes sense in some encounters, like raiding, should go on a variant
enemy resource (e.g. `raider.tres`), not on a shared one.

**Registration:** none. An enemy exists once a scenario spawns it.

---

## 4. Scenarios (encounters)

**Files**
- Folder: `Source/Content/ScenarioResources/Scenarios/<KIND>_<Name>/`, where
  KIND is `COMBAT`, `EVENT`, ... Subfolders are fine here, unlike tiles.
- `<name>.tres` (a `ScenarioResource`) plus one `.tres` per ship state it
  uses. `0GenericShipStates/pirate_combatant.tres` is a reusable plain
  aggressive pirate.

**ScenarioResource fields**
- **`map_icon`**: from `Assets/Textures/Map/EncounterIcons/` (enemy, boss,
  unknown, shop, healing...).
- **`background_resource`**: a `RandomBackgroundResource` pool, usually
  `RandomBackgroundResources/all_basic_backgrounds.tres`.
- **`starting_enemies`**: one `EnemyStateRewardResource` per ship:
  - `enemy_resource`, `starting_state`, `reward_resource`.
  - `starting_health_fraction`: start it pre-damaged.
  - `path_location_override`: leave at -1; the formation places ships.
- **`rewards`**: Faction → `RewardResource`, paid when a faction is wiped out
  by the player.
- **`starting_reward`**: an optional pickup floating on arrival.
- **`hazard`**: optional (§6).
- **`sector_gate_scenario`**: only for the boss and the jump gate.

**Ship states** (`ScenarioShipState`, one `.tres` each)
- `dialogue`.
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

- For a random branch, point a transition at a
  `ScenarioShipStateProbabilityTransition` (`weighted_probabilities`).
- **Never let two state files reference each other**, A→B and B→A. Godot
  can't load circular `.tres` references. Route around it with a third state.

**RewardResource:** `min_money`/`max_money`, `num_of_rewards` (tile offers),
`dice_probability` (chance an offer is a die instead), and
`min/max_money_pickup`.

**Registration** (required): open `Source/Scenes/main.tscn`, select
**GameStateManager**, and add the scenario to the right list:
- `combat_scenarios` or `question_scenarios` (events): the random sector mix.
- `boss_combat_scenarios`: one per sector, in order.
- `fate_scenarios`.
- Or set the single slots: `starting_scenario`, `jump_gate_scenario`,
  `shop_scenario`, `empty_scenario`.

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
- Nebula, star and debris toggles and counts.
- `static_objects` (`StaticBackgroundObjectResource`: a scene + position, e.g.
  the pulsar).
- `global_modifier`: an optional rule.

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

## 6. Hazards

`Source/Content/ScenarioResources/Hazards/<name>.tres` (a
`ScenarioHazardResource`):
- `hazard_name`, `description`, `icon`, `color`.
- `turns_until_first`, `turns_between`.
- `effect_chain`: what fires, e.g. `TARGET_ALL_SHIPS` → amount → `DAMAGE`.

Assign it to a scenario's `hazard`. The countdown banner is automatic.

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
  until they land.

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
  - If it removes the ship from play, add it to `is_safe_while_hidden()`.
- **Data a chain needs from its caller:** add a field to `EffectContext`
  (`effect_context.gd`).

---

## 8. Statuses (stack-based enemy debuffs)

1. Subclass `StatusModifier` in `Source/Behavior/Modifiers/Statuses/`. Copy
   `burn_status.gd` or `exposed_status.gd`. Set `status_id`, `display_name`,
   `title_color`, `icon`, `info_icon` and `priority`, and implement its hook.
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

Write `(my_kw)` in any description. It renders styled, and the info panel adds
the definition automatically.

---

## 10. New tile events and activation checks

- **TileEvent:**
  1. Add a value after `ON_ADJACENT_TILE_ACTIVATED` in `TileEvent.EventType`
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
