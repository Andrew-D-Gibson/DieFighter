## EffectRegistry
## Maps (category, subtype) pairs to EffectHandler instances.
##
## All handlers are stateless, so a single shared instance per handler
## type is safe and efficient.
##
## HOW TO ADD A NEW HANDLER:
##   1. Write your EffectHandler subclass.
##   2. Add a _register() call in _ready() below.
##
## HOW EffectChainV2 USES THIS:
##   var handler := EffectRegistry.get_handler(data.category, data.subtype)
##   await handler.apply(data, context, engine)


extends Node

# The registry: _handlers[category_int][subtype_int] = EffectHandler instance
var _handlers: Dictionary = {}


func _ready() -> void:
	_register_all()


## Look up the handler for a (category, subtype) pair.
## Returns null and logs an error if no handler is registered.
func get_handler(category: int, subtype: int) -> EffectHandler:
	if _handlers.has(category) and _handlers[category].has(subtype):
		return _handlers[category][subtype]
	push_error(
		"EffectRegistry: no handler registered for category=" +
		EffectEnums.Category.find_key(category) +
		" subtype=" +
		str(subtype) +
		"\nAdd a _register() call in effect_registry.gd._ready()."
	)
	return null


func _register(category: int, subtype: int, handler: EffectHandler) -> void:
	if not _handlers.has(category):
		_handlers[category] = {}
	_handlers[category][subtype] = handler


