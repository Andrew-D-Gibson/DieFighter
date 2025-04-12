class_name Tile
extends Node2D

@export var tile_resource: TileResource:
	set(new_resource):
		tile_resource = new_resource
		$Sprite2D.texture = tile_resource.base_texture
		
@export_category('Components')
@export var draggable: Draggable
@export var clickable: Clickable
@export var shakeable: Shakeable

signal tile_activation_complete()


func _ready() -> void:
	assert(tile_resource)
	$Sprite2D.texture = tile_resource.base_texture
	
	clickable.clicked.connect(func(): 
		Events.show_info.emit(_get_tile_info())
	)
	draggable.reached_new_home.connect(func():
		shakeable.small_shake()
		Events.tile_dropped.emit()
	)
	

func _get_tile_info() -> InfoResource:
	var info = InfoResource.new()
	info.title_label_text = tile_resource.tile_name
	info.top_label_text = tile_resource.activation_description
	info.texture = $Sprite2D.texture
	info.bottom_label_text = tile_resource.description
	
	return info


func try_to_activate(activator_die: Dice) -> void:
	for check in tile_resource.activation_checks:
		if not check.criteria_satisfied(activator_die):
			return
			
	activator_die.draggable.state = Draggable.DragState.MOVING_WITH_CODE
	_activate(activator_die)
		

func _activate(activator_die: Dice = null) -> void:
	# Set up the effects variables for chaining effects
	var effect_variables = EffectVariables.new()
	effect_variables.source = Globals.player
	effect_variables.activator_die = activator_die
		
	for effect_resource in tile_resource.effect_chain:
		# Add the effect node to the scene
		var effect = effect_resource.effect_scene.instantiate()
		effect.amount = effect_resource.amount
		add_child(effect)
		
		# Play the effect, recording the change in variables
		await effect.play(effect_variables)
		
		# Remove the effect node from the scene
		effect.queue_free()
		
	tile_activation_complete.emit()
