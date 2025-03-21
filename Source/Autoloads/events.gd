@warning_ignore_start("unused_signal")

extends Node

# UI Events
signal show_info(info: InfoResource)
signal game_over()

# Game Events
signal start_encounter()
signal player_turn_over()
signal enemy_turn_over()
signal enemy_died()
signal encounter_finished()
signal reward_picked()
signal load_encounter(encounter: EncounterResource)
