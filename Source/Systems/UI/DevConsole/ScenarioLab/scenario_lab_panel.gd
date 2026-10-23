class_name ScenarioLabPanel
extends Control
## The Scenario Lab in the game: a navigator for stepping through scenarios
## from a clean start, and a branch inspector for the one being played.
##
## The inspector lists each ship's scenario state, its line, and every
## transition out of it. Firing a transition's event broadcasts it the way the
## game would (every ship hears it); a weighted transition's outcomes can also
## be forced one at a time on a single ship, so a branch that depends on a roll
## doesn't have to be rerolled until it comes up.
##
## Below the ships, a checklist of every state the scenario can reach, ticked
## once seen in a lab run. Clicking one puts its ship straight into it, for
## branches gated on something a fresh start lacks (a toll needs credits the
## starter kit doesn't have: add_money, then replay the demand).
##
## Opens by itself during a lab run; F1 toggles it in any run. Dev builds only.

const _TOGGLE_KEY: Key = KEY_F1
## Sits in the open sky above the hull gauge, clear of the cockpit.
const _PANEL_RECT: Rect2 = Rect2(16, 16, 500, 620)

var _panel: PanelContainer
var _show_button: Button
var _picker: ScenarioLabPicker

var _position_label: Label
var _title_label: Label
var _seed_label: Label
var _status_label: Label
var _ships_box: VBoxContainer
var _states_box: VBoxContainer
var _refresh_queued: bool = false


func _ready() -> void:
	if not DevConsole.is_available():
		queue_free()
		return
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	_build_panel()
	_build_show_button()
	_picker = ScenarioLabPicker.new()
	_picker.name = "Picker"
	_picker.visible = false
	add_child(_picker)

	_set_collapsed(false)
	visible = ScenarioLab.active

	Events.load_scenario.connect(_queue_refresh.unbind(1))
	Events.start_scenario.connect(_queue_refresh)
	Events.ship_scenario_state_changed.connect(_queue_refresh.unbind(1))
	Events.enemy_left.connect(_queue_refresh.unbind(2))
	Events.start_combat.connect(_queue_refresh)
	Events.combat_finished.connect(_queue_refresh)
	ScenarioLab.coverage_changed.connect(_queue_refresh)
	# The dev console and its tile palette own the screen's edges while open.
	Events.dev_console_toggled.connect(func(is_open: bool) -> void:
		_panel.modulate.a = 0.25 if is_open else 1.0
	)
	_queue_refresh()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == _TOGGLE_KEY:
		visible = not visible
		if visible:
			_set_collapsed(false)
			_queue_refresh()
		get_viewport().set_input_as_handled()


# ── Layout ───────────────────────────────────────────────────────────────────

