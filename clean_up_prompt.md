Read @ARCHITECTURE_OVERVIEW.md and @STYLE_GUIDE.md.

I'm mid-refactor. I want you to analyze scripts for four separate concerns and
NOT conflate them:

1. STYLE — deviations from @STYLE_GUIDE.md (naming, formatting, typed vars, etc.)
2. ARCHITECTURE / COUPLING — scripts that are hard-wired to specific nodes,
   siblings, or autoloads in ways that make them fragile or hard to reuse
3. RESPONSIBILITY SIZE — scripts doing too many unrelated jobs that should be
   split into smaller components
4. BUGS - any bugs that might be inherent in the code

--- Definitions so you're consistent across files ---

A script is a SPLIT CANDIDATE if it meets 2+ of:
- Over ~250-300 lines of actual logic (not counting comments/blank lines)
- Mixes 3+ of these responsibility categories in one script:
  (a) input handling, (b) game state/logic, (c) presentation/animation/juice,
  (d) data/config, (e) signal routing/orchestration between other systems
- Has multiple unrelated reasons to change (if a designer wants to tweak
  camera zoom and an artist wants to tweak hit-flash timing, and both edits
  land in the same file, that's a signal)

A script has a COUPLING PROBLEM if it:
- Uses relative node paths like get_node("../../Foo") or deep $Path/To/Node
  chains to reach nodes outside its own subtree
- Directly calls methods on sibling/parent nodes instead of emitting a signal
- Hardcodes references to specific autoload singletons for things that could
  be passed in or resolved via signal/event bus
- Has magic numbers where an @export var or a Resource would let designers
  tune values without touching code
- Duplicates logic that already exists in another script (flag both files)

IMPORTANT COUNTERWEIGHT: don't recommend splitting a file just because it's
long. Only recommend a split if it demonstrably reduces coupling, gives a
clearer single owner, or removes a duplicated concern. If a script is long but
cohesive (one clear responsibility, no unrelated reasons to change), say so
explicitly and leave it alone. Over-fragmenting into many tiny scripts with
heavy signal wiring is its own architecture smell — weigh the cost of added
indirection against the benefit of the split.

--- Output ---

Add to "CLEAN_UP_PLAN.md". For each file analyzed, use this exact structure:

## <filename>
**Current responsibilities:** (bullet list, one line each)
**Style issues:** (cite @STYLE_GUIDE.md rule violated, or "none found")
**Coupling issues:** (specific line/pattern, or "none found")
**Split recommendation:** Yes / No / Maybe
  - If Yes/Maybe: proposed new script(s), what moves where, what signal(s)
    would connect them
  - If No: one sentence on why it's cohesive as-is
**Confidence:** High / Medium / Low — flag Low if you're inferring intent
  you can't verify from the code alone
**Bugs:** (bullet list, one line each)

--- Process ---

Do not make any code changes yourself — only create and edit
"CLEAN_UP_PLAN.md". Ask me any clarifying questions before starting. Then
start with the first file listed in @ANALYZE.md and produce its section.
Wait for me to confirm before moving to the next file. 