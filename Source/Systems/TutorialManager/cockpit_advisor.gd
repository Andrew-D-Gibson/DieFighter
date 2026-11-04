class_name CockpitAdvisor
extends Node2D
## The tutorial's character stays with the ship. Briefings read live dialogue
## and authored reaction triggers, so they cannot promise an obsolete branch.

const _FACE: Texture2D = preload("res://Assets/Textures/TutorialManager/computer_head-Sheet.png")
const _BEZEL: Texture2D = preload("res://Assets/Textures/TutorialManager/computer_bezel.png")
const _HOLOGRAM: Shader = preload("res://Assets/Shaders/hologram_figure.gdshader")
const _BIG_HIT: int = 6
const _REACTIONS: Dictionary[int, String] = {
	ScenarioManager.ScenarioEvent.PLAYER_ATTACKED_PIRATE: "ADVISOR_REACT_ATTACK_PIRATE",
	ScenarioManager.ScenarioEvent.PLAYER_ATTACKED_CIVILIAN: "ADVISOR_REACT_ATTACK_CIVILIAN",
	ScenarioManager.ScenarioEvent.PLAYER_LEFT_SCENARIO: "ADVISOR_REACT_LEAVE",
	ScenarioManager.ScenarioEvent.COMBAT_ENDED: "ADVISOR_REACT_COMBAT_END",
	ScenarioManager.ScenarioEvent.PIRATES_DEFEATED: "ADVISOR_REACT_PIRATES_DEFEATED",
	ScenarioManager.ScenarioEvent.CIVILIANS_DEFEATED: "ADVISOR_REACT_CIVILIANS_DEFEATED",
	ScenarioManager.ScenarioEvent.BOSS_DEFEATED: "ADVISOR_REACT_BOSS_DEFEATED",
	ScenarioManager.ScenarioEvent.PLAYER_TOOK_REWARD_TILE: "ADVISOR_REACT_SALVAGE",
	ScenarioManager.ScenarioEvent.PLAYER_TOOK_REWARD_MONEY: "ADVISOR_REACT_CREDITS",
	ScenarioManager.ScenarioEvent.PIRATE_ATTACKED_CIVILIAN: "ADVISOR_REACT_RAID",
	ScenarioManager.ScenarioEvent.PLAYER_COULDNT_PAY: "ADVISOR_REACT_CANNOT_PAY",
}
const _EVENT_QUIPS: Dictionary[String, String] = {
	"EVENT_deniable_assets": "ADVISOR_QUIP_DENIABLE",
	"EVENT_pickpocket": "ADVISOR_QUIP_PICKPOCKET",
	"EVENT_tollkeeper": "ADVISOR_QUIP_TOLL",
	"EVENT_pirate_attacking_civilian": "ADVISOR_QUIP_MAYDAY",
	"EVENT_mayday": "ADVISOR_QUIP_MAYDAY",
	"EVENT_wreck_salvage": "ADVISOR_QUIP_SALVAGE",
	"EVENT_sleeping_drone": "ADVISOR_QUIP_DRONE",
	"EVENT_pact": "ADVISOR_QUIP_PACT",
}

var _head: Sprite2D
var _panel: PanelContainer
var _briefing: RichTextLabel
var _title: Label
var _close_button: Button
var _portrait_button: Button
var _quip: RichTextLabel
var _quip_key: String = "ADVISOR_EVENT_QUIP"
var _unread: bool = false
var _age: float = 0.0
var _quip_until: float = 0.0
var _expression: int = 0
var _expression_until: float = 0.0
var _health: Health
var _last_hull: int = 0
var _last_shields: int = 0
var _hull_loss: int = 0
var _shield_loss: int = 0


