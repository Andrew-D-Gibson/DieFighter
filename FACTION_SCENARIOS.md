# Faction Scenarios

The faction encounters from `LORE.md`, built on the faction ships (commit
8b6ac6d6), and where every encounter in the game is dealt (below). Folders are
under `Source/Content/ScenarioResources/Scenarios/`. The faction events are in
SectorGenerator's `question_scenarios`, and Wake Riders is in `elite_scenarios`.

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
  Harpooner stripping a wreck field, and you look like more of it), Vigil (two
  Zealots keeping watch where the horizon is nearest), Scrap Run (a Smokestack,
  Harpooner and Jackal working the wake: *"Slow and shiny. Strip it."* Kill one
  and the Jackal bolts with whatever dice it holds).
- **Events:** Pilgrim (the Fate's Die handover), Straggler, Pirates Attacking
  Civilian†, Mayday†, Sleeping Drone, Signal, What Came Back†, White Flag (a
  limping Gaff hunted by the forgotten sentry drone), Martyr (a Gaff strips a
  Pilgrim that won't resist).
- **Elites:** Wake Riders†, Chopshop (the Warden's breakers: *"The Warden wants your
  parts."*), The Line Moved On (a sentry grid still holding a line that left
  decades ago).
- **Gate:** the Sector Warden, *Warlord of the Tail*: *"Everyone back here is
  already dead."*

### Sector 2: The Belly ("Keep everyone together.")
The Caravan's heart, and the most mixed layer: Compact enforcers, Undertow
infiltrators, Inbound recruiters and Rearguard press-gangs all come for something.

- **Combats:** Lien Collection, Pilgrimage (Inbound recruiters), Smash and Grab,
  Carrier†, Picket Line† (a draft sweep), Tender Escort (a Conscriptor and the Caravan
  medic it drafted), Cutpurse†, Wreckers†, Communion† (a Pilgrim feeding its luck to
  a Fate Shroud), Blockade (a Compact Arbiter and Tug halting traffic around a
  Liner that keeps them stocked with holograms: *"Compact blockade. Nobody
  jumps."*), Procession (Inbound recruiters in force: a Censer, a Plumb Line that
  sinks deeper every round, and an Acolyte shielding them: *"Turn around. Come
  and see."*).
- **Events:** Convoy, Cut Loose (the Chancellor's philosophy in miniature), Mercy
  Call, Pickpocket, Wreck Salvage (under a Claims Adjuster's guard), Pact†, Last
  Picket (the honest Rearguard holding the Belly's back), Ghost Carrier, Mayday†,
  Pirates Attacking Civilian†, What Came Back†, Wolf in the Fold (an Undertow
  infiltrator in a Caravan hull), Turn Around (a Zealot leading a family
  inward), Still on Patrol†, Recruiter (a Pilgrim talks a tired Caravan family
  into flying inward).
- **Elites:** Hunter-Killers† (an Undertow fighter and Jackal with a Rearguard drone:
  someone paid for you), Repossession (an Arbiter and Tug kept running by a Field Tender:
  *"Your lien is due."*), Wake Riders†, Twin Flames (a Zealot, Censer and the Pilgrim
  feeding them), Procession† (a Zealot, a Pilgrim relaying it luck, and an
  Acolyte shielding the procession).
- **Gate:** the Arc Dynamo, *the Chancellor's reactor barge*: *"The Belly can't wait
  for one ship."*

### Sector 3: The Spine ("Hold the line, buy time.")
Checkpoints, tithes and warships, plus the Undertow they hire under the table.

- **Combats:** Tithe Collector, Tithe Escort, Ion Lances, Defender + Disabler, Drone
  Battery, Siege Battery, Spotter, Bounty Run (a Rearguard lance escorting an Undertow
  smuggler in civilian clothes), Carrier†, Picket Line†, Communion†, Shield Wall (a
  Bulwark holding the checkpoint, a Drillmaster marking and firing on the mark,
  and a Herald passing them its dice: *"The line holds. You do not."*).
- **Events:** Tollkeeper (*"Tithe taken. It buys us all time."*), Deniable Assets,
  Black Market (the checkpoint's back door), Deserter, Pact†, Tithe Run, The
  Ledger, Quarantine, Stowaways, Still on Patrol†, Apostate (a Tithe Collector
  that saw where the tithe goes, flying inward under the Inbound halo).
- **Elites:** Tithe Fleet, Lance Squadron, Mortar Nest (a Picket shields the
  mortars), Hunter-Killers†, Procession†.
- **Gate:** the Bastion, *the Marshal's fortress*: *"Four hundred years. Not you."*

The Mayday comes from a Bounty Runner: a civilian hull with an Undertow badge, the
tell for anyone reading the targeting computer. Sometimes it's bait (it runs on round
3), and sometimes an Undertow straggler really is dying.

Blockade Runner was cut. It overlapped Bounty Run, and an Undertow smuggler escorted
by a Caravan medic fit neither faction.

### Ship variety within the faction slots

The third-wave ships also appear outside their showcase trios. These swaps
keep the original ship counts, sectors, states, dialogue, rewards and story
branches; each replacement has the same lore faction as the ship it replaces.

| Faction | Additional placements |
|---|---|
| Rearguard | Bulwark guards Siege Battery and Tithe Fleet; Drillmaster marks targets in Spotter and Lance Squadron; Herald feeds Drone Battery and Tithe Fleet. All stay in the Spine. |
| Undertow | Jackal joins Wolfpack and Hunter-Killers; Harpooner works Boneyard and Chopshop; Smokestack joins Chopshop and Smash and Grab. The hired Rearguard drone in Hunter-Killers remains. |
| Caravan | Liner supports the Claims Adjuster in Lien Collection. Repossession fields an Arbiter and Tug with its original Field Tender, preserving the Compact's collection demand and repair support. |
| Inbound | Plumb Line joins the relaying Pilgrim in Pilgrimage; Acolyte shields Elite Procession alongside its remaining Pilgrim; Censer replaces one of Twin Flames' two overload ships, with the relaying Pilgrim retained. |
| Spilled | Brood leads Hollows; Hulk escorts Maw; Grasp escorts Shroud and joins the hostile side of Last Picket. The Pickets and their rescue/betrayal states remain intact. |

Story-bound hulls keep their roles: the masquerading smuggler, adrift ships,
medics, the Apostate, and event allies with Raid hand-offs are unchanged.

### Foreshadowing the secret
Four encounters hint at `LORE.md` §4 without saying it, and only a player who puts
them together gets it: the tithe convoy flying *aft* with a Wisp on its wing (Tithe
Run), the Picket arrested for counting where the tithe goes (The Ledger), and the
Rearguard echo still carrying it in (Still on Patrol). Quarantine leaves open
whether what comes back out of the hole is still people.

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

The Fate's Die face each choice carves is noted beside it (LORE.md §5). They
are carved by a `CARVE_FATE_FACE` step on the ship state the choice leads to
(see CONTENT_BUILD_GUIDE §4); a saved ship also remembers the player
(`REMEMBER_SHIP`) and flies into the Reckoning to help.

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
**Shroud + Grasp**. *"We've held 400 years. Hold with us."*
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

### The Tithe Run — `EVENT_TitheRun` (sector 3)
A **Tithe Collector** and a silent **Picket** fly *aft*, toward Fate, against the
whole fleet. A **Fate Wisp** rides on their wing, under `BOSS`. *"Tithe convoy.
Clear the lane."* A courier's fee floats beside them.
- **Take the fee:** *"Good. Eyes forward."* All three fly off toward Fate together.
  — Duty
- **Rob the convoy:** the Rearguard bounty is the tithe itself (dice-heavy pick, big
  credits). When the convoy falls the Wisp wakes up, *"...that was ours... the front
  owes us..."*, and launches a Shroud. Kill both for a Strange pick (UNCOMMON or
  better, half dice). — Plunder
- **Shoot the Wisp:** `BOSS` shots raise no event, so the convoy turns when it dies:
  *"Orders: never touch the escort."* — Strange

`PIRATE` and `BOSS` are allied, so the Wisp really is on the convoy's side. Once the
convoy is attacked the Wisp stops watching the fee (`wisp_watching_silent`), so
pocketing it mid-fight doesn't send the Wisp home.

### The Ledger — `EVENT_Ledger` (sector 3, Aegis Link is ally support)
A battered **Picket** (`picket_holdout`, 60% hull) is under arrest, escorted by a
**Conscriptor**. Its ledger floats as the encounter's one pick (UNCOMMON or
better). Picket: *"I counted the tithe. It goes forward."* Conscriptor: *"Prisoner
transfer. Move along."*
- **Take the ledger, or shoot the Conscriptor:** *"That's classified. Hand it
  over."* / *"Aiding a traitor? Then hang."* The Picket breaks free and Raids. Win,
  and it patches 10 hull: *"Ask the Vanguard where it goes."* — Mercy
- **Shoot the Picket:** *"Saves us a tribunal."* The Picket's wreck pays credits,
  and the Conscriptor says *"Loyalty noted."* The ledger still floats, and taking it
  now turns the Conscriptor on you, alone. — Ruin

There is no faction bounty: the ledger is the pick, so betrayal can't stack a second
one on top.

### Quarantine — `EVENT_Quarantine` (sector 3)
A **Conscriptor** and a silent **Picket** (`picket_holdout`) are firing on a
**Hauler** (55% hull) that came back out of the hole. *"Quarantine. It came out of
the hole."* Hauler: *"We're still us! Please!"*
- **Join in:** Hauler: *"We only wanted to come home!"* Its wreck pays credits, and
  the Rearguard leave: *"Line holds clean. Move along."* — Duty
- **Protect it:** fight the Rearguard while the Hauler Raids. Win for the bounty
  pick, then a 3:2 roll:
  - *"We're us. We're still us."* 12 hull. — Mercy
  - *"...thank you... for carrying us..."* A purple, glitching patch: 16 hull.
    — Strange
- **Do nothing:** they finish it with the dice you hand them.

### Stowaways — `EVENT_Stowaways` (sector 3)
A **Tithe Collector** (`tithe_collector_inspector`) inspects a **Bounty Runner**
(`bounty_runner_smuggler`), the Undertow smuggler in a Caravan hull, its holds full
of refugees dodging the tithe. *"Holds open. Tithe by head."* Runner: *"Just cargo,
officer. Right, pilot?"*
- **Cover for them (shoot the Collector):** *"Ha! Knew I liked you."* The Runner
  Raids. Win for the bounty pick, and *"Fare's paid. Patch up on us."* 10 hull.
  — Mercy
- **Expose them (shoot the Runner):** *"Good eye. Burn the smuggler."* / *"Fine.
  Catch us if you can."* The Runner carries its own pick and bolts on round 3, as in
  Bounty Run. — Duty

The smuggler variant only flees while it's fighting you, never while it's on your
side.

### The Line Moved On — `ELITE_LineMovedOn` (sector 1)
Two **Cannon Drones**, a sentry grid the line left behind decades ago, still holding.
*"LINE HOLDS. ALL BEHIND IT: HOSTILE."* Behind the line is now the whole Tail. An
elite at 1.3×, and it stays inside the Tail's rule that the only Rearguard here is
the forgotten drone (`test_the_tail_meets_no_rearguard_but_what_it_left_behind`).

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

### White Flag — `EVENT_WhiteFlag` (sector 1)
A **Gaff** (`gaff_raider`, 75% hull) is hunted by the Rearguard sentry drone the line
forgot (`cannon_drone_hunter`). The predator is the straggler now. Pirates
Attacking Civilian with the roles flipped: the Gaff is the protected side.
*"UNDERTOW VESSEL. BOUNTY AUTHORISED."* Gaff: *"I know what I am. Help anyway."*
- **Shoot the drone:** *"INTERFERENCE. ENGAGING."* The Gaff Raids it. Win for the
  bounty pick, and *"Spare plates. We're square."* 10 hull. — Mercy (the Debt hook)
- **Shoot the Gaff:** *"Slow is dead. Right. Right."* The drone says *"BOUNTY
  CONFIRMED."* The Gaff's wreck pays credits. Quick and safe. — Duty
- **Do nothing:** the drone finishes it with the dice you hand it, then *"RESUMING
  PATROL."*

### Wolf in the Fold — `EVENT_WolfInTheFold` (sector 2)
A **Hauler** and a **Bounty Runner** (`bounty_runner_smuggler`) fly side by side in
the same Caravan hull. They're on opposite sides, so both speak, and both say the
same thing: *"That one's Undertow! Check its badge!"* The targeting computer's
badge is the only tell.
- **Shoot the Runner:** *"Clever. Too clever."* Hauler: *"You read it right!"* The
  Runner carries the pick and bolts on round 3 while the Hauler Raids it. Win, and
  *"Stay sharp. They're everywhere."* 10 hull. — Mercy
- **Shoot the Hauler:** *"We're Caravan! We're Caravan!"* The Runner says *"Thanks,
  mark,"* and leaves with its pick. All you get is the Hauler's salvage. — Ruin

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

### The Pilgrim — `EVENT_Pilgrim` (the Fate's Die handover)
A lone **Pilgrim** (`pilgrim_wandering`, no Relay, so sector 1) offers a die.
*"Everyone gets one. Few ever look."* (To a player who knows the secret: *"You've
seen the front. You know."*) Dealt into every first sector, past the first
jump's reach (`SectorGenerator.place_fate_pilgrim()`).
- **Take it:** *"It was always yours."* Fate's Die is yours, blank. It flies on inward.
- **Shoot it:** *"Why run? It's behind you too."* The die is yours anyway, with
  Ruin carved. It siphons your drive.

### The Pact — `EVENT_Pact`
A **Zealot** offers two RARE tiles. *"Power, for a little of you. 12 hull."*
- **Take one:** 12 hull, paid on the spot. *"Sealed. See you at the horizon."* — Hunger
- **Attack it:** *"Then give it all at once!"* It hits hard and overloads itself.
  Win, and the offer is free.

### Turn Around — `EVENT_TurnAround` (sector 2)
A **Zealot** (`zealot_herald`) leads a **Hauler** family inward. Two RARE tiles
float as its gift. *"Stop running. Turn around."* Hauler: *"They say it's better
over there."*
- **Take a gift:** *"Leave the credits. They don't cross."* It takes **every
  credit you have**, and both fly inward: *"Then we all go together."* — Hunger.
  Pact costs hull. This costs everything you'd spend on the way forward.
- **Shoot the Zealot:** *"Faithless!"* Hauler: *"I don't know who's right..."* The
  overload is the puzzle. Win, and the gift is free, plus *"It's still behind us.
  Isn't it."* 10 hull. — Mercy
- **Shoot the Hauler:** *"Yes! Send them across!"* The Zealot Raids it alongside
  you, then *"They're home. Take your gift."* The gift is free. — Ruin / Hunger

The take-everything uses `STEAL_MONEY` for 9999, which always comes up short, so
the Zealot's state must never transition on `PLAYER_COULDNT_PAY`.

### Twin Flames — `ELITE_TwinFlames` (sector 2)
A **Zealot**, a **Censer** and the **Pilgrim** relaying dice into them. *"Stop running. Come
home."* The Relay pushes the Zealot and Censer toward their overload and the Siphon pins you
in place: kill the Pilgrim first for a slower, safer fight, or ride the relays and
burn both out. An Inbound elite (1.35×, Belly only: the Relay is ally
support).

### The Vigil — `COMBAT_Vigil` (sector 1)
Two **Zealots** keep watch at the edge of the Tail, where the horizon is nearest, so
that nobody turns back. *"Stop running. We'll wait with you."* The Zealot's overload
is the fight: two 6s into one Zealot and it burns through its own hull instead of
attacking.

### Martyr — `EVENT_Martyr` (sector 1, vs the Undertow)
A **Gaff** (`gaff_raider`) strips a battered **Pilgrim** (`pilgrim_wandering`) that
doesn't resist. Gaff: *"Doesn't even beg. Gives me the creeps."* Pilgrim: *"Let it
take. I won't need any of it."* The Undertow and the Inbound agree the slow are
already dead; they disagree about what that means.
- **Shoot the Gaff:** *"Fine. You've got parts too."* The Pilgrim, unimpressed: *"Why
  fight? It was only things."* While it stands by, dice you hand it go to a Raid on
  the Gaff, and the Gaff's Raids go at it. Win with the Pilgrim alive and it patches
  10 hull before it flies inward: *"Keep running, then. I'll go ahead."* — Mercy
- **Shoot the Pilgrim:** it doesn't fight back. *"Thank you. Send me home."* The
  Gaff leaves you the wreck (12-20 credits): *"It thanked you?! Keep it. I'm gone."*
  — Ruin / Hunger

### Recruiter — `EVENT_Recruiter` (sector 2, vs the Caravan)
A **Pilgrim** (`pilgrim_wandering`, under PIRATE) talks a worn-out **Hauler** family
into flying inward. Pilgrim: *"Stop running. Come home with us."* Hauler: *"They say
it's better on the other side."* The Pilgrim's gift floats between them (two picks,
UNCOMMON or better).
- **Take the gift:** *"See? Even runners get tired."* Hauler: *"If even you'll take
  it... we'll go."* Both fly inward. — Hunger
- **Shoot the Pilgrim:** *"Then I'll wait for you there."* Hauler: *"Wait. What were
  we thinking?"* Win, and the Hauler patches 10 hull: *"We'll keep running. Take our
  spares."* Take the gift mid-fight and the family gives up and leaves anyway.
  — Mercy
- **Shoot the Hauler:** *"We were tired. Not dead!"* It fights and runs once hurt;
  its wreck pays credits and a pick. The Pilgrim consoles it (*"Shh. Not long now.
  You're going home."*), then, dead or fled: *"One way or another, it's going home."*
  — Ruin

### Communion — `COMBAT_Communion` (sectors 2-3, with the Spilled)
A **Pilgrim** kneels beside a **Fate Shroud** and Relays its luck into it. *"Be
still. It came back for us."* Everyone fears the Spilled; the Inbound feed them.

### Procession — `ELITE_Procession` (sectors 2-3)
A **Zealot**, a **Pilgrim** and an **Acolyte**, flying inward against the fleet. *"Make way. The
faithful are going home."* The Pilgrim and Acolyte siphon your drive so you can't leave. The Acolyte shields its allies, while the Pilgrim Relays dice into
the Zealot, so their faith can overload it for you.

### Apostate — `EVENT_Apostate` (sector 3, vs the Rearguard)
A **Tithe Collector** (`tithe_collector_apostate`: the Rearguard hull, the Inbound
badge) flies inward, dumping its hold of tithe (a die, or 20-30 credits). *"Take it.
I saw where the tithe goes."* A **Conscriptor**: *"Touch that tithe and you're
drafted."* It's the first hint of `LORE.md` §4 a player can find.
- **Take the tithe, or shoot the Conscriptor:** *"Drafted. Report to the line."*
  While it fights you, dice you hand the Apostate go to a Raid on it. Win for the
  bounty pick, and the Apostate leaves you the secret: *"Every die you ever paid went
  in."* — Hunger / Mercy
- **Shoot the Apostate:** *"Then it goes in with me."* The Conscriptor: *"Good. Bring
  the heretic down."* Win for its wreck (15-25 credits). The Conscriptor then guards
  the tithe (*"Tithe recovered. Leave it be."*), and taking it drafts you. — Duty

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

### Still on Patrol — `EVENT_StillOnPatrol` (sectors 2 and 3)
A lone **Fate Husk**, the Defender's echo, flies a patrol route 400 years old.
*"...Picket Nine... holding... holding..."* It offers "resupply": a common pick.
- **Take it:** *"...dismissed... resume patrol..."* It flies on, forever. — Duty
- **Relieve it (shoot it):** it barely fights. One of three fragments, at random:
  *"...relief...? at last..."*, *"...we carried the tithe... in..."*, *"...the
  front... said hold..."* The wreck holds a RARE pick. — Mercy / Strange

Shooting first and then taking the resupply gets both. That's deliberate: the kind
path pays more, and taking the issue is the safe one.

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
- **A faction "falls" when its last ship leaves, fled or killed.**
  `PIRATES_DEFEATED`, `CIVILIANS_DEFEATED` and `BOSS_DEFEATED` fire on a farewell
  `FLEE` too. A state that's waiting for the other side to fall must already have
  moved on when that side is only leaving (the Tithe Run's Wisp takes the fee path
  into `wisp_following_silent` first).
- **Any ship that can sit on your side while its enemy fights you needs a Raid in
  every pool.** For a ship whose shared resource has none, use a variant gated on
  not-aggressive, like `hauler.tres`: `cannon_drone_hunter`,
  `tithe_collector_inspector`, `zealot_herald`, `bounty_runner_smuggler` (which also
  only flees while it's hostile). `test_ally_hand_offs.gd` names any ship that's
  missing one.
- **Neutral ships only act on the dice they're handed.** A "they're firing on it"
  opening (Quarantine, White Flag) plays out only as fast as the player feeds it.

## Faction memory: what carries between encounters

The run remembers (ARCHITECTURE "Faction Memory"; authoring in
CONTENT_BUILD_GUIDE §4). Each outcome below records a deed: a standing change
for the faction that felt it, and a name later encounters can ask about. A
faction's standing reads as a regard: HATED ≤ −6 < DISLIKED ≤ −2 < NEUTRAL <
2 ≤ LIKED < 6 ≤ TRUSTED.

| Faction | Kind (deed, standing) | Cruel (deed, standing) |
|---|---|---|
| **Caravan** | `caravan_convoy_saved` +2 (Convoy), `caravan_tow_saved` +3 (Cut Loose), `caravan_hauler_saved` +2 (Deniable Assets), `caravan_straggler_saved` +2, `caravan_civilian_saved` +2 (Pirates Attacking Civilian), `caravan_lien_paid` +3 | `caravan_shop_attacked` −4, `caravan_dock_attacked` −4, `caravan_medic_betrayed` −4, `caravan_betrayed` −3 (any grateful Caravan ship turned on), `caravan_tow_cut` −2, `caravan_hauler_sold` −2, `caravan_straggler_plundered` −3, `caravan_salvage_robbed` −2, `caravan_lien_refused` −5 / `_defaulted` −3 |
| **Rearguard** | `rearguard_picket_relieved` +2, `rearguard_spared` +2, `rearguard_tithe_paid` +1, `rearguard_bribe_taken` +1, `rearguard_deserter_shot` +1 | `rearguard_prisoner_shot` −3, `rearguard_deserted` −3 (Last Picket), `rearguard_tithe_refused` −2, `rearguard_exposed` −2, `rearguard_defied` −2 (Deserter) |
| **Undertow** | `undertow_mayday_saved` +2, `undertow_partnered` +1 (Straggler, Pirates Attacking Civilian), `undertow_black_market` +1 | `undertow_mayday_betrayed` −3, `undertow_runner_burned` −2 |
| **Inbound** | `inbound_pilgrim_freed` +2 (Deserter), `inbound_pact_sealed` +2, `inbound_die_taken` +1 | `inbound_pilgrim_shot` −2 (Pilgrim, and Deserter's Conscriptor), `inbound_pact_refused` −2 |
| **Spilled** | `spilled_listened` +1 (Signal), `spilled_let_go` +1 (What Came Back) | `spilled_silenced` −2, `spilled_attacked` −2 |

Player kills are counted per faction too, though ordinary fights move no
standing.

**What reads it now:**
- **Every Compact shop and repair dock** prices by the Caravan's regard: ×1.5
  HATED, ×1.25 DISLIKED, ×0.9 LIKED, ×0.8 TRUSTED (a dock pays that much less
  for sold parts). The keeper says so on arrival (`shop_ship_greeting`,
  `repair_dock_greeting`): *"You hit a Compact shop. Prices went up."* /
  *"Compact has your file. Prices went up."* / *"Friend of the Compact! Fair
  prices for you."*
- **The Compact collects** (`GRUDGE_CompactLien`, a consequence): once the
  Caravan DISLIKES the player, the next sector holds a Claims Adjuster ahead of
  the arrival. It takes a 20-30 credit lien on arrival and names the
  crime (*"Lien for the shop you hit. Collected."*). Paying mends standing
  (+3); shooting it or coming up short is a fight and a deeper grudge.
- **Rearguard crews surrender** in Picket Line, Tithe Collector, Tithe Escort,
  Ion Lances and Defender + Disabler: at 30% hull a ship yields (*"Hold fire!
  We yield!"*), holds its fire and goes neutral. Shoot it, and it fights to the
  death (*"No quarter? Then none given!"*, −3). Let the fight end with it
  alive, and it gives 3 charge and 6 hull and flies off (*"You held fire. The
  line remembers."*, +2). Sparing a last ship forfeits the bounty; the standing
  pays it back later.
- **The Tollkeeper** waives the tithe for a Rearguard that LIKES the player
  (*"You're on the Marshal's list. Pass, pilot."*) and doubles it (20-36) for
  one that DISLIKES them.

## Open

- More readers. The hooks are general (standing branches, encounter
  requirements, consequences); most factions have no consequence encounter
  yet. Natural next ones: an Undertow bounty hunter for a player who hunts them
  and Debt allies for one who spares them (LORE §9), Inbound recruiters
  greeting a Hunger-heavy run, the Last Picket offering more to a Rearguard
  friend, Mayday calls going quiet for a player the Caravan hates.
- LORE §9's dice consequences (+1 on dice a hating faction is handed, a die
  back from a liking one) would touch combat balance everywhere, so they're
  not in yet.
- Fate's Die is carved, and saved ships and Debts carry into the Reckoning
  (`FateLedger`). Many outcome states carry both a faction deed and a Fate
  carving; the two ledgers don't read each other yet.
- Several betrayal paths (kill the Pilgrim, then take its die; fight the Zealot
  for a free tile) still pay as well as the kind path within the encounter;
  their cost is the standing they lose, the face they carve, and who isn't
  there at the end.
- Carved beyond the faces noted above: Mercy on the Mayday saved and the civilian
  rescued from pirates; Ruin on the Mayday wronged, the medic betrayed, the
  civilian betrayed, the Picket deserted and an angry shop or dock; Plunder on
  taking the Wreck Salvage cargo under guard; Debt for the Black Market runner,
  the Straggler's Wrecker and pirates left to their raid.
- Faces with only a few sources: Hunger (the Pact, flying into Fate's tiles) and
  Strange (Signal, What Came Back). A careful run in a short sector may not fill
  the die; watch how often it does.
- White Flag's spared Gaff and The Ledger's Vanguard line are written for run memory
  (a Debt ally, and the Vanguard answering the ledger): two more readers to add.
