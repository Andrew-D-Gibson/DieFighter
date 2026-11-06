# STORY_BOXES_PLAN.md — Story boxes beyond the Bastion

The Bastion's death (LORE.md §4, `FateRevelation`) introduced a **story box**: the
screen dims, the speaker's ship stays lit, and its lines appear one at a time in its own
speech-box art, stretched to fit, each with a green Close. This plan turns that into a
tool the rest of the game can use: boss beats, and a fix for encounters whose setup
doesn't read from 50-character barks.

Status: proposal. Nothing below is built except the Bastion's box.

---

## 1. What exists today

| Piece | Where | What it does |
|---|---|---|
| Barks | `EnemyDialogueManager`, `ScenarioShipState.dialogue` | One line (about 50 chars) in a 64×48 bubble beside a ship, faded on a timer, replayable from the targeting computer's comms badge. The game's main storytelling. |
| Boss intro card | `BossIntroCard` | Name and subtitle slammed across the screen as a gate fight starts. |
| Region / tutorial cards | `RegionAlert`, tutorial cards | Rules text, not story. |
| Story box | `FateRevelation` (`_SpeechBox`, `Enemy.hold_death()`, `EnemyGraphicsManager.set_spotlit()`) | The Bastion's dying confession. Hard-wired to the last gate. |
| Portraits | `*_targeting_image.png`, all 16×16 | The targeting computer's ship silhouettes (LORE.md §12). |

---

## 2. The rules (so it stays a spice, not a visual novel)

Story boxes stop the game, so they're expensive. Following LORE.md §1's "keep it simple":

- **Barks stay the default.** A box is for a beat a bark can't carry: a confession, a
  setup with a choice in it, a boss's last words.