func _ready() -> void:
	top_level = true
	global_position = Vector2(18, 70)
	z_as_relative = false
	z_index = 10
	_build()
	Events.start_scenario.connect(_on_arrival)
	Events.ship_scenario_state_changed.connect(_on_ship_changed)
	Events.player_health_hit.connect(_on_hull_hit)
	Events.player_shields_hit.connect(_on_shield_hit)
	Events.combat_finished.connect(_celebrate)
	Events.victory.connect(_celebrate)
	Events.tutorial_finished.connect(show)
	Events.locale_changed.connect(_on_locale_changed)
	_on_arrival()


func _build() -> void:
	var bezel: Sprite2D = Sprite2D.new()
	bezel.texture = _BEZEL
	add_child(bezel)
	_head = Sprite2D.new()
	_head.texture = _FACE
	_head.hframes = 5
	var hologram_material: ShaderMaterial = ShaderMaterial.new()
	hologram_material.shader = _HOLOGRAM
	_head.material = hologram_material
	add_child(_head)
	_portrait_button = Button.new()
	_portrait_button.position = Vector2(-12, -12)
	_portrait_button.size = Vector2(24, 24)
	for style: StringName in [&"normal", &"hover", &"pressed", &"focus"]:
		_portrait_button.add_theme_stylebox_override(style, StyleBoxEmpty.new())
	_portrait_button.tooltip_text = tr("ADVISOR_TITLE")
	_portrait_button.pressed.connect(_toggle_briefing)
	add_child(_portrait_button)
	_quip = RichTextLabel.new()
	_quip.position = Vector2(14, -12)
	_quip.size = Vector2(96, 26)
	_quip.bbcode_enabled = true
	_quip.fit_content = true
	_quip.scroll_active = false
	_quip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_quip)
	_panel = PanelContainer.new()
	# Ship dialogue inherits the enemy manager's foreground depth.
	_panel.z_as_relative = false
	_panel.z_index = 20
	_panel.position = Vector2(24, -62)
	var backing: StyleBoxFlat = StyleBoxFlat.new()
	backing.bg_color = Color("0f0c2e")
	backing.border_color = Color("463c91")
	backing.set_content_margin_all(4)
	backing.border_width_left = 1
	backing.border_width_right = 1
	backing.border_width_top = 1
	backing.border_width_bottom = 1
	backing.anti_aliasing = false
	_panel.add_theme_stylebox_override("panel", backing)
	add_child(_panel)
	var column: VBoxContainer = VBoxContainer.new()
	_panel.add_child(column)
	_title = Label.new()
	_title.text = tr("ADVISOR_TITLE")
	column.add_child(_title)
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(210, 84)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(scroll)
	_briefing = RichTextLabel.new()
	_briefing.custom_minimum_size.x = 202
	_briefing.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_briefing.bbcode_enabled = true
	_briefing.fit_content = true
	_briefing.scroll_active = false
	scroll.add_child(_briefing)
	_close_button = Button.new()
	_close_button.text = tr("REGION_ALERT_CLOSE")
	_close_button.pressed.connect(_close_briefing)
	column.add_child(_close_button)
	_panel.hide()


func _process(delta: float) -> void:
	_age += delta
	_head.position.y = sin(_age * TAU / 1.6)
	_head.frame = _expression if _age < _expression_until else (int(_age * 5.0) % 2 if _panel.visible else 0)
	_quip.visible = _unread and _age < _quip_until and not _panel.visible
	queue_redraw()


func _draw() -> void:
	if _unread:
		var color: Color = Globals.yellow
		color.a = 0.55 + sin(_age * 4.0) * 0.25
		draw_rect(Rect2(-13, -13, 26, 26), color, false, 1.0)


func _on_arrival() -> void:
	_bind_health()
	_close_briefing()
	if _is_event():
		var id: String = Globals.scenario_manager.current_scenario.resource_path.get_file().get_basename()
		_cue(_EVENT_QUIPS.get(id, "ADVISOR_EVENT_QUIP"))
	else:
		_unread = false


