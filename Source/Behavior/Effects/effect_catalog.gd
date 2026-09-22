@tool
## EffectCatalog
## The single source of truth for every effect type in the game.
##
## An effect used to be described in four places at once — the enum, the
## registry, the inspector's dropdown names, and EffectData's field-visibility
## rules. Nothing checked that those four agreed, and they drifted: six effects
## ended up unreachable from the inspector, one dropdown entry pointed at a
## handler that was never written, and MOVE_SHIP's only parameter was hidden
## from the editor entirely.
##
## Now each effect is one row here, and everything else is derived from it:
##   - EffectRegistry            builds its handler table from 'handler'
##   - EffectDataInspectorPlugin builds its dropdown from 'label'
##   - EffectData                decides field visibility from 'fields'
##
## EffectEnums still owns the ordinals, because authored .tres files store
## 'subtype' as a raw int. validate() cross-checks this catalog against those
## enums and is run by EffectRegistry at startup, so a half-added effect fails
## loudly instead of silently doing nothing.
##
## HOW TO ADD AN EFFECT:
##   1. APPEND a value to the END of the relevant EffectEnums subtype enum.
##      Never insert one in the middle — see the warning in effect_enums.gd.
##   2. Write the EffectHandler subclass.
##   3. Add a row below, in the same position as the enum value.
##   That's it. The registry, the dropdown and the inspector all follow.
##
## ROW SHAPE:
##   category — EffectEnums.Category value
##   subtype  — the matching EffectEnums.*Subtype value
##   label    — what the inspector dropdown shows
##   handler  — the EffectHandler subclass to instantiate (not an instance)
##   fields   — optional; the EffectData fields this effect actually reads.
##              Omit for effects that take no parameters. Anything not listed
##              is hidden in the inspector, so this must match what the
##              handler really reads or the author cannot set it.
##   reserved — optional; true marks an ordinal that is deliberately kept but
##              not implemented. It gets no handler and is not offered in the
##              dropdown, so it cannot be authored by accident.

class_name EffectCatalog
extends RefCounted


## Every optional EffectData parameter the inspector can show. A row's 'fields'
## entries must come from this list; validate() rejects anything else.
const KNOWN_FIELDS: Array[String] = [
	"amount", "multiplier", "string_param", "grid_offset",
	"sound_resource", "color", "range_min", "range_max",
]


