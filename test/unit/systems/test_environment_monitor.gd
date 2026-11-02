extends "res://test/helpers/die_fighter_test.gd"
## EnvironmentMonitor: flips down whenever the player arrives somewhere with a
## rule or a hazard, fight or no fight, and folds away for the jump out. A
## hazard's countdown shows only while a fight has it counting down.
##
## The monitor is in the tree, so it listens to the real Events; the signals
## the managers would send are emitted by hand. It answers a burst of them
## with one deferred present, so each step waits a frame before checking.

const MONITOR_SCENE: PackedScene = preload(
	"res://Source/Systems/Game/OverheadConsole/EnvironmentMonitor/environment_monitor.tscn"
)

var monitor: EnvironmentMonitor
var background: BackgroundResource
var hazard: BackgroundHazardResource


func before_each() -> void:
	super()
	hazard = BackgroundHazardResource.new()
	hazard.hazard_name = "Test Flare"
	hazard.turns_until_first = 3

	background = BackgroundResource.new()
	background.hazard = hazard
	var background_manager: BackgroundManager = autofree(BackgroundManager.new())
	background_manager.current_background = background
	Globals.background_manager = background_manager

	# The arrival card has tests of its own below; elsewhere it would only
	# leave stray cards in the test tree.
	Globals.show_region_alerts = false
	monitor = add_child_autofree(MONITOR_SCENE.instantiate())


func _settle() -> void:
	await get_tree().process_frame
	await get_tree().process_frame


func test_arriving_in_a_hazard_region_shows_it_without_a_fight() -> void:
	Events.start_scenario.emit()
	await _settle()
	assert_true(monitor._deployed, "up on arrival, not only once a fight starts")
	assert_false(monitor._countdown.visible, "no countdown outside a fight")
	assert_true(monitor._unread)


func test_a_fight_adds_the_countdown_and_its_end_keeps_the_monitor_up() -> void:
	Events.start_scenario.emit()
	await _settle()

	Events.hazard_armed.emit(hazard, 3)
	await _settle()
	assert_true(monitor._countdown.visible)
	assert_eq(monitor._countdown.text, "3")

	Events.hazard_armed.emit(null, 0)
	await _settle()
	assert_true(monitor._deployed, "the region's hazard stays on show after the fight")
	assert_false(monitor._countdown.visible)


func test_reading_it_survives_a_fight_starting() -> void:
	Events.start_scenario.emit()
	await _settle()
	monitor._on_clicked()
	assert_false(monitor._unread)

	Events.hazard_armed.emit(hazard, 3)
	await _settle()
	assert_false(monitor._unread, "the same hazard, just counting now")


func test_nothing_shows_in_hyperspace() -> void:
	# A rule or a re-armed hazard can be announced while the jump is still
	# playing out: the new region's engine exists before arrival.
	var modifier: BackgroundModifierResource = BackgroundModifierResource.new()
	Events.background_modifier_applied.emit(modifier)
	Events.hazard_armed.emit(hazard, 3)
	await _settle()
	assert_false(monitor._deployed)


func test_the_jump_stows_it_and_the_next_arrival_announces_afresh() -> void:
	Events.start_scenario.emit()
	await _settle()
	monitor._on_clicked()

	Events.jump.emit()
	await _settle()
	assert_false(monitor._deployed)

	Events.start_scenario.emit()
	await _settle()
	assert_true(monitor._deployed)
	assert_true(monitor._unread, "a repeat of the same hazard is still a new arrival")


func test_plain_space_stays_folded_away() -> void:
	Globals.background_manager.current_background = BackgroundResource.new()
	Events.start_scenario.emit()
	Events.background_modifier_applied.emit(null)
	await _settle()
	assert_false(monitor._deployed)


func test_a_rule_region_shows_its_rule_on_arrival() -> void:
	Globals.background_manager.current_background = BackgroundResource.new()
	var modifier: BackgroundModifierResource = BackgroundModifierResource.new()
	Events.start_scenario.emit()
	Events.background_modifier_applied.emit(modifier)
	await _settle()
	assert_true(monitor._deployed)
	assert_eq(monitor._shown, modifier)


# ── The arrival card ──────────────────────────────────────────────────────────

func _alerts() -> Array[RegionAlert]:
	var out: Array[RegionAlert] = []
	for child: Node in get_children():
		if child is RegionAlert:
			out.append(autofree(child))
	return out