func _is_event() -> bool:
	return is_instance_valid(Globals.scenario_manager) and Globals.scenario_manager.current_scenario != null \
		and Globals.scenario_manager.current_scenario.resource_path.get_file().begins_with("EVENT_")


func _on_ship_changed(_ship: Enemy) -> void:
	if _is_event():
		_cue("ADVISOR_STATE_QUIP")
		if _panel.visible:
			_refresh_briefing()
			_unread = false


func _cue(key: String) -> void:
	_quip_key = key
	_unread = true
	_quip_until = _age + 7.0
	_quip.text = Utils.format_text(tr(key))


func _toggle_briefing() -> void:
	if _panel.visible:
		_close_briefing()
	else:
		_unread = false
		_refresh_briefing()
		_panel.show()


func _close_briefing() -> void:
	if is_instance_valid(_panel):
		_panel.hide()


func _refresh_briefing() -> void:
	var lines: Array[String] = [tr("ADVISOR_HELP")]
	if _is_event():
		lines.append(tr("ADVISOR_CONTEXT"))
	if is_instance_valid(Globals.enemy_manager):
		for ship: Enemy in Globals.enemy_manager.enemies:
			if not is_instance_valid(ship) or ship.scenario_state == null:
				continue
			var dialogue: String = ship.scenario_state.display_dialogue()
			if not dialogue.is_empty():
				lines.append("[color=yellow]%s[/color]\n%s" % [ship.enemy_resource.display_name(), dialogue])
			var reactions: Array[String] = []
			for trigger: int in ship.scenario_state.transitions:
				if _REACTIONS.has(trigger):
					reactions.append(tr(_REACTIONS[trigger]))
			if not reactions.is_empty():
				lines.append(tr("ADVISOR_REACTS").format({"actions": ", ".join(reactions)}))
	_briefing.text = Utils.format_text("\n\n".join(lines))


func _bind_health() -> void:
	var health: Health = Globals.player.health if is_instance_valid(Globals.player) else null
	if health == _health:
		return
	if is_instance_valid(_health):
		_health.health_set.disconnect(_on_hull_set)
		_health.shields_set.disconnect(_on_shields_set)
	_health = health
	if is_instance_valid(_health):
		_last_hull = _health.health
		_last_shields = _health.shields
		_health.health_set.connect(_on_hull_set)
		_health.shields_set.connect(_on_shields_set)


func _on_hull_set() -> void:
	_hull_loss = maxi(0, _last_hull - _health.health)
	_last_hull = _health.health


func _on_shields_set() -> void:
	# Health clamps through the setter a second time; keep the actual hit.
	if _health.shields == _last_shields:
		return
	_shield_loss = maxi(0, _last_shields - _health.shields)
	_last_shields = _health.shields


func _on_hull_hit() -> void:
	_react(3 if _hull_loss >= _BIG_HIT else 2, 1.2)


func _on_shield_hit() -> void:
	_react(3 if _shield_loss >= _BIG_HIT else 2, 1.2)


func _celebrate() -> void:
	_react(4, 2.0)


func _react(frame: int, seconds: float) -> void:
	_expression = frame
	_expression_until = _age + seconds
	_head.frame = frame
	Juice.bump(_head, 0.15, 0.3)


func _on_locale_changed(_locale: String) -> void:
	_title.text = tr("ADVISOR_TITLE")
	_close_button.text = tr("REGION_ALERT_CLOSE")
	_portrait_button.tooltip_text = tr("ADVISOR_TITLE")
	_quip.text = Utils.format_text(tr(_quip_key))
	if _panel.visible:
		_refresh_briefing()


func _unhandled_input(event: InputEvent) -> void:
	if is_visible_in_tree() and _panel.visible and (event.is_action_pressed(&"PauseMenu") \
		or event.is_action_pressed(&"cursor_back") or event.is_action_pressed(&"ui_cancel")):
		_close_briefing()
		get_viewport().set_input_as_handled()
