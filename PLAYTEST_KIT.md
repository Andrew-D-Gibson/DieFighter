# Playtest Kit

Everything for running outside playtests: a checklist for you, a handout to
send testers, a feedback form, and a sheet for when you're watching someone
play. The handout and form are written to copy and paste as they are.

---

## 1. Before you send a build

- [ ] **Bump `config/version`** in `project.godot` (currently `v0.0.0.1`). The
      debug log header records it, so every report tells you which build it
      came from.
- [ ] **Export a release build, not debug.** The dev console is on in debug
      builds and in any preset with the `dev_console` feature tag
      (`dev_console.gd`). Leave that tag off for testers.
- [ ] **Play the exported build once** from a fresh start: tutorial, one fight
      and the shop, then Save and Quit and Continue.
- [ ] **Wipe your own progress first** so you see what a first-time player
      sees: the tutorial unplayed, only Basic tiles unlocked, and an empty
      codex. Either use Options' erase button (shown only when
      `show_progress_tools` is on in `options_menu.tscn`), or delete the user
      folder listed in §2. Decide whether testers should see those two
      buttons; they're off by default.
- [ ] Decide how much you'll say up front. **Less is better:** the tutorial is
      part of what you're testing.
- [ ] Set up somewhere for answers to land: a Google Form built from §3, or a
      shared doc.

---

## 2. Tester handout (send this with the build)

> **Thanks for playtesting Die Fighter!**
>
> Die Fighter is a turn-based roguelike about dice. You spend dice on your
> ship's systems, and the enemy gets the dice you spent. A full run is three
> sectors and takes roughly 45–75 minutes. You don't need to finish one, but
> it's great if you do.
>
> **What we'd love from you**
> - Play however you like. Getting confused is useful information, not a
>   failure on your part.
> - If you can, say what you're thinking out loud, or jot notes as you go:
>   "I don't get why that happened," "oh, that's cool," "this is dragging."
> - When you're done, fill in the feedback form (link below). It takes about
>   10 minutes.
>
> **If something breaks or looks wrong**
> - Press **`\`** (backslash) to save a screenshot. You can rebind it in
>   Options → Controls.
> - Send us the game's log files. The game writes one every time it runs, and
>   keeps the last few, so a crash is still on file after you relaunch.
>   Please send the whole folder, or at least every `debug_log*.txt` file in it:
>   - **Windows:** `%APPDATA%\Godot\app_userdata\DieFighter\`
>     (paste that into the File Explorer address bar)
>   - **macOS:** `~/Library/Application Support/Godot/app_userdata/DieFighter/`
>     (Finder → Go → Go to Folder…)
>   - **Linux:** `~/.local/share/godot/app_userdata/DieFighter/`
>
>   Screenshots are in the `screenshots` folder in the same place.
> - Tell us roughly what you were doing when it happened.
>
> **Feedback form:** [link]

The log folder paths are Godot's defaults for a project named `DieFighter`.
That's correct as long as `project.godot` doesn't turn on a custom user
directory, and it doesn't today. Check once on each OS you ship to before you
send the build.

---

## 3. Feedback form

Ask the questions in this order. Open questions come before the rating scales,
so testers answer in their own words before your categories steer them.

**About you**
1. How often do you play roguelikes or deckbuilders (Slay the Spire, Balatro,
   Dicey Dungeons, etc.)? *Never / Occasionally / A lot*
2. Which platform did you play on? Mouse, or controller?
3. How far did you get? *Tutorial only / Sector 1 / Sector 2 / Sector 3 / Won*
   If the end screen showed a run summary, please paste it or screenshot it.

**In your own words**

4. Describe the game to a friend in one or two sentences.
   *This tests whether the core idea, that the enemy uses the dice you spend,
   came through.*
5. What was the most memorable moment?
6. When were you most confused?
7. When were you most bored, or when did it drag?
8. Was there a moment you felt clever? What happened?
9. Did any tile, enemy or encounter feel unfair or way too strong?
10. If you stopped playing, what made you stop?

**Quick ratings (1–5)**

11. How clear was the tutorial?
12. Did you understand what enemies were about to do? (their intents)
13. How often did you feel you had a real decision to make each turn?
14. Difficulty: *1 too easy … 3 about right … 5 too hard*
15. How much did you want to play another run once it ended?

**Wrap-up**

16. Anything that looked broken, or any text that was wrong or hard to read?
17. Would you wishlist it? *Yes / Maybe / No* What would change your answer?
18. Anything else?

---

## 4. Observation sheet (when you're watching someone play)

Stay quiet and don't help unless they're truly stuck for more than a minute or
two. Every time you want to explain something is a note for this sheet.

| Time | What happened | What they said or did | Severity (blocker / confusing / minor / delight) |
|------|---------------|-----------------------|---------------------------------------------------|
|      |               |                       |                                                   |

Things to watch for:
- **The handover:** do they notice the die they spent goes to the enemy, and
  do they start playing around it? When does it click?
- **Intents:** do they read the enemy's intent slots before placing dice?
- **Tiles:** which do they ignore, misread, or hover over for a long time?
- **Shop and salvage:** do they hesitate, skip it, or misunderstand the costs?
- **Map:** do they understand jump gates, region alerts and hazards?
- **Where they sigh, lean back or check their phone:** those are pacing
  problems.
- **Where they lean in or laugh:** protect those moments.

Afterwards, ask: "What was the game about?" and "What would you change?"

---

## 5. After the playtests

1. **Crash and error reports first.** Each `debug_log*.txt` has the build
   version, the run's seed, a turn-by-turn play-by-play and every engine error
   with its backtrace. Fix anything a tester actually hit before anything else.
2. **Group the feedback by theme, not by tester.** One person saying "a tile
   is too strong" is an opinion. Three people saying it is a balance item.
   Cross-check balance claims against an AutoPilot batch
   (`tools/autoplay.sh`, `tools/tile_balance.py`).
3. **Confusion beats balance.** Something testers misunderstood skews every
   other answer they gave, so fix clarity issues before you retune numbers.
4. **Put what you'll act on into `ROADMAP.md`.** Record what changed in
   `DEVLOG.md` once it ships.