func _arrive_with_rule() -> BackgroundModifierResource:
	Globals.background_manager.current_background = BackgroundResource.new()
	var modifier: BackgroundModifierResource = BackgroundModifierResource.new()
	modifier.modifier_name = "Pulsar Wash"
	modifier.description = "No ship can raise shields"
	Events.start_scenario.emit()
	Events.background_modifier_applied.emit(modifier)
	await _settle()
	return modifier


## The card unfolds out of the screen once the monitor is up; this skips the
## swing rather than waiting it out.
func _finish_swing() -> void:
	if monitor._motion_tween and monitor._motion_tween.is_valid():
		monitor._motion_tween.custom_step(5.0)
	await _settle()
	await _settle()


func test_arriving_with_alerts_on_spells_the_rule_out() -> void:
	Globals.show_region_alerts = true
	await _arrive_with_rule()
	await _finish_swing()
	var alerts: Array[RegionAlert] = _alerts()
	assert_eq(alerts.size(), 1)
	assert_eq(alerts[0].title, "PULSAR WASH")


func test_the_card_waits_for_the_monitor_to_swing_up() -> void:
	Globals.show_region_alerts = true
	await _arrive_with_rule()
	await _settle()
	assert_eq(_alerts().size(), 0, "nothing comes out of a screen still in motion")
	await _finish_swing()
	assert_eq(_alerts().size(), 1)


func test_the_card_is_a_beat_the_ships_wait_for() -> void:
	Globals.show_region_alerts = true
	await _arrive_with_rule()
	await _finish_swing()
	var intro: ArrivalIntro = ArrivalIntro.shared()
	assert_true(intro._playing, "the ships are still held")
	_alerts()[0].landed.emit()
	_alerts()[0].queue_free()
	await _settle()
	await _settle()
	assert_false(intro._playing, "the card gone, the ships may come in")


func test_alerts_off_leaves_just_the_monitor() -> void:
	await _arrive_with_rule()
	assert_eq(_alerts().size(), 0)
	assert_true(monitor._deployed)
	assert_true(monitor._unread, "the lamp still asks to be read")


func test_the_card_landing_counts_as_read() -> void:
	Globals.show_region_alerts = true
	await _arrive_with_rule()
	await _finish_swing()
	var alerts: Array[RegionAlert] = _alerts()
	assert_true(monitor._unread)
	alerts[0].landed.emit()
	assert_false(monitor._unread)


func test_a_card_for_the_last_region_landing_late_changes_nothing() -> void:
	Globals.show_region_alerts = true
	await _arrive_with_rule()
	await _finish_swing()
	var alerts: Array[RegionAlert] = _alerts()
	await _arrive_with_rule()
	await _finish_swing()
	_alerts()
	alerts[0].landed.emit()
	assert_true(monitor._unread, "the new region's rule is still unread")


# ── The headline: when, then what ────────────────────────────────────────────

func test_before_a_fight_it_says_how_far_into_one_it_hits() -> void:
	hazard.turns_until_first = 2
	var text: String = EnvironmentMonitor.hazard_when_text(hazard, false, 0)
	assert_string_contains(text, "2 turns")
	assert_string_contains(text, "fight")


func test_during_a_fight_it_counts_the_turns_left() -> void:
	assert_eq(EnvironmentMonitor.hazard_when_text(hazard, true, 3), "In 3 turns")


func test_the_last_turn_says_which_end_of_it() -> void:
	hazard.timing = BackgroundHazardResource.Timing.YOUR_TURN_ENDS
	assert_eq(EnvironmentMonitor.hazard_when_text(hazard, true, 1), "At end of turn")
	hazard.timing = BackgroundHazardResource.Timing.YOUR_TURN_STARTS
	assert_eq(EnvironmentMonitor.hazard_when_text(hazard, true, 1), "Next turn")


## Two turn ends away is the end of the next turn, not "in 2 turns", which
## would read as the turn after that.
func test_a_turn_end_hazard_two_away_says_next_turn() -> void:
	hazard.timing = BackgroundHazardResource.Timing.YOUR_TURN_ENDS
	assert_eq(EnvironmentMonitor.hazard_when_text(hazard, true, 2), "End of next turn")
	hazard.timing = BackgroundHazardResource.Timing.YOUR_TURN_STARTS
	assert_eq(EnvironmentMonitor.hazard_when_text(hazard, true, 2), "In 2 turns")


