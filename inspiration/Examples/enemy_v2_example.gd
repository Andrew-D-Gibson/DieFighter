## enemy_v2_example.gd
## ============================================================
## Shows how an enemy uses the new system to execute its actions.
##
## The key insight: enemies are just another actor queuing EffectChainV2
## into the same ScenarioEngine. No special enemy-specific effect pipeline.
##
## BEFORE (old system):
##   An enemy action was probably an EnemyAction resource with an EffectChain.
##   On its turn, it built EffectVariables (actor = enemy ship) and called
##   await effect_chain.play(effect_variables).
##
## AFTER (new system):
##   The enemy action has an EffectChainV2 instead (or both, during migration).
##   On its turn, it builds EffectContext (actor = enemy ship) and calls
##   await effect_chain_v2.play(context, scenario_engine).
##   Then awaits scenario_engine.process_events().
##
## ENEMY ACTION EXAMPLE:
##   An enemy that:
##     1. Animates its die flying to the player's tile
##     2. Deals 3 damage to the player
##     3. Gains 1 shield for itself
##
##   EffectChainV2.effects = [
##     EffectData { category=TARGETING,         subtype=TARGET_PLAYER },
##     EffectData { category=VISUAL,            subtype=ANIMATE_DIE_TO_TILE },
##     EffectData { category=ATTRIBUTE_CHANGE,  subtype=DAMAGE, amount=3 },
##     EffectData { category=TARGETING,         subtype=TARGET_SELF },
##     EffectData { category=ATTRIBUTE_CHANGE,  subtype=SHIELD, amount=1 },
##   ]
##
## The engine handles damage first, then shields, all with full modifier support.
## ============================================================

## Annotated excerpt of an EnemyAction or EnemyShip script.
## Read alongside your actual EnemyAction/EnemyShip classes.

# ── EnemyAction resource (what you'd add) ─────────────────────────────────────

# In your EnemyActionResource (or equivalent):
#
# @export var effect_chain_v2: EffectChainV2    ← ADD THIS
# @export var effect_chain: EffectChain         ← KEEP until fully migrated


# ── How an enemy ship executes an action ──────────────────────────────────────

## Call this from your enemy's take_turn() or use_die() method.
## 'enemy_ship' is the enemy node. 'action' is an EnemyActionResource.
## 'activator_die' is the die the enemy is using (may be null for passive actions).
func execute_enemy_action(enemy_ship: Node, action: Resource, activator_die: Node, engine: ScenarioEngine) -> void:

	# ── V2 path ───────────────────────────────────────────────────────────────
	if action.effect_chain_v2 and engine:
		var context := EffectContext.new()
		context.actor         = enemy_ship   # ← The enemy is the actor
		context.effect_source = enemy_ship   # ← Source is the enemy ship itself
		context.activator_die = activator_die

		await action.effect_chain_v2.play(context, engine)
		await engine.process_events()

	# ── V1 fallback ───────────────────────────────────────────────────────────
	elif action.effect_chain:
		var effect_variables := EffectVariables.new()
		effect_variables.actor = enemy_ship
		effect_variables.effect_source = enemy_ship
		effect_variables.activator_die = activator_die
		await action.effect_chain.play(effect_variables)


# ── Why this works without special cases ──────────────────────────────────────
#
# DamageEvent.resolve() checks:
#   if actor is Player and target is Enemy:
#       Events.player_attacked_ship.emit(...)
#
# When an enemy is the actor:
#   - actor is Enemy (not Player), so that branch is skipped
#   - target.health.take_damage(amount) still runs for the player
#   - Modifiers can check event.actor to apply enemy-specific effects
#
# Modifier example — "+2 damage when enemies attack":
#   func on_before_event(event, engine):
#       if event is DamageEvent and event.actor is Enemy:
#           event.amount += 2
#
# Everything flows through the same engine. No special casing needed.
