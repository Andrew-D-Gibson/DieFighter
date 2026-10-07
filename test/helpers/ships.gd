extends RefCounted
## Builders for enemy ships and their action pools, for tests about how ships
## pick and bind their intents. The ships are kept out of the tree, so none of
## their components need to exist; free them with the test's autofree().

const Effects := preload("res://test/helpers/effects.gd")
const Cat := EffectEnums.Category


## A ship with a faction, an attitude and a hull, and nothing else. Its
## Health isn't parented to it, so autofree both.
static func ship(faction: ScenarioManager.Faction, hull: int = 10, max_hull: int = 10,
		attitude: Enemy.Attitude = Enemy.Attitude.AGGRESSIVE) -> Enemy:
	var made: Enemy = Enemy.new()
	made.enemy_resource = EnemyResource.new()
	made.enemy_resource.enemy_name = ScenarioManager.Faction.find_key(faction)
	made.scenario_state = ScenarioShipState.new()
	made.scenario_state.faction = faction
	made.scenario_state.attitude = attitude
	made.health = Health.new()
	made.health.max_health = max_hull
	made.health.health = hull
	return made


static func action(action_name: String, effects: Array[EffectData]) -> EnemyActionResource:
	var made := EnemyActionResource.new()
	made.name = action_name
	made.effect_chain = Effects.chain(effects)
	return made


static func attack() -> EnemyActionResource:
	var effects: Array[EffectData] = [
		Effects.data(Cat.TARGETING, EffectEnums.TargetingSubtype.TARGET_PLAYER),
		Effects.die_value(), Effects.damage(),
	]
	return action("Attack", effects)


## Shields itself, then feeds the die to its bound ally.
static func relay() -> EnemyActionResource:
	var effects: Array[EffectData] = [
		Effects.data(Cat.TARGETING, EffectEnums.TargetingSubtype.TARGET_SELF),
		Effects.shield(),
		Effects.data(Cat.DICE_CONTROL, EffectEnums.DiceControlSubtype.FEED_ALLY),
	]
	return action("Relay", effects)


## Conjures a hologram, face = its intent amount, for its bound ally.
static func loader() -> EnemyActionResource:
	var effects: Array[EffectData] = [
		Effects.data(Cat.DICE_CONTROL, EffectEnums.DiceControlSubtype.SPAWN_HOLOGRAM_FOR_ALLY),
		Effects.data(Cat.DICE_CONTROL, EffectEnums.DiceControlSubtype.GIVE_DIE_TO_PLAYER),
	]
	return action("Loader", effects)


static func option(base: EnemyActionResource, weight: float = 1.0,
		min_amount: int = 0, max_amount: int = 0) -> EnemyActionOptionResource:
	var made := EnemyActionOptionResource.new()
	made.base_action = base
	made.weight = weight
	made.min_amount = min_amount
	made.max_amount = max_amount
	return made


static func pool(options: Array[EnemyActionOptionResource]) -> EnemyTurnActionList:
	var made := EnemyTurnActionList.new()
	made.actions_possible = options
	return made


## Gives [param made] a single action pool to roll and reroll from.
static func give_pool(made: Enemy, options: Array[EnemyActionOptionResource]) -> void:
	var pools: Array[EnemyTurnActionList] = [pool(options)]
	made.enemy_resource.action_options = pools


## Sets a ship's table outright, numbering the slots.
static func set_table(made: Enemy, actions: Array[EnemyActionResource]) -> void:
	for i: int in range(actions.size()):
		actions[i].activating_die_number = i + 1
	made.turn_actions = actions


static func roster(ships: Array) -> Array[Enemy]:
	var out: Array[Enemy] = []
	out.assign(ships)
	return out