func test_the_headline_leads_with_the_countdown() -> void:
	hazard.headline = "[color=blue]shields[/color] drop, [color=red]3 dmg[/color] to all"
	var headline: String = Utils.strip_bbcode_tags(EnvironmentMonitor.hazard_headline(hazard, true, 2))
	assert_true(headline.begins_with("In 2 turns: "), headline)
	assert_string_contains(headline, "shields drop")


func test_a_hazard_without_a_headline_falls_back_to_its_name() -> void:
	var headline: String = Utils.strip_bbcode_tags(EnvironmentMonitor.hazard_headline(hazard, true, 1))
	assert_eq(headline, "Next turn: Test Flare")


func test_the_info_panel_says_how_often_it_comes_back() -> void:
	hazard.turns_between = 2
	assert_string_contains(Utils.strip_bbcode_tags(EnvironmentMonitor.hazard_repeat_text(hazard)), "every 2 turns")
	hazard.turns_between = 1
	assert_string_contains(Utils.strip_bbcode_tags(EnvironmentMonitor.hazard_repeat_text(hazard)), "every turn")


## The panel gives the countdown, the full rule and how often it comes back,
## but not the headline: beside the full rule it only says the same thing
## twice. The headline is the arrival card's alone.
func test_the_info_panel_counts_down_and_leaves_the_headline_to_the_card() -> void:
	hazard.headline = "enemy dice [color=green]re-roll[/color]"
	hazard.description = "The long version"
	hazard.turns_between = 2
	var info: InfoResource = EnvironmentMonitor.hazard_info(hazard, true, 3)
	assert_eq(Utils.strip_bbcode_tags(info.top_label_text), "In 3 turns")
	var body: String = Utils.strip_bbcode_tags(info.bottom_label_text)
	assert_string_contains(body, "The long version")
	assert_string_contains(body, "every 2 turns")
	assert_false(body.contains("re-roll"), body)
	assert_false(body.contains("In 3 turns"), "the countdown is said once, at the top")


func test_the_info_panel_shows_the_count_as_it_stands() -> void:
	Events.start_scenario.emit()
	await _settle()
	Events.hazard_armed.emit(hazard, 3)
	await _settle()
	Events.hazard_countdown_changed.emit(hazard, 2)
	var shown: Array[InfoResource] = []
	var keep: Callable = func(info: InfoResource) -> void: shown.append(info)
	Events.show_info.connect(keep)
	monitor._on_clicked()
	Events.show_info.disconnect(keep)
	assert_eq(shown.size(), 1)
	assert_eq(Utils.strip_bbcode_tags(shown[0].top_label_text), "In 2 turns")


## The card carries the headline and nothing else: the full rule waits in the
## info panel, so the card reads as fast as a rule's one line.
func test_a_hazard_card_is_its_headline() -> void:
	Globals.show_region_alerts = true
	hazard.turns_until_first = 2
	hazard.headline = "enemy dice [color=green]re-roll[/color]"
	hazard.description = "The long version"
	Events.start_scenario.emit()
	await _settle()
	await _finish_swing()
	var alerts: Array[RegionAlert] = _alerts()
	assert_eq(alerts.size(), 1)
	assert_eq(alerts[0].description, EnvironmentMonitor.hazard_headline(hazard, false, 0))
	assert_eq(alerts[0].footnote, "")
	assert_false(alerts[0].description.contains("long version"))


func test_a_rule_card_has_no_footnote() -> void:
	Globals.show_region_alerts = true
	await _arrive_with_rule()
	await _finish_swing()
	assert_eq(_alerts()[0].footnote, "")


# ── Nothing over the ships' sky ───────────────────────────────────────────────

func _arrive_and_fight() -> void:
	Events.start_scenario.emit()
	await _settle()
	await _finish_swing()
	Events.hazard_armed.emit(hazard, 3)
	await _settle()


## The headline lives on the arrival card and in the info panel; the screen
## itself keeps only its glyph and count. Ticks, hovering and the hazard going
## off slide nothing out across the sky the ships fly in.
func test_the_screen_carries_no_headline_strip() -> void:
	var before: int = monitor._face.get_child_count()
	await _arrive_and_fight()
	Events.hazard_countdown_changed.emit(hazard, 1)
	monitor._clickable.is_hovered.emit(true)
	Events.hazard_triggered.emit(hazard)
	await _settle()
	assert_eq(monitor._face.get_child_count(), before)
	assert_true(monitor._face.find_children("*", "RichTextLabel", true, false).is_empty())


