extends Node2D

@export var progress_bar: TextureProgressBar
@export var fill_head: Sprite2D
@export var charged_indicator: Sprite2D
@export var display_text: RichTextLabel


func _ready() -> void:
	Events.engine_charge_changed.connect(_update_ui)
	Events.start_scenario.connect(_update_ui)
	Events.load_scenario.connect(_check_for_combat_scenario)
	Events.combat_finished.connect(func():
		Globals.player.engine_charge = Globals.player.max_engine_charge	
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
	var charge_proportion: float = Globals.player.engine_charge / float(Globals.player.max_engine_charge)
	
	if charge_proportion != progress_bar.value:
		var tween_time = 0.25
		var bar_tween = get_tree().create_tween()
		bar_tween.tween_property(
			progress_bar, 
			'value', 
			charge_proportion, 
			tween_time
		)\
		.from_current()\
		.set_trans(Tween.TRANS_QUAD)
		
		
		# The bar is 32 long and the head bar's maximum y is 2
		var desired_head_ypos: float = 2 - (charge_proportion * 32) 
			
		var head_tween = get_tree().create_tween()
		head_tween.tween_property(
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
	else:
		fill_head.visible = true
		charged_indicator.visible = false
		
	display_text.text = str(Globals.player.engine_charge) + '/' + str(Globals.player.max_engine_charge)
