# LORE.md — The Long Retreat

The world, its factions, and the Fate storyline. This is a design doc rather than an
implementation plan: names, numbers and mechanics here are proposals until they're built.

---

## 1. The Premise

A black hole is eating the galaxy. Everyone calls it **Fate**.

It isn't chasing *you*. It's chasing everyone. The whole of civilization is fleeing in
the same direction, in one vast refugee fleet light-years wide: **the Long Retreat**.
Nobody alive remembers a time before it. Children are born into the Retreat, grow old
in it, and die in it, and the horizon behind them is a little closer each generation.

You're one ship in that fleet, trying to get ahead.

### Theme pillars

- **Chance and choice.** Dice decide what you *can* do; you decide what you *do*. Fate
  is the one thing nobody chooses, and the game is about what people do anyway.
- **Every die goes to someone.** You never keep your dice. Each one you roll ends up
  with you or with an enemy, so every turn is about dividing up chance. In the world,
  luck is something you can literally hand to someone else.
- **Running is the verb.** Engine charge, jumping, escaping. The fiction should always
  be about getting ahead of something that can't be outrun.
- **The sector is watching.** Your deeds travel ahead of you through the fleet. Factions
  remember, and so does Fate.

---

## 2. The Factions

Each faction is defined by its answer to the same question: *what do you do when the
end is certain?*

| Faction | Their answer | Role in play | Existing content that belongs to them |
|---|---|---|---|
| **The Rearguard** | "Hold the line, buy time." | Imperials / military | Tithe Collector, Tollkeeper, the Bastion |
| **The Undertow** | "The slow ones are already dead, so take their stuff." | Pirates | Raider, Bounty Runner, Dice Thief, Black Market, Sector Warden |
| **The Caravan** | "Keep everyone together." | Civilians, shops, medics | Shop, Repair Dock, Civilian Transport, Mayday, Mercy Call |
| **The Inbound** | "Stop running." | Fate cult | *(new)* |
| **The Spilled** | Nobody knows. | Aliens from the hole | Fate Husk, Fate Leech, Fate Maw, Fate Attacker |

### The Rearguard
An army that has been retreating for four hundred years. Proud, worn out, and the only
thing standing between the Caravan and the horizon, or so they say. They claim the
right to draft any ship and collect a **tithe** of dice from everyone who passes their
checkpoints. Most of them truly believe the tithe buys the fleet time. (See §4 for
where it actually goes.)

### The Undertow
Pirates who live in the fleet's wake, where the stragglers fall behind. They pick off
ships too slow or too broken to keep up. Brutal, but honest about it: they're the only
faction that doesn't pretend the Retreat is fair. The Rearguard officially hunts them
and quietly hires them as deniable muscle.

### The Caravan
Generation ships, traders, medics, families. The Caravan is what everyone else is
supposedly protecting. It's also the slowest part of the fleet, which means the hole
reaches it first. Shops and repair docks belong to the **Caravan Compact**, a loose
trade network that shares news and grudges fast.

### The Inbound
A cult flying *toward* the hole. They believe whatever crosses the horizon gets
re-rolled into something better. They recruit from desperate Caravan families, offer
cursed pacts (big power with an honest downside), and are the only faction that
*wants* you to meet Fate.

### The Spilled
Things that came *out* of the black hole. Usually hostile, rarely understandable. Fate
Husks and Leeches are their dead, or their scouts, or their children. Nobody knows.
They know more about Fate than anyone, and they're the only ones who could tell you,
in pieces across many runs, what's on the other side.

### How they relate

- The **Rearguard** protects the **Caravan** and taxes it hard.
- The **Undertow** preys on the **Caravan**, while the **Rearguard** secretly hires them.
- The **Inbound** recruit from the **Caravan**'s most desperate and are hated by the
  **Rearguard**, who see them as deserters.
- Everyone fears the **Spilled**. The **Inbound** worship them.

Each choice you make favours someone and hurts someone else.

How each faction *looks* (colours, shapes, symmetry, and the badge on the targeting
computer) is in §12.

---

## 3. The Fleet's Geography

Each sector is a layer of the Retreat, getting closer to the front. Every boss is a
**pack leader racing for the front**: they want exactly what you want, and each has
paid a different price for it.