# ── The first sighting waits to be closed ────────────────────────────────────

func _card_for(modifier: BackgroundModifierResource) -> RegionAlert:
	Globals.show_region_alerts = true
	Globals.background_manager.current_background = BackgroundResource.new()
	Events.start_scenario.emit()
	Events.background_modifier_applied.emit(modifier)
	await _settle()
	await _finish_swing()
	return _alerts()[0]


func _rule(rule_name: String) -> BackgroundModifierResource:
	var modifier: BackgroundModifierResource = BackgroundModifierResource.new()
	modifier.modifier_name = rule_name
	return modifier


func test_a_rule_never_read_waits_for_close() -> void:
	CollectionManager.clear()
	var card: RegionAlert = await _card_for(_rule("Pulsar Wash"))
	assert_true(card.wait_for_close)
	assert_null(card._hold_timer, "no timer to fold it before the player is done")


## A new player can read the first card as slowly as they like: the ships
## don't fly in under it, however long it stays up.
func test_a_card_waiting_for_close_holds_the_ships_until_it_is() -> void:
	CollectionManager.clear()
	var intro: ArrivalIntro = ArrivalIntro.shared()
	var backstop: float = intro.max_beat_seconds
	intro.max_beat_seconds = 0.1
	var card: RegionAlert = await _card_for(_rule("Pulsar Wash"))
	await wait_seconds(0.3)
	assert_true(intro._playing, "still held past the backstop")
	card._fold()
	await wait_seconds(RegionAlert._FOLD_SECONDS + 0.1)
	intro.max_beat_seconds = backstop
	assert_false(intro._playing, "closed: the ships may come in")
	CollectionManager.clear()


func test_a_card_that_folds_on_its_own_keeps_the_backstop() -> void:
	CollectionManager.clear()
	var modifier: BackgroundModifierResource = _rule("Pulsar Wash")
	CollectionManager.record_region(EnvironmentMonitor.region_id(modifier))
	var intro: ArrivalIntro = ArrivalIntro.shared()
	var backstop: float = intro.max_beat_seconds
	intro.max_beat_seconds = 0.1
	await _card_for(modifier)
	await wait_seconds(0.3)
	intro.max_beat_seconds = backstop
	assert_false(intro._playing, "a card on a timer can't hold the ships forever")
	CollectionManager.clear()


func test_closing_it_counts_as_read_for_good() -> void:
	CollectionManager.clear()
	var modifier: BackgroundModifierResource = _rule("Pulsar Wash")
	var card: RegionAlert = await _card_for(modifier)
	card.landed.emit()
	assert_true(CollectionManager.has_read_region(EnvironmentMonitor.region_id(modifier)))
	CollectionManager.clear()


func test_a_rule_read_before_folds_away_on_its_own() -> void:
	CollectionManager.clear()
	var modifier: BackgroundModifierResource = _rule("Pulsar Wash")
	CollectionManager.record_region(EnvironmentMonitor.region_id(modifier))
	var card: RegionAlert = await _card_for(modifier)
	assert_false(card.wait_for_close)
	assert_not_null(card._hold_timer)
	CollectionManager.clear()


func test_bots_and_the_lab_never_wait() -> void:
	CollectionManager.clear()
	SaveManager.save_path = "user://test_somewhere_else.json"
	var card: RegionAlert = await _card_for(_rule("Pulsar Wash"))
	SaveManager.save_path = SaveManager.SAVE_PATH
	assert_false(card.wait_for_close)


func test_every_card_has_a_close_button_that_folds_it() -> void:
	CollectionManager.clear()
	var card: RegionAlert = await _card_for(_rule("Pulsar Wash"))
	assert_not_null(card._close_button)
	card._close_button.pressed_within_window.emit()
	assert_true(card._folding)


func test_rules_and_hazards_are_remembered_apart() -> void:
	var rule: BackgroundModifierResource = load(
		"res://Source/Resources/BackgroundResources/BackgroundModifiers/dead_systems.tres"
	)
	assert_eq(EnvironmentMonitor.region_id(rule), "rule:dead_systems")
	assert_eq(EnvironmentMonitor.region_id(hazard), "hazard:Test Flare", "an unsaved one goes by name")
