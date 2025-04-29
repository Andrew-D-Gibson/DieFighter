@warning_ignore_start("unused_signal")

extends Node

# Loading Events
signal load_game_save(game_save: GameSaveResource)
signal load_scenario(scenario: ScenarioResource)


# UI Events
signal show_info(info: InfoResource)


# Control Events
signal show_map()
signal show_systems()
signal show_comms()
signal hide_comms()

signal show_dialogue(text: String)
signal dialogue_closed()
signal show_choice_dialogue(text: String, choices: Array[ChoiceResource])
signal choice_made(choice_index: int)

signal targeting_computer_retargeted()


# Game Events
signal enemy_left(ship: Enemy, faction: ScenarioManager.Faction)
signal game_over()
signal player_health_hit()
signal player_shields_hit()
signal engine_charge_changed()

# Game Sequencing Events
signal set_background(background_resource: BackgroundResource)
signal start_scenario()
signal start_combat()
signal player_turn_over()
signal enemy_turn_over()
signal combat_finished()

signal spawn_reward(pos: Vector2, money: int, num_of_rewards: int, dice_probability: float)
signal reward_picked()

signal enemy_acted(enemy_name: String, action_name: String)
signal player_attacked_ship(ship: Enemy, ship_faction: ScenarioManager.Faction)
signal scenario_event(event: ScenarioManager.ScenarioEvent)

signal set_money(value: int)


# Scenario Events
signal open_shop()
signal close_shop()


# Audio Events
signal play_sound(sound_name: String)