static var _entries: Array[Dictionary] = [

	# ── TARGETING ─────────────────────────────────────────────────
	{category = EffectEnums.Category.TARGETING, subtype = EffectEnums.TargetingSubtype.TARGET_ENEMIES, label = "Target All Enemies", handler = TargetEnemiesHandler},
	{category = EffectEnums.Category.TARGETING, subtype = EffectEnums.TargetingSubtype.TARGET_PLAYER, label = "Target Player", handler = TargetPlayerHandler},
	{category = EffectEnums.Category.TARGETING, subtype = EffectEnums.TargetingSubtype.TARGET_RANDOM_ENEMY, label = "Target Random Enemy", handler = TargetRandomEnemyHandler},
	{category = EffectEnums.Category.TARGETING, subtype = EffectEnums.TargetingSubtype.TARGET_ALL_SHIPS, label = "Target All Ships", handler = TargetAllShipsHandler},
	{category = EffectEnums.Category.TARGETING, subtype = EffectEnums.TargetingSubtype.TARGET_ALL_OTHER_SHIPS, label = "Target All Other Ships", handler = TargetAllOtherShipsHandler},
	{category = EffectEnums.Category.TARGETING, subtype = EffectEnums.TargetingSubtype.TARGET_RANDOM_SHIP, label = "Target Random Ship", handler = TargetRandomShipHandler},
	{category = EffectEnums.Category.TARGETING, subtype = EffectEnums.TargetingSubtype.TARGET_RANDOM_TILE, label = "Target Random Tile", handler = TargetRandomTileHandler},
	{category = EffectEnums.Category.TARGETING, subtype = EffectEnums.TargetingSubtype.TARGET_SURROUNDING_TILES, label = "Target Surrounding Tiles", handler = TargetSurroundingTilesHandler},
	{category = EffectEnums.Category.TARGETING, subtype = EffectEnums.TargetingSubtype.TARGET_WITH_TARGETING_COMPUTER, label = "Target With Targeting Computer", handler = TargetWithTargetingComputerHandler},
	{category = EffectEnums.Category.TARGETING, subtype = EffectEnums.TargetingSubtype.TARGET_TILE_WITH_OFFSET, label = "Target Tile With Offset", handler = TargetTileWithOffsetHandler, fields = ["grid_offset"]},
	{category = EffectEnums.Category.TARGETING, subtype = EffectEnums.TargetingSubtype.TARGET_EFFECT_SOURCE, label = "Target Effect Source", handler = TargetEffectSourceHandler},
	{category = EffectEnums.Category.TARGETING, subtype = EffectEnums.TargetingSubtype.TARGET_SELF, label = "Target Self", handler = TargetSelfHandler},
	{category = EffectEnums.Category.TARGETING, subtype = EffectEnums.TargetingSubtype.TARGET_RANDOM_OTHER_ENEMY, label = "Target Random Other Enemy", handler = TargetRandomOtherEnemyHandler},

	# ── ATTRIBUTE_CHANGE ──────────────────────────────────────────
	{category = EffectEnums.Category.ATTRIBUTE_CHANGE, subtype = EffectEnums.AttributeChangeSubtype.DAMAGE, label = "Damage", handler = DealDamageHandler},
	{category = EffectEnums.Category.ATTRIBUTE_CHANGE, subtype = EffectEnums.AttributeChangeSubtype.HEAL, label = "Heal", handler = HealHandler},
	{category = EffectEnums.Category.ATTRIBUTE_CHANGE, subtype = EffectEnums.AttributeChangeSubtype.SHIELD, label = "Shield", handler = GainShieldsHandler},
	{category = EffectEnums.Category.ATTRIBUTE_CHANGE, subtype = EffectEnums.AttributeChangeSubtype.CHANGE_ENGINE_CHARGE, label = "Change Engine Charge", handler = ChangeEngineChargeHandler},
	{category = EffectEnums.Category.ATTRIBUTE_CHANGE, subtype = EffectEnums.AttributeChangeSubtype.SPEND_ENGINE_CHARGE, label = "Spend Engine Charge", handler = SpendEngineChargeHandler, fields = ["amount"]},
	{category = EffectEnums.Category.ATTRIBUTE_CHANGE, subtype = EffectEnums.AttributeChangeSubtype.ADD_OVERCHARGE, label = "Add Overcharge", handler = AddOverchargeHandler},

	# ── AMOUNT_MODIFIER ───────────────────────────────────────────
	{category = EffectEnums.Category.AMOUNT_MODIFIER, subtype = EffectEnums.AmountModifierSubtype.SET, label = "Set", handler = SetAmountHandler, fields = ["amount"]},
	{category = EffectEnums.Category.AMOUNT_MODIFIER, subtype = EffectEnums.AmountModifierSubtype.ADD, label = "Add", handler = AddAmountHandler, fields = ["amount"]},
	{category = EffectEnums.Category.AMOUNT_MODIFIER, subtype = EffectEnums.AmountModifierSubtype.MULTIPLY, label = "Multiply", handler = MultiplyAmountHandler, fields = ["multiplier"]},
	{category = EffectEnums.Category.AMOUNT_MODIFIER, subtype = EffectEnums.AmountModifierSubtype.ADD_ADJACENT_TILES, label = "Add Adjacent Tiles", handler = AddAdjacentTilesAmountHandler},
	{category = EffectEnums.Category.AMOUNT_MODIFIER, subtype = EffectEnums.AmountModifierSubtype.ADD_TILE_DATA, label = "Add Tile Data", handler = AddTileDataAmountHandler, fields = ["string_param"]},
	{category = EffectEnums.Category.AMOUNT_MODIFIER, subtype = EffectEnums.AmountModifierSubtype.SET_TO_ENGINE_CHARGE, label = "Set to Engine Charge", handler = SetAmountToEngineChargeHandler},
	{category = EffectEnums.Category.AMOUNT_MODIFIER, subtype = EffectEnums.AmountModifierSubtype.SET_TO_DIE_VALUE, label = "Set to Die Value", handler = SetAmountToDieValueHandler},
	{category = EffectEnums.Category.AMOUNT_MODIFIER, subtype = EffectEnums.AmountModifierSubtype.SET_TO_ENEMY_INTENT, label = "Set to Enemy Intent", handler = SetAmountToEnemyIntentHandler},
	{category = EffectEnums.Category.AMOUNT_MODIFIER, subtype = EffectEnums.AmountModifierSubtype.ADD_EMPTY_ADJACENT_CELLS, label = "Add Empty Adjacent Cells", handler = AddEmptyAdjacentCellsAmountHandler},
	{category = EffectEnums.Category.AMOUNT_MODIFIER, subtype = EffectEnums.AmountModifierSubtype.SET_TO_MISSING_CHARGE, label = "Set to Missing Charge", handler = SetAmountToMissingChargeHandler},
	{category = EffectEnums.Category.AMOUNT_MODIFIER, subtype = EffectEnums.AmountModifierSubtype.SET_TO_OVERCHARGE, label = "Set to Overcharge", handler = SetAmountToOverchargeHandler},

	# ── DICE_CONTROL ──────────────────────────────────────────────
	{category = EffectEnums.Category.DICE_CONTROL, subtype = EffectEnums.DiceControlSubtype.CHANGE_ACTIVATOR_VALUE, label = "Change Activator Value", handler = ChangeActivatorValueHandler},
	{category = EffectEnums.Category.DICE_CONTROL, subtype = EffectEnums.DiceControlSubtype.REROLL_ACTIVATOR, label = "Reroll Activator", handler = RerollActivatorHandler},
	{category = EffectEnums.Category.DICE_CONTROL, subtype = EffectEnums.DiceControlSubtype.REROLL_ALL, label = "Reroll All", handler = RerollAllDiceHandler},
	{category = EffectEnums.Category.DICE_CONTROL, subtype = EffectEnums.DiceControlSubtype.FLIP_ONES_AND_SIXES, label = "Flip Ones and Sixes", handler = FlipOnesAndSixesHandler},
	{category = EffectEnums.Category.DICE_CONTROL, subtype = EffectEnums.DiceControlSubtype.GIVE_DIE_TO_PLAYER, label = "Give Die to Player", handler = GiveDieToPlayerHandler},
	{category = EffectEnums.Category.DICE_CONTROL, subtype = EffectEnums.DiceControlSubtype.GIVE_DIE_TO_TARGET, label = "Give Die to Target", handler = GiveDieToTargetHandler},
	{category = EffectEnums.Category.DICE_CONTROL, subtype = EffectEnums.DiceControlSubtype.GIVE_DIE_AWAY, label = "Give Die Away", handler = GiveDieAwayHandler},
	{category = EffectEnums.Category.DICE_CONTROL, subtype = EffectEnums.DiceControlSubtype.KEEP_DIE_WITH_TILE, label = "Keep Die with Tile", handler = KeepDieWithTileHandler},
	{category = EffectEnums.Category.DICE_CONTROL, subtype = EffectEnums.DiceControlSubtype.SPAWN_HOLOGRAPHIC_DIE, label = "Spawn Holographic Die", handler = SpawnHolographicDieHandler},
	## Enemy-side 'take a die from a target' was specced but never built. The
	## ordinal is kept so KEEP_DIE_WITH_ACTOR below stays at 10, which authored
	## content already refers to.
	{category = EffectEnums.Category.DICE_CONTROL, subtype = EffectEnums.DiceControlSubtype.RECEIVE_DIE_FROM_TARGET, label = "Receive Die from Target", handler = null, reserved = true},
	{category = EffectEnums.Category.DICE_CONTROL, subtype = EffectEnums.DiceControlSubtype.KEEP_DIE_WITH_ACTOR, label = "Keep Die with Actor", handler = KeepDieWithActorHandler},

	# ── AUDIO_VISUAL ──────────────────────────────────────────────
	{category = EffectEnums.Category.AUDIO_VISUAL, subtype = EffectEnums.AudioVisualSubtype.SPAWN_HIT_PARTICLES, label = "Spawn Hit Particles", handler = SpawnHitParticlesHandler, fields = ["color"]},
	{category = EffectEnums.Category.AUDIO_VISUAL, subtype = EffectEnums.AudioVisualSubtype.SPAWN_EXPLOSION_PARTICLES, label = "Spawn Explosion Particles", handler = SpawnExplosionParticlesHandler, fields = ["color"]},
	{category = EffectEnums.Category.AUDIO_VISUAL, subtype = EffectEnums.AudioVisualSubtype.ANIMATE_DIE_TO_TILE, label = "Animate Die to Tile", handler = AnimateDieToTileHandler, fields = ["grid_offset"]},
	{category = EffectEnums.Category.AUDIO_VISUAL, subtype = EffectEnums.AudioVisualSubtype.ATTACK_TWEEN, label = "Attack Tween", handler = AttackTweenHandler},
	{category = EffectEnums.Category.AUDIO_VISUAL, subtype = EffectEnums.AudioVisualSubtype.SHAKE_DICE, label = "Shake Dice", handler = ShakeDiceHandler},
	{category = EffectEnums.Category.AUDIO_VISUAL, subtype = EffectEnums.AudioVisualSubtype.PLAY_SOUND, label = "Play Sound", handler = PlaySoundHandler, fields = ["sound_resource"]},
	{category = EffectEnums.Category.AUDIO_VISUAL, subtype = EffectEnums.AudioVisualSubtype.WAIT, label = "Wait", handler = WaitHandler},

	# ── TILE_CONTROL ──────────────────────────────────────────────
	{category = EffectEnums.Category.TILE_CONTROL, subtype = EffectEnums.TileControlSubtype.ACTIVATE_SELF, label = "Activate Self", handler = ActivateSelfHandler},
	{category = EffectEnums.Category.TILE_CONTROL, subtype = EffectEnums.TileControlSubtype.ACTIVATE_TARGETED_TILES, label = "Activate Targeted Tiles", handler = ActivateTargetedTilesHandler},
	{category = EffectEnums.Category.TILE_CONTROL, subtype = EffectEnums.TileControlSubtype.MOVE_TILE_WITH_OFFSET, label = "Move Tile with Offset", handler = MoveTileWithOffsetHandler, fields = ["grid_offset"]},
	{category = EffectEnums.Category.TILE_CONTROL, subtype = EffectEnums.TileControlSubtype.PUSH_TILE_IN_DIRECTION, label = "Push Tile in Direction", handler = PushTileInDirectionHandler, fields = ["grid_offset"]},
	{category = EffectEnums.Category.TILE_CONTROL, subtype = EffectEnums.TileControlSubtype.PULL_ROW_TILES_TO_COLUMN, label = "Pull Row Tiles to Column", handler = PullRowTilesToColumnHandler, fields = ["grid_offset"]},
	{category = EffectEnums.Category.TILE_CONTROL, subtype = EffectEnums.TileControlSubtype.ADD_AMPLIFIER_MODIFIER, label = "Add Amplifier Status", handler = AddAmplifierModifierHandler},
	{category = EffectEnums.Category.TILE_CONTROL, subtype = EffectEnums.TileControlSubtype.LOCKOUT_TILE, label = "Lockout Tile", handler = LockoutTileHandler},
	{category = EffectEnums.Category.TILE_CONTROL, subtype = EffectEnums.TileControlSubtype.ADD_USES_REMAINING, label = "Add Uses Remaining", handler = AddUsesRemainingHandler},
	{category = EffectEnums.Category.TILE_CONTROL, subtype = EffectEnums.TileControlSubtype.INCREMENT_TILE_DATA, label = "Increment Tile Data", handler = IncrementTileDataHandler, fields = ["string_param"]},
	{category = EffectEnums.Category.TILE_CONTROL, subtype = EffectEnums.TileControlSubtype.SET_TILE_DATA, label = "Set Tile Data", handler = SetTileDataHandler, fields = ["string_param"]},
	{category = EffectEnums.Category.TILE_CONTROL, subtype = EffectEnums.TileControlSubtype.PUSH_TARGETED_TILES, label = "Push Targeted Tiles", handler = PushTargetedTilesHandler, fields = ["grid_offset"]},
	{category = EffectEnums.Category.TILE_CONTROL, subtype = EffectEnums.TileControlSubtype.PASS_DIE_TO_TILE, label = "Pass Die to Tile", handler = PassDieToTileHandler},
	{category = EffectEnums.Category.TILE_CONTROL, subtype = EffectEnums.TileControlSubtype.ADD_DEATH_SAVE_MODIFIER, label = "Add Death Save Modifier", handler = AddDeathSaveModifierHandler},

	# ── SCENARIO_CONTROL ──────────────────────────────────────────
	{category = EffectEnums.Category.SCENARIO_CONTROL, subtype = EffectEnums.ScenarioControlSubtype.OPEN_SHOP, label = "Open Shop", handler = OpenShopHandler},
	{category = EffectEnums.Category.SCENARIO_CONTROL, subtype = EffectEnums.ScenarioControlSubtype.CLOSE_SHOP, label = "Close Shop", handler = CloseShopHandler},
	{category = EffectEnums.Category.SCENARIO_CONTROL, subtype = EffectEnums.ScenarioControlSubtype.JUMP, label = "Jump", handler = JumpHandler},
	{category = EffectEnums.Category.SCENARIO_CONTROL, subtype = EffectEnums.ScenarioControlSubtype.FLEE, label = "Flee", handler = FleeHandler},
	{category = EffectEnums.Category.SCENARIO_CONTROL, subtype = EffectEnums.ScenarioControlSubtype.MOVE_SHIP, label = "Move Ship", handler = MoveShipHandler, fields = ["multiplier"]},

	# ── CONDITIONAL ───────────────────────────────────────────────
	{category = EffectEnums.Category.CONDITIONAL, subtype = EffectEnums.ConditionalSubtype.IF_ACTIVATOR_ODD, label = "If Activator Odd", handler = ConditionalHandler},
	{category = EffectEnums.Category.CONDITIONAL, subtype = EffectEnums.ConditionalSubtype.IF_ENEMY_TARGETED, label = "If Enemy Targeted", handler = ConditionalHandler},
	{category = EffectEnums.Category.CONDITIONAL, subtype = EffectEnums.ConditionalSubtype.IF_ENGINE_CHARGED, label = "If Engine Charged", handler = ConditionalHandler},
	{category = EffectEnums.Category.CONDITIONAL, subtype = EffectEnums.ConditionalSubtype.IF_DIE_VALUE_IN_RANGE, label = "If Die Value in Range", handler = ConditionalHandler, fields = ["range_min", "range_max"]},
	{category = EffectEnums.Category.CONDITIONAL, subtype = EffectEnums.ConditionalSubtype.IF_TARGET_HOLDS_MATCHING_DIE, label = "If Target Holds Matching Die", handler = ConditionalHandler},
	{category = EffectEnums.Category.CONDITIONAL, subtype = EffectEnums.ConditionalSubtype.IF_OVERCHARGED, label = "If Overcharged", handler = ConditionalHandler},

	# ── REPETITION ────────────────────────────────────────────────
	{category = EffectEnums.Category.REPETITION, subtype = EffectEnums.RepetitionSubtype.ADD_REPETITIONS, label = "Add Repetitions", handler = AddRepetitionsHandler},

	# ── UTILITY ───────────────────────────────────────────────────
	{category = EffectEnums.Category.UTILITY, subtype = EffectEnums.UtilitySubtype.DESTROY_SOURCE, label = "Destroy Source", handler = DestroySourceHandler},
	{category = EffectEnums.Category.UTILITY, subtype = EffectEnums.UtilitySubtype.PRINT_DEBUG, label = "Print Debug", handler = PrintDebugHandler, fields = ["string_param"]},
]

