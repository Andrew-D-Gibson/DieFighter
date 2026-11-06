# RECKONING_ENDINGS.md — The Last Fight and How the Run Ends

The redo of the Reckoning (LORE.md §7) and the endings behind it (§8). Agreed
with Drew on 2026-11-06. This supersedes §7-8 where they disagree; LORE.md §13
describes the first pass as built before this redo.

> **The run deals you three hands, and the last fight is where you choose
> which to play.** Your kills set the Become Fate goal, the ships you saved set
> the Save Others goal, and your dice set the Save Yourself goal. Each is fixed
> the moment you turn Back.

Every die goes to someone. In the Reckoning, the target you aim at decides who:
yourself (the engine), the people you saved (their way out), or the thing the
hole made of you. There's no choice menu. The ending emerges from where the
player sends their dice.

---

## 1. The Reckoning, redone

### What stays
- **The way in.** You must know the secret, have all six faces carved, and turn Back at the last gate.
- **Fate's Corruption** is the background.
- **Fate throws your die** at the start of every round, before a die is placed.
- **The Tally.** Everything you destroyed comes back, washed purple.
- **The Spilled** keep coming once the Tally is spent.

### What changes

| Before | Now |
|---|---|
| A separate escape meter (ReckoningHud) | **The engine charger is the bar**, recoloured in the Vanguard Drive's gold (#EED35D). No new loading bar. |
| Goal: 3× the drive limit, recalculated live | **Goal: 3× the drive limit for the dice you hold when you turn Back, fixed for the fight.** The limit normally shrinks as dice leave (`player.gd`: 10 at 3 dice, 4 at 2, 1 at 1), which would make giving dice away *lower* your own goal. |
| Charge banked into escape at the end of every turn | Charge simply stays on the charger and climbs toward the goal. A full bank lights the map's jump arrow, and **you jump the way you always have**. |
| No fleeing (the background's NoEscape and the Reckoning's HorizonModifier) | **Both removed.** The background instead says **"Attacks can't be evaded"**. Charge climbs toward 30 and never banks away, so evasion (3% a charge, up to 50%) would sit at the cap for most of the fight. |
| The horizon eats a grid column every 3 rounds | **Gone.** The hole spitting back your enemies, your allies and its own Spilled, with three goals to choose from, is the finale. Your machine stays whole. |
| Saved ships as Saved Ship tiles; spared pirates as Old Debt tiles | **Saved ships fly in as ally ships** on your side (§3). **Spared pirates make one strafing flyby** (§3). Both tiles are retired. |
| Echoes at full hull, in waves of 3 | **Echoes at half hull**, since they're memories. **One wave per encounter** (§2). |

**The Vanguard Drive tile** still replaces the engine charger tile: any die
puts **2× its face** into the engine. It reads as the gold engine charger.

**Siphons and drains** (enemy actions that take engine charge) now attack your
escape directly. That's intended tension; tune it in playtesting.

**Tiles that read "engine charged" and the redline display** compare against
`max_engine_charge`. For the fight, `max_engine_charge` *is* the fixed goal,
so they mean "the escape is ready". The redline is overcharge past the goal.

### Fate's faces in the Reckoning

| Face | Round effect |
|---|---|
| **Mercy** | The next ally in the queue arrives now. If an ally is already on the board, that ally is healed and shielded instead. |
| **Plunder** | A hostile ship snatches the best die in hand (unchanged). |
| **Duty** | Every enemy gains 4 shields (unchanged). "You" is never shielded. |
| **Ruin** | A random tile is locked for the round (unchanged). |
| **Hunger** | **The next wave comes now**, even if the current one isn't cleared. The hole is hungry. |
| **Strange** | Every echo is scrambled for 2 (unchanged). |

The hidden modifier stays: a run that refused every tithe leaves the
Rearguard's echoes out, and Duty shields the player instead.

---

## 2. The queue: your run, played backwards

