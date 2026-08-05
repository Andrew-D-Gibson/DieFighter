Read @ARCHITECTURE_OVERVIEW.md and @STYLE_GUIDE.md.

I'm mid-refactor. Analyze every unanalyzed file listed in @ANALYZE.md and add
to "CLEAN_UP_PLAN.md" — one section per file, in the same format as the files
already there. This is a single pass now: there's no separate local-model
draft to verify afterward, so get each judgment right the first time rather
than asserting things that need correcting later. The file's existing
"## Cross-File Findings & Low-Hanging Fruit" and "## Recommended for Fable
Review" sections came from reviewing the first 11 files this way; you'll be
extending both once this batch is done (see Output below).

--- Known about this codebase already (from the first 11 files) ---

Carry these forward. They'll keep recurring, and a fresh single-file read
won't surface them on its own:

- `Events` and `Globals` are this project's documented Systems-tier
  autoloads (see ARCHITECTURE_OVERVIEW.md's Autoloads table — `Events` is
  the central signal bus, `Globals` is the system registry). A Content-tier
  script depending on them is the sanctioned dependency direction, not a
  coupling problem.
- The `EffectChain` → `EffectChainV2` migration is actively in progress (see
  ARCHITECTURE_OVERVIEW.md §6 and recent commit history). A legacy
  `EffectChain`-typed field is migration debt, not an isolated bug — note it
  as such rather than a one-off defect.
- `Source/Systems/Components/` already holds this project's pattern for
  composable node behavior (`Shakeable`, `Draggable`, `Clickable`,
  `CanAcceptDice`, `Health`, `HealthBarController`, `DiceQueue`). If you're
  about to recommend splitting presentation/behavior logic out of a script,
  check whether it belongs there before proposing a new ad hoc file.
- Resource subclass files in this codebase are named after their full class
  name in snake_case (`BackgroundResource` → `background_resource.gd`,
  `SoundEffectResource` → `sound_effect_resource.gd`, etc.) — except
  `game_save.gd` (class `GameSaveResource`), already flagged as an
  inconsistency worth a rename. Watch for more instances of this mismatch.
- STYLE_GUIDE.md is snake_case throughout for variables and functions, and
  shows a double-blank-line convention before function definitions. Don't
  assert a spacing violation without literally counting the lines first.

Before starting, run `mcp__godot__validate_scripts` once across the files
you're about to analyze in this batch and keep the results at hand. Use that
as ground truth for anything that would be a compile-time issue (type
mismatches, unresolved references, syntax problems) instead of guessing.

--- Analyze each file across five separate concerns — do NOT conflate them ---

1. STYLE — deviations from @STYLE_GUIDE.md (naming, formatting, typed vars, etc.)
   Only cite a violation if you can point to the specific line in
   @STYLE_GUIDE.md that demonstrates the convention being broken. If you're
   noting a reasonable-but-undemonstrated convention, label it "inferred,
   not shown in STYLE_GUIDE.md" rather than stating it as a violation.
   Before citing a blank-line/spacing issue at a specific line number,
   re-count the actual lines around that citation in the file you just
   read — quote the line number and its content to yourself first.

2. ARCHITECTURE / COUPLING — scripts hard-wired to specific nodes, siblings,
   or autoloads in ways that make them fragile or hard to reuse.
   Before flagging autoload/singleton usage, check @ARCHITECTURE_OVERVIEW.md's
   Autoloads table. If the autoload is listed there as a System (e.g.
   `Events`, `Globals`), a Content-tier script using it is the sanctioned
   dependency direction, not a violation — don't flag it. If a pattern
   (e.g. `Events.X.emit()`) appears multiple times in the same file, flag
   all instances or none — don't single out one call among several
   identical ones.

3. RESPONSIBILITY SIZE — scripts doing too many unrelated jobs that should be
   split into smaller components

4. BUGS — any bugs inherent in the code (logic errors, off-by-ones, null
   references, incorrect signal connections, type mismatches, etc.). Keep
   this to defects you can actually point to in the code, not speculation.
   Cross-check against the `validate_scripts` results you already have
   rather than guessing about anything compile-checkable. For logic bugs it
   can't catch, only use confident language if you can trace the bug through
   with concrete example values. If it depends on GDScript/Godot-specific
   runtime semantics you're not fully certain of (typed-array coercion,
   Dictionary.values() return type, randf_range() inclusivity, property-
   setter initialization order, etc.), phrase it as "worth verifying" rather
   than a confirmed bug. Before claiming a declared variable is unused,
   search the rest of the function body — not just the next few lines — for
   the identifier.

5. FOLDER PLACEMENT — based on the GDQuest modular architecture (Libraries →
   Systems → Content, dependencies flow one direction
   only): where should this script's responsibilities live?
   - Libraries: game-agnostic, could be copy-pasted into an unrelated
     project, talks only to the engine
   - Systems: core game rules/mechanics, can depend on Libraries and other
     Systems, independent of specific content
   - Content: level/quest/character-specific, depends on Systems
   You can't see reverse dependencies (what else calls into this file) from
   a single-file view, so default to Medium/Low confidence here unless the
   file's full dependency picture is visible in what you're reading. This is
   not discretionary: before writing the Confidence rating, re-read your own
   "Suggested folder" reasoning — if it contains any phrase like "would be
   in X" or "not visible in this file," the confidence must be Medium or Low.

