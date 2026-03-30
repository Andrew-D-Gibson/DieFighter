---
  1. Duplicated Array(..., TYPE_OBJECT, "Node", null) in Targeters
  Every targeter file (5+) repeats this exact constructor with only the value
   changing. Extract a helper method.

  2. Repeated amount-calculation pattern in attribute-changing effects
  DamageEffect, ShieldEffect, HealEffect, ChargeEngineEffect all share the
  same "inherit die value OR use export amount, then apply modifiers" logic.
  Extract to EffectVariables.setup_amount().

  3. Magic-number modifier categories (0, 1, 2)
  calculate_final_amount_with_global_modifiers(1) — the integer meaning
  DAMAGE is implicit. Replace with a proper enum or constants.

  4. Scattered preloaded UID strings
  8+ effect files preload scenes via raw UID strings like
  preload("uid://doi43icsr46q0"). These are fragile and undiscoverable.
  Centralize into an AssetManager or export them as editor properties.

  5. Typo: repititions_to_add in AddRepetitionsEffect
  Also an audit opportunity — check all effect exports for similar typos or
  stale/unused variables.

  6. Magic numbers throughout GameStateManager
  randi_range(2,3), 0.3, 0.33, 0.2 wait times — none of these are named. Pull
   them out to named constants at the top of the file.

  7. tile.gd's effect_data variable is misnamed
  It's actually tile-persistent state data (turn counters, etc.), not effect
  data. EffectVariables is what holds "effect data." Rename to
  tile_state_data to eliminate the confusion.

  8. Activation validation logic is tangled in Tile
  can_activate() and _clears_activation_criteria() mix grid checks, use-count
   checks, error message generation, and popup signaling. Extract to an
  ActivationValidator class.

  9. AddRepetitionsEffect has manually-reset instance state
  num_of_activations is reset inside play() rather than being scoped to a
  scenario lifecycle. This is fragile. Hook into Events.start_scenario or
  make the state ephemeral.

  10. Inconsistent error reporting across effects
  Some use printerr(), some print(), some silently return, some trigger UI
  popups. A single DebugLogger or consistent convention would make debugging
  much easier.

  ---
  The biggest bang-for-buck refactors are probably #2 (DRY out the amount
  pattern), #3 (enum for modifier categories), and #8 (ActivationValidator)
  since they touch the most files and make the codebase easier to extend.
  Where do you want to start?