func _build_panel() -> void:
	_panel = ScenarioLabUI.panel()
	_panel.name = "Panel"
	_panel.position = _PANEL_RECT.position
	_panel.size = _PANEL_RECT.size
	add_child(_panel)

	var content: VBoxContainer = ScenarioLabUI.column(6)
	_panel.add_child(content)

	var header: HBoxContainer = ScenarioLabUI.row()
	var heading: Label = ScenarioLabUI.label("SCENARIO LAB", ScenarioLabUI.HEADING_SIZE)
	heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(heading)
	header.add_child(ScenarioLabUI.button("LIST", _picker_open))
	header.add_child(ScenarioLabUI.button("HIDE", _set_collapsed.bind(true)))
	content.add_child(header)

	var nav: HBoxContainer = ScenarioLabUI.row()
	nav.add_child(ScenarioLabUI.button(" < ", _step.bind(-1), ScenarioLabUI.TITLE_SIZE))
	var titles: VBoxContainer = ScenarioLabUI.column(0)
	titles.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_position_label = ScenarioLabUI.label("", ScenarioLabUI.BODY_SIZE, ScenarioLabUI.MUTED_COLOR)
	_position_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	titles.add_child(_position_label)
	_title_label = ScenarioLabUI.label("", ScenarioLabUI.HEADING_SIZE)
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_label.clip_text = true
	titles.add_child(_title_label)
	nav.add_child(titles)
	nav.add_child(ScenarioLabUI.button(" > ", _step.bind(1), ScenarioLabUI.TITLE_SIZE))
	content.add_child(nav)

	var run_row: HBoxContainer = ScenarioLabUI.row()
	run_row.add_child(ScenarioLabUI.button("RESTART", _restart.bind(false)))
	run_row.add_child(ScenarioLabUI.button("NEW SEED", _restart.bind(true)))
	_seed_label = ScenarioLabUI.label("", ScenarioLabUI.BODY_SIZE, ScenarioLabUI.MUTED_COLOR)
	_seed_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_seed_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	run_row.add_child(_seed_label)
	content.add_child(run_row)

	_status_label = ScenarioLabUI.wrapped_label("", ScenarioLabUI.BODY_SIZE, ScenarioLabUI.MUTED_COLOR)
	content.add_child(_status_label)
	content.add_child(HSeparator.new())

	var scroll: ScrollContainer = ScenarioLabUI.vertical_scroll()
	content.add_child(scroll)
	var body: VBoxContainer = ScenarioLabUI.column(10)
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(body)
	_ships_box = ScenarioLabUI.column(8)
	body.add_child(_ships_box)
	_states_box = ScenarioLabUI.column(2)
	body.add_child(_states_box)


func _build_show_button() -> void:
	_show_button = ScenarioLabUI.button("LAB", _set_collapsed.bind(false), ScenarioLabUI.HEADING_SIZE)
	_show_button.name = "ShowLab"
	_show_button.position = _PANEL_RECT.position
	add_child(_show_button)


func _set_collapsed(collapsed: bool) -> void:
	_panel.visible = not collapsed
	_show_button.visible = collapsed


# ── Navigation ───────────────────────────────────────────────────────────────

func _step(direction: int) -> void:
	ScenarioLab.launch(ScenarioLab.index + direction)


func _restart(reroll_seed: bool) -> void:
	ScenarioLab.launch(ScenarioLab.index, reroll_seed)


func _picker_open() -> void:
	_picker.show()


# ── Inspector ────────────────────────────────────────────────────────────────

## Coalesces the bursts of signals a jump or a death sends into one rebuild.
func _queue_refresh() -> void:
	if _refresh_queued:
		return
	_refresh_queued = true
	_refresh.call_deferred()


func _refresh() -> void:
	_refresh_queued = false
	if not is_inside_tree():
		return
	_refresh_navigator()
	_refresh_ships()
	_refresh_states()


func _refresh_navigator() -> void:
	var lab_id: String = ScenarioLab.current_id()
	_position_label.text = "%s  %d / %d" % [
		ScenarioLab.category(lab_id), ScenarioLab.index + 1, ScenarioLab.scenario_ids.size()
	]
	_title_label.text = ScenarioLab.display_name(lab_id)
	_title_label.tooltip_text = lab_id
	_seed_label.text = "seed %d" % ScenarioLab.run_seed if ScenarioLab.run_seed != 0 else ""

	var lines: PackedStringArray = []
	var live_id: String = ScenarioLab.live_id()
	if not ScenarioLab.active:
		lines.append("Not a lab run: arrows, RESTART and LIST start one.")
	elif not live_id.is_empty() and live_id != lab_id:
		lines.append("Now in %s %s." % [ScenarioLab.category(live_id), ScenarioLab.display_name(live_id)])
	if is_instance_valid(Globals.state_manager):
		lines.append(_combat_text())
	if not live_id.is_empty():
		lines.append_array(_scenario_facts(ScenarioLab.scenario_resource(live_id)))
	_status_label.text = "\n".join(lines)


