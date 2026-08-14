# AGENTS.md — Godot Development Conventions

## Context
- Godot dev build: 4.7.1_stable. APIs may have changed from stable docs — treat any
  doc result as "probably true," not "definitely true," when it touches something
  new or edge-case.
- This file governs all Godot projects, not just game jams. Default to maintainable,
  readable architecture over the fastest thing that compiles. Jam-specific scope
  cuts (if any) should be called out explicitly in a project's own README, not
  assumed from this file.

## Documentation Workflow
1. Start with `godot-mcp-docs_get_documentation_tree` to see what's covered before
   drilling in.
2. Use `godot-mcp-docs_get_documentation_file` for the specific class/method/tutorial.
3. `get_documentation_resource` is also available as a resource template — use it
   when a direct file lookup doesn't surface what you need.
4. If a docs result doesn't explicitly mention 4.8 or a "changed in" note, treat it
   as last-confirmed-stable, not current. Cross-check against live state (below)
   before relying on a method signature, property name, or enum value you haven't
   used yet this session.
5. Prefer official docs over trained-in general knowledge, but prefer live
   introspection over docs when the two could plausibly disagree (new nodes,
   renamed properties, changed signal signatures — these move between minor
   versions).

## Script Validation Workflow (mandatory, not optional)
1. Every time you create or edit a `.gd` file — via `godot_create_script`,
   `godot_write_file`, or `godot_attach_script` — run `godot_validate_script` on it
   immediately after. Do not consider the edit done until it returns clean.
2. Before wrapping up a task that touched multiple scripts, run
   `godot_validate_scripts` as a final sweep across the changed set.
3. A clean validate result means it compiles — it does not mean it's correct.
   Treat it as the floor, not the finish line; follow with the verification steps
   below for actual behavior.
4. Never present code as "done" on the basis of "this should work." It's done when
   validate_script is clean AND (where applicable) the verification loop below has
   run.

## Verification Loop (behavior beyond compiling)
`godot_validate_script` catches syntax/type/compile errors, not logic errors. Close
that gap:
1. Before touching a node or resource, confirm its actual current shape rather than
   an assumed one: `godot_read_scene` for a `.tscn` file, or `godot_game_get_node_info`
   if a game session is live.
2. Check what signals actually exist with `godot_game_list_signals` before wiring
   new connections — don't assume from memory or docs.
3. For isolated logic (math, curves, state transitions), use `godot_game_eval` to
   run a quick GDScript snippet against a live session and check the output before
   wiring it into a scene. Cheaper than a full run cycle.
4. After any live session, check `godot_game_get_errors` and `godot_game_get_logs`
   for anything that only surfaces at runtime — null refs, bad type coercion, silent
   warnings.
5. Runtime tools (godot_game_*) require an active game session with the
   McpInteractionServer autoload running — there's no launch tool available.
   If runtime verification (godot_game_eval, get_errors, get_logs) would help,
   ask the user to start the game rather than assuming a session exists.

## Scene & Node Workflow
- Never modify a scene blind. Run `godot_read_scene` (file-based) or
  `godot_game_get_scene_tree` (live) first — don't assume prior-turn state still
  holds.
- Use `godot_manage_scene_structure`, `godot_add_node`, `godot_modify_scene_node`,
  and `godot_remove_scene_node` for edits, after confirming current hierarchy.
- `godot_save_scene` explicitly after structural changes — don't assume autosave.

## Scripting Conventions
- GDScript, static typing on all declared variables and function signatures
  (`var x: int`, `func foo() -> void:`), consistent with existing project style.
- Favor clear decomposition over the fastest path to "it runs." Assume this code
  gets extended and read by someone (including future-you) without today's context.
- Autoload singletons for cross-scene systems — check `godot_manage_autoloads`
  before adding a new one, to avoid duplicating a responsibility that already has
  a home.
- Signals over polling for cross-system communication. Direct calls are fine within
  a single scene where the coupling stays contained — don't let that pattern leak
  project-wide.
- Follow STYLE_GUIDE.md conventions when a project has one and there's ambiguity.
- Comment intent ("why"), not mechanics ("what") — the code should already say what
  it does.

## Resource & Project File Management
- Use `godot_manage_resource` for `.tres`/`.res` edits rather than hand-editing
  text resources blind.
- `godot_read_project_settings` before `godot_modify_project_settings`, to avoid
  clobbering unrelated settings.
- `godot_list_project_files` to confirm naming and location conventions before
  creating new files (`godot_create_script`, `godot_create_resource`,
  `godot_create_directory`).

## When Uncertain
If a method, property, or signal can't be confirmed via `godot_game_get_node_info`,
`godot_game_list_signals`, or a docs lookup that explicitly matches 4.8 behavior,
say so explicitly rather than guessing at a plausible-sounding API. Flag it as
"unconfirmed for 4.8dev" and propose the concrete verification step needed, rather
than writing code against an assumed signature.