func _register_all() -> void:
	var T := EffectEnums  # Shorthand alias

	# ── TARGETING ─────────────────────────────────────────────────────────────
	_register(T.Category.TARGETING, T.TargetingSubtype.TARGET_ENEMIES,                 TargetEnemiesHandler.new())
	_register(T.Category.TARGETING, T.TargetingSubtype.TARGET_PLAYER,                  TargetPlayerHandler.new())
	_register(T.Category.TARGETING, T.TargetingSubtype.TARGET_RANDOM_ENEMY,            TargetRandomEnemyHandler.new())
	_register(T.Category.TARGETING, T.TargetingSubtype.TARGET_ALL_SHIPS,               TargetAllShipsHandler.new())
	_register(T.Category.TARGETING, T.TargetingSubtype.TARGET_ALL_OTHER_SHIPS,         TargetAllOtherShipsHandler.new())
	_register(T.Category.TARGETING, T.TargetingSubtype.TARGET_RANDOM_SHIP,             TargetRandomShipHandler.new())
	_register(T.Category.TARGETING, T.TargetingSubtype.TARGET_RANDOM_TILE,             TargetRandomTileHandler.new())
	_register(T.Category.TARGETING, T.TargetingSubtype.TARGET_SURROUNDING_TILES,       TargetSurroundingTilesHandler.new())
	_register(T.Category.TARGETING, T.TargetingSubtype.TARGET_WITH_TARGETING_COMPUTER, TargetWithTargetingComputerHandler.new())
	_register(T.Category.TARGETING, T.TargetingSubtype.TARGET_EFFECT_SOURCE,           TargetEffectSourceHandler.new())
	_register(T.Category.TARGETING, T.TargetingSubtype.TARGET_SELF,                    TargetSelfHandler.new())

	# ── ATTRIBUTE CHANGE ───────────────────────────────────────────────────────
	_register(T.Category.ATTRIBUTE_CHANGE, T.AttributeChangeSubtype.DAMAGE,               DealDamageHandler.new())
	_register(T.Category.ATTRIBUTE_CHANGE, T.AttributeChangeSubtype.HEAL,                 HealHandler.new())
	_register(T.Category.ATTRIBUTE_CHANGE, T.AttributeChangeSubtype.SHIELD,               GainShieldsHandler.new())
	_register(T.Category.ATTRIBUTE_CHANGE, T.AttributeChangeSubtype.CHANGE_ENGINE_CHARGE, ChangeEngineChargeHandler.new())

	# ── AUDIO_VISUAL ──────────────────────────────────────────────────────────
	_register(T.Category.AUDIO_VISUAL, T.AudioVisualSubtype.SPAWN_HIT_PARTICLES,       SpawnHitParticlesHandler.new())
	_register(T.Category.AUDIO_VISUAL, T.AudioVisualSubtype.SPAWN_EXPLOSION_PARTICLES, SpawnExplosionParticlesHandler.new())
	_register(T.Category.AUDIO_VISUAL, T.AudioVisualSubtype.ANIMATE_DIE_TO_TILE,       AnimateDieToTileHandler.new())
	_register(T.Category.AUDIO_VISUAL, T.AudioVisualSubtype.ATTACK_TWEEN,              AttackTweenHandler.new())
	_register(T.Category.AUDIO_VISUAL, T.AudioVisualSubtype.SHAKE_DICE,                ShakeDiceHandler.new())
	_register(T.Category.AUDIO_VISUAL, T.AudioVisualSubtype.PLAY_SOUND,                PlaySoundHandler.new())
	_register(T.Category.AUDIO_VISUAL, T.AudioVisualSubtype.WAIT,                      WaitHandler.new())

	# ── TILE CONTROL ───────────────────────────────────────────────────────────
	_register(T.Category.TILE_CONTROL, T.TileControlSubtype.ACTIVATE_SELF,              ActivateSelfHandler.new())
	_register(T.Category.TILE_CONTROL, T.TileControlSubtype.ACTIVATE_TARGETED_TILES,    ActivateTargetedTilesHandler.new())
	_register(T.Category.TILE_CONTROL, T.TileControlSubtype.MOVE_TILE_WITH_OFFSET,      MoveTileWithOffsetHandler.new())
	_register(T.Category.TILE_CONTROL, T.TileControlSubtype.PUSH_TILE_IN_DIRECTION,     PushTileInDirectionHandler.new())
	_register(T.Category.TILE_CONTROL, T.TileControlSubtype.PULL_ROW_TILES_TO_COLUMN,   PullRowTilesToColumnHandler.new())
	_register(T.Category.TILE_CONTROL, T.TileControlSubtype.ADD_AMPLIFIER_STATUS,       AddAmplifierStatusHandler.new())
	_register(T.Category.TILE_CONTROL, T.TileControlSubtype.LOCKOUT_TILE,               LockoutTileHandler.new())
	_register(T.Category.TILE_CONTROL, T.TileControlSubtype.ADD_USES_REMAINING,         AddUsesRemainingHandler.new())
	_register(T.Category.TILE_CONTROL, T.TileControlSubtype.INCREMENT_TILE_DATA,        IncrementTileDataHandler.new())
	_register(T.Category.TILE_CONTROL, T.TileControlSubtype.SET_TILE_DATA,              SetTileDataHandler.new())

	# ── DICE CONTROL ───────────────────────────────────────────────────────────
	_register(T.Category.DICE_CONTROL, T.DiceControlSubtype.CHANGE_ACTIVATOR_VALUE,  ChangeActivatorValueHandler.new())
	_register(T.Category.DICE_CONTROL, T.DiceControlSubtype.REROLL_ACTIVATOR,        RerollActivatorHandler.new())
	_register(T.Category.DICE_CONTROL, T.DiceControlSubtype.REROLL_ALL,              RerollAllDiceHandler.new())
	_register(T.Category.DICE_CONTROL, T.DiceControlSubtype.FLIP_ONES_AND_SIXES,     FlipOnesAndSixesHandler.new())
	_register(T.Category.DICE_CONTROL, T.DiceControlSubtype.GIVE_DIE_TO_PLAYER,      GiveDieToPlayerHandler.new())
	_register(T.Category.DICE_CONTROL, T.DiceControlSubtype.GIVE_DIE_TO_TARGET,      GiveDieToTargetHandler.new())
	_register(T.Category.DICE_CONTROL, T.DiceControlSubtype.GIVE_DIE_AWAY,           GiveDieAwayHandler.new())
	_register(T.Category.DICE_CONTROL, T.DiceControlSubtype.KEEP_DIE_WITH_TILE,      KeepDieWithTileHandler.new())
	_register(T.Category.DICE_CONTROL, T.DiceControlSubtype.SPAWN_HOLOGRAPHIC_DIE,   SpawnHolographicDieHandler.new())

	# ── SCENARIO CONTROL ───────────────────────────────────────────────────────
	_register(T.Category.SCENARIO_CONTROL, T.ScenarioControlSubtype.OPEN_SHOP,  OpenShopHandler.new())
	_register(T.Category.SCENARIO_CONTROL, T.ScenarioControlSubtype.CLOSE_SHOP, CloseShopHandler.new())
	_register(T.Category.SCENARIO_CONTROL, T.ScenarioControlSubtype.JUMP,       JumpHandler.new())
	_register(T.Category.SCENARIO_CONTROL, T.ScenarioControlSubtype.FLEE,       FleeHandler.new())
	_register(T.Category.SCENARIO_CONTROL, T.ScenarioControlSubtype.MOVE_SHIP,  MoveShipHandler.new())

	# ── CONDITIONAL ───────────────────────────────────────────────────────────
	_register(T.Category.CONDITIONAL, T.ConditionalSubtype.IF_ACTIVATOR_ODD,      ConditionalHandler.new())
	_register(T.Category.CONDITIONAL, T.ConditionalSubtype.IF_ENEMY_TARGETED,     ConditionalHandler.new())
	_register(T.Category.CONDITIONAL, T.ConditionalSubtype.IF_ENGINE_CHARGED,     ConditionalHandler.new())
	_register(T.Category.CONDITIONAL, T.ConditionalSubtype.IF_DIE_VALUE_IN_RANGE, ConditionalHandler.new())

	# ── REPETITION ─────────────────────────────────────────────────────────────
	_register(T.Category.REPETITION, T.RepetitionSubtype.ADD_REPETITIONS, AddRepetitionsHandler.new())

	# ── UTILITY ────────────────────────────────────────────────────────────────
	_register(T.Category.UTILITY, T.UtilitySubtype.DESTROY_SOURCE, DestroySourceHandler.new())
	_register(T.Category.UTILITY, T.UtilitySubtype.PRINT_DEBUG,    PrintDebugHandler.new())
