@warning_ignore_start("unused_signal")

extends Node

# Loading Events
signal load_game_save(game_save: GameSaveResource)

# UI Events
signal show_info(info: InfoResource)
signal show_map()
signal show_tile_grid()
signal show_dialogue(text: String)
signal dialogue_closed()
signal show_choice_dialogue(text: String, choices: Array[ChoiceResource])
signal choice_made(choice_index: int)

# Game Events
signal enemy_died()
signal game_over()

# Game Sequencing Events
signal start_scenario()
signal start_combat()
signal player_turn_over()
signal enemy_turn_over()
signal combat_finished()
signal reward_picked()

# Audio Events
signal tile_dropped()