| Sector | Layer | Feel | Boss |
|---|---|---|---|
| 1 | **The Tail** | Wreckage, stragglers, Fate visible on the horizon behind you. Mostly Undertow. | **An Undertow warlord** (the Sector Warden) who survives by eating the slow. *"Everyone back here is already dead. I'm just the one who noticed."* |
| 2 | **The Belly** | The Caravan's heart: markets, medics, generation ships. Most shops and civilian events. | **The Caravan's Chancellor**, who keeps the Caravan moving by deciding who gets left behind. Sympathetic, maybe even right. |
| 3 | **The Spine** | Rearguard territory: checkpoints, tolls, Tithe Collectors, warships. | **The Marshal of the Rearguard**, who has held the line their whole life and just wants one ship to make it. |
| Final | **The Front** | Empty, quiet, beautiful, and wrong. | **The Vanguard.** |

More sectors later fit in as more layers (the Wings, the Vanguard's Escort, and so on).

Each encounter is dealt only into its layer's sector (`ScenarioResource.sectors`).
The rosters, and the story each encounter tells, are in
`Planning Documents/FACTION_SCENARIOS.md`.

**The Rearguard isn't at the rear.** They say they hold the line between the Caravan
and the horizon, but the Spine sits *ahead* of the Belly, and that's deliberate. They
tithe everyone who passes from safety. In the Tail and the Belly you meet only what
they left behind: a sentry drone the line forgot, press-gangs drafting Caravan ships
(the Conscriptor and its pressed medic), and the few honest Pickets actually holding
the back (Last Picket). That foreshadows §4: the tithe was never buying the back of
the fleet anything.

---

## 4. The Vanguard and the Secret

**The Vanguard** has led the fleet for over three hundred years.

> *"I've been at the front longer than your grandmother's grandmother was alive. Do you
> know why no one ever catches me?"*

When the Vanguard dies, they pass on the forbidden knowledge, in two parts:

1. **There's a black hole ahead.** The fleet was never escaping. It's being herded.
2. **The Vanguard made a deal with it.** Fate lets the front survive, and keeps the
   Vanguard alive, in exchange for the back of the fleet. **The Rearguard's tithe is a
   sacrifice.** Every die the Tithe Collector took went into the hole. The Rearguard
   thinks it's buying the fleet time. It's buying the Vanguard's life.

When the Vanguard dies, the deal breaks, and Fate comes to collect what it's owed. The
only question is whether it comes for *you* (see §6).

The dying Vanguard also gives you the **Vanguard Drive**: coordinates and a drive design
that can outrun a horizon. It's what makes the secret fight winnable.

---

## 5. Fate's Die

A seventh die that sits in your cockpit all run. **It's Fate's intent bank, and you
carve it.**

Enemies already have six intent slots keyed to die values. Fate's Die has six faces,
and each face is both a possible roll *and* an intent slot for the Fate fight.

### Introduction

Early in sector 1, an **Inbound pilgrim** flies past on their way *into* the hole and
hands you a blank die.

> *"It's been waiting for you. Everyone gets one. Most people never look at theirs."*

After that it sits in the cockpit, always visible, slowly filling in.

### Carving

- The die starts with **six blank faces**.
- Choices with moral weight carve a face. Each faction has its own:

| Face | Carved by (examples) |
|---|---|
| **Mercy** (Caravan) | Saving the Mayday ship, paying the medic, sparing a fleeing ship |
| **Plunder** (Undertow) | Robbing a shop, raiding a Caravan ship for the black market |
| **Duty** (Rearguard) | Paying the tithe, answering a conscription order |
| **Ruin** (betrayal) | Attacking someone who trusted you: the grateful civilian, the shop |
| **Hunger** (Inbound) | Taking a cursed pact, flying *into* a Fate node instead of jumping away |
| **Strange** (Spilled) | Helping or talking to the things that came out of the hole |

- **Once the die is full, new carvings go over old ones, and you choose which face to
  replace.** The die becomes something you shape on purpose rather than a tally: "I've
  got two Ruins, so I'll take this Mercy job and carve over one."
- Carving should be a visible moment (the die glows, a chisel sound, a line from the
  ship's AI) so the player always knows what they've done.

---

## 6. Unlocking the Secret Boss

The Fate fight is a hidden super-boss in the spirit of Spelunky's King Yama or Slay
the Spire's Heart. Three gates:

**Gate 1 — The knowledge carries over (meta).**
The Fate route only exists after you've beaten the Vanguard once. The forbidden
knowledge stays with *you*, the player, across runs. On later runs the Inbound pilgrim
has a new line: *"You've seen the front. You know."*

**Gate 2 — The die must be full.**
Fate only notices people who make choices. If any face is still blank when the
Vanguard dies, Fate passes you by and you get the normal ending. A careful, neutral run
never meets Fate; you have to go looking for crossroads. That's the theme in one rule.

**Gate 3 — The choice at the end.**
After the Vanguard falls, you get two jump vectors:
- **Forward**, to the front. The normal ending (§8).
- **Back**, toward Fate. Only appears if Gates 1 and 2 are met. The die in the cockpit
  starts rattling on its own.

**Optional hidden modifiers.** Secret conditions that change *how* the fight goes
rather than whether it happens. For example: if you refused every tithe, the Rearguard
echoes fight on *your* side, because you never paid into the deal.

---

## 7. The Reckoning (the Fate fight)

### Win condition: escape velocity
Fate can't be killed. You win by filling an **escape-velocity meter** to something
absurd, around 3× your normal max engine charge. The **Vanguard Drive** is the only
reason this is possible: a special tile or rule that turns surplus dice into escape
charge. The forbidden knowledge becomes a mechanic.

### Fate rolls your die
At the start of each round, before you place dice, Fate rolls the die you carved. The
face that comes up decides the round:

| Face | Round effect (proposal) |
|---|---|
| **Mercy** | An ally arrives (see below) |
| **Plunder** | An Undertow echo grabs one of your dice before you can place it |
| **Duty** | Rearguard echoes shield each other |
| **Ruin** | One of your tiles cracks (locked for this round) |
| **Hunger** | The event horizon moves forward an extra step |
| **Strange** | Something unpredictable, e.g. the Spilled scramble some enemy intent slots |

The roll happens up front, so you always know the round's modifier before committing
dice (perfect information holds). A bloody run gives a cruel die; a merciful run gives
a die that keeps sending help. And it's still a roll: even a saint's die can come up
Ruin.

### The Tally: your run played backwards
The hole spits out **every ship you destroyed**, stretched and time-dilated, in waves,
in **reverse order of when you killed them**. The last kill comes out first, and the
final wave is the **first enemy you ever destroyed**. You re-live the run backwards as
it gets swallowed.

Long runs will need a cap, e.g. grouping echoes by sector or taking the most notable
kills, but the reverse order is the emotional core.

### The horizon eats your cockpit
Every few rounds the event horizon swallows one column of your 3×5 grid. Those tiles
fall in, and you watch your machine being consumed.

### Allies fill the gap
**Ships you saved fly into the space the horizon ate.** The Mayday civilian you rescued
becomes a temporary ally tile in a swallowed column. The pirate you spared shows up as
a **Debt** tile that does one powerful thing and leaves.

A merciful run: as your cockpit is eaten, it fills back up with people you saved. A
ruthless run: the empty columns stay empty. *What you did out there is what holds your
ship together at the end.*

(Implementation note: allies as temporary tiles reuse the existing tile system and
avoid a new "friendly ship" targeting layer.)

---

## 8. Endings

**Forward (normal ending).** You reach the front and become the new Vanguard. A quiet
closing line: *"The Tithe Collector is waiting for your orders."* Do you keep the deal?
(Possible hook: that choice could become a starting option on the next run.)

**Escape (secret ending).** You jump and land somewhere *off the board*. In dice games,
a die that rolls off the table doesn't count. You're the first thing in history that
**doesn't count**: outside the Retreat, outside Fate. A quiet ending. The epilogue could
list the faces left on your die and what became of each ship that helped you.

**Fall in (secret loss).** You become one of the **Spilled**. On a later run, your ship
can appear as a Spilled enemy carrying one of your tiles, salvageable if you beat it.
The graveyard-echo idea, with lore behind it.

---

## 9. Factions in Day-to-Day Play

Principles:

- **Show consequences on the map.** Faction anger should be visible: hostile nodes
  marked, a bounty icon following your route. Players plan around a grudge instead of
  stumbling into it.
- **Make consequences use dice.** Factions that hate you have learned how you fight, so
  their ships get +1 on dice you give them. Factions that like you return a die at the
  start of combat. Reputation touches the core mechanic, not just prices.
- **Mercy pays more than cruelty costs.** The reward for being good should be bigger
  than the punishment for being bad, or players will just take the stats.
- **Every faction offers a deal and a chance to betray it.** One tempting moment per
  relationship where you choose who to cross.
- **Gossip.** The first line in a new node references something you actually did
  (*"You're the one who left the medic to burn."*). Cheap, and it makes the fleet feel
  like it's watching.

Per faction:

- **Caravan:** attack a shop or dock and the Caravan Compact circulates your ship's
  description. Shops still trade but **put a lien on a tile** (locked until you pay it
  off), or send a **Claims Adjuster**, a combat encounter carrying exactly what you
  stole. Mayday calls go quiet or turn into traps. Protect them and you get discounts,
  and allies in the Fate fight.
- **Rearguard:** pay tithes for safe passage, fewer ambushes and Duty faces. Refuse and
  they draft you: a forced combat with a Warden. Once you learn where the tithe goes,
  every tithe you paid feels different.
- **Undertow:** spare them and they remember: Debt allies, black-market access. Hunt
  them and the Rearguard likes you, while a bounty ship follows your route.
- **Inbound:** cursed pacts and Hunger faces. The only faction rooting for you to meet
  Fate.
- **Spilled:** usually hostile, but rare events let you talk to them. Each conversation
  reveals a little more about the other side.

---

## 10. Mapping to the Current Code

- Each ship's lore faction is `EnemyResource.faction`, a `FactionIdentity`
  (`Source/Content/Factions/`) holding its name and badge. That is who *built and flies*
  the ship; who it fights for in an encounter is still the scenario's ship state below.
- `ScenarioManager.Faction` is currently `PIRATE / CIVILIAN / BOSS`. It would grow to
  something like `REARGUARD / UNDERTOW / CARAVAN / INBOUND / SPILLED` (with `BOSS`
  possibly folded into the boss's own faction).
- `Events.player_attacked_ship(target, faction)` already reports attacks by faction,
  which is the natural hook for reputation and for carving Ruin/Plunder faces.
- Angry scenario states already exist (`shop_ship_angry`, `repair_dock_angry`,
  `mayday_wronged`, `medic_betrayed`, `civilian_betrayed`, `runner_burned`), so the
  per-encounter half of consequences is in place. What's missing is run-wide memory.
- Fate's Die and faction reputation would be run state on the save, alongside the
  existing sector and run stats.

---

## 11. Open Questions

- What does the Vanguard look like, and what is their name?
- Is "Fate" what everyone calls the hole, or only some factions? Does the Rearguard
  have its own name for it, and do the Inbound?
- How many faces can be carved per sector? Too few and Gate 2 is hard to reach; too
  many and the replace-a-face choice comes up constantly.
- Should blank faces exist in the Fate fight at all (e.g. "nothing happens"), or is a
  full die required precisely so they never do?
- How does the Tally scale with a 3-sector demo run versus a longer full run?
- Does the player ever learn what the Spilled are, or does that stay a mystery?

### Parked ideas
- **Knucklebones:** dice carved from the fossil bones of an extinct alien species that
  fell into the hole long ago, which is why rolling them bends probability. Could
  explain why dice matter in-world, and could be who the Spilled once were.
- **Throw count:** the menu counts runs as "Throw #37" rather than "Run 37", hinting
  that every run is the universe being re-rolled.

---

## 12. Visual Language

A ship should say which faction it belongs to before the player reads a word. Each
faction owns **one accent colour, one shape vocabulary and one symmetry rule**, and its
badge on the targeting computer is drawn from the same three things.

### Shared rules

- Ships face down at the player, engines at the top. Outlines are a single 1px `#040217`
  line, closed all the way round. Colours come only from the approved palette
  (`Art/_Palettes/aseprite_palette_final.aseprite`).
- Hulls are machined grey by default. The faction's accent goes on **lights, stripes,
  windows and emitters**, a small share of the pixels, not the whole hull. The two
  exceptions are deliberate: the Undertow's hulls are darker, and the Spilled's aren't
  grey at all.
- The 16×16 targeting portrait is a pale `#CEF0F1` silhouette; accent features (stripes,
  windows, slits, voids) are cut out of it as the interior detail.
- A ship's `cloak_main_color` / `cloak_bg_color` are its faction's light and middle
  accent, so a cloaked ship still shimmers in its own colour.

### The five factions

| | Rearguard | Undertow | Caravan | Inbound | Spilled |
|---|---|---|---|---|---|
| **Idea** | Hold the line | Pick off the slow | Keep everyone together | Fly toward the end | Came back wrong |
| **Accent** | Regulation blue `#43A6FC` `#3789CC` `#2C71AA` | Venom red `#D03656` `#90263C`, rust `#563226` | Lantern green `#7ABD33` `#659C2A`, warm window orange `#F29C5D`, cargo yellow `#CCB550` | Pilgrim gold `#EED35D` `#CCB550` `#98873B`, bleached white `#C4C1BC` `#CEF0F1` | Fate purple `#C552F1` `#A846CE` `#80359D`, void `#000000`, flesh navy `#463C91` |
| **Hull** | Light machined grey (`#C4C1BC`/`#A5A29D`), clean and even | Dark salvage (`#63605C`/`#343330`) with odd lighter plates bolted on | Mid grey, soft and rounded | Bleached, almost white; dark only at the tip | No grey, or a stolen grey scrap at most |
| **Shapes** | Chevrons and wedges pointing at the target; a horizontal band across the hull (*the line*); square shoulders; stacked armour plates | Hooks, barbs, cranes and rams; swept, jagged edges; one oversized part | Circles, capsules and pods strung together; wide and low; rows of lit windows | Rings and halos around a single tall spine; thin spokes; a point aimed down, at Fate | Voids punched through the body; tendrils; ragged edges with no panel lines |
| **Symmetry** | Strict mirror symmetry. Nothing out of place | Asymmetric on purpose: mismatched engines, one side bigger | Mirror symmetry, but soft, never pointed | Radial: the ring is the same all the way round | *Almost* mirrored, then skewed a pixel or two |
| **Badge** | A bar over a chevron (the line) | A barbed hook | A round pod with a row of lit windows | A halo over a descending spine | A void with a ragged, tendrilled rim |

The badge sits top-left of the targeting computer's screen, above the attitude face, so
the player reads *who* a ship is and *how it feels about them* in one glance. Its colour
is the faction's, independent of the attitude tint; the overlap is intentional (the
Undertow's red badge usually sits in a hostile red frame, the Caravan's green one in a
friendly green frame), so a red badge in a green frame is itself news.

### Ships by faction

| Faction | Built to the language | Older ships (assigned, predate it) |
|---|---|---|
| **Rearguard** | **Picket** (line ship: Aegis Link on an ally, light fire), **Conscriptor** (draft ship: Impound + Lockout) | Tithe Collector, Bamba Defender, Disabler, Siege Mortar, Cannon Drone, Ion Lance, the Bastion |
| **Undertow** | **Gaff** (crane-and-hook scavenger: Pilfer + Siphon), **Wrecker** (ram-jawed breaker: attack, Incendiary, Grid Quake) | Venom Fighter, Cutpurse, Bounty Runner, Carrier, Interceptor, Sector Warden |
| **Caravan** | **Hauler** (three-pod freighter: shields, then flees), **Claims Adjuster** (Compact enforcer: attack + Lockout as the lien) | Shop, Repair Dock, Civilian Transport, Field Tender, Arc Dynamo |
| **Inbound** | **Pilgrim** (haloed skiff: Siphon + Relay + Scrambler), **Zealot** (ring-and-lance: big hits, Overloads into its own hull) | none yet |
| **Spilled** | **Fate Wisp** (void with legs: Scrambler + Siphon), **Fate Shroud** (manta of voids: attack, Lockout, Target Lock) | Fate Attacker, Husk, Leech, Maw |

Encounters for the new pairs: `COMBAT_PicketLine`, `COMBAT_Wreckers`,
`COMBAT_LienCollection`, `COMBAT_Pilgrimage`, and the Fate variant `FATE_Shroud`.

### Bringing the older ships in line

Older ships were drawn before this language. A pass on 2026-10-30 brought them in:

- **Rearguard** lights are blue throughout (the Tithe Collector, Siege Mortar, Ion Lance,
  Disabler and Bastion were red, orange or yellow). The Defender and Cannon Drone are
  mirrored and clean, and the Tithe Collector, Defender and Cannon Drone carry the blue
  band.
- **Undertow** accents are venom red (the Carrier was orange, the Cutpurse purple). The
  Venom Fighter and Interceptor have dark salvage hulls, a bolted lighter plate,
  mismatched engines and a hook.
- **Caravan** ships have lit orange windows, a cargo stripe and green running lights. The
  Civilian Transport's face-like mouth is now a lit hangar.
- **Spilled echoes.** The Fate Husk, Leech, Maw and Fate Attacker are fleet ships that
  fell in and came back: the Defender, Cutpurse, Siege Mortar and Venom Fighter. Each is
  rebuilt from its source ship. Grey turns to navy flesh with purple highlights, one grey
  scrap survives, voids ringed in purple are punched through, the lower half skews a
  pixel, and unoutlined tendrils replace the engines. A new echo follows the same recipe.
- **Bosses**, one per faction by sector:
  - The Sector Warden (sector 1) is the Undertow warlord: a welded hull with a furnace
    maw, a crane and grapple, and trophies taken from the Caravan and the Rearguard.
  - The Arc Dynamo (sector 2) is a Caravan reactor barge.
  - The Bastion (sector 3) is a Rearguard fortress whose turrets read by shape: guns, a
    reactor and a shield.
- Every ship cloaks in its faction's colours, and every mirror-symmetric ship has a
  mirror-symmetric portrait.

Still open:
- The Bounty Runner (Undertow) flies the Civilian Transport's Caravan hull, a smuggler in
  civilian clothes. It cloaks green.
- The Sector Warden's description still calls it a "gate authority".
- The Shop keeps its boxy silhouette.
