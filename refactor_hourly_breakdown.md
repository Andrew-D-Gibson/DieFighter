Plan Overview (TL;DR)
The current system has effects that own their own behavior — DamageEffect directly mutates HP, spawns particles, emits signals, all in one place. That's brittle and hard to extend (especially for modifiers/upgrades).
The new system introduces a CombatEngine that acts as a central traffic controller. Instead of effects doing things directly, they push typed events (like DamageEvent) into a queue. The engine then processes each event through modifiers (upgrades, passives, statuses) that can tweak values before/after resolution. Effects become pure data (EffectData resources) that describe intent, with small handlers that translate that intent into engine events.
The migration is intentionally incremental — old system stays running while you build the new one alongside it, then you migrate piece by piece and delete the old stuff at the end.
5 phases: Build engine core → Build data/handler layer → Wire tiles to engine → Migrate damage logic → Delete legacy code.

~1 Hour Work Blocks

Block 1 — Orient & Read (~1 hr)
Before touching anything

Re-read effect.gd, effect_chain.gd, tile.gd, and damage_effect.gd to re-familiarize yourself with the current system
Re-read the plan's sections 1–3 (understand/isolate, desired end-state, what gets removed)
Sketch or annotate the current data flow on paper/whiteboard: Tile → EffectChain → DamageEffect → health.take_damage()
Goal: be able to describe in your own words what the old system does and why it's being replaced


Block 2 — Scaffold CombatEngine (~1 hr)
Phase 1, step 1

Create Source/Combat/combat_engine.gd as a Node class
Add event_queue: Array, modifiers: Array
Implement enqueue_event(), add_modifier(), remove_modifier(), has_pending_events()
Stub out process_events() — loop structure only, no real logic yet
No integration anywhere yet; just the skeleton


Block 3 — Define EffectEvent and DamageEvent (~1 hr)
Phase 1, step 2

Create Source/Combat/effect_event.gd with base fields: actor, targets, amount, source_tile, die_value, canceled
Create Source/Combat/damage_event.gd extending EffectEvent
Implement resolve(engine) stub — port damage logic from DamageEffect.play() (shields → HP splitting, health.take_damage(), Events.player_attacked_ship, Globals.state_manager update)
Don't wire it to anything yet; just get the logic living in the right place


Block 4 — Define Modifier Base & Implement process_events() (~1 hr)
Phase 1, steps 3–4

Create Source/Combat/modifier.gd with priority: int, on_before_event(), on_after_event() (both no-ops)
Finish CombatEngine.process_events(): pop event → run before-hooks sorted by priority → if not canceled, call event.resolve(engine) → run after-hooks
Write two throwaway test modifiers (DoubleDamageModifier, GainShieldOnDamageModifier) — these are just for validation, not real gameplay yet


Block 5 — Smoke Test CombatEngine in Isolation (~1 hr)
Phase 1, step 5 + validation

Add CombatEngine as a Node in your combat scene (created on combat start, freed on end)
Don't connect tiles yet — manually enqueue a test DamageEvent in _ready() or a debug button
Run process_events() and verify: before-hooks fire → damage resolves → after-hooks fire
Check that DoubleDamageModifier actually doubles the amount
Fix anything broken before moving on


Block 6 — EffectData Resource & Enums (~1 hr)
Phase 2, steps 1–2

Create Source/Content/EffectsV2/effect_enums.gd with category and subtype enums (TARGETING, AMOUNT, STATUS; TARGET_ENEMIES, TARGET_PLAYER, DAMAGE, HEAL, etc.)
Create Source/Content/EffectsV2/effect_data.gd as a Resource with category, subtype, and parameter exports (damage_amount, inherit_die_amount)
Create Source/Content/EffectsV2/effect_context.gd with: actor, effect_source, activator_die, targets, repetitions
Verify these show up cleanly in the Godot inspector


Block 7 — EffectHandler Base & Core Handlers (~1 hr)
Phase 2, step 3

Create Source/Content/EffectsV2/effect_handler.gd base with apply(data, context, engine) stub
Implement TargetEnemiesHandler — populates context.targets with current enemy list
Implement TargetPlayerHandler — sets player as target
Implement DealDamageHandler — reads damage_amount / inherit_die_amount from EffectData, builds a DamageEvent per target, enqueues into engine


Block 8 — Registry & EffectChainV2 (~1 hr)
Phase 2, steps 4–5

Create Source/Content/EffectsV2/effect_registry.gd — maps (category, subtype) → handler instance
Create Source/Content/EffectsV2/effect_chain_v2.gd with effects: Array[EffectData]
Implement play(context: EffectContext, engine: CombatEngine): iterate EffectData → look up handler in registry → call handler.apply()
No repetitions handling yet if that adds complexity — keep it simple first


Block 9 — Wire One Tile to the New System (~1 hr)
Phase 3, partial — the most important milestone

Pick the simplest "deal damage to enemy" tile in your game
Pass CombatEngine reference to it (via setter or combat scene)
Update its activate() to: build EffectContext → call effect_chain_v2.play(context, engine) → engine runs process_events()
Keep the old effect_chain path in an if/else as a fallback
Play the game and verify this one tile works end-to-end through the new pipeline


Block 10 — Wire handle_tile_event() & Add EffectChainV2 to More Tiles (~1 hr)
Phase 3, remainder

Update handle_tile_event() in Tile to use EffectContext + new chain (same pattern as Block 9)
Migrate 2-3 more simple tiles to EffectChainV2 + EffectData
Start getting a feel for what's awkward about the EffectContext builder and refine it


Block 11 — Migrate DamageEffect → DamageEvent Resolution (~1 hr)
Phase 4, steps 1–2

Audit DamageEffect.play() line by line and confirm all its logic is now in DamageEvent.resolve()
Update DealDamageHandler to use EffectData params for base amount
Verify that modifier hooks are what adjusts amount now (not calculate_final_amount_with_global_modifiers)
Stop using DamageEffect for any new tiles from this point forward


Block 12 — Introduce Real Modifiers (~1 hr)
Phase 4, steps 3–4

Port 1-2 real player upgrades/passives into the Modifier system
Register them with CombatEngine at combat start
Test that they interact correctly with DamageEvent (before/after hooks)
This is the first time the new architecture actually drives real gameplay — take time to validate thoroughly


Block 13 — Migrate Remaining Legacy Tiles (~1 hr, possibly 2 sessions)
Phase 4, step 5

Go through remaining tiles that still use old EffectChain + DamageEffect
For each: create EffectData entries, swap to EffectChainV2, test
This is the grind phase — likely the most time-consuming part of the whole refactor
Track progress with a simple checklist


Block 14 — Delete Legacy Code (~1 hr)
Phase 5

Once all tiles are migrated: remove DamageEffect and other obsolete Effect subclasses
Strip EffectVariables.calculate_final_amount_with_global_modifiers
Remove old effect_chain.play() call paths from Tile
Mark Effect and EffectChain as deprecated (or delete if nothing references them)
Do a global search for direct combat state mutations (health.take_damage outside of event resolution, direct Globals.state_manager sets, etc.)


Block 15 — Audit, Debug Tooling & Cleanup (~1 hr)
Phase 5, remainder

Add a debug mode to CombatEngine that logs the event queue and modifier changes per event
Play through a few combat encounters end-to-end and watch the logs
Fix anything still broken or awkward
Optionally: add the EditorInspectorPlugin for nicer EffectData dropdowns in the inspector