func _combat_text() -> String:
	var text: String = GameStateManager.GameState.find_key(Globals.state_manager.state).replace("_", " ")
	if Globals.state_manager.is_scenario_cleared():
		text += " (cleared)"
	return text


## The parts of a scenario that aren't ships, so they can be checked off too.
func _scenario_facts(scenario: ScenarioResource) -> PackedStringArray:
	var facts: PackedStringArray = []
	if not scenario.boss_title.is_empty():
		facts.append("Boss: %s" % scenario.boss_title)
	if scenario.starting_reward:
		facts.append("Salvage floating on arrival")
	if not scenario.rewards.is_empty():
		var factions: PackedStringArray = []
		for faction: ScenarioManager.Faction in scenario.rewards:
			factions.append(ScenarioManager.Faction.find_key(faction))
		facts.append("Bounty for beating: %s" % ", ".join(factions))
	if scenario.hull:
		facts.append("Ships mounted on a hull")
	return facts


func _refresh_ships() -> void:
	ScenarioLabUI.clear_children(_ships_box)
	if not is_instance_valid(Globals.enemy_manager):
		return
	var ships: Array[Enemy] = Globals.enemy_manager.get_alive_enemies()
	_ships_box.add_child(ScenarioLabUI.label("SHIPS (%d)" % ships.size(), ScenarioLabUI.HEADING_SIZE))
	for ship: Enemy in ships:
		if ship.scenario_state:
			_ships_box.add_child(_build_ship_card(ship))


func _build_ship_card(ship: Enemy) -> Control:
	var card: PanelContainer = ScenarioLabUI.panel(ScenarioLabUI.ENTRY_COLOR, 8.0)
	var box: VBoxContainer = ScenarioLabUI.column(2)
	card.add_child(box)

	var state: ScenarioShipState = ship.scenario_state
	var ship_name: String = ship.enemy_resource.enemy_name if ship.enemy_resource else String(ship.name)
	box.add_child(ScenarioLabUI.wrapped_label("%s  [%s, %s]" % [
		ship_name,
		ScenarioManager.Faction.find_key(state.faction),
		Enemy.Attitude.find_key(state.attitude),
	]))
	box.add_child(ScenarioLabUI.label("> " + ScenarioGraph.label(state), ScenarioLabUI.BODY_SIZE, ScenarioLabUI.CURRENT_COLOR))
	if not state.dialogue.is_empty():
		box.add_child(ScenarioLabUI.wrapped_label('"%s"' % state.dialogue.replace("\n", " "), ScenarioLabUI.BODY_SIZE, ScenarioLabUI.MUTED_COLOR))

	if state.transitions.is_empty():
		box.add_child(ScenarioLabUI.label("No way out: an end state.", ScenarioLabUI.BODY_SIZE, ScenarioLabUI.MUTED_COLOR))
	for event: ScenarioManager.ScenarioEvent in state.transitions:
		box.add_child(_build_transition(ship, event, state.transitions[event]))
	return card


func _build_transition(ship: Enemy, event: ScenarioManager.ScenarioEvent, next: ScenarioShipStateBase) -> Control:
	var box: VBoxContainer = ScenarioLabUI.column(2)
	var line: HBoxContainer = ScenarioLabUI.row(6)
	var fire: Button = ScenarioLabUI.button(ScenarioGraph.event_name(event), _fire.bind(event))
	fire.tooltip_text = "Emit this scenario event: every ship reacts, as in play."
	line.add_child(fire)
	box.add_child(line)

	if next is ScenarioShipStateProbabilityTransition:
		line.add_child(ScenarioLabUI.label("-> rolls:", ScenarioLabUI.BODY_SIZE, ScenarioLabUI.MUTED_COLOR))
		var weights: Dictionary[ScenarioShipState, float] = (next as ScenarioShipStateProbabilityTransition).weighted_probabilities
		var weight_sum: float = 0.0
		for weight: float in weights.values():
			weight_sum += weight
		for outcome: ScenarioShipState in weights:
			var force_row: HBoxContainer = ScenarioLabUI.row(6)
			force_row.add_child(ScenarioLabUI.label("    "))
			var force: Button = ScenarioLabUI.button(
				"FORCE %d%% %s" % [roundi(100.0 * weights[outcome] / weight_sum), ScenarioGraph.label(outcome)],
				_force.bind(ship, outcome)
			)
			force.tooltip_text = "Put only this ship in that state, skipping the roll."
			force_row.add_child(force)
			box.add_child(force_row)
	else:
		line.add_child(ScenarioLabUI.wrapped_label("-> " + ScenarioGraph.label(next), ScenarioLabUI.BODY_SIZE, ScenarioLabUI.MUTED_COLOR))
	return box