# Lazily-built lookups, keyed for the two access patterns that matter:
# one exact row (the registry, the inspector's field rules) and one category's
# worth of rows (the dropdown).
static var _by_pair: Dictionary = {}
static var _by_category: Dictionary = {}


static func _build_index() -> void:
	if not _by_pair.is_empty():
		return
	for entry: Dictionary in _entries:
		var category: int = entry["category"]
		var subtype: int = entry["subtype"]
		if not _by_pair.has(category):
			_by_pair[category] = {}
			_by_category[category] = [] as Array[Dictionary]
		_by_pair[category][subtype] = entry
		(_by_category[category] as Array).append(entry)


## Every row, in declaration order.
static func all() -> Array[Dictionary]:
	return _entries


## The row for one (category, subtype) pair, or an empty Dictionary if there
## is none. Callers should treat empty as "this effect does not exist".
static func get_entry(category: int, subtype: int) -> Dictionary:
	_build_index()
	if not _by_pair.has(category):
		return {}
	return _by_pair[category].get(subtype, {})


## Rows for one category that an author is allowed to pick, in enum order.
## Reserved ordinals are left out so they cannot be selected by accident.
static func selectable_entries(category: int) -> Array[Dictionary]:
	_build_index()
	var rows: Array[Dictionary] = []
	for entry: Dictionary in _by_category.get(category, [] as Array[Dictionary]):
		if not entry.get("reserved", false):
			rows.append(entry)
	return rows


