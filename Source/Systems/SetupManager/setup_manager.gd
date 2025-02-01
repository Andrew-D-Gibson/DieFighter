extends Node

@export_category('Behavior')
@export var game_state: GameStateResource
@export var time_between_die_spawns: float = 0.2

@export_category('Components')
@export var player: Player

@export_category('')
@export var dice_scene: PackedScene


func _ready() -> void:
	# Add the tiles to the player's grid
	if player and player.tile_grid:
		player.tile_grid.setup_tiles(game_state.tile_locations)

	_spawn_dice(game_state.num_of_dice)
		
		
func _spawn_dice(num_of_dice: int) -> void:
	for i in range(num_of_dice):
		await get_tree().create_timer(time_between_die_spawns).timeout
		
		var new_die = dice_scene.instantiate()
		new_die.position = player.position + player.dice_queue_offset + Vector2(600, 0)

		add_child(new_die)
		Globals.player.dice_queue.add(new_die)
