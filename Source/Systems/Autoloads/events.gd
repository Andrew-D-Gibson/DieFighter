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
## The cockpit comes up all at once instead of revealing panel by panel. A run
## opens mid-fight, so there's no calm moment for a staggered boot sequence —
## every listener that owns a reveal overlay should snap it to fully revealed.
signal cockpit_snap_online()


# Game State/Sequencing Events
signal start_scenario()
signal start_combat()
signal jump()
signal game_over()
signal victory()
## Emitted once a new sector has been generated. sector_index is zero-based.
signal sector_advanced(sector_index: int)
signal scenario_event(event: ScenarioManager.ScenarioEvent)


# Combat/Turn Management
signal player_turn_start()
signal player_turn_over()
signal enemy_turn_over()
signal combat_finished()


# Player Events
signal player_health_hit()
signal player_shields_hit()
## The player's shields just dropped to zero. Worth its own signal — going from
## protected to exposed is a bigger moment than any single point of chip damage.
signal player_shields_broken()
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
## The dev console was opened or closed. Dev-only UI that lives outside the
## console's own scene follows this rather than watching for the key itself.
signal dev_console_toggled(is_open: bool)
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


# Hazard Events
## A scenario's hazard is set up (or cleared, when the hazard is null).
signal hazard_armed(hazard: ScenarioHazardResource, turns_remaining: int)
## The countdown ticked. Emitted every player turn while a hazard is active.
signal hazard_countdown_changed(hazard: ScenarioHazardResource, turns_remaining: int)
## The hazard just went off.
signal hazard_triggered(hazard: ScenarioHazardResource)


# Background Modifier Events
## The background on screen has finished changing, with any random pool
## already resolved to a concrete resource. Listeners that care about which
## background is actually up should use this rather than 'set_background',
## which fires before the pick is made.
signal background_changed(background: BackgroundResource)
## The background the player just arrived in carries a permanent rule (or
## none, when the resource is null). Emitted once per scenario, after the
## rule has been registered on that scenario's engine.
signal background_modifier_applied(modifier: BackgroundModifierResource)


# Visual/Effects Events
## Sustained red vignette pulse — the ship is in trouble in a way that outlasts
## a single hit. Distinct from the one-shot flashes driven by damage signals.
signal red_alert(duration: float)
signal set_background(background_resource: BackgroundResource)
signal take_screenshot()
signal camera_shake_small()
signal camera_shake_large()
signal set_glitch(glitch_state: bool)


# Audio Events
signal play_sound(sfx: SoundEffectResource)


# Configuration Events
signal save_options_config()


# Save/Load Events
signal game_saved()
