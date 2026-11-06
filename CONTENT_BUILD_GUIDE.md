# Content Build Guide

How to add content by hand. Each section is the exact workflow, from files to
registration to testing. For how the systems work underneath, see
`ARCHITECTURE_OVERVIEW.md`.

---

## 0. Rules that apply everywhere

- **Enums stored in `.tres` are append-only.** These include
  `EffectEnums.*Subtype`, `TileEvent.EventType`, `ScenarioManager.ScenarioEvent`
  and `ActivationResource.ActivationType`.
  Inserting a value mid-enum silently rewires every authored file below it.
  Count ordinals carefully when hand-editing a `.tres`. Better still, author in
  the inspector, where you pick by name.
- **EffectData: set `category` before `subtype`.** The category setter resets
  the subtype.
- **After adding a script with a new `class_name`**, rebuild the class cache:
  `/Users/drew/Documents/Godot/Godot_4.7_stable.app/Contents/MacOS/Godot --headless --path . --import`.
- **Art is drawn in `Art/`, never in `Assets/`.** Every PNG the game loads
  is exported from the `.aseprite` at the mirrored path (`Art/Textures/X/foo`
  -> `Assets/Textures/X/foo.png`, or `foo-Sheet.png` for several frames) by
  `python3 tools/export_art.py`. `--check` reports stale PNGs. See
  `Art/README.md`.
- **Art uses only the approved palette**, the 33 colours in
  `Art/_Palettes/aseprite_palette_final.aseprite`. Outlines are `#040217` (never
  pure black). Alpha is free. The exceptions are white masks that get tinted
  in-engine (particle pixels, stars, smoke, shader masks), which stay pure
  white.
- **Before committing**, run the GUT suite:
  `.../Godot --headless --path . -s addons/gut/gut_cmdln.gd`.
  `test/core/content/test_authored_content.gd` loads every `.tres` under
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
    (`Any die while [color=purple]engines[/color] fully charged`). Passive tiles use the same arrow.
  - Order: cost (`Spend`), main effect, side effects, then where the die goes.
  - **Defaults go unsaid.** A die used on a tile goes to `target`, and so do
    the tile's `Deal` and `Apply`. Neither is written: `Any die -> Deal
    5 damage`, not `... to target. Give die`. Only the exceptions are spelled
    out, so they stand out:
    - another destination for the die, in orange: `Give die to random
      enemy`, `Give die as (die_1)`, `Return die`, `Keep die`, `Hold die`, or
      a Feed token (`(feed_right)`);
    - another ship for the effect: `to you`, `to random enemy`,
      `to every enemy`, `to all ships`.
    Write `target` only where the sentence needs a noun for it
    (`per die target holds`, `Steal target's shields`).
  - Branches read `Label: effect`, as in `Odd: Feed up. Even: Feed down`.
  - `per` is for scaling (`2 shields per burn`). `equal to` is for copying a
    value (`damage equal to die`, `damage equal to 2x die`). `adjacent` is
    the four orthogonal tiles, `surrounding` is all eight.
  - Uses are never written: the tile's lights show them.
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
  - **Numbers come from data.** Tile, rule, hazard and keyword text never
    types a design number: write `{name}` and bind it to the data that holds
    the number, so the text can't drift from what the game does. Tiles bind
    a step (§1), rules their `parameters` (§5), hazards a chain step (§6),
    statuses a constant in their script (§8). Rule-of-the-game numbers
    (`At 0`) and die faces stay literal. `{name}` is filled once, from the resource;
    `[data]key[/data]` is a tile's run-time counter, and `(amount)` an enemy
    intent's rolled value.
- **Player-facing text is written in English in the `.tres`** (inspector),
  and translated through `Localization/content.csv`. After changing any of
  it, run `tools/loc.sh sync` and commit `content.csv` with the `.tres`.
  Never put display text in `string_param`: a callout's words go in
  `callout`. See §13.

---

## 1. Tiles

**Files**
- Art: `Art/Textures/Tiles/<Colour>Tiles/<name>.aseprite`, exported to
  `Assets/Textures/Tiles/<Colour>Tiles/<name>.png`.
  - Colour by role: Red attack, Blue defence, Green die tricks/movement,
    Purple engine, Yellow support/buffs.
  - Red and green each have a house motif. A red tile is grey hardware with
    a bright red stripe under a light top edge, staggered between body and
    barrel, with a grey muzzle. That is the Dice Cannon, and the enemy attack
    intent copies it, so red art keeps to it. Green tiles draw the hardware
    that does the job, often with a green-lit band, and draw a die only where
    the die is the idea (Die Splitter, Value Exchange, holograms).
  - The folder is the tile's colour as far as the game is concerned: the
    codex sorts by it, and the Color Symbols option badges the tile's
    top-left corner with its family's shape (`ColorSymbolBadge`). So file
    the art by what it looks like, and keep the top-left 7×7 inside the
    frame free of anything vital. A new colour family needs an entry in
    `ColorSymbolBadge._FAMILY_FOLDERS` and `CodexCatalog._TILE_COLOUR_ORDER`,
    and a frame in `Art/Textures/Tiles/ColorSymbols/color_symbols.aseprite`.
  - Tiles are 24×24. An unlimited tile is a single frame, `<name>.png`.
  - **The lower panel shows which dice the tile takes**, matching its
    `activation_checks`. The marker is a 7×7 slot in the darkest shade of the
    tile's ramp, with pips in the panel's mid shade:
    - any die (including checks that aren't about the value, like charge,
      combat or holograms): a blank slot;
    - one value: that die face (Flashpoint 6, Chaff Pod 1);
    - two values: both faces side by side, slots at x=3 and x=11
      (Chaos Explosion 5+6, Leeching Shot 1+2);
    - a run: a 4×7 `<` or `>` chevron before the face (Bump `<6` for 1-5,
      Doubler `<4` for 1-3, Nudge Down `>1` for 2-6).
    - `CANT_BE_ACTIVATED_WITH_DIE`: no lower panel at all, only the
      coloured outline, with the art centred in the tile (Emergency Shield).
  - **A limited-use tile must show its uses.** It is a horizontal strip,
    `<name>-Sheet.png`, of `uses_per_turn + 1` frames. `Tile` shows frame
    `uses_remaining`, so frame *k* has *k* white lights lit and frame 0 has
    none. Bump is the reference. The lights are 2×2 slots on the right edge
    of the lower panel, stacked up from the bottom, lit `#cef0f1` and unlit
    `#070326`, outlined in the tile's own border colour. There is room for
    three, so uses top out at 3. `TileUseLights` knows where the slots are
    (to burst sparks off a spent light and gather them into a refilled one),
    so a change to the script's layout means updating its `_BOTTOM_LIGHT` and
    `_LIGHT_STEP` too.
  - Don't draw the lights by hand. Draw the tile as one frame, then run
    `tools/add_use_lights.lua` (usage at the top of the script). It turns the
    `.aseprite` into the frames; `tools/export_art.py` then writes the sheet.
    Then import (`Godot --headless --path . --import`) to get the sheet's
    uid, and `git rm` the old single-frame png and its `.import`.
  - If a tile's uses change later, rebuild its frames from frame 0 with the
    lights painted out (delete the other frames first). The script refuses
    an already-multi-frame file.
- Resource: `Source/Content/Tiles/TileResources/<name>.tres` (a
  `TileResource`). It must sit **directly** in that folder, not in a
  subfolder.

**Registration:** none. Any `TileResource` in that folder is automatically:
- in the reward and shop pools (`RewardManager`), weighted by `rarity`,
  unless `offered_as_reward` is off (upgrades, ship-only and benched tiles);
  a ship's signature tiles (`ShipResource.signature_tiles`) keep it off and
  join the pools only while that ship is flown (§12);
- saved by its filename id (`ContentRegistry`). Filenames must be unique, and
  renaming one breaks existing saves that hold it.

**Family (does a new player see it?):** a tile in no family is **Basic**,
offered from a player's first run. A tile whose text uses an advanced
keyword (Feed/Fed, Burn, Jammed, Scrambled, Exposed, Weakened, Hologram,
Countdown, Echo) belongs in a `TileFamilyResource` under
`Source/Content/Tiles/TileFamilies/`: add it to that family's `tiles`. A tile
sits in one family only (the card shows all its tiles): one that leans on two
mechanics goes in whichever unlocks later. Evasion and Phased (you) count as Basic. `test_tile_families.gd`
fails on an advanced tile left in no family. Families unlock in the order
`tile_unlock_order.tres` lists them, one per new sector reached; reorder
that list to change it. See ARCHITECTURE_OVERVIEW "Tile Unlocks".

