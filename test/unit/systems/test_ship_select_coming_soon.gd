extends "res://test/helpers/die_fighter_test.gd"
## Ships still being built show on ship select greyed out, and nothing on the
## popup can pick or launch one.

const SHIP_SELECT: PackedScene = preload("res://Source/Systems/UI/ShipSelect/ship_select_popup.tscn")

var _was_selected: ShipResource


func before_each() -> void:
	_was_selected = Globals.selected_ship


func after_each() -> void:
	Globals.selected_ship = _was_selected


func _open() -> ShipSelectPopup:
	var popup: ShipSelectPopup = add_child_autofree(SHIP_SELECT.instantiate())
	popup.open()
	return popup


func _card(popup: ShipSelectPopup, id: StringName) -> ShipCard:
	for card: ShipCard in popup._cards:
		if card.ship.id == id:
			return card
	return null


func _press(popup: ShipSelectPopup, action: StringName) -> void:
	var event: InputEventAction = InputEventAction.new()
	event.action = action
	event.pressed = true
	popup._unhandled_input(event)


func test_the_unfinished_ships_are_coming_soon() -> void:
	assert_true(ShipCatalog.find(&"outrigger").coming_soon)
	assert_true(ShipCatalog.find(&"carousel").coming_soon)
	assert_false(ShipCatalog.find(ShipCatalog.DEFAULT_ID).coming_soon, "the default ship stays pickable")


func test_coming_soon_ships_still_get_a_card() -> void:
	var popup: ShipSelectPopup = _open()
	assert_eq(popup._cards.size(), ShipCatalog.all().size())
	assert_true(_card(popup, &"outrigger").locked)
	assert_false(_card(popup, ShipCatalog.DEFAULT_ID).locked)


func test_a_remembered_coming_soon_ship_falls_back_to_the_default() -> void:
	# An AutoPilot gauntlet on --ship carousel leaves it selected.
	Globals.selected_ship = ShipCatalog.find(&"carousel")
	var popup: ShipSelectPopup = _open()
	assert_eq(popup._picked.ship.id, ShipCatalog.DEFAULT_ID)


func test_clicking_a_coming_soon_card_doesnt_pick_it() -> void:
	Globals.selected_ship = null
	var popup: ShipSelectPopup = _open()
	popup._pick(_card(popup, &"outrigger"))
	assert_eq(popup._picked.ship.id, ShipCatalog.DEFAULT_ID)


func test_the_arrow_keys_pass_over_coming_soon_ships() -> void:
	Globals.selected_ship = null
	var popup: ShipSelectPopup = _open()
	_press(popup, &"ui_right")
	assert_false(popup._picked.locked, "right")
	_press(popup, &"ui_left")
	assert_false(popup._picked.locked, "left")


func test_launch_flies_a_pickable_ship() -> void:
	Globals.selected_ship = ShipCatalog.find(&"outrigger")
	var popup: ShipSelectPopup = _open()
	watch_signals(popup)
	popup._on_launch()
	assert_signal_emitted_with_parameters(popup, "launched", [ShipCatalog.find(ShipCatalog.DEFAULT_ID)])
