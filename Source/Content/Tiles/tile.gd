class_name Tile
extends Node2D

@export var tile_resource: TileResource:
	set(new_resource):
		tile_resource = new_resource
		if sprite_frames:
			_set_up_resource()
		
var _saturation_tween: Tween
@export var uses_remaining: int = -1:
	set(new_value):
		uses_remaining = new_value
		
		var outer_radius: float
		var strength: float
		if uses_remaining == 0:
			outer_radius = 0.0
			strength = 1.0
		else:
			outer_radius = 10.0
			strength = 0.0
			
		if _saturation_tween:
			_saturation_tween.kill()
			
		var tween_time: float = 0.75
		_saturation_tween = create_tween()
		_saturation_tween.tween_property(
			sprite_frames.material, 
			'shader_parameter/strength',
			strength,
			0.1
		)
		_saturation_tween.tween_property(
			sprite_frames.material, 
			'shader_parameter/outer_radius',
			outer_radius,
			tween_time
		).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		
				
		if uses_remaining == -1:
			sprite_frames.frame = 0
		else:
			sprite_frames.frame = uses_remaining

		
@export_category('Components')
@export var draggable: Draggable
@export var clickable: Clickable
@export var shakeable: Shakeable
@export var sprite_frames: AnimatedSprite2D


signal tile_activation_complete()


func _ready() -> void:
	assert(tile_resource)
	_set_up_resource()
	
	if clickable:
		clickable.clicked.connect(func(): 
			Events.show_info.emit(_get_tile_info())
		)
	if draggable:
		draggable.reached_new_home.connect(func():
			shakeable.small_shake()
			Events.tile_dropped.emit()
		)
	Events.enemy_turn_over.connect(reset_uses_remaining)
	Events.start_scenario.connect(reset_uses_remaining)
	

func _set_up_resource() -> void:
	sprite_frames.sprite_frames = tile_resource.textures
	uses_remaining = tile_resource.uses_per_turn


func _get_tile_info() -> InfoResource:
	var info = InfoResource.new()
	info.title_label_text = tile_resource.tile_name
	info.top_label_text = tile_resource.activation_description
	info.texture = tile_resource.textures.get_frame_texture('default', 0)
	info.bottom_label_text = tile_resource.description
	
	return info


func try_to_activate(activator_die: Dice) -> void:
	if not (uses_remaining == -1 or uses_remaining > 0):
		return
		
	for check in tile_resource.activation_checks:
		if not check.criteria_satisfied(activator_die):
			return
	
	# We're cleared hot to activate!
	if uses_remaining != -1:
		uses_remaining -= 1
		
	activator_die.draggable.state = Draggable.DragState.MOVING_WITH_CODE
	_activate(activator_die)
		

func _activate(activator_die: Dice = null) -> void:
	# Set up the effects variables for chaining effects
	var effect_variables = EffectVariables.new()
	effect_variables.actor = Globals.player
	effect_variables.effect_source = self
	effect_variables.activator_die = activator_die
		
	for effect in tile_resource.effect_chain:
		# Play the effect, recording the change in variables
		await effect.play(effect_variables)
		
	tile_activation_complete.emit()


func reset_uses_remaining() -> void:
	uses_remaining = tile_resource.uses_per_turn
