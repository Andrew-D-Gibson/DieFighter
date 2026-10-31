# Faction Scenarios

The faction encounters from `LORE.md`, built on the faction ships (commit
8b6ac6d6), and where every encounter in the game is dealt (below). Folders are
under `Source/Content/ScenarioResources/Scenarios/`. The faction events are in
GameStateManager's `question_scenarios`, and Wake Riders is in `elite_scenarios`.

## By sector

Each sector is a layer of the fleet (`LORE.md` §3), and a scenario's `sectors`
flags keep it to its layers. Every boss is a faction's pack leader racing for the
front. The Rearguard in the Spine is deliberate irony: they claim to hold the rear,
but they sit safe ahead of the Caravan and tithe everyone who passes. Behind them you
meet only what they left: a forgotten sentry drone, their press-gangs, and the few
honest Pickets. A dagger (†) marks an encounter in two layers.

### Sector 1: The Tail ("Everyone back here is already dead.")
Stragglers, scavengers and wreckage, with Fate on the horizon. The Undertow's rule:
slow is dead.

- **Combats:** Attacker, Wolfpack, Loose Wing, Cutpurse†, Wreckers†, Cannon Drone
  (a Rearguard sentry left behind when the line moved on), Boneyard (a Gaff and a
  Venom Fighter stripping a wreck field, and you look like more of it).