--- Definitions so you're consistent across files ---

A script is a SPLIT CANDIDATE if it meets 2+ of:
- Over ~250-300 lines of actual logic (not counting comments/blank lines)
- Mixes 3+ of these responsibility categories in one script:
  (a) input handling, (b) game state/logic, (c) presentation/animation/juice,
  (d) data/config, (e) signal routing/orchestration between other systems
- Has multiple unrelated reasons to change (if a designer wants to tweak
  camera zoom and an artist wants to tweak hit-flash timing, and both edits
  land in the same file, that's a signal)

When writing "Split recommendation," explicitly state in your reasoning
which of the criteria above are actually met before answering Yes/Maybe —
don't recommend a split on a file that doesn't hit at least 2. Also: before
including a function in a proposed split, check whether its body is fully
or mostly commented-out/stubbed. If so, note it as dead code and don't
recommend extracting it yet — wait until it's reimplemented.

A script has a COUPLING PROBLEM if it:
- Uses relative node paths like get_node("../../Foo") or deep $Path/To/Node
  chains to reach nodes outside its own subtree
- Directly calls methods on sibling/parent nodes instead of emitting a signal
- Hardcodes references to specific autoload singletons for things that could
  be passed in or resolved via signal/event bus — EXCEPT singletons listed
  as Systems in @ARCHITECTURE_OVERVIEW.md's Autoloads table (e.g. `Events`,
  `Globals`); a Content-tier script depending on those is expected, not a
  coupling problem
- Has magic numbers where an @export var or a Resource would let designers
  tune values without touching code
- Duplicates logic that already exists in another script (flag both files)

IMPORTANT COUNTERWEIGHT: don't recommend splitting a file just because it's
long. Only recommend a split if it demonstrably reduces coupling, gives a
clearer single owner, or removes a duplicated concern. If a script is long
but cohesive (one clear responsibility, no unrelated reasons to change), say
so explicitly and leave it alone. Over-fragmenting into many tiny scripts
with heavy signal wiring is its own architecture smell — weigh the cost of
added indirection against the benefit of the split.

Same logic applies to folder placement: this project is solo-developed, so
don't force enterprise-scale rigidity onto small/simple scripts. If a script
is small and clearly fine where it is, say so rather than proposing a move
for its own sake.

--- Output: per file ---

Add to "CLEAN_UP_PLAN.md". For each file, use this exact structure:

## <filename>
**Current responsibilities:** (bullet list, one line each)
**Style issues:** (cite @STYLE_GUIDE.md rule violated, or "none found")
**Coupling issues:** (specific line/pattern, or "none found")
**Split recommendation:** Yes / No / Maybe
  - If Yes/Maybe: proposed new script(s), what moves where, what signal(s)
    would connect them
  - If No: one sentence on why it's cohesive as-is
**Bugs:** (bullet list with line references, or "none found")
**Suggested folder:** Libraries / Systems / Content / UI — one sentence why
**Confidence:** High / Medium / Low — flag Low if you're inferring intent,
  dependency direction, or reverse-dependencies you can't verify from the
  code alone

--- Output: after all files in this batch are analyzed ---

Update the existing "## Cross-File Findings & Low-Hanging Fruit" and
"## Recommended for Fable Review" sections at the end of CLEAN_UP_PLAN.md so
they reflect ALL analyzed files — the original 11 plus everything from this
pass. Don't just append below them: check whether the new files surfaced
more instances of patterns already documented there (Events/Globals
mis-flags, EffectChain migration debt, Resource-naming mismatches, etc.) and
fold those into the existing bullets, then add any genuinely new cross-file
patterns you found, covering:
1. Cross-file patterns invisible to a single-file view: repeated mistakes,
   logic duplicated across files, two split candidates that are really the
   same underlying problem, inconsistent folder placement between similar
   scripts.
2. Low-hanging fruit: shared-utility opportunities, naming inconsistencies,
   dead code, a system that could absorb 2-3 proposed new scripts instead of
   each existing separately.

Keep "Recommended for Fable Review" short and prioritized — it protects a
limited, expiring model budget. Only include what genuinely needs
whole-codebase architectural judgment, not more per-file review.

--- Process ---

Do not make any code changes yourself — only edit "CLEAN_UP_PLAN.md" and
"ANALYZE.md". Work through every unanalyzed file listed in @ANALYZE.md in
order, inserting a new section for each *before* the existing "## Cross-File
Findings & Low-Hanging Fruit" heading. This is a single autonomous pass —
don't stop for confirmation between files; run through the full remaining
list. Mark each file `-- ANALYZED` in ANALYZE.md as you finish it, so
progress survives if this gets interrupted.

Ask me any clarifying questions before starting.
