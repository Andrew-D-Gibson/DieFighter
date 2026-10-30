extends "res://test/helpers/die_fighter_test.gd"
## AttitudeDisplay: the targeting computer's face and bezel tint for how the
## targeted ship feels about the player.

const Ships := preload("res://test/helpers/ships.gd")
const DISPLAY_SCENE: PackedScene = preload("res://Source/Systems/Game/TargetingComputer/attitude_display.tscn")

## The approved palette's ramps the tints are drawn from.
const RED_RAMP: Array[Color] = [Color("d03656"), Color("90263c"), Color("511521")]
const GREY_RAMP: Array[Color] = [Color("c4c1bc"), Color("a5a29d"), Color("8e8b85"), Color("63605c"), Color("343330")]
const GREEN_RAMP: Array[Color] = [Color("7abd33"), Color("659c2a"), Color("4c7520")]

var _display: AttitudeDisplay


func before_each() -> void:
	super()
	_display = DISPLAY_SCENE.instantiate()
	add_child_autofree(_display)


func _faction() -> FactionIdentity:
	var faction: FactionIdentity = FactionIdentity.new()
	faction.display_name = "The Test Fleet"
	faction.icon = PlaceholderTexture2D.new()
	faction.motto = "Hold still."
	faction.description = "They only exist in tests."
	return faction


func _ship(attitude: Enemy.Attitude) -> Enemy:
	var ship: Enemy = Ships.ship(ScenarioManager.Faction.PIRATE, 10, 10, attitude)
	autofree(ship)
	autofree(ship.health)
	return ship


func test_nothing_targeted_shows_nothing() -> void:
	assert_false(_display.visible, "the computer's own purple should show with no target")
	_display.show_ship(_ship(Enemy.Attitude.FRIENDLY))
	_display.show_ship(null)
	assert_false(_display.visible)


func test_each_attitude_tints_from_its_own_ramp() -> void:
	var ramps: Dictionary[Enemy.Attitude, Array] = {
		Enemy.Attitude.AGGRESSIVE: RED_RAMP,
		Enemy.Attitude.NEUTRAL: GREY_RAMP,
		Enemy.Attitude.FRIENDLY: GREEN_RAMP,
	}
	for attitude: Enemy.Attitude in ramps:
		_display.show_ship(_ship(attitude))
		assert_true(_display.visible)
		assert_has(ramps[attitude], _display.get_node("%BezelTint").modulate,
			"%s bezel" % Enemy.Attitude.find_key(attitude))
		assert_has(ramps[attitude], _display.get_node("%ImageFrameTint").modulate,
			"%s frame" % Enemy.Attitude.find_key(attitude))


func test_the_face_shows_the_attitude() -> void:
	var face: Sprite2D = _display.get_node("%Face")
	assert_eq(face.hframes, Enemy.Attitude.size(), "one face per attitude")
	for attitude: int in Enemy.Attitude.values():
		_display.show_ship(_ship(attitude as Enemy.Attitude))
		assert_eq(face.frame, attitude)


func test_a_ship_without_a_scenario_state_reads_hostile() -> void:
	var ship: Enemy = _ship(Enemy.Attitude.FRIENDLY)
	ship.scenario_state = null
	assert_eq(AttitudeDisplay.attitude_of(ship), Enemy.Attitude.AGGRESSIVE)


func test_a_change_of_heart_blinks_but_a_retarget_does_not() -> void:
	var ship: Enemy = _ship(Enemy.Attitude.NEUTRAL)
	_display.show_ship(ship)
	_display.show_ship(_ship(Enemy.Attitude.AGGRESSIVE))
	assert_null(_display._blink_tween, "a new target shouldn't blink")

	_display.show_ship(ship)
	ship.scenario_state.attitude = Enemy.Attitude.AGGRESSIVE
	_display.show_ship(ship)
	assert_not_null(_display._blink_tween)
	assert_true(_display._blink_tween.is_running())
	assert_eq(_display.get_node("%Face").frame, int(Enemy.Attitude.AGGRESSIVE))


func test_clearing_mid_blink_leaves_the_parts_lit() -> void:
	var ship: Enemy = _ship(Enemy.Attitude.NEUTRAL)
	_display.show_ship(ship)
	ship.scenario_state.attitude = Enemy.Attitude.AGGRESSIVE
	_display.show_ship(ship)
	_display._set_lit(false)
	_display.clear()
	_display.show_ship(_ship(Enemy.Attitude.FRIENDLY))
	assert_true(_display.get_node("%Face").visible)
	assert_true(_display.get_node("%BezelTint").visible)


func test_the_faction_badge_explains_the_faction_when_clicked() -> void:
	var ship: Enemy = _ship(Enemy.Attitude.NEUTRAL)
	ship.enemy_resource.faction = _faction()
	_display.show_ship(ship)
	var clickable: Clickable = _display.get_node("%FactionClickable")
	assert_true(clickable.input_pickable)
	var shown: Array[InfoResource] = []
	var catch: Callable = func(info: InfoResource) -> void: shown.append(info)
	Events.show_info.connect(catch)
	clickable.clicked.emit()
	Events.show_info.disconnect(catch)
	assert_eq(shown.size(), 1)
	assert_string_contains(shown[0].title_label_text, "The Test Fleet")
	assert_eq(shown[0].top_label_text, "Hold still.")
	assert_eq(shown[0].bottom_label_text, "They only exist in tests.")


func test_no_badge_takes_no_click() -> void:
	_display.show_ship(_ship(Enemy.Attitude.NEUTRAL))
	assert_false(_display.get_node("%FactionClickable").input_pickable, "a ship with no faction")
	var ship: Enemy = _ship(Enemy.Attitude.NEUTRAL)
	ship.enemy_resource.faction = _faction()
	_display.show_ship(ship)
	_display.clear()
	assert_false(_display.get_node("%FactionClickable").input_pickable, "nothing targeted")


func test_every_faction_has_its_words() -> void:
	for path: String in DirAccess.get_files_at("res://Source/Content/Factions"):
		if not path.ends_with(".tres"):
			continue
		var faction: FactionIdentity = load("res://Source/Content/Factions/" + path)
		assert_true(faction.motto.begins_with("FACTION_"), "%s motto is a translation key" % path)
		assert_true(faction.description.begins_with("FACTION_"), "%s description is a translation key" % path)
		assert_ne(TranslationServer.translate(faction.description), faction.description,
			"%s description has English text" % path)
