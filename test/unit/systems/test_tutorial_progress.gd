extends "res://test/helpers/die_fighter_test.gd"
## The tutorial as player progress: played once on a new player's first Play,
## then offered again from ship select, and never an option.

const SHIP_SELECT: PackedScene = preload("res://Source/Systems/UI/ShipSelect/ship_select_popup.tscn")


## --- Saved progress, and migrating the old option ---

func test_a_first_launch_hasnt_played_it() -> void:
	assert_false(OptionsSettings.read_tutorial_completed(ConfigFile.new()))


func test_an_old_file_with_show_tutorial_off_counts_as_played() -> void:
	var config: ConfigFile = ConfigFile.new()
	config.set_value("Game", "show_tutorial", false)
	assert_true(OptionsSettings.read_tutorial_completed(config),
		"a player who'd finished or switched off the tutorial is put back through it")


func test_an_old_file_with_show_tutorial_on_hasnt_played_it() -> void:
	var config: ConfigFile = ConfigFile.new()
	config.set_value("Game", "show_tutorial", true)
	assert_false(OptionsSettings.read_tutorial_completed(config))


func test_saved_progress_wins_over_the_old_option() -> void:
	var config: ConfigFile = ConfigFile.new()
	config.set_value("Game", "show_tutorial", false)
	config.set_value("Progress", "tutorial_completed", false)
	assert_false(OptionsSettings.read_tutorial_completed(config))


func test_it_isnt_an_option_any_more() -> void:
	assert_false(OptionsSettings.has_option(&"Game/show_tutorial"))


## --- Which runs the tutorial narrates ---

func _manager() -> TutorialManager:
	var manager: TutorialManager = autofree(TutorialManager.new())
	manager.tutorial_steps.append(TutorialStep.new())
	Globals.selected_ship = ShipCatalog.find(ShipCatalog.DEFAULT_ID)
	Globals.pending_load_save = null
	return manager


func test_it_plays_a_run_the_menu_launched_as_the_tutorial() -> void:
	var manager: TutorialManager = _manager()
	Globals.tutorial_requested = true
	assert_true(manager.should_play())


func test_an_ordinary_new_game_isnt_narrated() -> void:
	var manager: TutorialManager = _manager()
	Globals.tutorial_requested = false
	Globals.tutorial_completed = false
	assert_false(manager.should_play(), "only the menu's request starts the tutorial")


func test_a_continue_isnt_narrated() -> void:
	var manager: TutorialManager = _manager()
	Globals.tutorial_requested = true
	Globals.pending_load_save = GameSaveResource.new()
	assert_false(manager.should_play())


func test_the_bot_switching_it_off_still_wins() -> void:
	var manager: TutorialManager = _manager()
	Globals.tutorial_requested = true
	manager.auto_start = false
	assert_false(manager.should_play())


## --- Replay Tutorial on ship select ---

func _open_ship_select(completed: bool) -> ShipSelectPopup:
	Globals.tutorial_completed = completed
	var popup: ShipSelectPopup = add_child_autofree(SHIP_SELECT.instantiate())
	popup.open()
	return popup


func test_replay_is_hidden_until_the_tutorial_is_played() -> void:
	var popup: ShipSelectPopup = _open_ship_select(false)
	assert_false(popup.get_node("%ReplayTutorialButton").visible)


func test_replay_sits_in_the_corner_away_from_launch() -> void:
	var popup: ShipSelectPopup = _open_ship_select(true)
	var card: ShipCard = popup.tutorial_card()
	assert_not_null(card)
	assert_true(card.ship.supports_tutorial)
	var button: Button = popup.get_node("%ReplayTutorialButton")
	assert_true(button.visible)
	assert_lt(button.position.y + button.size.y, ShipSelectPopup._CARD_TOP, "above the cards")
	assert_lt(button.position.x + button.size.x, 0.0, "on the left")


func test_replay_flies_the_tutorials_ship() -> void:
	var popup: ShipSelectPopup = _open_ship_select(true)
	watch_signals(popup)
	popup._on_replay_tutorial()
	assert_signal_emitted_with_parameters(popup, "tutorial_launched", [popup.tutorial_card().ship])
	assert_signal_not_emitted(popup, "launched")