The hole gives back **every encounter you fought, in reverse order**: last in,
first out. Each wave is **one encounter**: the echoes of the ships you destroyed
there, and any ship you saved there.

The emotional core is that the Tally restages your run scene by scene. Kill
two pirates and save the Hauler they were attacking, and all three come back
together. This time you're getting the Hauler out.

### Rules
- **Echoes rise from the hole on the left**, purple. **Allies jump in from the fleet on the right**, in their faction colour. Friend and echo read apart at a glance.
- **The next wave arrives when no hostile is left.** It also arrives early on a Hunger throw.
- **The very first kill always comes last, alone.** Since the opening encounter is always a fight, you always get the chance to save everyone before the chance to destroy everything.
- **When the Tally is spent**, "You" appears (§4), and from then on the Spilled come in waves of 3.

### One ally on the board at a time
A bunch of friendly ships on screen would trivialise the fight, so allies hold
the escort's slot (`EnemyManager.ESCORT_SLOT`) one at a time.
- An ally who comes up in the queue while the slot is taken **waits at the edge of the fleet**.
- The next ally can't arrive until the current one leaves, either sent off with your die or lost. That's a natural pacing pressure.

### Telegraph: names, never numbers
- An arriving ally names who is still waiting: *"The medic's right behind us. Hold on for them."*
- The last ally in the queue says *"That's all of us."*

Names tell you *who* is still coming. The last line tells you the queue is empty.

---

## 3. Allies

### Saved ships
**Who.** Every ship `REMEMBER_SHIP` recorded as `KIND_ALLY`: the Mayday's runner,
rescued civilians, the Pickets and so on.

**On the board.** Each one flies as a friendly ship in the escort slot, built
like the Mayday escort (`mayday_runner.tres`): Shield and Raid, no attack and no
Flee of its own. You can target it, pirates can raid it, and it can die.

**"Run for it."** A green intent in the Getaway style sits on some faces of its
table (start with 2 of the 6).
- Spend a die on that face and the ally **jumps out carrying that die**. The die leaves your Fleet for good (`num_of_dice` − 1), exactly as a Cutpurse's Getaway strands it.
- Players already learned that icon means "leaves with your die". Green says it's a gift this time.
- Sending an ally is a placement puzzle like everything else: the right die on the right ship.

**Lines:**
- On arrival: *"Give us a die and we're gone."*
- Taking a die (not the last): *"We'll carry it for you."*
- With your bank nearly full and an ally still aboard: *"Your drive's lit. Don't wait for us."*
- Taking your **last** die: *"...What about you?"* You have no way to answer.
- The escort's existing return lines still apply on arrival: *"You saw us home. Our turn."* or *"We fell once. Not this time."*

**An ally who dies in the Reckoning is lost.** It's never left behind and
never saved. Letting allies die never helps you.