- **At most one box per encounter, three lines per box** (the Bastion's eight are the
  one exception: it's the secret).
- **Only on-screen characters speak.** The speaker's ship is lit in the box. Fate never
  speaks; the player's ship never speaks.
- **Seen once, then short or silent.** A box remembers it was read (across runs, like
  the Fate knowledge) and plays its short form or nothing after that.
- **Boxes explain; play decides.** A box can name the choice (*"Take the ledger and
  they'll hang you with me."*), but the choice is still made by shooting, taking or
  paying, as today. No dialogue trees, no choice buttons.
- **Only at calm moments:** an encounter's arrival, a state change after the player's
  action has resolved, or a fight's end. Never mid-turn or mid-volley.

---

## 3. Design

### StoryBox (the component)
Extract from `FateRevelation`: dim, spotlight, `_SpeechBox`, typing, Close, keyboard.
`StoryBox.play(beat, speaker: Enemy) -> finished`. FateRevelation then just holds the
Bastion, calls `play`, and learns the knowledge. No behaviour change for the Bastion.

### StoryBeatResource (the content)
A `.tres` per beat, so writers add beats without code:

| Field | |
|---|---|
| `id` | For the seen-memory. |
| `lines` / `short_lines` | English in the resource; `tools/loc.sh sync` moves it to `content.csv` like every other content string. `short_lines` empty means silent on a repeat. |
| `speaker` | Which ship speaks: by spawn index in the scenario, or "the ship whose state fired this". |
| `remember` | `ONCE_EVER` (default), `ONCE_PER_RUN`, or `ALWAYS`. |

### Triggers
- **`ShowStoryBeatEvent`**, an `EffectEvent` for a ship state's `effects_on_enter`.
  Encounters already change state on arrival and after every choice, so this reaches
  any moment the state machine can, with no new trigger system. The event resolves
  when the box closes, so the chain waits for it.
- **Boss deaths:** `ScenarioResource.death_beat`. The generalized hold-the-last-ship
  flow plays it, as the Bastion's does now.
- **Boss intros:** `ScenarioResource.intro_beat`, right after `BossIntroCard` clears.

### Speaker and portrait
- **Default: the live ship, spotlit** (as the Bastion's last part). It's bigger and more
  readable than any portrait, and it's the thing the player is about to shoot or save.
- **The 16×16 targeting image** at 3× beside the box only when the speaker isn't on
  screen. Today that's nobody, by the rules above, so build this last, if at all.
  At 3× (48px) it's chunky; a named character who speaks often may deserve a hand-drawn
  32×32 bust (via `Art/`, never hand-edited PNGs).
- **Box colour by faction.** Today there are red, green and yellow boxes, and every boss
  talks in red. Add Rearguard blue, Inbound gold and Spilled purple sources in
  `Art/` and export them. The Bastion should then speak in blue.

### Memory
`CollectionManager.has_read_beat(id)` / `mark_beat_read(id)`, saved like
`has_fate_knowledge()`. Recording runs only, as now.

---

## 4. Candidate beats

I don't know which encounters you've found confusing; these are guesses from
`FACTION_SCENARIOS.md`, ranked by how much rides on a bark today. Swap in yours.

### Bosses
| Beat | Speaker | Why |
|---|---|---|
| Sector Warden, death | Warden | First "the bosses know something" moment. A hint, not the secret: *"The Rearguard pays us to keep the Tail thin. Ask what they pay with."* |
| Arc Dynamo, death | Arc Dynamo | Second hint, from the Caravan's side: the tithe it pays every jump. **Blocked on naming** (LORE.md §11: Chancellor or Arc Dynamo, one character). |
| Bastion, intro | Bastion | Optional. Its bark already does the job. |
| Bastion, death | Bastion | Done. |
| The Fallen, arrival | The Fallen | Its bark is good; a box could make the first meeting land. Low priority. |

With these, the three bosses build to the secret: hint, hint, confession.

### Encounters that may read better with a box
| Encounter | What's hard to read now |
|---|---|
| **The Pilgrim** (first run only) | What Fate's Die is and why you'd want it. The most important setup in the game, on a 50-char bark. |
| **The Ledger** | Who's arrested, why, and that taking the ledger means fighting the Conscriptor. |
| **Tithe Run** | Why a tithe convoy flies *aft*, with a Spilled Wisp on its wing. The best clue to the secret, easy to miss. |
| **Apostate** | A Rearguard hull under an Inbound badge; the mismatch is the story but needs a sentence. |
| **Deniable Assets** | That the Rearguard is hiring the Undertow. |
| **Tollkeeper** (first tithe of a run) | That paying or refusing is a choice with a cost. |

Use the playtest kit's "When were you most confused?" (`PLAYTEST_KIT.md` Q6) to pick.
Add a box only where testers stumble, and take it out if they stop.

---

## 5. Build order

1. **Extract `StoryBox`** from `FateRevelation`. Bastion unchanged; check it in play.
2. **`StoryBeatResource`, `ShowStoryBeatEvent`, seen-memory**, loc sync for beat lines.
3. **Two boss death beats** (Warden, then Dynamo once it's named), hold-the-last-ship
   generalized from the Bastion.
4. **Two or three encounter beats** from playtest confusion.
5. **Faction box colours** (`Art/`), then portraits only if a speaker ever needs one.
6. **A comms log** in the Codex: every beat read so far, rereadable. Cheap once beats
   are resources, and the best fix for "I clicked Close too fast".

---

## 6. Things easy to miss

- **The AutoPilot, trailer shots and tests** must never stop on a box. FateRevelation
  already only plays on recording runs; keep that gate in `StoryBox`.
- **Save and Continue.** A box shown on arrival must not replay on every Continue of
  the same fight, or must, deliberately. The seen-memory decides; mark it read when the
  box opens, not when it closes.
- **Localization length.** Box width is fixed (132px wide, about 5 lines of text). The
  existing localization length test can cover beat lines once they're in `content.csv`.
- **Text speed.** Typing should follow the animation-speed option like dice rerolls do,
  and a click always finishes the line.
- **Input:** keyboard works (any key finishes or closes). Check controllers if the game
  gets controller support.
- **Sound:** `SOUND_EFFECTS_TODO.md` already has a comms-burst slot for the revelation;
  the same sound per line suits every box.
- **One test, at most:** content integrity (every beat's speaker index exists in its
  scenario, every line has a translation key). No tests on layout or timing
  (`test/README.md`).

---

## 7. Open questions

- Do bosses get an intro beat, a death beat, or both? (Proposal: deaths only. The intro
  card already does the arrival.)
- One-time beats across all runs, or once per run for bosses? (Proposal: encounters
  once ever, boss deaths once ever with a short form after, like the Bastion.)
- Does the Bastion switch to a blue Rearguard box once it exists, or keep boss red?
