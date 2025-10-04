@warning_ignore_start("unused_signal")

extends Node

# Loading Events
signal load_game_save(game_save: GameSaveResource)
signal load_scenario(scenario: ScenarioResource)


# UI Events
signal show_info(info: InfoResource)
signal info_graphic_closed()
signal tile_clicked_for_info()
signal close_info()
signal toggle_pause_menu()
signal highlight_dice_area()


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

signal targeting_computer_retargeted()
signal tile_activation_complete()


# Game Events
signal enemy_left(ship: Enemy, faction: ScenarioManager.Faction)
signal game_over()
signal player_health_hit()
signal player_shields_hit()
signal engine_charge_changed()

signal error_text_popup(text: String, global_pos: Vector2)
signal tutorial_text_popup(text: String, global_pos: Vector2)
signal close_tutorial_text_popup()

signal die_placed_on_tile(die: Dice, tile: Tile)

# Game Sequencing Events
signal jump()
signal set_background(background_resource: BackgroundResource)
signal start_scenario()
signal start_combat()
signal player_turn_start()
signal player_turn_over()
signal enemy_flew_in()
signal enemy_received_die()
signal enemy_used_die(enemy: Enemy, die_value: int)
signal enemy_turn_over()
signal combat_finished()
signal die_added()

signal spawn_reward(pos: Vector2, reward_resource: RewardResource)
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


# Tile Grid Events
signal add_status_to_grid_pos(grid_loc: Vector2i, status: GridStatusEffect)


# Audio Events
signal play_sound(sound_name: String)


# Startup Events
signal health_bar_startup()
signal main_viewer_startup()
signal targeting_computer_startup()