### Spared pirates (Old Debt)
- **Who.** Ships recorded as `KIND_DEBT`.
- **What they do.** They come up in the queue but take no slot and need no die. They jump in from the right, make **one strafing pass** across the echoes (3× damage to every hostile, the old tile's number, tunable), call out, and jump away.
- They pay their debt and go their own way. They don't count toward any ending.

---

## 4. "You"

When the Tally's last echo falls, the hole sends what it has made of you.

### Its arrival
1. The first kill's echo, as it falls: *"Before me, there was only you."*
2. The canopy die rattles harder than it ever has. The chain snaps and the bone die **shatters**.
3. The shards stream out through the viewport and reassemble above a ship drifting out of the hole: **your own hull**, nose toward you.
4. The die hangs there as a small 3D `FateDieSpin`, slowly turning.

### Its look
- Your hull sprite (`ShipResource.cutscene_frames`, as the Fallen uses), with the purple cloak wash **crawling across it in waves**.
- Tearing glitch slices in the `GlitchShader` language.
- Pixels peeling off toward the hole.
- The takeover isn't finished, and you can see Fate working on it.
- The targeting computer names it **"You"**.

### The die above it
From now on, Fate's throws come from it. The small die tumbles above "You" and
lands on the round's face. Between throws it turns lazily and **slows toward
the face it will throw next round**. An attentive player can read what's coming;
everyone else just feels it watching.

### How it fights
- 1 hull. No dice of its own. It never acts first.
- **Every die you hand it, it fires back at you at 2× the face** ("Your Own Fire": a 1 does 2, a 6 does 12). Aiming at yourself while you charge is a real risk, never a free place to dump dice. *Every die spent while targeting yourself comes back at you double.*
- 2× is the one number to tune.

### What can touch it
- **Nothing reaches it by accident.** It's excluded from hit-everything and random targeting, Burn, splash, ricochet, the Old Debt flyby, Duty's shields and every Fate throw.
- **The only way to destroy it** is damage from a die spent while you're targeting it.
- **Destroying it is the Become Fate ending.**

It stays until you destroy it, or the fight ends another way. The Spilled
keep coming around it.

---

## 5. The endings

### Triggers

| What happens | Ending |
|---|---|
| You jump (bank full) and **no ally got out** | **Alone** |
| You jump and **at least one ally got out** | **The Convoy** |
| ...and the run left nobody behind (§5.1) | **The Convoy, perfect**: the formation closes and you take the front |
| Your last die leaves with an ally before your bank is full | **The Last Die** (Save Others) |
| You destroy "You" | **Become Fate** |
| Your hull hits 0, or an echo takes your last die | **Fell In** |

Notes:
- **Last die, full bank.** If your last die leaves with an ally *while the bank is full*, you are not consumed. The arrow is lit, and you can still jump with no dice at all.
- **Allies who got out** means those who jumped out with your die during this fight. Allies still on the board, or still queued, when you jump are **left behind**.
- **The Last Die needs no threshold.** One ally can only take one die, so a run that saved one ship usually ends Alone or in the Convoy. The Last Die naturally belongs to runs that saved more ships than they hold dice: N dice, N seats. Its size is the truth of the run.
- **Not everyone has to make it.** With more saved ships than dice, you can't save them all. That's honest.

### 5.1 The perfect run
The Convoy becomes perfect when **nobody was left behind anywhere**:
- **in the Reckoning:** every saved ship got out, none died, none were left on the board or in the queue;
- **during the run:** no missed opportunities.

**Missed opportunities** come from records the game already keeps:
- civilians you killed (the CIVILIAN side when they died);
- betrayals: `mayday_wronged`, `medic_betrayed`, `civilian_betrayed`, `runner_burned`, `caravan_betrayed`, and the angry shop and repair dock states (attacking a shop counts);
- an escort lost on the way.

A civilian killed *by pirates* in an encounter where you could have stepped in
is a candidate too. It needs checking whether that's recorded (open question).

**The telegraph is the Tally itself.** Civilians you killed come back as echoes
and say so: *"We were running too."* The player learns in the fight that the
perfect ending is gone, without a counter.

### 5.2 What the ending knows
The director hands every cutscene one `ReckoningEnding`:
- the kind;
- the ship flown;
- the saved ships that got out, in the order they left;
- those left behind in the fight;
- those lost in the fight;
- the run's missed opportunities;
- `perfect`;
- the first ship the run ever saved;
- the dice left.

Cutscenes draw from it; they never read the ledger themselves.

---

## 6. The cutscenes

### Shared rules
- **Built like the first ending** (`EndingCutscene`): a 320×180 PixelWorld SubViewport blown up 6×, with the starfield behind at 1080p so it glides. The flight runs on an AnimationPlayer or a tween; the shared skip comes from `CutsceneSkipPrompt`.
- **Hardware, never cartoon.** Approved 33-colour palette, art-pixel scale.
- **No new PNG art is needed:**
  - ships reuse their combat sprites (`PixelArtShrinker` for small sizes);
  - flares, motes and streaks are drawn on the 320×180 grid (`JuicePixelated`, `JumpFx`);
  - new sprites, if ever wanted, go through `Art/` and `tools/export_art.py`.
- **Colours:**
  - gold #EED35D is the Vanguard Drive, so it's *you*;
  - cyan #8DF1F4 is the opening's exhaust;
  - purple is Fate;
  - allies jump in their `FactionIdentity.color`.

### The sky with no Fate in it
"Off the table" is a planning word only. **No table appears, ever.** On
screen, leaving means **the first sky in the game with no black hole in it**:
an unfamiliar, quieter starfield, with a few faint unfamiliar colours and no
purple anywhere.

Alone, the Convoy and the second shot of the Last Die all arrive in **this same
sky**. Only who's there changes:
- **Alone:** nobody.
- **The Convoy:** a formation, with you in it.
- **The Last Die:** a formation with a gap at the front.

### The formation
A Caravan travelling formation: a broad chevron, readable as a shape, so a
missing ship reads as a gap.
- **Slots:** one for every ship the run *could* have saved: the saved ships, plus the missed opportunities. Capped at 12 for screen space at 320×180.
- **The order:** the ships that got out fill the slots nearest the front first.
- **Empty slots** come in two kinds:
  - **Missed during the run:** the slot is simply empty. They never had a chance to come.
  - **Left behind in the Reckoning:** charge motes gather at the slot, a jump flare starts, stutters... and nothing arrives. The motes drift apart. It's a jump that was trying to follow you and never made it: no body, only the effort to reach you. This replaces both ghosts and wreckage.

---

### 6.1 The escape (in the fight, before every jump-out ending)
This is the triumph. Whatever comes after, getting out of the Reckoning is a
win, and the game says so.

1. **The bank fills.** The gold charger flares, and "VANGUARD DRIVE!" (the existing callout) lands on the last point. The map's jump arrow lights.
2. **The player jumps.** The music swells to its biggest sting of the fight. The dice rattle and the ship stretches gold, then the white jump-out (the existing `play_jump_intro` with a white tint).
3. **Cut to black.** The cutscene for the ending takes over.

### 6.2 Alone
*Freedom, but loneliness. Anti-ceremonial.* **Camera rule: the only cutscene
that never pushes in.**

1. **Black, then the sky with no Fate in it.** Hold on the empty sky for a beat before anything moves. **Sound:** no music, a low engine hum only.
2. **Your ship drifts in from the left**, small, its gold engines burning low. Wide shot. It crosses the frame slowly, right.
3. **It's too wide and too long.** Nothing happens. A star or two twinkles. The engines dim one step.
4. **If anyone was left behind in the fight:** midway, a single comms crackle: *"Pilot? ...Pilot?"* The static cuts out mid-word. The ship doesn't slow.
5. **The ship leaves the frame on the right.** The sky holds empty for two seconds. The hum fades.
6. **Credits: silent and short** (§7). After the last card, one line: ***"You made it."*** It's true and kind, and in that silence it also says *alone*.

No title card and no YOU DON'T COUNT.

### 6.3 The Convoy
*Joy, and who is missing.* **Camera rule:** it starts wide, and the push in is
saved for the perfect version.

1. **Black, then the sky with no Fate in it.** Your ship jumps in from the left, gold, and slows to a stop near the middle. **Sound:** the music comes back, warm.
2. **The allies arrive one by one** in the order they left the fight. Each is a jump-in flash in its faction colour (`JumpFx` in reverse) into its formation slot, with a soft chime that rises a step each time.
3. **The gaps.**
   - Missed slots stay empty.
   - Left-behind slots get the failed jump-in: motes gather, the flare stutters, nothing comes, and the motes drift off. Each is a small, flat sound with no chime.
4. **The joy.**
   - The ships fire **signal flares** in their faction colours: pixel streaks up and out, bursting into a few sparks. They're staggered, not all at once.
   - Comms chatter overlaps in speech bubbles over the ships: *"We're out!"*, *"Is that... no hole?"*, *"Drinks are on the Caravan."* (lines by faction).
5. **The convoy sets off right**, together, your ship among them. As they slide off screen the **credits filter in behind them** (§7). The credits are short, so this is a quick beat.

#### The perfect version
Between steps 4 and 5:

- **4a. The formation closes.** There are no gaps. Your ship slides forward through the formation **to the front**, gold engines brightening. **Camera:** the one push in, toward the front of the formation.
- **4b. Every ship fires its flares at once.** It's the biggest burst in the game: faction colours plus your gold.
- **4c. The closing line types over the formation: *"No one is behind you."*** Nobody was left behind, and nothing is chasing you. It answers the Forward ending, where you become the Vanguard and keep the deal: here you lead a fleet that isn't running any more.

### 6.4 The Last Die
*Sacrifice, and a higher calling.* Two shots: being consumed, then what became
of those you saved.

#### Shot 1: consumed
This must not feel like Fell In. That one is violent; this one is quiet acceptance.

1. **In the fight:** the last ally takes the last die. *"...What about you?"* There's no answer. The ally jumps out in its faction colour.
2. **Cut to the 320×180 world.** Your ship alone, near the hole's rim, left of frame. **The hull is intact and the engines are still gold.**
3. **The engines go out one at a time:** the gold flame shortens, flickers and goes dark, with a soft click as each goes. The purple light grows on the hull from the hole's side.
4. **The ship drifts back, calmly**, toward the hole. **Camera:** a slow pull out, the ship getting smaller. It stretches slightly as it nears the rim, then it's a point of light, then it's gone. **Sound:** the music falls away to a single sustained note that ends with the light.
5. **Hold on purple for a breath. Cut to black.**

#### Shot 2: those you saved
1. **The sky with no Fate in it.** The saved ships arrive one by one (as in the Convoy), into a formation **with a gap at the front where you would be**. Missed and left-behind slots follow the same rules as the Convoy.
2. **The first ship the run ever saved** speaks (the oldest debt): ***"Leave the front open."***
3. **A gold salute.** The ships fire flares **in your drive's gold, one ship at a time, slowly**. These are the same flares as the Convoy's joy, slowed down: joy and mourning share a vocabulary.
4. **The last ship to leave** holds the die you gave it. A small die sprite beside its hull catches the 6s glint (`Juice.glint`) once.
5. **The formation sets off right, with the gap at the front kept.** The credits come in behind (§7).

### 6.5 Become Fate
*The hole recognises its own. The game loops.*

1. **In the fight:** your die hits "You". It breaks apart: no explosion, the glitch slices simply pull it to pieces. The small Fate's Die above it stops turning.
2. **The die floats free**, across to your ship, and settles where the canopy die hung.
3. **Cut to the 320×180 world.** Your ship, alone. **The purple spreads from the nose back** (the cloak wash, filling the hull a pixel row at a time). The gold engines turn purple.
4. **It sinks into the hole.** **Camera:** follow it *down*, into the centre, without cutting. The stars stretch and lens around the rim. Through the centre: black.
5. **The camera turns.** We're now looking **out from the hole**:
   - the frame is ringed by the swirling purple rim (the menu's `fate_behind.gdshader`);
   - the stars bend around its edge;
   - in the distance, a small ship claws away, burning **the opening's cyan**.

   It's the opening cutscene, seen from Fate's side. **Sound:** the opening's theme, slowed and lowered.
6. **The small ship jumps away.** Hold. Your die tumbles once in the dark, in the foreground, landing on a face.
7. **Credits, falling:** they scroll *downward* (§7), and hand off straight to the main menu, which now shows **Throw #N** (§8).

### 6.6 Fell In
*A loss. Short, around 6 s, because players will retry.*

1. **In the fight:** the normal cockpit death plays (the existing destruction sequence).
2. **Cut to the 320×180 world:** the hull cracks, stretches and turns **nose down** toward the hole, purple taking it. It's violent where the Last Die is calm.
3. **Camera:** push in toward the hole's centre, fast. The final frames before black are **the nose-down purple hull: exactly the sprite the Fallen wears** on a later run (`FateLedger._dress_as_fallen`), so the ghost is born on screen.
4. **Fade to black.** Then the existing *YOU FELL IN* end screen. No credits.

---

## 7. Credits

Short: the team, the music and the tools, then *Thanks for playing*. Each real
ending rolls them its own way.

| Ending | Credits |
|---|---|
| **Alone** | Silent, over the empty sky. The hum cuts out at the end. Last line: *"You made it."* |
| **The Convoy** | The formation keeps flying beside the scroll. Ends on *"Flew with you"* and the names of the ships that got out. |
| **The Last Die** | Over the formation with its gap at the front. Last card: *"In memory of the [Die Fighter / Outrigger / Carousel]."* |
| **Become Fate** | Scrolling *downward*, falling, handing straight off to the menu. |
| **Fell In** | None. It's a loss. |

After the credits, the victory screen comes up with the run summary, as after
the first ending.

---

## 8. Throw #N and the loop

- **The menu never shows a run count until your first Become Fate.** After it, **"Throw #N"** is suddenly there, and N is the real number of runs you've started. The counter has been counting all along; it just never showed. You realise every run was a throw. (The parked LORE §11 idea pays off here.)
- **"Throw #N" belongs to Become Fate only**, so it stays a reveal.
- **The pilgrim's line changes** on every run after a Become Fate: *"It's been waiting for you. ...Oh. It's you."*

---

## 9. Lines

| Who | When | Line |
|---|---|---|
| Ally | Arrives | *"Give us a die and we're gone."* |
| Ally | Arrives, more queued | *"[Name]'s right behind us. Hold on for them."* |
| Ally | Arrives, queue empty | *"That's all of us."* |
| Ally | Takes a die | *"We'll carry it for you."* |
| Ally | Your bank nearly full | *"Your drive's lit. Don't wait for us."* |
| Ally | Takes your last die | *"...What about you?"* |
| Civilian echo | Wave arrives | *"We were running too."* |
| First kill's echo | Falls | *"Before me, there was only you."* |
| Convoy | Chatter | *"We're out!"*, *"Is that... no hole?"*, *"Drinks are on the Caravan."* |
| Convoy, perfect | Closing | *"No one is behind you."* |
| First ship saved | Last Die, shot 2 | *"Leave the front open."* |
| Alone | After credits | *"You made it."* |
| Last Die | Last credit | *"In memory of the [ship]."* |
| Pilgrim | Runs after a Become Fate | *"It's been waiting for you. ...Oh. It's you."* |

---

## 10. Open questions

- **"You"'s fire: is 2× the face right?** It may be weak late in a run. Test it.
- **The formation cap of 12.** A very bloody run is mostly gaps, which is intended. Check it reads at 320×180.
- **"Run for it" on 2 faces.** Too few and sending an ally is a lottery; too many and allies are free exits.
- **Siphons on a 30-point bank.** They're now the escape's main threat. Tune their amounts.
- **Civilians killed by pirates** while the player could have stepped in: are they recorded anywhere, and should they count as missed?
- **Very long runs.** The old Tally kept the latest 15 kills plus the first. With one wave per encounter, cap by encounters (the latest 12 plus the first?).
- **Hunger's early wave** can stack waves fast on a Hunger-heavy die. Watch for pile-ups.
- **Credits content:** who and what gets listed.
- **Music:** the escape sting, the Convoy's warm theme, the Last Die's sustained note, and the slowed opening theme for Become Fate. Until they exist, these borrow existing cues; list them in `SOUND_EFFECTS_TODO.md`.