func _refresh_states() -> void:
	ScenarioLabUI.clear_children(_states_box)
	var id: String = ScenarioLab.live_id()
	if id.is_empty():
		return
	var seen: Vector2i = ScenarioLab.coverage(id)
	_states_box.add_child(ScenarioLabUI.label("SEEN %d / %d" % [seen.x, seen.y], ScenarioLabUI.HEADING_SIZE))
	var graph: ScenarioGraph = ScenarioLab.graph(id)
	if not graph.states.is_empty():
		_states_box.add_child(ScenarioLabUI.wrapped_label("Click a state to put its ship in it.", ScenarioLabUI.BODY_SIZE, ScenarioLabUI.MUTED_COLOR))
	if not ScenarioLab.active:
		_states_box.add_child(ScenarioLabUI.wrapped_label("Only lab runs count toward these.", ScenarioLabUI.BODY_SIZE, ScenarioLabUI.MUTED_COLOR))
	for state: ScenarioShipState in graph.states:
		var was_seen: bool = ScenarioLab.has_seen(id, state)
		var ship: Enemy = _ship_for_state(graph, state)
		var entry: Button = ScenarioLabUI.button(
			"[%s] %s" % ["x" if was_seen else " ", ScenarioGraph.label(state)],
			_force.bind(ship, state)
		)
		entry.flat = true
		entry.alignment = HORIZONTAL_ALIGNMENT_LEFT
		entry.disabled = ship == null
		entry.add_theme_color_override("font_color", ScenarioLabUI.SEEN_COLOR if was_seen else ScenarioLabUI.UNSEEN_COLOR)
		entry.add_theme_color_override("font_disabled_color", ScenarioLabUI.MUTED_COLOR)
		entry.tooltip_text = "%s\n\nClick to put %s in this state." % [
			state.dialogue, ship.enemy_resource.enemy_name if ship else "its ship (gone)"
		]
		_states_box.add_child(entry)
	if graph.has_fight:
		var ended: bool = ScenarioLab.has_ended_fight(id)
		_states_box.add_child(ScenarioLabUI.wrapped_label(
			"[%s] fight ended" % ("x" if ended else " "),
			ScenarioLabUI.BODY_SIZE,
			ScenarioLabUI.SEEN_COLOR if ended else ScenarioLabUI.UNSEEN_COLOR
		))


## A ship still here whose branch reaches [param state], preferring one
## already in it. Null once they've all gone.
func _ship_for_state(graph: ScenarioGraph, state: ScenarioShipState) -> Enemy:
	var candidates: Array[Enemy] = []
	if not is_instance_valid(Globals.enemy_manager):
		return null
	for ship: Enemy in Globals.enemy_manager.get_alive_enemies():
		if ship.spawn_index in graph.owners.get(state, []):
			if ship.scenario_state == state:
				return ship
			candidates.append(ship)
	return candidates[0] if not candidates.is_empty() else null


func _fire(event: ScenarioManager.ScenarioEvent) -> void:
	Events.scenario_event.emit(event)


func _force(ship: Enemy, state: ScenarioShipState) -> void:
	if is_instance_valid(ship):
		ship.force_scenario_state(state)
