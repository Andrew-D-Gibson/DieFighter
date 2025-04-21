class_name EnemyActionFilter
extends RefCounted

## Determines which actions are available based on enemy attitude, faction, and game state
## Filters and weights actions according to the current situation

var enemy: Enemy
var available_actions: Array[EnemyActionResource]
var action_weights: Dictionary

# Weight multipliers for different situations
const WEIGHT_MULTIPLIERS = {
	"LOW_HEALTH": 2.0,  # More likely to heal when health is low
	"LOW_SHIELDS": 1.5,  # More likely to shield when shields are low
	"ALLIED_LOW_HEALTH": 1.3,  # More likely to heal allies when they're low
	"ENEMY_PRESENT": 1.4,  # More likely to attack when enemies are present
	"NO_ENEMIES": 0.0,  # Don't attack when no valid targets
	"DEFAULT": 1.0
}

func _init(p_enemy: Enemy) -> void:
	enemy = p_enemy

## Updates the available actions and their weights based on current game state
func update_available_actions() -> void:
	available_actions.clear()
	action_weights.clear()
	
	var current_faction = enemy.scenario_state.faction
	var other_ships = _get_other_ships()
	
	for action in enemy.enemy_resource.actions_and_likelihoods:
		var base_weight = enemy.enemy_resource.actions_and_likelihoods[action]
		var adjusted_weight = base_weight
		
		# Check if action is valid for this faction
		if not _is_action_valid_for_faction(action, current_faction):
			continue
			
		# Adjust weights based on action type and current situation
		match action.action_type:
			EnemyActionResource.ActionType.ATTACK:
				adjusted_weight = _adjust_attack_weight(action, current_faction, other_ships)
			EnemyActionResource.ActionType.SHIELD:
				adjusted_weight = _adjust_shield_weight(action, other_ships)
			EnemyActionResource.ActionType.HEAL:
				adjusted_weight = _adjust_heal_weight(action, other_ships)
				
		if adjusted_weight > 0:
			available_actions.append(action)
			action_weights[action] = adjusted_weight

## Checks if an action is valid for a given faction
func _is_action_valid_for_faction(action: EnemyActionResource, faction: FactionSystem.Faction) -> bool:
	if action.target_type == EnemyActionResource.TargetType.PLAYER:
		return FactionSystem.can_attack(faction, FactionSystem.Faction.PLAYER)
	elif action.target_type == EnemyActionResource.TargetType.OTHER:
		# Check if there are any valid targets for this faction
		var other_ships = _get_other_ships()
		for ship in other_ships:
			if FactionSystem.can_attack(faction, ship.scenario_state.faction):
				return true
		return false
	return true  # Self-targeting actions are always valid

## Adjusts weight for attack actions
func _adjust_attack_weight(action: EnemyActionResource, faction: FactionSystem.Faction, other_ships: Array) -> float:
	var base_weight = enemy.enemy_resource.actions_and_likelihoods[action]
	
	# Check if there are valid targets
	var has_valid_targets = false
	for ship in other_ships:
		if FactionSystem.can_attack(faction, ship.scenario_state.faction):
			has_valid_targets = true
			break
			
	if not has_valid_targets:
		return 0.0
		
	# Increase weight if there are enemies present
	return base_weight * WEIGHT_MULTIPLIERS.ENEMY_PRESENT

## Adjusts weight for shield actions
func _adjust_shield_weight(action: EnemyActionResource, other_ships: Array) -> float:
	var base_weight = enemy.enemy_resource.actions_and_likelihoods[action]
	var multiplier = WEIGHT_MULTIPLIERS.DEFAULT
	
	if action.target_type == EnemyActionResource.TargetType.SELF:
		if enemy.health.shields < enemy.health.starting_shields * 0.3:
			multiplier = WEIGHT_MULTIPLIERS.LOW_SHIELDS
	else:
		# Check if any allies have low shields
		for ship in other_ships:
			if ship.scenario_state.attitude == Enemy.Attitude.FRIENDLY and \
			   ship.health.shields < ship.health.starting_shields * 0.3:
				multiplier = WEIGHT_MULTIPLIERS.ALLIED_LOW_HEALTH
				break
				
	return base_weight * multiplier

## Adjusts weight for heal actions
func _adjust_heal_weight(action: EnemyActionResource, other_ships: Array) -> float:
	var base_weight = enemy.enemy_resource.actions_and_likelihoods[action]
	var multiplier = WEIGHT_MULTIPLIERS.DEFAULT
	
	if action.target_type == EnemyActionResource.TargetType.SELF:
		if enemy.health.health < enemy.health.max_health * 0.3:
			multiplier = WEIGHT_MULTIPLIERS.LOW_HEALTH
	else:
		# Check if any allies have low health
		for ship in other_ships:
			if ship.scenario_state.attitude == Enemy.Attitude.FRIENDLY and \
			   ship.health.health < ship.health.max_health * 0.3:
				multiplier = WEIGHT_MULTIPLIERS.ALLIED_LOW_HEALTH
				break
				
	return base_weight * multiplier

## Gets all other ships in the scene
func _get_other_ships() -> Array:
	var ships = []
	var enemies = Globals.enemy_manager.get_alive_enemies()
	for other_enemy in enemies:
		if other_enemy != enemy:
			ships.append(other_enemy)
	return ships

## Selects a random action based on the current weights
func select_random_action() -> EnemyActionResource:
	if available_actions.is_empty():
		return null
		
	var total_weight = 0.0
	for weight in action_weights.values():
		total_weight += weight
		
	var choice = randf_range(0, total_weight)
	var current_sum = 0.0
	
	for action in available_actions:
		current_sum += action_weights[action]
		if choice <= current_sum:
			return action
			
	return available_actions[-1]  # Fallback to last action
