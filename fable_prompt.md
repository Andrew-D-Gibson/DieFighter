Read @ARCHITECTURE_OVERVIEW.md, @STYLE_GUIDE.md, and the fully populated
@CLEAN_UP_PLAN.md (now including a local LLM's per-file pass and a Sonnet
sanity-check layer with cross-file findings and a "Recommended for Fable
Review" list).

This is the final, most expensive pass in a three-stage review. Don't repeat
the first two stages' work — assume the per-file analysis and cross-file
sanity-checking are already done and mostly correct. Your value here is
whole-codebase judgment neither prior stage could make:

1. START with the "Recommended for Fable Review" list — that's been
   pre-triaged as needing your level of judgment specifically. Give those
   the deepest attention.

2. THEN do one holistic read of the whole plan and architecture doc looking
   for anything both prior passes missed — patterns that only become visible
   when you're weighing the entire project's shape at once, not any single
   file or pair of files.

3. EVALUATE THE REFACTOR PLAN ITSELF, not just individual files. Does the
   direction described in @ARCHITECTURE_OVERVIEW.md actually solve the
   problems surfaced in @CLEAN_UP_PLAN.md, or does it leave some unaddressed
   / introduce new ones? Say so plainly if the plan needs to change, not just
   the code.

4. THOUGHT-PROCESS FEEDBACK: beyond this specific cleanup, tell me what
   patterns in how I got here are worth changing going forward — not
   "fix these files" but "here's a habit or blind spot that produced this
   category of issue, and here's what would prevent it next time." This is
   the part I most want from spending a frontier model's judgment on this:
   not just what to fix, but what in my process led to needing the fix.

--- Output ---

Append to @CLEAN_UP_PLAN.md:

## Fable Review — Priority Findings
For each item from "Recommended for Fable Review": your judgment call,
reasoning, and recommended action. Overrule the earlier passes explicitly
where you disagree, with reasoning.

## Fable Review — Refactor Plan Assessment
Does the plan in @ARCHITECTURE_OVERVIEW.md actually resolve what
@CLEAN_UP_PLAN.md surfaced? Gaps, sequencing risks, or anything that should
change about the plan itself before more code gets touched.

## Going Forward
Process- and habit-level observations — what tends to produce the
overbuilt-script / coupling patterns you saw across this codebase, and what
would catch these earlier next time (a convention, a check, a different
default when starting a new script, etc.). This section is for me as a
developer, not for the codebase.

Do not make any code changes yourself — documentation only, same as the
prior two stages. Ask me any clarifying questions before starting.