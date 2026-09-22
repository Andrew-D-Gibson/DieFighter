extends Node2D

@export var progress_bar: TextureProgressBar
@export var fill_head: Sprite2D
@export var charged_indicator: Sprite2D
@export var display_text: RichTextLabel

## Applied to the charged indicator while the drive is past the gate.
const _REDLINE_TINT: Color = Color(1.0, 0.45, 0.45)

## The fill level the bar is currently animating towards. Tracked separately
## from progress_bar.value because several charge changes can land in the same
## frame before any tween has stepped, and the bar's value would still read as
## the pre-tween one.
var _target_proportion: float = -1.0
var _bar_tween: Tween
var _head_tween: Tween


func _ready() -> void:
	# The charger opens empty: a run starts mid-ambush, with the engine cold.
	progress_bar.value = 0
	fill_head.position = Vector2(60, 2)
	fill_head.visible = true
	charged_indicator.visible = false

	Events.engine_charge_changed.connect(_update_ui)
	Events.start_scenario.connect(_update_ui)
	Events.load_scenario.connect(_check_for_combat_scenario)
	Events.start_combat.connect(func():
		Globals.player.engine_charge = 0
		_update_ui()
	)
	Events.combat_finished.connect(func():
		Globals.player.engine_charge = Globals.player.max_engine_charge
		_update_ui()	
	)
	Events.die_added.connect(func() -> void:
		if Globals.state_manager.state == GameStateManager.GameState.OUT_OF_COMBAT:
			Globals.player.engine_charge = Globals.player.max_engine_charge
		_update_ui()
	)


func _check_for_combat_scenario(scenario: ScenarioResource) -> void:
	var in_combat: bool = false
	for ship in scenario.starting_enemies:
		if ship.starting_state.attitude == Enemy.Attitude.AGGRESSIVE:
			in_combat = true
			break
		
	if in_combat:
		Globals.player.engine_charge = 0
	else:
		Globals.player.engine_charge = Globals.player.max_engine_charge
			
	

func _update_ui() -> void:
	if not Globals.player:
		return
		
	# The bar tops out at the jump gate. Charge above it is redline, shown by
	# recolouring the charged indicator and spelling the surplus out in the
	# readout, rather than by overflowing a bar that has nowhere to go.
	var charge_proportion: float = minf(
		1.0, Globals.player.engine_charge / float(Globals.player.max_engine_charge)
	)
	if charge_proportion != _target_proportion:
		_target_proportion = charge_proportion
		var tween_time: float = 0.25
		
		# Any tween still in flight is chasing a stale charge value, so it has
		# to die before a new one starts or the two fight over the bar.
		if _bar_tween and _bar_tween.is_valid():
			_bar_tween.kill()
		if _head_tween and _head_tween.is_valid():
			_head_tween.kill()
		
		_bar_tween = get_tree().create_tween()
		_bar_tween.tween_property(
			progress_bar, 
			'value', 
			charge_proportion, 
			tween_time
		)\
		.from_current()\
		.set_trans(Tween.TRANS_QUAD)
		
		# The bar is 32 long and the head bar's maximum y is 2
		var desired_head_ypos: float = 2 - (charge_proportion * 32)
		_head_tween = get_tree().create_tween()
		_head_tween.tween_property(
			fill_head, 
			'position', 
			Vector2(60, desired_head_ypos), 
			tween_time
		)\
		.from_current()\
		.set_trans(Tween.TRANS_QUAD)
		
	if charge_proportion >= 1:
		fill_head.visible = false
		charged_indicator.visible = true
		# Redlining is dangerous, so the "you may leave" light stops reading
		# as reassurance and goes hot.
		charged_indicator.modulate = (
			_REDLINE_TINT if Globals.player.is_overcharged() else Color.WHITE
		)
	else:
		fill_head.visible = true
		charged_indicator.visible = false
		charged_indicator.modulate = Color.WHITE
		
	# The readout is only about five characters wide, so the redline can't just
	# be appended to "10/10" — it clips. Past the gate the denominator carries
	# no information (it's always full), so the surplus takes its place: "10+3".
	if Globals.player.is_overcharged():
		display_text.text = str(Globals.player.max_engine_charge) \
			+ '+' + str(Globals.player.overcharge_amount())
	else:
		display_text.text = str(Globals.player.engine_charge) \
			+ '/' + str(Globals.player.max_engine_charge)
