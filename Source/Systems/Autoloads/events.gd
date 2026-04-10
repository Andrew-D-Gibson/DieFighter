@warning_ignore_start("unused_signal")

extends Node

# Loading Events
signal load_game_save(game_save: GameSaveResource)
signal load_scenario(scenario: ScenarioResource)


# Startup Events
signal health_bar_startup()
signal systems_startup()
signal targeting_computer_startup()
signal map_startup()


# Game State/Sequencing Events
signal start_scenario()
signal start_combat()
signal jump()
signal game_over()
signal scenario_event(event: ScenarioManager.ScenarioEvent)


# Combat/Turn Management
signal player_turn_start()
signal player_turn_over()
signal enemy_turn_over()
signal combat_finished()


# Player Events
signal player_health_hit()
signal player_shields_hit()
signal engine_charge_changed()
signal player_attacked_ship(ship: Enemy, ship_faction: ScenarioManager.Faction)
signal player_fatal_damage()

# Enemy Events
signal enemy_left(ship: Enemy, faction: ScenarioManager.Faction)
signal enemy_flew_in()
signal enemy_received_die()
signal enemy_used_die(enemy: Enemy, die_value: int)
signal enemy_acted(enemy_name: String, action_name: String)


# Dice Events
signal die_placed_on_tile(die: Dice, tile: Tile)
signal die_added()


# Tile & Grid Events
signal tile_manually_moved(tile: Tile)
signal tile_pushed(tile: Tile)
signal tile_activation_complete()
signal tile_clicked_for_info()
signal add_status_to_grid_pos(grid_loc: Vector2i, status: GridStatusEffect)


# Reward/Economy Events
signal spawn_reward(pos: Vector2, reward_resource: RewardResource)
signal reward_picked()
signal set_money(value: int)


# UI Events
signal show_info(info: InfoResource)
signal info_graphic_closed()
signal close_info()
signal toggle_pause_menu()
signal toggle_fps_display()
signal highlight_dice_area()
signal show_map()
signal show_systems()
signal systems_shown()
signal map_shown()
signal open_shop()
signal close_shop()


# Info/Tutorial Events
signal error_text_popup(text: String, global_pos: Vector2)
signal tutorial_text_popup(text: String, global_pos: Vector2)
signal close_tutorial_text_popup()


# Interaction Events
signal mouse_clickable_for_info(clickable_for_info: bool)
signal set_current_clickable(clickable: Clickable)
signal targeting_computer_retargeted()


# Visual/Effects Events
signal set_background(background_resource: BackgroundResource)
signal take_screenshot()
signal camera_shake_small()
signal camera_shake_large()
signal set_glitch(glitch_state: bool)


# Audio Events
signal play_sound(sfx: SoundEffectResource)


# Configuration Events
signal save_options_config()