- **Events:** Pilgrim (the Fate's Die handover), Straggler, Pirates Attacking
  Civilian†, Mayday†, Sleeping Drone, Signal, What Came Back†.
- **Elites:** Wake Riders†, Chopshop (the Warden's breakers: *"The Warden wants your
  parts."*).
- **Gate:** the Sector Warden, *Warlord of the Tail*: *"Everyone back here is
  already dead."*

### Sector 2: The Belly ("Keep everyone together.")
The Caravan's heart, and the most mixed layer: Compact enforcers, Undertow
infiltrators, Inbound recruiters and Rearguard press-gangs all come for something.

- **Combats:** Lien Collection, Pilgrimage (Inbound recruiters), Smash and Grab,
  Carrier†, Picket Line† (a draft sweep), Tender Escort (a Conscriptor and the Caravan
  medic it drafted), Cutpurse†, Wreckers†.
- **Events:** Convoy, Cut Loose (the Chancellor's philosophy in miniature), Mercy
  Call, Pickpocket, Wreck Salvage (under a Claims Adjuster's guard), Pact†, Last
  Picket (the honest Rearguard holding the Belly's back), Ghost Carrier, Mayday†,
  Pirates Attacking Civilian†, What Came Back†.
- **Elites:** Hunter-Killers† (an Undertow fighter with a Rearguard drone: someone
  paid for you), Repossession (two Claims Adjusters kept running by a Field Tender:
  *"Your lien is due."*), Wake Riders†.
- **Gate:** the Arc Dynamo, *the Chancellor's reactor barge*: *"The Belly can't wait
  for one ship."*

### Sector 3: The Spine ("Hold the line, buy time.")
Checkpoints, tithes and warships, plus the Undertow they hire under the table.

- **Combats:** Tithe Collector, Tithe Escort, Ion Lances, Defender + Disabler, Drone
  Battery, Siege Battery, Spotter, Bounty Run (a Rearguard lance escorting an Undertow
  smuggler in civilian clothes), Carrier†, Picket Line†.
- **Events:** Tollkeeper (*"Tithe taken. It buys us all time."*), Deniable Assets,
  Black Market (the checkpoint's back door), Deserter, Pact†.
- **Elites:** Tithe Fleet, Lance Squadron, Mortar Nest (a Picket shields the
  mortars), Hunter-Killers†.
- **Gate:** the Bastion, *the Marshal's fortress*: *"Four hundred years. Not you."*

The Mayday comes from a Bounty Runner: a civilian hull with an Undertow badge, the
tell for anyone reading the targeting computer. Sometimes it's bait (it runs on round
3), and sometimes an Undertow straggler really is dying.

Blockade Runner was cut. It overlapped Bounty Run, and an Undertow smuggler escorted
by a Caravan medic fit neither faction.

## How choices work

Events have no dialogue menus. The player chooses through the game's own verbs, and
each encounter turns on one choice made with them:

- **who you shoot** (`PLAYER_ATTACKED_PIRATE` / `_CIVILIAN`)
- **who you hand dice to.** Every ship spends the dice it holds, friendly ones
  included, so a friendly ship fights only if you pay it in luck. A die reaches it
  through any tile that "gives die to target" without damaging it.
- **what you take**: the pick or the money (`PLAYER_TOOK_REWARD_TILE` / `_MONEY`).
  Taking a die or grid slot also counts as the pick.
- **whether you stay**: jump out, or couldn't pay.

Mechanical sides stay `PIRATE` (predator) / `CIVILIAN` (protected). Each ship carries
its lore identity in its `FactionIdentity`. **Mercy pays more than cruelty costs**:
the kind path has the bigger payoff, and the cruel path is quicker or safer.

The Fate's Die face each choice *would* carve is noted for later.

---

## Rearguard — "Hold the line, buy time."

### Deniable Assets — `EVENT_DeniableAssets`
A **Gaff** (`gaff_raider`) is stripping a **Hauler**. A Rearguard **Conscriptor**
looks away. *"Not our jurisdiction. Move along."* Hush money floats beside them.
- **Take the money:** *"Good pilot. You saw nothing."* Hauler: *"So that's what we
  cost."* No fight. — Duty / Ruin
- **Shoot either pirate:** both turn. *"You weren't supposed to see that."* Win, and
  the Hauler patches 10 hull on top of the bounty. — Mercy
- **Take the money, then shoot:** *"Our coin, then our hull? Fine."*

### The Last Picket — `EVENT_LastPicket` (sector 2+, Aegis Link is ally support)
Two battered, friendly **Pickets** (`picket_holdout`) hold against a Spilled
**Shroud + Wisp**. *"We've held 400 years. Hold with us."*
- Dice you hand a Picket go to its **Raid** on the Spilled (die returned) or to an
  Aegis Link on the other Picket.
- **Win:** each Picket still alive gives +4 engine charge and 6 hull. *"Go. We'll
  hold."* — Duty
- **Hit a Picket:** both turn. *"Deserter! Fire!"* Raid is off once they turn, and an
  attack on you comes on.

### Deserter — `EVENT_Deserter` (sector 3)
A **Pilgrim** (`pilgrim_wandering`) flies inward past a checkpoint. *"Let me pass.
I'm going home."* A **Conscriptor**: *"Deserter. Fire on it, pilot."* This is the
Rearguard's hatred of the Inbound, who desert the line by flying the wrong way.
- **Shoot the Pilgrim:** *"Good. Finish it."* It barely fights back (Siphon and
  Scrambler), its wreck pays 15-25 credits, and the Conscriptor leaves. *"The line
  holds. Carry on."* — Duty
- **Shoot the Conscriptor:** *"Then you desert with it."* Win for the bounty pick,
  and the Pilgrim gives +4 charge and 8 hull before it flies on. *"Run if you must.
  Take this."* — Mercy / Hunger

## Undertow — "The slow ones are already dead, so take their stuff."

### The Straggler — `EVENT_Straggler`
A **Hauler** with a dead drive (`hauler_adrift`, 35% hull) drifts toward Fate. A
**Wrecker** (`wrecker_raider`) circles. *"It's dead already. Strip it, we split."*
- **Shoot the Hauler:** *"Now you get it."* Its salvage drops (credits and a die),
  and the Wrecker leaves. *"Pleasure. Don't fall behind."* — Plunder
- **Shoot the Wrecker:** a fight. Bounty pick, plus 12 hull from the Hauler.
  *"Take our spares. Don't wait for us."* — Mercy

### Wake Riders — `ELITE_WakeRiders`
Two **Gaffs** and a **Wrecker**. *"Slow ship. You're ours now."* The Gaffs pilfer
dice and siphon the drive, so you become the straggler. The Wrecker burns and quakes.

## Caravan — "Keep everyone together."

### Convoy — `EVENT_Convoy`
Two damaged **Haulers** under Gaff + Wrecker raid (raid variants).
*"Stay with us! Nobody gets left!"* Each Hauler alive when the raiders fall patches
8 hull, so both saved pays double. — Mercy

### Cut Loose — `EVENT_CutLoose`
A **Hauler** tows a second with a dead drive. A **Claims Adjuster**, the Compact's
own enforcer: *"Compact ruling: cut the tow loose."* The tug: *"We don't leave
people behind."*
- **Destroy the tow:** the Adjuster stands down. *"Ruling enforced. The Belly
  moves."* The tug: *"...we'll remember them."* Its salvage drops (credits and a
  pick). — Ruin
- **Fight the Adjuster:** its Lockout is the lien. Win, and both Haulers patch you
  (10 + 8). *"Everyone's still here. Thank you."* — Mercy

The towed ship fights under `BOSS`, which raises no attack event. Shooting it doesn't
make the tug think it was attacked, and `BOSS_DEFEATED` reads as "the tow was cut".

## Inbound — "Stop running."

### The Pilgrim — `EVENT_Pilgrim` (stand-in for the Fate's Die handover)
A lone **Pilgrim** (`pilgrim_wandering`, no Relay, so sector 1) offers a die.
*"Everyone gets one. Few ever look."*
- **Take it:** *"It was always yours."* It flies on inward.
- **Shoot it:** *"Why run? It's behind you too."* It siphons your drive.

### The Pact — `EVENT_Pact`
A **Zealot** offers two RARE tiles. *"Power, for a little of you. 12 hull."*
- **Take one:** 12 hull, paid on the spot. *"Sealed. See you at the horizon."* — Hunger
- **Attack it:** *"Then give it all at once!"* It hits hard and overloads itself.
  Win, and the offer is free.

## Spilled — "Nobody knows."

### Signal — `EVENT_Signal`
A **Wisp** sits neutral. *"...you... are falling too..."* It offers two picks (RARE
or better, half dice).
- **Take anything:** it fades on one of three random fragments. — Strange
  - *"...not behind... ahead... another..."*
  - *"...your dice... were our bones..."*
  - *"...we went in... came out... wrong..."*
- **Shoot it:** *"...hush... hush... HUSH..."* and a **Shroud** uncloaks beside it.

### What Came Back — `EVENT_WhatCameBack`
A **Shroud** escorts a **Hauler** that fell in. Hauler: *"Where are we? What year is
it?"* Shroud: *"...returned... incomplete..."*
- **Take the cargo:** *"Keep it. We have to go back."* Both fly back toward Fate.
  — Strange
- **Shoot the Shroud:** the Hauler turns on you (*"No! It brought us back!"*), and the
  Shroud calls a Wisp. — Ruin

---

## Authoring notes

- **A parting line needs time.** `FLEE` frees the ship at once, so every farewell
  state waits first (SET amount + WAIT, 3 s; 5.5 s when a second ship speaks at the
  same moment, since its line queues 3 s behind).
- **One voice per side.** A second ship on a side is silent (`_silent` states). Lines
  from the two sides queue rather than overlap.
- **Shots on one side can't be told apart**: any pirate hit raises
  `PLAYER_ATTACKED_PIRATE`. Build "shoot A vs B" choices across sides (or put one
  ship under `BOSS`, as in Cut Loose).
- **A friendly ally's table runs under the sector's variety cap.** In sector 1 the
  Picket would drop a kind; it only appears from sector 2, where Aegis, Raid and
  Shield all fit.
- `ATTITUDE_IS` conditions flip a ship's kit when it turns (the Picket's Raid only
  while friendly, its attack only once it turns).

## Open

- Nothing carries between encounters yet (gossip, liens, Debt allies). Several
  betrayal paths (kill the Pilgrim, then take its die; fight the Zealot for a free
  tile) pay as well as the kind path. Run memory and Fate's Die are where they'd cost.
- Fate's Die faces aren't carved yet. The faces noted above are the hooks.
