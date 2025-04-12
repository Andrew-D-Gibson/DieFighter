@warning_ignore_start("unused_signal")

extends Node

# Loading Events
signal load_game_save(game_save: GameSaveResource)
signal load_scenario(scenario: ScenarioResource)


# UI Events
signal show_info(info: InfoResource)


# Control Events
signal show_map()
signal show_tile_grid()
signal show_comms()

signal show_dialogue(text: String)
signal dialogue_closed()
signal show_choice_dialogue(text: String, choices: Array[ChoiceResource])
signal choice_made(choice_index: int)

signal targeting_computer_retargeted()


# Game Events
signal enemy_died()
signal game_over()
signal player_health_hit()
signal player_shields_hit()


# Game Sequencing Events
signal set_background(background_resource: BackgroundResource)
signal start_scenario()
signal start_combat()
signal player_turn_over()
signal enemy_turn_over()
signal combat_finished()

signal spawn_reward(pos: Vector2, money: int, dice_probability: float)
signal reward_picked()


# Audio Events
signal tile_dropped()
