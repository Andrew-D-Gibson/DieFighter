extends Node2D

@export_category('Behavior')
@export var current_save: GameSaveResource

@export_category('Components')
@export var player: Player
@export var enemy_manager: EnemyManager


func _ready() -> void:
	# Add tiles and dice for the player
	if player:
		player.num_of_dice = current_save.num_of_dice
		
		if player.tile_grid:
			player.tile_grid.setup_tiles(current_save.tile_locations)

	# Hook up the signals for turn management
	if player and enemy_manager:
		player.player_turn_over.connect(enemy_manager.run_enemy_turn)
		enemy_manager.enemy_turn_ended.connect(func():
			player.targeting_computer.check_target_is_valid()	 # Update the computer with the new enemy intents
			player.start_player_turn()
		)
		
	Events.load_encounter.connect(_load_encounter)
	_load_encounter(current_save.current_encounter)
	
	
func _load_encounter(encounter: EncounterResource) -> void:
	var dice = get_tree().get_nodes_in_group('Dice')
	for die in dice:
		player.dice_queue.add(die)
		player.reroll_dice()
	
	# Spawn enemies (temporary)
	if enemy_manager:
		enemy_manager.spawn_enemies(encounter.enemies_to_spawn)
