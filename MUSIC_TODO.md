# Music the game needs — production and integration checklist

Audited against the repository on **2026-11-06**. Style: **keep the existing
chiptune/synth sound** of `game_start_theme` and `trailer_1`. This is the music
twin of [SOUND_EFFECTS_TODO.md](SOUND_EFFECTS_TODO.md) and follows its format.
No audio or game code has been changed. Coverage is from static inspection of
`MusicDirector`, the track resources and every `play_track` call, not a listening
pass.

## How to use this list

- **P1:** make first: the Reckoning and its endings, which today run on borrowed songs.
- **P2:** finish the game's musical vocabulary (map, shops, bosses, the end screens).
- **P3:** optional polish.
- **Borrowed:** the moment plays an existing song that wasn't written for it.
- **Missing:** the moment plays no music at all, or nothing was made for it.

Each backticked name is a proposed **filename without extension** and future
`MusicTrackResource` id. Check a row off when the track is made; integration is a
separate step. Deliver **WAV, 44.1 kHz stereo, trimmed leading silence**, ending
exactly on a bar line with no tail baked past the end unless the row says so.
`MusicTrackResource.repeats` loops a track by restarting it, so a looping track
must **end at the bar its start picks up from** (a seamless tail-to-head join,
no silence in either). A non-looping track hands over to the next track in its
playlist when it ends, so one-shots should end on a clean final chord or on
silence. Stems: where a row says *layers*, export each layer as its own full
length WAV starting on the same sample so `MusicDirector.set_layer_enabled` can
fade them in and out. Tempo and key notes are suggestions; keep the existing
songs' feel (bright square/pulse leads, punchy bass, dry drums). Put finished
files anywhere and give me the path: matching these names lets me place them
without guessing. Suffix alternate mixes `_alt`.

## What exists

Two songs play the whole game. Everything else is silence or one of them.

| Track id | File | Plays today | Notes |
|---|---|---|---|
| `game_start_theme` | `Assets/Music/Battle Themes/Game_Start_Theme/GameStartTheme.wav` (loops) | Main menu (`MainMenu._MENU_TRACK`); the first ending's flight (`EndingCutscene._FLIGHT_TRACK`); **borrowed** as the Reckoning's escape sting (`ReckoningDirector._ESCAPE_STING_TRACK`); **borrowed** as the Convoy's warm theme and the Last Die salute (`ArrivalCutscene._CONVOY_TRACK`); the main menu after Become Fate (`BecomeFateCutscene._MENU_TRACK`). | The game's identity song. Doing five jobs. |
| `trailer_1` | `Assets/Music/Trailer/Trailer_1/Trailer_1_updated.wav` (-5 dB, one-shot) | The run: the opening cutscene hands to it, and `MainMenu` starts it on a new run (`_RUN_TRACK`), so **every encounter, shop, boss and the Reckoning fight itself play it**. **Borrowed** at 0.72 pitch as Become Fate's "slowed opening theme" (`BecomeFateCutscene._OPENING_PITCH`). | It's a trailer cue used as the in-run song; being a non-looping track it hands back to `game_start_theme` when it ends. |

On disk but **not wired to anything**:

| File | What it is |
|---|---|
| `Assets/Music/Battle Themes/Battle_Theme_1/Battle_Theme_1.wav` (+ `.flp`) | A finished battle track with no `MusicTrackResource`. The obvious first candidate for ordinary combat. |
| `Assets/Music/MainMenu/Victory Music.mp3` | Imported, referenced nowhere. A victory piece, unused by the end screen. |
| `Explore_1.flp`, `Short_Trailer.flp`, `MainMenu.flp` | FL Studio projects with no rendered audio. |

The audio around the music: `MusicDirector` crossfades by track id inside one
playlist (`default_playlist.tres`, which holds only the two tracks above), and
`play_track` errors on an id the current playlist lacks, so every new track also
goes into that playlist. The game-over (YOU FELL IN) screen and the victory end
card play nothing of their own.

## P1 — the Reckoning and its endings

