## tile_v2_example.gd
## ============================================================
## Shows the minimal changes needed to wire Tile to the new system.
##
## This is NOT a replacement for the full tile.gd — it's an annotated
## excerpt showing only the pieces that change. Read it alongside tile.gd.
##
## CHANGES SUMMARY:
##   1. Add a 'scenario_engine' property with a setter.
##   2. Update activate() to use effect_chain_v2 when available.
##   3. Update handle_tile_event() similarly.
##   4. Keep the old effect_chain path as a fallback for un-migrated tiles.
##   5. Build EffectContext instead of EffectVariables when using v2.
##
## MIGRATION STRATEGY:
##   - Add both effect_chain and effect_chain_v2 to TileResource.
##   - Migrate tiles one at a time: author the v2 chain, leave v1 in place,
##     verify the tile works, then delete the v1 chain from the resource.
##   - Once ALL tiles are migrated, remove the old fallback code.
## ============================================================

# This is a pseudoclass — it won't run as-is. Think of it as annotated pseudocode.
# In reality you'll be editing Source/Content/Tiles/tile.gd directly.

extends Node2D  # Tile extends Node2D in the real codebase

# ── NEW: ScenarioEngine reference ─────────────────────────────────────────────

## Reference to the active ScenarioEngine.
## Injected by TileGrid after the engine is created at scenario start.
##
## In TileGrid (or wherever you create the engine), after creating tiles:
##   for tile in all_tiles:
##       tile.set_scenario_engine(scenario_engine)
var scenario_engine: ScenarioEngine = null

func set_scenario_engine(engine: ScenarioEngine) -> void:
	scenario_engine = engine


# ── UPDATED: activate() ────────────────────────────────────────────────────────

## Original signature preserved. Only the effect execution block changes.
func activate(activator_die) -> void:
	# --- all existing pre-effect logic stays exactly the same ---
	# (uses_remaining, animation setup, activation checks, etc.)
	# ... (unchanged code) ...

	# ── V2 path ───────────────────────────────────────────────────────────────
	if tile_resource.effect_chain_v2 and scenario_engine:
		var context := EffectContext.new()
		context.actor         = Globals.player    # or whoever owns this tile
		context.effect_source = self
		context.activator_die = activator_die

		# play() enqueues events; process_events() resolves them all.
		await tile_resource.effect_chain_v2.play(context, scenario_engine)
		await scenario_engine.process_events()

	# ── V1 fallback (remove once all tiles are migrated) ──────────────────────
	elif tile_resource.effect_chain:
		var effect_variables := _generate_effect_variables(activator_die)
		await tile_resource.effect_chain.play(effect_variables)

	# --- all existing post-effect logic stays exactly the same ---
	# (Events.tile_activation_complete, etc.)
	# ... (unchanged code) ...


# ── UPDATED: handle_tile_event() ───────────────────────────────────────────────

## Same pattern as activate().
func handle_tile_event(tile, event_type: int) -> void:
	# --- all existing guard logic stays exactly the same ---
	# ... (unchanged code) ...

	var event_check: TileEvent = _find_matching_event_response(event_type)
	if event_check == null:
		return

	# ── V2 path ───────────────────────────────────────────────────────────────
	var v2_response: EffectChainV2 = tile_resource.event_responses_v2.get(event_check)
	if v2_response and scenario_engine:
		var context := EffectContext.new()
		context.actor         = Globals.player
		context.effect_source = self
		# No activator die for event responses (they trigger automatically).

		await v2_response.play(context, scenario_engine)
		await scenario_engine.process_events()

	# ── V1 fallback ───────────────────────────────────────────────────────────
	elif tile_resource.event_responses.has(event_check):
		var effect_variables := _generate_effect_variables(null)
		await tile_resource.event_responses[event_check].play(effect_variables)


# ── TileResource additions ─────────────────────────────────────────────────────
## Add these to tile_resource.gd alongside the existing fields:
##
##   @export var effect_chain_v2: EffectChainV2
##   @export var event_responses_v2: Dictionary[TileEvent, EffectChainV2]
##
## The old fields (effect_chain, event_responses) stay until migration is complete.