## Does this effect actually read the given EffectData field? Drives which
## fields the inspector shows, so it answers false for unknown effects rather
## than guessing.
static func uses_field(category: int, subtype: int, field: String) -> bool:
	var entry: Dictionary = get_entry(category, subtype)
	if entry.is_empty():
		return false
	return field in (entry.get("fields", []) as Array)


## Cross-checks this catalog against EffectEnums and returns one string per
## problem found. Empty means the two agree. Run by EffectRegistry at startup.
static func validate() -> PackedStringArray:
	var problems: PackedStringArray = []
	_build_index()

	var seen: Dictionary = {}
	for entry: Dictionary in _entries:
		var category: int = entry["category"]
		var subtype: int = entry["subtype"]
		var where: String = "%s/%d" % [EffectEnums.Category.find_key(category), subtype]

		var pair_key: String = "%d:%d" % [category, subtype]
		if seen.has(pair_key):
			problems.append("duplicate row for %s" % where)
		seen[pair_key] = true

		var subtypes: Dictionary = EffectEnums.subtype_enum(category)
		if subtypes.is_empty():
			problems.append("%s: unknown category" % where)
		elif subtype < 0 or subtype >= subtypes.size():
			problems.append("%s: subtype is outside its enum (0..%d)"
					% [where, subtypes.size() - 1])

		if entry.get("reserved", false):
			if entry.get("handler") != null:
				problems.append("%s: reserved rows must not have a handler" % where)
		elif entry.get("handler") == null:
			problems.append("%s: no handler (mark it 'reserved = true' if that is deliberate)" % where)

		if (entry.get("label", "") as String).is_empty():
			problems.append("%s: missing label" % where)

		for field: String in (entry.get("fields", []) as Array):
			if field not in KNOWN_FIELDS:
				problems.append("%s: unknown field '%s'" % [where, field])

	# Every enum value needs a row, or it is an effect that can never be
	# authored — the exact failure this catalog exists to prevent.
	for category: int in EffectEnums.Category.values():
		var subtypes: Dictionary = EffectEnums.subtype_enum(category)
		for subtype: int in subtypes.values():
			if get_entry(category, subtype).is_empty():
				problems.append("%s.%s has no catalog row"
						% [EffectEnums.Category.find_key(category),
						   subtypes.find_key(subtype)])

	return problems