| Made | Proposed file | Mood / brief | Length and loop | Where it plays |
|---|---|---|---|---|
| [ ] | `reckoning_theme` | **A unique song for the last fight.** Dread, then defiance. The Reckoning is a countdown against a black hole while your run is played backwards at you, so it wants a driving pulse that never resolves: a low, slow-building ostinato, purple-tinted synth (detuned square, a little bit-crush so it sounds *corrupted*), and a counter-melody that is **the opening theme's motif, played back reversed**. Never triumphant: the player hasn't won yet. Layers: `base` (bass + pulse), `tension` (arps and a high drone, brought in as more of the board is swallowed), `escape` (the motif finally major, lit only when the bank is nearly full). | 2:30–3:30, **loops** seamlessly. 3 layers, same length. ~120–132 BPM, minor, ending its loop on the dominant so it keeps wanting to go on. | `ReckoningDirector`, from the first round (replaces the run song `trailer_1`, which the fight inherits today). `escape` layer on at `ReckoningDirector.add_escape_velocity` when the bank is nearly full ("Your drive's lit"). Cut to `reckoning_escape` on the escape. |
| [ ] | `reckoning_escape` | **The escape sting** (RECKONING_ENDINGS §6.1, §10). The biggest cue of the fight: the bank full, the jump. Starts mid-tension off the fight's last chord, rises through a rattling snare roll to a single huge gold major chord that blooms as the ship stretches, then *drops out* into the white of the jump. | 6–8 s. **One-shot**, ending on the chord held with a natural tail into silence (the cutscene is black by then). | `ReckoningDirector._play_escape` (borrows `game_start_theme` now), timed to the dice rattle and the stretch. Pairs with SFX `vanguard_escape`: if both are made, the SFX is the impact and this is the harmony. |
| [ ] | `convoy_triumph` | **The triumphant song for the Convoy and the Convoy, perfect.** Relief first, then joy: an unhurried warm opening (soft pads and a lone bell-like lead, the "we got out" breath), then the whole arrangement lifts into a major-key march that sounds like a fleet setting off together: big gliding lead, bright bass, marching snare, bells on flares. It borrows the game's own identity tune: the opening theme's motif, finally resolved in major, with the reverse-motif from `reckoning_theme` turned the right way round. Layers: `warm` (pads, bell lead: the arrival), `joy` (full band: brought in as the flares go up), `crown` (gold brass and a high countermelody: only the **perfect** version turns it on, at the burst and the push-in). | 1:30–2:15, one-shot with a natural ending that lands on the credits' last card (the film is ~50 s, then the credits). Layers share a length. ~108–116 BPM, major, an ending that resolves rather than loops. | `ArrivalCutscene._shoot_convoy` (`_CONVOY_TRACK`, borrowed `game_start_theme` now): `warm` from 0.6 s, `joy` at the first flare (`_schedule_celebration`), `crown` at the perfect burst (`_schedule_perfect` 4b). Plays on under the victory end card for the Convoy. |
| [ ] | `last_die_salute` | The Last Die's shot 2 (§6.4): **mourning that is also gratitude**. The Convoy theme's tune played slowly, in a lower register, mostly on one soft lead and pads, with a gap left in it where "you" would be: the lead drops out for a bar at the front of the phrase. No drums. Builds a little as the gold salute goes up, ends open, unresolved but at peace. | 1:20–1:50, one-shot. Same key as `convoy_triumph` so a player who has heard both hears the family resemblance. | `ArrivalCutscene._shoot_last_die`, on the salute (borrows `game_start_theme` now). Continues under the victory end card. |
| [ ] | `last_die_note` | **The sustained note** (§6.4 shot 1, §10): the fight's music falls away until one held note is all that is left, and it ends exactly as the point of light goes out. Currently synthesised in `SustainedNote`. A warm, slightly detuned pad note with a slow swell, a faint octave shimmer, and a release that dies into the purple. Not sad, accepting. Deliver both a held loop and a release tail. | `last_die_note_hold`: 8 s seamless loop. `last_die_note_release`: 2–3 s tail. Fixed pitch (the key of `last_die_salute`, so the salute's first note answers it). | `ConsumedCutscene._note_swells` / `_light_gone`; replaces `SustainedNote` (synth) for Last Die. |
| [ ] | `become_fate_theme` | **The slowed opening theme for Become Fate** (§6.5, §10). Today `trailer_1` at 0.72 pitch, which also drags the tempo and muddies it. A proper rearrangement: the opening theme in a lower key, half-time, with the lead played on something cold (bowed glass, soft pulse) and the rhythm section stripped to a heartbeat, so it feels like the run being remembered as it falls. It should hold the hole's purple dread without being horror: the player has *become* it. | 1:15–1:45 to cover the ~70 s film, **one-shot**, ending in a long tail that hands to the menu theme. | `BecomeFateCutscene._OPENING_TRACK` (borrowed `trailer_1` + `_OPENING_PITCH`). |
| [ ] | `alone_silence` | **Not a track, a rule.** Alone has no music on purpose (§6.2); the engine hum and the comms break are the soundtrack (see SFX `drive_hum`, `comms_break`). Listed so nobody fills it. After the credits Alone's victory card is also silent today; keep that unless the team decides otherwise. | — | `ArrivalCutscene._shoot_alone` (`MusicDirector.stop`). |

## P2 — the rest of the game