**Fields**
- **Info**
  - `tile_name`: bbcode-coloured to match the tile's colour. All three are
    content text (§13): run `tools/loc.sh sync` after editing them.
  - `activation_description`, `description`: say what the die does,
    e.g. `[color=yellow]Any die[/color] -> ...` (see the text conventions at
    the top), with every number a `{placeholder}` (see "Numbers in tile
    text" below).
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
  - **Twin dice** (Twin Barrel, Pair Lock, Lucky Seven): the first die is
    held, the next pays out on both. Tick `holds_first_die` and wrap the
    chain in `IF_SOURCE_HOLDS_DIE`: false branch `CALLOUT` (`callout` "HOLD") then
    `KEEP_DIE_WITH_TILE`; true branch the payout, reading the held die with
    `ADD_HELD_DIE_VALUE` and handing it over with `GIVE_HELD_DIE_TO_TARGET`
    (or leaving it to go home). The hold spends no use, so a 1-use tile's use
    goes on the payout, and an echo waits for the payout. A held die goes back
    to the hand at turn end, so a hold can't be banked. To restrict the second
    die, add `MATCHES_HELD_DIE` or `SUMS_WITH_HELD_DIE` (`threshold` = the
    total): it refuses a die that doesn't pair, back to the hand, and takes
    any die while nothing is held. The lower panel shows two blank slots.
  - **Boost** (an optional charge cost): an `IF_CHARGE_AT_LEAST` conditional
    (`amount` = cost) whose true branch spends it (`TARGET_PLAYER`, an Engine
    `STREAM`, `SPEND_ENGINE_CHARGE`) then does the extra. The tile still works
    without the charge, so it takes no `CHARGE_AT_LEAST` check. Text:
    `(boost) [color=purple]3 charge[/color]: Apply 3 (burn)` (Sunlance).
  - **Rows**: `IF_SOURCE_IN_ROW` (`range_min`-`range_max`, 0 = top) for a tile
    that does more in part of the grid. On the Carousel's turning ring that's
    part of each lap (Apex Cannon, Keel Plating). Text: `[color=yellow]Top
    row[/color]: +3`.
  - **Multipliers**: an Amplifier adds to what a `MULTIPLY` step left
    behind (3x die, then +2). Tick `amplify_multiplier` when the multiplier
    is the tile's amount, so Amplify grows it instead (Preflight Interlock:
    3x die Amplified +2 is 5x die), and the info panel names the new
    multiplier. Text: `damage equal to {times}x die`.
  - **Ship readings**: `AMOUNT_MODIFIER / SET_TO_SHIP_READING`
    (`string_param` = the reading) sets the running amount to a number the
    flown ship's own rules keep, or adds it with `add_to_amount` (§12). 0 on
    a ship that keeps none, so such a tile is a signature tile. The
    Outrigger's pods keep `pod_lead` (how far the source tile's (pod) is
    ahead of the other, not counting the die activating it: what the gauge
    showed as it was placed) and `pod_level` (the lower pod's thrust this
    turn). Yaw Cannon: `SET_TO_DIE_VALUE`, then `pod_lead` added. Text:
    `+1 per pip this (pod) leads` (the `+1` is in `LITERAL_EXEMPT`: the
    reading has no amount).
  - **Ship mechanism**: `TILE_CONTROL / ADVANCE_SHIP_MECHANISM` steps the
    flown ship's moving part by the running amount, signed, and holds the
    chain until it lands, so the next step reads the new layout. On the
    Carousel it turns the ring on the spot, ridden like a turn's step
    (Ratchet: `IF_ACTIVATOR_ODD` -> `SET 1` / `SET -1`, then the step). It
    moves tiles, not dice, and does nothing on a ship without one; gate it
    on `IN_COMBAT`, since the ring only turns in a fight.
  - **Echo**: `TILE_CONTROL / ARM_ECHO` arms an `EchoModifier`. The next tile
    the player activates this turn plays its whole chain twice (its
    `activation_repetitions` doubles, so the die is handed on once). Echoes
    queue: each is spent by one activation, so a chain that repeats arms
    one per pass. An echo waits out a refused die, a lock, and any rule that
    holds tiles to one pass, and lapses at turn or fight end. Put `ARM_ECHO`
    before a Feed and the fed tile is the one echoed (Echo Relay); in an
    `ON_TURN_START` response it echoes the first tile played (Opening Salvo).
    Every tile takes an echo; there is no opt-out. A tile whose effect
    compounds multiplies on the second pass (Fortress Protocol quadruples
    shields), and that's welcome: fun over balance. A tile that spends
    charge, hull or shields runs its activation checks once, so an echoed
    second pass it can't afford pays nothing and still pays out. Only fix a
    tile under echo if it breaks mechanically (a crash, a soft-lock, a lost
    die), never by exempting it. Text: `(echo) the next tile you activate`.
  - **Enemy dice and intents** (aim with `TARGET_WITH_TARGETING_COMPUTER`
    first, then hand the die over as usual):
    - `SET_TARGETS_HIGHEST_DIE` (`amount` = the new face) turns the highest
      die each target holds to that face, before the ship can spend it
      (Cryo Lance: a 1). Gate it on `TARGETED_SHIP_HOLDS_DIE_ABOVE`
      (`threshold` 1), so it refuses a die when there's nothing to freeze.
    - `SILENCE_TARGETS_FACE` makes each target's intent for the activator's
      face (or `amount`) do nothing until its table is next rolled
      (Counter-Battery). `Enemy.silence_face()` swaps the slot for a Do
      Nothing that keeps the old action in `silenced_action`, so threat,
      Jammed and the AutoPilot read it as idle, and the targeting computer
      shows the old icon greyed and crossed out. Text: `intent for that face
      does nothing on its next turn`.
  - **Bounties**: `BOUNTY_DAMAGE` is `DAMAGE` (running amount) that pays
    `amount` credits for each ship that very hit destroys, as coins off the
    wreck. Civilians and launched fighters carry none (Bounty Scanner).
