@warning_ignore_start("unused_signal")

extends Node

# Loading Events
signal load_game_save(game_save: GameSaveResource)
signal load_scenario(scenario: ScenarioResource)


# UI Events
signal show_info(info: InfoResource)
signal toggle_pause_menu()


# Misc.
signal take_screenshot()
signal camera_shake_small()
signal camera_shake_large()
signal set_glitch(glitch_state: bool)
signal mouse_clickable_for_info(clickable_for_info: bool)
signal set_current_clickable(clickable: Clickable)


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
signal tile_activation_complete()

signal hand_option_unlock(option_num: int)
signal add_tile_to_discard(tile: Tile)

# Game Events
signal enemy_left(ship: Enemy, faction: ScenarioManager.Faction)
signal game_over()
signal player_health_hit()
signal player_shields_hit()
signal engine_charge_changed()
signal error_text_popup(text: String, global_pos: Vector2)
signal player_out_of_dice()

# Game Sequencing Events
signal jump()
signal set_background(background_resource: BackgroundResource)
signal start_scenario()
signal start_combat()
signal player_turn_start()
signal player_turn_over()
signal enemy_turn_over()
signal combat_finished()
signal die_added()

signal spawn_reward(pos: Vector2, money: int, num_of_rewards: int, dice_probability: float)
signal reward_picked()

signal enemy_acted(enemy_name: String, action_name: String)
signal player_attacked_ship(ship: Enemy, ship_faction: ScenarioManager.Faction)
signal scenario_event(event: ScenarioManager.ScenarioEvent)

signal set_money(value: int)


# Scenario Events
signal open_shop()
signal close_shop()


# Tile Events
signal tile_manually_moved(tile: Tile)
signal tile_pushed(tile: Tile)


# Audio Events
signal play_sound(sound_name: String)


# Startup Events
signal health_bar_startup()