| Made | Proposed file | Mood / brief | Length and loop | Where it plays |
|---|---|---|---|---|
| [ ] | `run_theme` | **A song written for the run.** `trailer_1` is a trailer cue and doesn't loop, so the game falls back to `game_start_theme` mid-run when it ends. A looping map-and-encounter bed: forward motion, hopeful but tense, a bit sparse so dialogue and dice-rolls aren't buried. Layers: `base`, `battle` (drums and a lead, up while enemies are on the board). | 2:00–3:00, **loops**. 2 layers. | `MainMenu._RUN_TRACK`, `OpeningCutscene._RUN_TRACK`. Replaces `trailer_1` as the run track, which stays for the trailer and the opening. |
| [ ] | `battle_theme_1` | Already made (`Battle_Theme_1.wav`) and unused. Wire it as ordinary combat, or fold into `run_theme`'s `battle` layer. Needs a `MusicTrackResource` and a loop check (no silence at the join). | As recorded; verify it **loops**. | Ordinary encounters, once `run_theme` has the `battle` layer role or is split. |
| [ ] | `boss_theme` | One shared song for sector bosses (the Sector Warden, the Arc Dynamo, the Bastion). Heavier and slower than the fight music; plays under the boss intro card and the gate fight. A faction-flavoured variant per boss is optional (P3). | 2:00, **loops**. | Boss encounters (`BossIntroCard` onward). |
| [ ] | `shop_theme` | A small, warm, slightly comic loop for shops and repair docks (the Caravan Compact's sound): a plucked bass, a bell, a lazy shuffle. Ducked under purchases. | 1:00, **loops**. | Shop and repair-dock encounters. |
| [ ] | `sector_stinger` | A short rising sting for a new sector's title reveal, in the sector's mood (Tail: ragged; Belly: warm; Spine: cold, martial). Three 4–6 s variants. | 4–6 s each, **one-shot**. | `JumpManager.jump_through_gate`, with SFX `sector_arrive`. |
| [ ] | `game_over_theme` | **YOU FELL IN** and the run-over screen are silent today. A short, quiet, falling-off cue: the main motif in a lone lead, then the purple takes it. Not mocking: players retry. | 20–30 s, **one-shot**, ending in silence. | `GameOver` on the loss state. |
| [ ] | `victory_theme` | The unused `Victory Music.mp3` is the starting point. Decide whether the end card after Alone (silence), the Convoy (the theme keeps playing), the Last Die and the first ending each get their own; at minimum one warm, short end-card song. | 45–90 s, **loops** under the card. | `GameOver` victory card, after the credits. |

## P3 — optional

| Made | Proposed file | Mood / brief | Length and loop | Where it plays |
|---|---|---|---|---|
| [ ] | `menu_theme_slow` | A calmer menu arrangement for after a Become Fate (the game now loops: Throw #N is the first thing the player sees). Same melody as `game_start_theme`, slower, as if remembered. | 1:30–2:00, **loops**. | `BecomeFateCutscene._MENU_TRACK`, and the menu after one. |
| [ ] | `explore_theme` | A calm drift-through-space bed for non-combat encounters (Mayday, medic, pilgrim). `Explore_1.flp` exists with no audio. | 2:00, **loops**. | Non-combat events. |
| [ ] | `fate_ambience` | A droning low pad for Fate-infected backgrounds and the Reckoning's hole at rest; layers under any song. | 1:00 seamless loop. | Fate backgrounds, the Reckoning pre-fight. |
| [ ] | `ending_first_theme` | The first ending's flight borrows `game_start_theme`. A short ending track would suit it better (see SOUND_EFFECTS_TODO). | 1:00–1:30, **one-shot**. | `EndingCutscene._music_in`. |

## Integration rules for the future wiring pass

1. Tracks live in `Source/Resources/MusicResources/Tracks/` as
   `MusicTrackResource`; streams under `Assets/Music/`, one folder per song.
   Every id above also goes in `default_playlist.tres` (or its own playlist),
   or `MusicDirector.play_track` will refuse it. Imports need **loop off**
   (see `MusicTrackResource`): the track resource's `repeats` does the looping.
2. A looping track's last sample must flow into its first; test the join with
   a loop in the DAW. A one-shot ends on a chord or into silence and must not
   rely on the next track starting at the right place.
3. Layered tracks (`reckoning_theme`, `convoy_triumph`, `run_theme`) share one
   length and one start sample; export stems, not a mixdown, so
   `set_layer_enabled` can fade them.
4. When a cutscene already runs its own timeline (the arrival films), time the
   cues to the film (the Convoy's flares, the perfect burst), not the other way
   round. The film is the length; the song is cut to fit, or the film's cues
   adjust.
5. Music duck: the Convoy's chatter, the Alone comms and the typed closing
   line should sit over the music at about -6 dB of its level; no automatic
   ducking exists yet, so mix with room for them.
