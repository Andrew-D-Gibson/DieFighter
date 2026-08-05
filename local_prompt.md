Read @ARCHITECTURE_OVERVIEW.md and @STYLE_GUIDE.md.

I'm mid-refactor. Analyze every file listed in @ANALYZE.md and populate
"CLEAN_UP_PLAN.md" with one section per file. Analyze each file across five
separate concerns — do NOT conflate them:

1. STYLE — deviations from @STYLE_GUIDE.md (naming, formatting, typed vars, etc.)
   Only cite a violation if you can point to the specific line in
   @STYLE_GUIDE.md that demonstrates the convention being broken. If you're
   inferring a reasonable-but-undemonstrated convention, label it "inferred,
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
   Only use confident language if you can trace the bug through with
   concrete example values. If it depends on GDScript/Godot-specific
   runtime semantics you're not fully certain of (typed-array coercion,
   Dictionary.values() return type, randf_range() inclusivity, property-
   setter initialization order, etc.), phrase it as "worth verifying"
   rather than a confirmed bug. Before claiming a declared variable is
   unused, search the rest of the function body (not just the next few
   lines) for the identifier.
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
   file's full dependency picture is visible in what you're reading. This
   is not discretionary: before writing the Confidence rating, re-read your
   own "Suggested folder" reasoning — if it contains any phrase like "would
   be in X" or "not visible in this file," the confidence must be Medium
   or Low.

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
don't force Epictellers'-scale rigidity onto small/simple scripts. If a
script is small and clearly fine where it is, say so rather than proposing
a move for its own sake.

--- Output ---

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

--- Process ---

Do not make any code changes yourself — only edit
"CLEAN_UP_PLAN.md". Work through every file listed in @ANALYZE.md in order,
appending a section for each. Don't stop for confirmation between files —
run through the full list and produce a complete CLEAN_UP_PLAN.md in one
pass.

Start with the first file that hasn't been looked at already, and 
analyze a single file at a time.  I'll validate, then you can go on.

After analysis, modify ANALYZE.md to record your progress, 
and write your analysis to CLEAN_UP_PLAN.md
ANALYZE A SINGLE FILE AT A TIME AND ASK PERMISSION BEFORE GOING ON.