- **`event_responses`**: `TileEvent` → `EffectChain` for reactive tiles
  (`ON_TURN_START`, `ON_ENEMY_TURN_OVER`, `ON_PLAYER_HEALTH_HIT`, ...). A tile
  can take no dice at all and live only on these. `ON_TURN_START` also fires
  for a fight's opening turn, but only after `Events.enemies_arrived` (every
  ship landed and targeted), so it is safe to target enemies from it.
  - Event responses skip `activation_checks`. A response that can fire
    outside combat (`ON_PLAYER_SHIELDS_GAINED`, since shield tiles work
    anywhere) and hits a random enemy must wrap its chain in `IF_IN_COMBAT`,
    or it can attack a merchant (Repulsor Field). Mid-fight a random enemy
    can still be an ally or a bystander; a passive that must only hit the
    ships fighting the player aims with `TARGET_RANDOM_HOSTILE_ENEMY`
    (AGGRESSIVE ships only, nothing when there are none) and says
    `random hostile enemy` (Spark Gap).
  - A tile that spends or cashes in shields gates on `SHIELDS_AT_LEAST`, and
    pays with `SPEND_SHIELDS`, not a negative `SHIELD`: that would read as a
    hit and set off anything listening for one.
  - **Hull as a cost**: `SPEND_HULL` (`amount`) comes straight off the hull,
    past the shields, and gates on `HULL_AT_LEAST` set one above the price,
    so paying never kills (it refuses rather than kill if they disagree). It
    is a hull hit, so `ON_PLAYER_HEALTH_HIT` tiles answer it, but it isn't
    damage: Phased, Exposed and Double Damage leave it alone. An echo pays
    twice past a check made once; a second payment that would kill is
    refused (Blood Valve). Text: `Spend [color=red]3 hull[/color]`.
  - **Per-fight counters**: a tile that builds something up over a fight
    keeps it in its own tile data (`INCREMENT_TILE_DATA`, shown with
    `[data]key[/data]`) and zeroes it in an `ON_COMBAT_START` response, which
    is queued ahead of the fight's first `ON_TURN_START` (Ratchet Cannon,
    Overclock Coil). A per-turn counter zeroes in `ON_TURN_START` instead.
  - **Responses about a ship** (`ON_STATUS_APPLIED_TO_ENEMY`) start with that
    ship as the chain's target, so `that ship` needs no targeting step: go
    straight to the effect (Hex Coil: ZAP, `SET 2`, `DAMAGE`). It fires once
    per ship per application, only for statuses the player puts on an enemy
    (not on themselves), so a payoff that only deals damage can't loop.
    `ON_PLAYER_ATTACKED` works the same way with the attacker (Spiked Hull):
    once per enemy hit aimed at the player, whether the shields or the hull
    take it, ion fire included, but not a hit Phased dodged. A response is
    queued behind the chain that set it off, and starts with no target if
    that ship has died or fled by then. Text: `[color=yellow]Enemy hits you
    or your shields[/color] -> Deal [color=red]2 damage[/color] to it`.
  - **Evasion** (`EvasionModifier`, ARCHITECTURE 4.5.1): `ON_PLAYER_EVADED`
    fires once per enemy hit the engines dodged, with the attacker as the
    starting target, like `ON_PLAYER_ATTACKED` (which a miss never fires).
    Text: `[color=yellow]Enemy hit misses you[/color] -> ...` (Afterimage,
    Slipstream Vane; Feint Cannon banks it in tile data). To raise the
    chance, `ADD_EVASION` adds the running amount in percentage points until
    the player's next turn; gate it on `EVASION_BELOW_CAP` so a die isn't
    wasted at the 50% cap (Juke Thrusters). Write it `(evasion)`.
  - **Family boosts**: `TILE_CONTROL / ADD_FAMILY_BOOST` (`string_param` =
    `red`, `blue`, ...; `range_max` = cap; running amount = step, negative to
    take it back) gives every tile whose art is in that colour's folder +N
    damage per hit for the rest of the fight (`FamilyBoostModifier`, one per
    source tile, shown on each boosted tile's info panel). War Footing builds
    it on `ON_TURN_START` and loses it on `ON_PLAYER_HEALTH_HIT`.
  - **The Outrigger's pods**: `ON_PODS_LEVEL` fires on every tile as the
    player's turn ends with both (pods)' thrust exactly level and above 0,
    queued behind that turn's charge. The pods still hold the turn's thrust
    then, so `SET_TO_SHIP_READING pod_level` reads it (Gyro Stabilizer).
    Text: `[color=yellow]Your turn ends with (pods) level[/color] -> ...`.
- **`dragging_allowed`, `max_dice_in_queue`**: rarely touched.

**Numbers in tile text.** Never type a tile's number into its text. Write
`{name}` and set `text_token = name` on the step that holds it (inspector:
EffectData > Text Token). `TextTokens` fills it when the text is shown, in
every language and on every surface, so changing the step changes the text.
(The `Text:` examples in this guide show the filled English.)
- `text_token_value` picks another number than the default: `-amount` (a
  cost stored negative), `range_max`, `multiplier`, `threshold + 1`, or a
  sum with another token (`amount + damage`). Empty reads `amount`
  (EffectData), `base_repetitions` (EffectChain) or `threshold`
  (ActivationResource). `{countdown}` reads the tile's own countdown. A die
  face can be one too: `(die_{face})`.
- Name a token by what the number means in the sentence: `{bonus}` for a
  "+N" add-on, `{times}` for "Nx", `{percent}` for "N%", `{cost}` for
  charge spent. Keep a sign that belongs to the prose in the text:
  `-{loss_per_die}` with `text_token_value = "-multiplier"` (Skeleton Crew).
- Steps that show the same number share one token; the lint keeps them
  equal (Phantom Squadron's "until you own 5 dice" binds both the activation
  threshold and the repetition ADD).
- A range whose ends are the d6's own faces (1, 6) keeps them literal. A
  boundary that is data is bound (Polarizer's split, `{low_max}`), and the
  number one past it can sit on the branch step that handles it:
  `text_token_value = "low_max + 1"`.
- Rule numbers stay literal (`At 0`). A tile that keeps another literal on
  purpose, because no step stores it (a per-unit rule like Flak Cannon's
  "+1 per surrounding tile", d6 face pairs, Fabricator's two spawn steps),
  goes in `LITERAL_EXEMPT` in
  `Source/Systems/Localization/Tools/tile_text_tokens_tool.gd` with the
  reason.
- `test/core/content/test_tile_text_tokens.gd` fails on an unbound `{name}`, on
  steps sharing a name that disagree, on a marked step its text never shows,
  and on any literal number not exempt.
- Tools: `tools/loc.sh tokens report --family <f>` lists literals left,
  `tokens convert --family <f> [--dry-run]` binds them by value, kind and
  the unit after them, and `tokens verify --family <f> --against <ref>`
  checks the filled text equals the English at that git ref. When two
  literals in one text have the same value, check each `{name}` landed on
  the right step: `verify` compares English only, so a swap of equal numbers
  passes it.

**Upgrades.** Every tile offered as a reward has an upgraded version, which
the player gets by dropping a second copy of the tile on the first. A new
offered tile needs one too, and so does every ship's signature tile, which
is offered while its ship is flown. Tiles that are never offered (a ship's
kit tile that isn't one of its signature tiles, benched tiles) get none,
because no second copy can turn up.
- Make `<name>_plus.tres` beside the tile: a copy of its `.tres` with a
  fresh header `uid` (duplicate it in the FileSystem dock, or remove the uid
  and save it once in the editor before committing), `is_upgrade = true`,
  `offered_as_reward = false`, the name with a `+` (`Dice Cannon+`) and the
  description updated where the words change (its `{placeholders}` follow
  the new numbers). Then set the base tile's `upgraded_version` to it.
  Every tile file carries a uid, and every reference to one names it as well
  as the path. A file without one gets a uid stamped into some unrelated
  diff the next time the editor opens it.
- Upgrade levers, cheapest first:
  - **Numbers** (an amount, or an `ADD` after `SET_TO_DIE_VALUE`) and
    **cheaper costs** (less charge spent) reuse the base art.
  - **Looser conditions** that aren't die faces and **new behaviour** (Countermeasures+ also gives shields)
    reuse the base art too.
  - **Uses** need a new light sheet: `<name>_plus-Sheet.png`. Copy the base
    `.aseprite` to `<name>_plus.aseprite`, keep frame 0 with its lights
    painted out, and run it through `add_use_lights.lua`. Uses still top out at 3,
    and relays stay at 1-2.
  - **Looser faces** need a new lower panel showing the new faces
    (Shield Burst+ borrows Keel Plating's 3+4 slots).
- No art for the upgraded look: `TileUpgradeLook` gives every upgraded tile
  the shimmer (`tile.gdshader`) and sparks in its family's colour.
- `test_tile_upgrades.gd` checks each upgrade is marked, held out of offers,
  named apart, goes no further, and has one frame per light, and that every
  ship's signature tile has an upgrade and isn't offered to every ship.
  `test_tile_upgrade_chains.gd` plays one upgrade of each kind whole. Add a
  case there when an upgrade changes what the chain does, not just a number.

**Countdown tiles** (`(countdown) N`, Pulse Repeater is the reference) save
up dice for a payout. Set `countdown` = N on the resource. Dice count it
down by their value; each time it reaches 0 it fires and starts again from
N, extra counts carried over (one count can fire it twice). The count lasts
between turns and starts full every fight (`TileCountdown`, kept in
`effect_data["countdown"]` as what's left).
- `effect_chain`: `TARGET_EFFECT_SOURCE`, `SET_TO_DIE_VALUE`,
  `COUNT_DOWN`, then the usual `TARGET_WITH_TARGETING_COMPUTER`,
  `GIVE_DIE_TO_TARGET`. Checks: `REQUIRES_ACTIVATOR_DIE`, `IN_COMBAT`
  (the count only means something in a fight), `SHIP_TARGETED`.
- The payout is an `ON_COUNTDOWN_ZERO` event response. It resolves straight
  after the count, before the die is handed on. No die rides with it, so
  fire a LASER or MISSILE, never ATTACK_TWEEN.
- Anything can count a tile down: `COUNT_DOWN` acts on every countdown tile
  in `targets` (Fuse Cutter uses `TARGET_OTHER_COUNTDOWN_TILES` and gates
  on `OTHER_COUNTDOWN_ON_GRID`). A tile that activates twice counts twice.
- A payout that hands out dice must refuse holograms
  (`ACTIVATOR_DIE_NOT_HOLOGRAPHIC`), or its own holograms can run it out
  again forever (Fabricator).
- Art: no die slot. Leave a 9×7 readout window at (6, 15) in the panel's
  darkest shade; `CountdownReadout` draws what's left there in lit 3×5
  digits (two at most, so N ≤ 99).
- Text: `(countdown) 6. [color=yellow]Any die[/color] -> Count down by
  die. At 0: Deal [color=red]7 damage[/color]`.
  The info panel adds how much is left. Upgrade by lowering N.

**Later turns** (Time Bomb, Holding Bay): something set up now that happens
as one of the player's later turns starts. Both run on `DelayedEffect`, a
modifier that counts the player's turns down (the beat after the hand is
re-rolled, before `ON_TURN_START`; a fight's opening turn never counts). It
is dropped when the fight ends or the player jumps, and never goes off out
of a fight, so give the tile an `IN_COMBAT` check. Nothing is saved mid-fight,
so there's nothing to save.
- **A payload on a ship**: `UTILITY / DELAY_EFFECTS`, authored as a
  `DelayedEffectData` (like a conditional). Target the ship and build the
  running amount first; both are captured. `amount` = turns, `color` tints
  the countdown badge on the ship (`badge_icon` 11×11, `badge_info_icon`,
  `badge_title`, `badge_text` with `{amount}`). `delayed_effects` then play
  on that ship with that amount: flourishes and the hit, no targeting, no
  die steps. If the ship leaves first the payload moves to another hostile
  ship, or fizzles. Hand the die over as usual.
- **A die kept for later**: end with `DICE_CONTROL / HOLD_DIE_FOR_TURNS`
  (`amount` = turns, 1 if unset) instead of a hand-off. The die waits on the
  tile and comes back to the hand at its face. It isn't a held die for
  `get_held_die()`. Keep the uses low (a free bank is no choice).
- Text: `[color=yellow]In 2 turns[/color]: Deal ...`.

**Loop rule for Feed tiles:** a tile with unlimited uses may only Feed
**right**. Feeding up, down, left or randomly needs limited uses, so every loop
on the grid runs dry.

**Relays are always limited, to 1 or 2 uses.** A relay takes any die, acts and
Feeds it on, so with unlimited uses one die chains through every relay for
free. Use 2 for modest effects (Signal, Surge, Toll, Afterburner Relay, and
Relay Terminal) and 1 for the biggest per-die hit (Leech Relay, Ballast Tanks).

**Every play should be a choice.** A tile that pays out and hands the die
straight back (old Ballast Tanks: 3 shields, Return) is free value: the right
play is always "feed it", so it adds nothing to think about. Make the die cost
something (it goes to `target`, it drops in value, it Feeds on), or tie the
payout to position, sequence or a resource. Passives can't cost a die, so give
them a side to manage (Static Bloom scrambles you as well as an enemy).

A relay with a flat payout (Signal, Overshield, Toll, Booster Stage, Sensor
Spike) passes the die on 1 lower: "Subtract {tax} from die. (feed_right)",
built from a SET -1 amount step tokened `tax` and an `ADD_TO_ACTIVATOR_VALUE`
just before the feed. A 1 stays a 1. The payout then costs a pip of the die
the next tile gets, so a 6 meant for a 6-tile skips the relay.

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
| `KEEP_DIE_WITH_ACTOR` | is held and spent on the ship's next turn, on whatever that face shows (Seize, Charge Bore). Reads as Dangerous: the player goes a turn without it. The action's intent amount rides along to a `fills_kept_faces` payoff |
| `FEED_ALLY` | is passed to the bound ship, who uses it at once: an ally (Relay), or the ship a Raid just hit |
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
- The soft shield cap: an action whose only effect is shields (Shield Burst,
  Aegis Link) is never rolled for a ship that already holds as many shields
  as its max hull, and Aegis Link only binds an ally under that cap. Nothing
  clamps shields, and shields that come with another job (Relay) are left
  alone. It keeps shield stackers from turning a fight into a
  stalemate; no condition to set.

---

## 3. Enemies

**Files**
- Art: `Assets/Textures/Enemies/<Name>/`.
  - Hull sprite: ~32×32 (wider for capital ships). The outline is one
    `#040217` pixel wide and closed all the way round, so keep the hull a
    pixel clear of every canvas edge.
  - `<name>_targeting_image.png`: 16×16. It is also the enemy's portrait in
    the main menu's codex, drawn grey until the player meets the ship.
  - Draw both to the ship's faction's visual language (`LORE.md` §12): its
    accent colour, shapes and symmetry rule. A mirror-symmetric ship gets a
    mirror-symmetric portrait.
- Ship graphics scene: `Source/Content/Enemies/EnemyShipGraphicScenes/<name>_ship_graphics.tscn`.
  Copy `attacker_ship_graphics.tscn`.
  - The root **must** be a `Sprite2D` whose material is a
    `resource_local_to_scene` ShaderMaterial using `enemy_shader.gdshader`.
    The flash, fade and cloak effects drive its parameters. Set
    `cloak_main_color` / `cloak_bg_color` to the faction's light and middle
    accent; the copied scene's are the Undertow's.
  - Add `engine_particles.tscn` children at the exhausts.
  - Damage smoke is automatic (`ShipDamageSmoke`): a plume breaks out at
    75%, 50% and 25% hull, from spots picked off the hull's opaque pixels
    (the same spots for every ship of that kind), kept off the face: the
    middle column from just behind the hull's centre to the nose, where the
    cockpit, eye or core goes. If they land somewhere odd (say, a face drawn
    off-centre), pin them: add a `Node2D` named `DamageSmokePoints` with one
    `Marker2D` per plume, in the order they should light. Draw the sheet
    nose-down; the smoke drifts out of the tail (local up).
- Resource: `Source/Content/Enemies/EnemyResources/<name>.tres` (an
  `EnemyResource`).

**Fields**
- `enemy_name`, `description`.
- `faction`: the fleet faction that built the ship, one of the
  `FactionIdentity` resources in `Source/Content/Factions/`. It puts the
  faction's badge on the targeting computer. A variant (`gaff_raider.tres`) copies it.
- `in_codex`: untick for a ship that isn't a foe (the shop, the repair dock,
  the civilian transport), so the codex leaves it out of its enemy list.
- `max_health`, `starting_shields`. Both are scaled +35% per sector, and by
  the encounter's `enemy_hull_multiplier` (elites). What's written here is
  what a sector 1 ship spawns with and what the codex shows. Size them against
  an 80-hull player whose turn does about 15 damage: a normal fight should
  last two or three turns. Sector 1 ships run about 5-20 (Interceptor 5,
  Raider 16), gate bosses about 40-50 (Sector Warden 38, Arc Dynamo 49), and
  starting shields stay small (3-5). Per-hit numbers
  (attacks, shields, heals per turn) stay on the smaller scale tiles use.
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
    If the loading action had an intent amount, the payoff fires for exactly
    that instead of rolling its own, so give the loader the payoff's range.
  - `conditions`: `EnemyActionCondition`s, all of which must hold. Types:
    `ALLY_EXISTS`, `HOSTILE_SHIP_EXISTS`, `ALLY_HURT`, `SELF_HURT` (with
    `hull_fraction`), `ATTITUDE_IS`, `ALLIES_AT_MOST` (with `count`; gate a
    launcher on it so it can't fill the board), `SELF_HAS_STATUS` (with an
    optional `status_id`), plus `invert`. An action that vents its own
    statuses (`TRANSFER_STATUSES`, Purge Vents) is only rolled while the
    ship has one, read off the chain; nothing to set.
  - `situational_weights`: `EnemyActionWeightRule` = a condition and a
    multiplier.
  - `strength_tier_override`: how strong the action counts as for
    `face_bias`, on the threat scale (0 nothing, 1 something, 2 damage).
    -1 reads it off the chain. Raise it for actions the chain undersells
    (Lockout, a Relay into a heavy hitter).
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

**Ally support waits for sector 2.** A ship with any action bound to an
ally (Repair Beam, Aegis Link, Relay, Holo Loader: `Binding.ALLY`) is never
dealt into sector 1, and neither is any encounter it starts in
(`EnemyResource.earliest_sector()`, `ScenarioResource.allowed_in_sector()`).
Read off the actions, nothing to set; `test_sector_generation.gd` checks it.

**Which side a ship fights on** isn't on the enemy (its `faction` is only
who built it); it's on the scenario's ship state (§4). Who
allies with whom, and who raids whom, is `FactionRelations`
(`Source/Systems/Game/ScenarioManager/faction_relations.gd`). Behaviour that
only makes sense in some encounters, like raiding, should go on a variant
enemy resource (e.g. `gaff_raider.tres`), not on a shared one.

**A ship on the player's side always hands off.** Raid hits its prey and
hands it the die, so a die fed to a friendly ship still reaches the enemy.
Without that, an ally is a safe home for every die: the enemy, never handed
one, sits the turn out while the player charges their engines. So any ship
that isn't AGGRESSIVE, while a ship it's hostile to is, rolls at least one
Raid (`EnemyActionSituation.owes_hand_off`; the selector swaps one in if the
roll missed it, past the variety cap if need be). A ship that can be in
that spot needs a Raid option in every pool. Gate it on `ATTITUDE_IS`
AGGRESSIVE, inverted, so it only turns up while the ship is on the player's
side and its ordinary fights don't change (see `hauler.tres`).
`test/core/content/test_ally_hand_offs.gd` walks every scenario's reachable ship
states and names any ship that's missing one. Pirates count too: one
standing by while the player fights a civilian owes the civilian a Raid.

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
  - `unscaled_hull`: spawn on exactly the authored hull, ignoring sector and
    elite scaling (the tutorial's opening raider, whose turns are counted).
  - `path_location_override`: leave at -1; the formation places ships.
- **`enemy_hull_multiplier`** / **`enemy_damage_multiplier`**: scale the
  hull and shields, and every rolled intent amount, of each ship the
  encounter spawns or launches, on top of the sector's scaling. This is
  how an elite fields ordinary ships and still hits harder: 1.3 in sector
  1, 1.3-1.4 in sector 2, up to 1.5 in sector 3. Leave both at 1.0 for
  combats and events.
  - `mounted` / `mount_offset`: this ship is a part of the scenario's `hull`
    (below), seated at that offset from the hull's centre.
- **`rewards`**: Faction → `RewardResource`, paid when the player destroys a
  faction's last ship. A last ship that flees or escapes takes it along.
- **`starting_reward`**: an optional pickup floating on arrival, at
  `starting_reward_position` (default `(160, 60)`, clear of the systems
  panel). It reserves its stretch of the formation, so a lone ship beside a
  centred offer is squeezed toward the screen edge with no room to speak:
  move the offer aside (Mayday's sits at `(230, 60)`).
- **`sectors`**: the layers of the fleet the encounter belongs to (LORE.md
  §3): **Tail** (sector 1: the Undertow, stragglers, what the Rearguard left
  behind), **Belly** (sector 2: the Caravan and everyone come to take from
  it), **Spine** (sector 3: the Rearguard's checkpoints). Tick every layer
  its story fits, usually one, at most two. Every combat, event and elite
  needs at least one; none ticked would deal it everywhere, and a test fails.
  Pick by whose story it is, not by the ships' strength: the sector's own
  scaling handles that. See the rosters in
  `FACTION_SCENARIOS.md`.
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
  spills out the bottom. The lint fails a line over 50 characters, in any
  language.
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
| 11 | `PLAYER_ATTACKED_SELF`: heard only by the ship the player hit (see below) |
| 12 | `HULL_CRITICAL`: heard only by the ship a hit left at or below its state's `critical_hull_fraction` |

- For a random branch, point a transition at a
  `ScenarioShipStateProbabilityTransition` (`weighted_probabilities`).
- For a branch on the player's past, point a transition (or a ship's
  `starting_state`) at a `ScenarioShipStateStandingBranch`; see Faction
  memory below. A `starting_state` is a state or a standing branch, never a
  weighted roll (`test_scenario_graph` fails on one).
- **Events 11 and 12 are the ship's own.** Events 0-10 are broadcast, so
  every ship on a side hears a hit on any of them (`PLAYER_ATTACKED_PIRATE`
  can't tell two pirates apart). `PLAYER_ATTACKED_SELF` can. A ship that has
  just changed state ignores the rest of the volley that changed it, so a
  multi-hit tile can't turn a surrender straight into an execution.
- **Never let two state files reference each other**, A→B and B→A. Godot
  can't load circular `.tres` references. Route around it with a third state.

**Faction memory** (`FACTION_SCENARIOS.md` has the deeds already authored)

The run remembers what the player does to each faction (`FactionLedger`,
ARCHITECTURE "Faction Memory"). Encounters write to it with deeds and read it
with conditions.

- **Deeds** (`ScenarioShipState.deeds`, an array of `FactionDeed`): what
  reaching this state means. Each has a `standing` change (keep it to ±1-5:
  standing is read in bands two points wide), an optional `deed` name to
  count, and an optional `faction` (empty: the ship's own
  `EnemyResource.faction`). Recorded when the ship enters the state and its
  effects play, opening states included; never again on a Continue.
  - Put deeds on outcomes, not on hails: on `shop_ship_angry`, not on the
    shop's greeting. Put them on the voiced ship only (`hauler_thanks`, not
    `hauler_thanks_silent`) so two haulers don't count one rescue twice.
  - Name a deed `<faction>_<what happened>` (`caravan_shop_attacked`,
    `rearguard_spared`). Reuse a name when it's the same deed
    (`caravan_betrayed` for every grateful Caravan ship the player turned
    on), so a later encounter can ask for it once.
  - Betrayals swing harder than kindness pays (−3/−4 against +2/+3): one
    robbed shop makes the Compact DISLIKE the player; it takes two good
    deeds to win them back.
- **Conditions** (`FactionCondition`): `REGARD_AT_LEAST` / `REGARD_AT_MOST` a
  regard (HATED, DISLIKED, NEUTRAL, LIKED, TRUSTED), `DEED_DONE` /
  `DEED_NOT_DONE` (`count` times), `KILLS_AT_LEAST`. An empty `faction` asks
  about the ship's own. Ask by regard, never by raw standing: the bands are
  tuned in one place (`FactionLedger.LIKED_AT`, `TRUSTED_AT`).
- **Standing branches** (`ScenarioShipStateStandingBranch`): `options`, each
  a list of conditions (all must hold) and a state, and `otherwise`. The
  first option that holds wins, so put the most specific first (gossip about
  one deed, then a general grudge). Branch options are states, not rolls.
  This is how gossip works: `Shop/shop_ship_greeting.tres` opens the shop on
  "You hit a Compact shop. Prices went up." for a player who did.
- **`escort`** on a state (an `EscortResource`): entering it signs the ship
  on to ride along with the player (the Mayday's grateful runner,
  `EVENT_Mayday/mayday_escort_terms.tres`). Give it its own hull
  (`ship_resource`, with a Raid in every pool: it is on the player's side in
  every fight it joins; `test_ally_hand_offs` checks), a riding state
  (NEUTRAL, listening only to `PLAYER_ATTACKED_SELF`, since it hears every
  later encounter's broadcasts), a farewell state (the thank-you line, then
  WAIT and FLEE), `fights` and a money-only `payout`. Pair it with
  `REMEMBER_SHIP ally` on the same state: the Reckoning counts the ship once,
  from that, whether or not it made it. ARCHITECTURE "Escorts".
  - **To the gate** (`rides_to_gate`, the Outrigger courier): `fights` is
    ignored; it rides until the sector's gate fight is won and says goodbye
    there from its slot, with the jump held until it's done. Its extra lines
    go in `farewell_lead_in`, one state each (dialogue only), said in order
    before the farewell state. `unlocks_ship` (a ship `id`) earns that ship
    when it's delivered and shows the ship-unlock card once it has gone; a
    `payout` is optional. A gate escort takes the slot from one already
    riding, which says goodbye early.
- **`holds_fire`** on a state: every intent the ship rolls is silenced, so
  dice handed to it do nothing. For a crew that has surrendered.
- **Surrender** (`0GenericShipStates/rearguard_combatant.tres`): an
  aggressive state with `HULL_CRITICAL` → a `holds_fire` yielding state,
  which goes to an execution on `PLAYER_ATTACKED_SELF` and to sparing on
  `COMBAT_ENDED`. A yielding last ship ends the fight at once, and a spared
  ship flees, so sparing forfeits the bounty: make the spared state pay
  something now, and its deed pay later. Use it for crewed ships only (no
  drones), and not on the generic `pirate_combatant`: every Undertow fight
  ending in a surrender would wear thin.
- **`standing_requirements`** on a `ScenarioResource`: the encounter is
  dealt only while all of them hold (name the `faction`: an encounter has no
  ship of its own). Any list respects it.
- **Consequences** (`SectorGenerator.consequence_scenarios`): an encounter
  that *will* be met when its requirements hold, placed as each sector is
  generated, on an ordinary stop ahead of the arrival (so the player sees it
  coming and can choose to jump past it), at most `consequences_per_sector`. Give it a way to
  make amends as well as a fight: `GRUDGE_CompactLien` takes a lien, and
  paying it mends standing. Leave its `sectors` empty unless its story
  belongs to one layer.
- **Prices**: shops and repair docks charge by their keeper's faction's
  regard (`FactionLedger.PRICE_MULTIPLIERS`), with nothing to author.

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

**Fate's Die** (LORE.md §5, ARCHITECTURE "Fate's Die and the Reckoning"). An
encounter's choices carve the run's die through the ship state the choice
leads to:
- Put `SCENARIO_CONTROL / CARVE_FATE_FACE` (`string_param` = `mercy`,
  `plunder`, `duty`, `ruin`, `hunger` or `strange`) **first** in that state's
  `effects_on_enter`, ahead of any WAIT, so it lands before a checkpoint can be
  taken. Mercy is saving, Plunder taking from the slow, Duty the Rearguard's
  way, Ruin turning on someone who trusted you, Hunger the Inbound's pacts,
  Strange listening to the Spilled. The faces each encounter carves are listed
  in `FACTION_SCENARIOS.md`.
- **One carving per choice.** A state two ships enter at once (a `_silent`
  twin) carves on the speaking one only.
- A ship the player saved: add `REMEMBER_SHIP` (`string_param` `ally`) to its
  grateful state, and it flies into the Reckoning as a Saved Ship tile. A
  pirate they spared or dealt with: `debt`, for an Old Debt. Give a `_silent`
  twin its own `REMEMBER_SHIP`, since each saved ship counts.
- `RECORD_DEED` counts a deed the Reckoning reads: `tithe_paid`, `tithe_refused`.
- A state can say something else to a player who already knows the secret:
  `fate_knowing_dialogue` (the pilgrim's "You've seen the front.").
- A new face is a `FateFaceResource` in `Source/Content/FateDie/Faces/` named
  by its `FateDie.Face` id, with a 7x7 glyph and the `reckoning_chain` it plays
  when Fate throws it (player as actor, no die). Bind its numbers with
  `text_token`, like a tile.

**Registration** (required): open `Source/Scenes/main.tscn`, select
**GameStateManager/SectorGenerator**, and add the scenario to the right list:
- `combat_scenarios` or `question_scenarios` (events): the random sector mix.
  Each layer needs at least 7 combats, 4 events and 2 elites to fill a
  sector without repeats; removing one can drop a layer under that
  (`test_each_layer_holds_enough_to_fill_its_sector`).
- `elite_scenarios`: the elite pool (`elites_per_sector` per sector).
- `gate_boss_scenarios`: the boss guarding each sector's gate, in order.
- `consequence_scenarios`: reckonings the run has earned (Faction memory,
  above). Folder kind `GRUDGE_`.
- Fate's encounters go on the **Map** instead (`main_viewer.tscn`):
  `fate_scenario` and `fate_variants`.
- The Reckoning's scenario is on the **ReckoningDirector** (`main.tscn`), with
  the echo state, the Spilled pool and its tiles; the pilgrim who hands over
  Fate's Die is SectorGenerator's `fate_pilgrim_scenario`.
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

**Background** (`Source/Content/BackgroundResources/<name>.tres`, a
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
  A piece's `scene_variants` lists other designs that may stand in for its
  `scene` on a visit (the star field's sun slot draws from blue, amber, red
  and white suns). Every variant must fit the slot and take its light, so
  keep them the same kind of body.
- `star_tints` / `tinted_star_share`: palette colours that a share of the
  star pixels take instead of white (the star field tints about a fifth).
- **Stars.** Where anything is on screen besides stars and nebula (set
  pieces or scrolling objects), the stars hold still between jumps; only
  open space drifts. Nothing to set: `BackgroundResource.anchors_the_view()`
  works it out.
- `global_modifier`: an optional permanent rule that suits the place
  (the pulsar strips shields, shrapnel doubles damage; see
  `test_background_rules.gd`, which pins the pairings), **or**
- `hazard`: an optional timed event (§6). Never both: the environment monitor
  has one screen.

A run's first stops are rule-free: in sector 1, any stop within one jump of
the arrival draws only from its pool's backgrounds with neither a
`global_modifier` nor a `hazard` (`GameStateManager.is_rule_free_slot`). A
one-background pool built around its hazard keeps it. Keep at least one
plain background (star field) in `all_basic_backgrounds.tres`.

To make a background appear, add it to a pool's `eligible_backgrounds`
(`RandomBackgroundResources/all_basic_backgrounds.tres`), or make a new pool
for specific scenarios. A pool can also take in another (`includes_pool`)
minus some backgrounds (`excluded_backgrounds`).

**A rule is one `.tres`, plus a script if it's a new kind.** Create a
`BackgroundModifierResource` in `BackgroundModifiers/`:
- `modifier_name` (a place name, caps on the banner), `description`,
  `callout` (the word or two floated off the environment monitor when the
  rule bites: "NO SHIELDS", "MAX {cap}"), `color`, optional `icon` and
  `trigger_sfx` (else the monitor's chime).
- `modifier_script`: the Modifier that enforces it. Existing ones are in
  `Source/Behavior/Modifiers/BackgroundModifiers/` (plus
  `double_damage_modifier.gd`): shield, repair, engine and reroll
  blackouts, no repetition, amount cap (Doldrums), dice freeze (no face
  changes at all; Flash Freeze), and once per turn (every grid tile
  activates once a turn, the engine is immune; Dead Systems).
- `parameters`: the rule's numbers, keyed by the modifier property each
  sets (`{&"cap": 3}` sets `AmountCapModifier.cap`). Write them in the text
  as `{cap}`, never as digits: `TextTokens` fills them from the same
  dictionary. A modifier that shows its rule's name or colour declares
  `var rule: BackgroundModifierResource` and is handed the resource.

A rule that caps tile uses overrides `Modifier.get_tile_use_cap(tile)`:
`Tile.max_uses_per_turn()` reads it, so the lights, gray-out and refusal
follow with no art changes.

**A new way to change a die's face** (a new event) must override
`EffectEvent.changes_die_values()` to return true, or Flash Freeze won't stop
it. A face change outside an event (Scrambled's) asks
`DiceFreezeModifier.active_on(engine)` and calls `announce_triggered()` on it.

**New kind of rule:** write a `Modifier` subclass in
`Source/Behavior/Modifiers/BackgroundModifiers/` (copy
`shield_blackout_modifier.gd`; it must construct with no arguments). Use
`on_before_event()` to cancel or adjust, and call `announce_triggered()`
when it changes something. A rule that cuts an amount calls
`event.cap_amount(capped, self)` rather than assigning `amount`, so the
popup can show the cut ("12→3", in the colour `get_trigger_color()`
returns). Give each number it needs a `var`, set from the rule's
`parameters`, and point a new rule `.tres` at the script. Nothing to
register: no enum, no match.

---

## 6. Hazards (timed backgrounds)

A hazard belongs to a background, not a scenario: the place itself goes off.
`Source/Content/BackgroundResources/BackgroundHazards/<name>.tres` (a
`BackgroundHazardResource`):
- `hazard_name`, `description`, `color`.
- `headline`: what it does in a few words, read after the countdown on the
  arrival card ("In 2 turns: " + this). Lower case, no full stop, tokens
  welcome. The monitor's info panel shows the full `description` instead.
- `banner`: what it just did, in capitals, under its name the turn it goes
  off. Plain text, 30 characters at most.
- `icon`: 9x9 at most, from `Assets/Textures/TargetingComputer/HazardIcons/`.
  It sits beside the countdown digit on the environment monitor.
- `trigger_sfx`: optional; played on the environment monitor as it goes
  off, else the monitor's chime.
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
- Write the chain's numbers as `{name}`, never digits, in the description,
  headline and banner alike, and set `text_token` on the step that holds the
  number (§1). Solar Flare's damage step carries `text_token = &"amount"`
  and its text reads "Deal {amount} damage", so changing the chain changes
  the text.

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
  GRAPPLE is for an enemy taking the die it was handed: the die sets off for
  the player's hand and a claw from the ship reels it back (Seize). It holds
  the chain until the die is back; its `sound_resource` plays as the claw
  bites. Follow it with `KEEP_DIE_WITH_ACTOR`.
  ION_BOLT aims at the target's shields (the player's shield counter). Tick `juice_flags` for
  how they move: Rise (sparks drift up, for gains), Outward (a stream flows
  out of the source), Engine (the player's end of a stream or callout is the
  engine gauge), Hull Hub / Engine Hub (the stream's own end is the player's
  health bar / engine gauge instead of the tile, e.g. a drain that heals).
- A CALLOUT's words go in **`callout`**: English, capitals, very short.
  `{amount}` shows the running amount and `{die}` the die's face. They're
  translated like any content text, so run `tools/loc.sh sync` after adding
  one. `string_param` is for internal names only (status ids, tile data keys,
  families) and is never shown. A content test enforces both.
  A callout's `{amount}` and `{die}` are filled as it plays, from the
  running chain; they aren't design numbers (§1), so no `text_token` binds
  them. A background rule's callout is the rule's own `callout` field (§5),
  not a CALLOUT step.
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
   `test/core/effects/test_effect_catalog.gd`.
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
- **Changing a die's face:** `ADD_TO_ACTIVATOR_VALUE` steps it (a negative
  step, as in Nudge Down, is never amplified, so an Amplifier can't turn it
  into a rise). `SPLIT_ACTIVATOR` (Die Splitter) leaves the die the bigger
  half and hands the player a hologram of the rest, as one event so a freeze
  stops both.
- **The die a tile holds:** read it with `Tile.get_held_die()`, which counts
  only dice put there by `KEEP_DIE_WITH_TILE` (`Tile.hold_die()`), not dice
  merely dropped on the tile and waiting for their activation.
- **Something for a later turn:** subclass `DelayedEffect`
  (`Modifiers/DelayedEffects/`), set `turns_left` and override `_on_due()`;
  see "Later turns" in §1 for the two that exist.
- **Data a chain needs from its caller:** add a field to `EffectContext`
  (`effect_context.gd`).

---

## 8. Statuses (stack-based debuffs)

Statuses go on enemies and on the player. The same status works on both, so
a new one needs a rule for each side.

1. Subclass `StatusModifier` in `Source/Behavior/Modifiers/Statuses/`. Copy
   `burn_status.gd` or `exposed_status.gd`. Set `priority` in `_init()` and
   implement its hook; the name, colour and icons live on its resource
   (step 3). Every number its rule will mention (stacks spent, a
   percentage) is a constant the hook uses, returned by a static
   `rule_values()` (`{"spent": SPENT_PER_HIT}`). Where it touches dice,
   branch on `is_on_player()`: an enemy spends dice on its table, the player
   places them on tiles (`JammedStatus` and `ScrambledStatus` show both).
   - A status that lasts a number of the ship's turns counts down as that
     ship's own turn ends (`Events.enemy_turn_over` for an enemy,
     `Events.player_turn_over` for the player), not in `on_status_tick()`:
     that tick runs before an enemy acts and after the player's turn, so it
     would spend a stack before the status ever did anything (`WeakenedStatus`).
2. Art: `Assets/Textures/Statuses/` (11×11 badge, 24×24 info).
3. Add a `StatusResource` to `Source/Content/Keywords/KeywordResources/`
   (New Resource → StatusResource); its file name is the status's id. It is
   a keyword (§9) with four more fields: `modifier_script` (your script),
   `color` (a palette name), `icon` and `info_icon`. Its `title` is the
   status's name. Write numbers in the rule as `{name}` from
   `rule_values()` ("Spends {spent} Exposed."), never as digits; a test fails
   on a typed number. If it reads differently on the player, fill
   `player_rule` and add a token ticked `player_side` (`(jammed_you)`): the
   player's badge shows that rule, and enemy actions aimed at the player use
   that token. There is no catalog to edit: `StatusCatalog` finds it. Run
   `tools/loc.sh sync`.
4. Apply it with `ATTRIBUTE_CHANGE / APPLY_STATUS`: `string_param` = id,
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

**Phased** (Phase Cloak) is the defensive one: the next hit from the other
side (an enemy's on the player, a tile's on an enemy) drops the ship from its
targets before anything reads it, so shields keep every point and a death
save never fires. Each stack takes one hit; all of it wears off at the status
tick (for the player, as the enemy turn ends). Burn, hazards and a tile's own
cost get through. The tile applies it to the player with `TARGET_PLAYER`,
`SET N`, `APPLY_STATUS` `phased`; its text uses `(phased_you)`.

**Status payoffs.** `MULTIPLY_STATUSES` (`multiplier`, x2 doubles) grows
every status on the targets by applying the difference, one `APPLY_STATUS`
per status, so it lands like any application (Status Catalyst; gate it on
`TARGETED_SHIP_HAS_STATUS`). That check takes a status id in `data_key` for a
tile that pays per stack of one status (Flashpoint, Heat Sink: `burn`); empty
means any status. `TRANSFER_STATUSES` moves only harmful statuses
(`StatusModifier.is_harmful()`, false for Phased), so a cloak stays put;
Countermeasures gates on `PLAYER_HAS_HARMFUL_STATUS`. A tile answering the player applying a status
listens for `ON_STATUS_APPLIED_TO_ENEMY` (Hex Coil); `APPLY_STATUS`,
`TRANSFER_STATUSES` and `MULTIPLY_STATUSES` all set it off.

## 9. Keywords

Add a `KeywordResource` to `Source/Content/Keywords/KeywordResources/`; the
file name is its id. Write `title` and `rule` (a sentence or two, terse).
A number the rule repeats from code is a `{placeholder}`, filled through
`TextTokens` from the keyword's `_text_tokens()` (a status's come from its
script's `rule_values()`, §8); die faces in yellow may be written out.
Add one `KeywordToken` to `tokens` per spelling: `token` (`"(my_kw)"`),
`label`, and `color` when the word follows another colour rule (holograms are
blue; keywords are otherwise orange). Then run `tools/loc.sh sync`. Token keys
go by position (`KEYWORD.MY_KW.TOKENS_0.LABEL`), so add new tokens at the end.

**Spatial terms:** `(adjacent)` means the four slots directly above, below,
left and right; `(surrounding)` means all eight neighboring slots, including
diagonals. Use `(Adjacent)` / `(Surrounding)` at the start of a sentence.
Their hover pop-ups show a grid diagram. Missing/off-grid slots do not count;
empty-slot effects count only valid, unoccupied slots. The inspector calls
these eight-slot counting effects **Add Surrounding Tiles** and **Add Empty
Surrounding Cells**; their serialized enum IDs still contain `ADJACENT` for
compatibility. Never infer four-way behavior from those legacy IDs.

Write `(my_kw)` in any description. It renders styled and underlined, and the
info panel shows its rule in a pop-up while the player hovers it.

---

## 10. New tile events and activation checks

- **TileEvent:**
  1. Append a value after the last one below `ON_PLAYER_FATAL_DAMAGE` in
     `TileEvent.EventType` (`Source/Content/Tiles/TileEventListener/tile_event.gd`;
     `ON_PODS_LEVEL` today). Values up to 99 are free;
     `ON_PLAYER_FATAL_DAMAGE` is pinned at 100.
  2. Fire it from `tile.gd` by connecting the triggering signal to
     `handle_tile_event(self, TileEvent.EventType.MY_EVENT)` alongside the
     others (~line 115). Pass the ship the event is about as `subject` and
     the response starts aimed at it.
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
   `test_ship_layouts.gd` checks). `unlocked_cells` lists the cells open at
   the start; the rest of the layout is sealed until the player buys or finds
   Grid Slots. Leave it empty to open every cell. The Die Fighter opens its
   middle 3x3.
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
     group (`hud_hull_gauge`, `hud_targeting_computer`, `hud_status_bar`,
     `hud_overhead_console`; `Cockpit.HUD_GROUPS`). An instrument with no slot
     stays put. The overhead console's marker is its ceiling mount, just above
     the top edge of the screen: it hangs down about 46 px from there.
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
   saves can name them) with `offered_as_reward = false`. A tile it should
   find as salvage or in shops goes in its `signature_tiles`: offered (by
   rarity) only while that ship is flown, so it needs an upgrade (§1
   Upgrades). One that's only ever in its kit needs none. The codex lists
   both, read from `ShipCatalog`. Signature tiles are Basic (no family).
9. Rules tiles can read or drive go through `ShipRules`, so tiles never name
   a ship: a node of the behavior scene in `ShipRules.READINGS_GROUP`
   answers `has_ship_reading(key)` / `ship_reading(key, context)` for
   `SET_TO_SHIP_READING`, and one in `ShipRules.MECHANISMS_GROUP` has an
   awaitable `advance_mechanism(steps)` for `ADVANCE_SHIP_MECHANISM` (§1).
   The Outrigger's `OutriggerSync` and the Carousel's `CarouselBehavior`
   are the references.
10. **Locked until earned** (optional): `starts_locked`, an `unlock_hint`
   (a `translations.csv` key: a rumour of how to earn it, shown greyed out
   on its card) and how it's earned. For an encounter, set `unlock_scenario`
   and `unlock_sector` (0-based): it's dealt onto an ordinary stop of that
   sector in each of the player's own runs while the ship is locked, never
   into the random mix. The encounter earns it with an escort's
   `unlocks_ship` (§4), or `ShipUnlocks.unlock(id)` from code. The two
   reference each other by `id` only, since `.tres` files can't load in a
   circle. The Outrigger's `EVENT_Shipwright` is the reference.
   Or earn it by Fate's Die: `unlock_face` and `unlock_face_count` (the run
   must end, won or lost, with that face on the die at least that often),
   `unlock_card_header` (a key for the card's heading, "THE CARAVAN
   REMEMBERS") and `unlock_carve_hint` (a key called out under the die at
   each carving while the ship is locked, "THE CARAVAN NOTICED"). The card
   leads the rumour with the face's glyph. The Carousel is the reference.
11. Check balance against the Die Fighter on the same seeds:
   `tools/autoplay.sh --seed 1 --runs 24 --policy smart -- --ship=<id>`.
   Teach the bot the ship's rule if it plays it badly.

---

## 13. Text & localization

Player-facing text is English and is translated into zh_CN, ja, ru, de, fr, es
and pt_BR through two CSVs in `Localization/`:
- `translations.csv`: UI and code text. Write the key and the English in the
  CSV by hand (new rows at the end) and read it with `tr("KEY")`, or put the
  key in a scene's label (below).
- `content.csv`: content text. **Generated; never edit its `en` column.**
  The English is written in the content resource itself, in the inspector,
  and `tools/loc.sh sync` copies it here under a generated key. You may
  improve a row's `_context` note by hand; sync keeps it.

**Writing content text.** Edit the field in the inspector and play: English
is read straight from the resource. Before committing, run `tools/loc.sh
sync` and commit `content.csv` with the `.tres` (the lint fails otherwise).
Changing English that was already translated marks those translations
`stale` (they still show until someone redoes them). Close the Godot editor
before running the tools. Display text never goes in `string_param` or other
internal ids; a callout's words go in `callout` (§7).

**Numbers in content text** are `{placeholders}` filled from the resource's
own data by `TextTokens` (§0): a tile's steps (§1), a rule's `parameters`
(§5), a hazard's chain (§6), a status's `rule_values()` (§8). A translator
keeps each `{name}` as written and may move it; the lint fails a translation
that drops one. Rows' `_context` notes tell the translator a `{name}`
becomes a number.

| Type | Fields | Key |
|---|---|---|
| `TileResource` | tile_name, activation_description, description | `TILE.<file>.NAME/ACTIVATION/DESC` |
| `KeywordResource` (and `StatusResource`) / `KeywordToken` | title, rule, player_rule / label | `KEYWORD.<file>.*`, `…TOKENS_N.LABEL` |
| `EnemyResource` | enemy_name, description | `ENEMY.<file>.NAME/DESC` |
| `EnemyActionResource` | name, description | `ENEMY_ACTION.<file>.NAME/DESC` |
| `EffectData` | callout | `<file's key>.<path>.CALLOUT` |
| `BackgroundHazardResource` | hazard_name, description, headline, banner | `HAZARD.<file>.*` |
| `BackgroundModifierResource` | modifier_name, description, callout | `BG_MODIFIER.<file>.NAME/DESC/CALLOUT` |
| `TutorialStep` | tutorial_text | `TUTORIAL.<file>.TEXT` |
| `ScenarioShipState` | dialogue (50 chars) | `SHIP_STATE.<folder>.<file>.DIALOGUE` |
| `ScenarioResource` | boss_title, boss_subtitle | `SCENARIO.<file>.BOSS_*` |

A status is a keyword (`StatusResource`), and its name is the title (§8).

**Keys.** A resource saved as its own file is keyed by the file:
`HAZARD.SOLAR_FLARE.HEADLINE`. One embedded in another file (a callout in a
tile's chain, a token in a keyword) is keyed by its place in that file:
`TILE.GEARBOX.EFFECT_CHAIN.EFFECTS_5.IF_TRUE_EFFECTS_2.CALLOUT`. Re-saving
never changes a key. Renaming the file or moving a step does: sync then moves
the row's translations to the new key when the English is unchanged, and
reports anything it can't match as an orphan (move its translations by hand,
then delete the old row).

**Plurals.** Text with a count that changes the words ("1 stack", "3 stacks")
is one plural row in `translations.csv`, read with
`tr_n(&"KEY", &"KEY_PLURAL", n).format({"n": n})`. Put the plural id
(`KEY_PLURAL`, any unique name) in the row's `?plural` cell, and add one
keyless row under it per further form. English needs two, but give three,
the third repeating the second: Russian has three (1, 2-4, 5+) and a
translator can only fill a row that exists. Say in each row's `_context`
which form it is. The loc tools call the rows under a plural row `KEY#2`,
`KEY#3`; an export only asks a language for the forms it has (Japanese and
Chinese one, Russian three, the rest two). Don't sort or reorder those rows:
Godot numbers the forms by position. To check for duplicate keys, skip the
keyless rows: `cut -d, -f1 Localization/translations.csv | grep -v '^$' |
sort | uniq -d`.

**UI text in scenes.** A Label's or RichTextLabel's `text` can be the key
itself (`text = "PAUSE_TITLE"`); Godot translates it. Buttons built on
`Buttons/button.gd` translate the key on hover too. Text a script sets uses
`tr()`. Placeholder text a script always overwrites (InfoShower,
BossIntroCard) can stay English.

**Display code** never reads a text field directly. It calls the resource's
`display_*()` accessor (`hazard.display_headline()`), which returns the
current language.

**Making a new content type translatable:**
1. On the resource script, add `_content_text_prefix()` (the key's first
   part, e.g. `"TILE"`) and `_content_text_fields()` returning a
   `ContentText.Field` per text property: property name, key suffix, a
   context note for translators, and a `_max_chars` limit if the text has a
   hard width.
2. Add a `display_<field>()` accessor per field that returns
   `ContentText.text(self, &"<field>")`.
3. Switch every display call site to the accessors.
4. `tools/loc.sh sync`. Nothing else to register: the sync finds every such
   resource under `res://Source` (except `Scenarios/TEST`), including ones
   embedded in another file. If the type's file names repeat across folders,
   add `func _content_text_folder_in_key() -> bool: return true`.
5. Game code that copies content at run time calls `ContentText.copy(res)`
   (for actions, `action.copy()`), never `duplicate()`. A plain duplicate
   loses its keys and shows English in every language.

**Translating** (one language at a time):
1. `tools/loc.sh export de` writes `Localization/pending/de.csv`. It holds
   every row German is missing or has stale, UI and content alike, with the
   English, the context, the length limit and the old translation for stale
   rows.
2. Fill in the `de` column (a translator, or a machine draft). Keep every
   `{placeholder}`, `%d`, `(token)` and `[tag]` exactly as in the English;
   they may move within the sentence. Keep line breaks as `\n`. Save as
   UTF-8 CSV.
3. `tools/loc.sh import Localization/pending/de.csv` (add `--status
   reviewed` for a checked translation; the default is `machine`). It merges
   each row into whichever CSV owns its key, re-imports the CSVs and runs
   the lint. A row whose English changed after the export comes in `stale`.
4. Check it in the game: pick it in Options, or `lang de` in the dev
   console. Every language is offered from the start (the Localization
   autoload registers each `translations.<l>.translation` itself), so there
   is nothing to register; until about 90% of English's text is translated,
   Options marks it "(English text)" and a first launch won't pick it from
   the OS language.

**Fonts.** Never set a font or a font size on translated text. Pick its
role and scale: leave small x1 text alone (the theme default), otherwise set
`theme_type_variation` to a slot type such as `SmallX2` or `BodyX6`
(`FontRoles.SLOT_TYPES`; add a new one there and in
`Assets/Themes/default.tres` if no scale fits). In code, use
`FontRoles.slot(role, scale)`, or `FontRoles.font(role)` with
`FontRoles.size(role, scale)` for draw_string. To change how a language
looks, edit its profile in `Assets/Fonts/Profiles/` (or the shared face in
`Assets/Fonts/Faces/`): every slot of the role follows, which keeps sizes
consistent. Keep a face's size on its font's native pixel grid; if only an
off-grid size fits, say so in the face's `note`. `test_font_roles.gd` fails
on a raw override, and `test_localization.gd` fails when a language's text
has a character none of its role fonts can draw. Floating figures
(DamageNumber) are always m5x7/m3x6 through the `digits` roles; a translated
callout word is in the `popup` role. A language whose role units aren't 16
needs its own Readable Font overlay (`FontProfile.readable`) at those units:
rescale the readable fonts with `tools/rescale_font_unit.py` (see its header)
and give the faces the language face's spacing. A new language's face must
keep English's line box: set `spacing_top` / `spacing_bottom` so ascent + top
= 11 and descent + bottom = 2 at its unit size
(`test_every_language_keeps_englishs_line_box` checks). Check a profile before
its translations exist with `tools/loc.sh audit fonts` (pseudo text in each
distinct profile) or `audit pseudo@<locale>`.

**Fitting text (TextFit).** Translations overflow in predictable ways: German
runs long and builds compounds no line can break, Chinese runs short but its
characters fill the whole 13 px line where English capitals use 6. So text
that sits in a frame declares *where it may appear* and *how it may give way*,
and the fitter shrinks it, wraps it and moves it to stay there in every
language. Never hand-tune a label's offset for one language's glyphs.
- **Buttons** (`Buttons/button.gd`) already fit their label to the button's
  face: inside the border and rivets, above the 3D lip. A button drawn some
  other way sets its own face: `button.text_fitter().set_padding(l, t, r, b)`.
- **A label in a fixed frame** (a panel, a strip, a callout):
  `TextFitter.attach(label, TextFitPolicy.paragraph())`. Its box is the parent
  Control less the padding, or (`box_source = AUTHORED`) the rect the label
  was laid out with, or any `fitter.box` you set. Connect `fitted` to resize a
  frame that hugs its text.
- **A label in a container row**: `row.add_child(TextFitBox.wrap(label,
  TextFitPolicy.row_label()))`. The row grows when it wraps.
- **Text drawn with `draw_string`**: `TextFit.fit_line()` then
  `TextFit.draw_fitted_line()`.
- **A set of texts that should match** (tabs, a button bar): give each fitter
  the same `TextFitGroup`, so one long title shrinks them all a step rather
  than standing out.
- Policies (`TextFitPolicy`): `single_line()` for buttons and titles,
  `wrapping(n)` / `row_label(n)` for labels that may take n lines,
  `paragraph()` for running text. Words never split unless nothing else
  fits (so a German compound shrinks), wrapped lines come out even ("动画 /
  速度", not "动画速 / 度"), and shrinking goes in whole canvas pixels per
  font pixel down to `min_scale` (2/3 by default), so the text stays crisp.
- Don't put soft hyphens in translations: Godot draws the hyphen in a system
  font when the pixel font lacks U+2010 (Tiny5, monogram and Fusion Pixel do).
- A fit that fails even at `min_scale` is reported by the overflow watcher
  and the audit as `fit_failed`, with roughly the scale it needed: give the
  text a bigger box or ask for a shorter translation.

**Checking every language.**
- `tools/loc.sh lint` (also part of GUT, `test/core/content/test_localization.gd`)
  fails when content English hasn't been synced, when a translation lost or
  broke a placeholder, token or BBCode tag, or when text overruns its
  `_max_chars`. Missing glyphs are reported, not failed, until each language
  has its font.
- `tools/loc.sh audit [locale|pseudo|all]` (dev console `loc_audit`) shows
  every text surface in each language and flags text that overflows or lacks
  glyphs. It writes
  `~/Library/Application Support/Godot/app_userdata/DieFighter/loc_audit/report.html`.
  `pseudo` stretches every translated string, so it finds text that won't fit
  a longer language, and any literal English, before a translation exists.
  `--headless` checks without photos.
- In a debug build, `loc_watch on` (dev console) starts the overflow
  watcher for that session: it outlines text that doesn't fit in red and
  logs a `Loc` line with its key to the debug log. It's off at every launch.
  Set the `loc_watch_ignore` meta on a label that is meant to overflow.
  Besides text past its box, it flags glyphs whose ink leaves their button,
  words split by smart wrapping, wrapped lines that draw into each other, and
  fitted text that failed to fit.

Status column (`_status`): `machine`, `reviewed` or `stale`, as one word for
the whole row or per language (`de=reviewed fr=stale`). `_en_hash` is the
tool's record of the English it last saw; leave it alone.

---

## 14. Checklist before committing content

- [ ] New scripts validated, class cache rebuilt if a `class_name` was added.
- [ ] GUT suite green (content tests load every new `.tres`).
- [ ] Scenarios added to SectorGenerator in `main.tscn`; `starting_scenario`
      restored.
- [ ] Played it once: intents read correctly, nothing in the godot.log
      (`~/Library/Application Support/Godot/app_userdata/DieFighter/logs/godot.log`,
      grep `SCRIPT ERROR`).
- [ ] Changed content text? `tools/loc.sh sync`, and `content.csv` committed
      with the `.tres`.
- [ ] New sound slots noted in `SOUND_EFFECTS.md`; DEVLOG entry for anything
      sizable.
- [ ] Opened the codex (main menu): a new tile or enemy shows on its tab, in
      its colour group for a tile. The codex lists every tile offered as a
      reward or in a ship's kit, and every enemy with `in_codex`, with no
      registration step.
