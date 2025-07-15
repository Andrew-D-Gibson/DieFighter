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

## tile_data holds any necessary data that a tile's effects might need
## e.g. "turns_since_last_activation", "last_activator_value", etc.
var effect_data: Dictionary[String, int]
		
		
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
			Events.play_sound.emit('tile_dropped')
		)
	Events.enemy_turn_over.connect(reset_uses_remaining)
	Events.start_scenario.connect(reset_uses_remaining)
	_connect_tile_event_signals()


func _connect_tile_event_signals() -> void:
	Events.tile_pushed.connect(func(tile: Tile):
		handle_tile_event(tile, TileEvent.EventType.ON_TILE_PUSHED)
	)	
	Events.tile_manually_moved.connect(func(tile: Tile):
		handle_tile_event(tile, TileEvent.EventType.ON_TILE_MANUALLY_MOVED)
	)


func _set_up_resource() -> void:
	sprite_frames.sprite_frames = tile_resource.textures
	uses_remaining = tile_resource.uses_per_turn


func _get_tile_info() -> InfoResource:
	var info = InfoResource.new()
	info.title_label_text = tile_resource.tile_name
	info.top_label_text = tile_resource.activation_description
	info.texture = tile_resource.textures.get_frame_texture('default', 0)
	info.bottom_label_text = _replace_event_data_in_string(tile_resource.description)
	
	return info


func handle_tile_event(tile: Tile, event: TileEvent.EventType) -> void:
	for event_check in tile_resource.event_responses.keys():
		if event_check.event == event:
			# We can do the response if we don't care about listening for this tile
			if not event_check.listen_only_for_self\
			
			# Or if we are this tile!
			or (event_check.listen_only_for_self == (tile == self)):
				var effect_variables = _generate_effect_variables()
				await tile_resource.event_responses[event_check].play(effect_variables)


func try_to_activate(activator_die: Dice = null) -> void:
	# Check for uses, remembering -1 uses means unlimited
	if not (uses_remaining == -1 or uses_remaining > 0):
		return
		
	for check in tile_resource.activation_checks:
		if not check.criteria_satisfied(activator_die):
			return
	
	# We're cleared hot to activate!
	if uses_remaining != -1:
		uses_remaining -= 1
		
	if activator_die:
		activator_die.draggable.state = Draggable.DragState.MOVING_WITH_CODE
	_activate(activator_die)
		
		
func _generate_effect_variables() -> EffectVariables:
	var effect_variables = EffectVariables.new()
	effect_variables.actor = Globals.player
	effect_variables.effect_source = self
	
	return effect_variables
	

func _activate(activator_die: Dice = null) -> void:
	# Set up the effects variables for chaining effects
	var effect_variables = _generate_effect_variables()
	effect_variables.activator_die = activator_die
	
	await tile_resource.effect_chain.play(effect_variables)
	
	Events.tile_activation_complete.emit()


func reset_uses_remaining() -> void:
	uses_remaining = tile_resource.uses_per_turn


func _replace_event_data_in_string(text: String) -> String:
	var pattern = r"\[data\](.+?)\[/data\]"
	var regex = RegEx.new()
	regex.compile(pattern)

	var result = text

	for match in regex.search_all(text):
		var full_match := match.get_string(0)
		var expression := match.get_string(1)

		# Replace unknown identifiers with 0
		# Tokenize the expression and rebuild it with known values
		var tokens = expression.split(" ", false)
		var rebuilt_expression = ""
		for token in tokens:
			if token.is_valid_identifier():
				if effect_data.has(token):
					rebuilt_expression += str(effect_data[token]) + " "
				else:
					rebuilt_expression += "0 "
			else:
				rebuilt_expression += token + " "

		# Evaluate the safe expression
		var safe_result := Expression.new()
		var err := safe_result.parse(rebuilt_expression.strip_edges())
		if err == OK:
			var value = safe_result.execute()
			result = result.replace(full_match, str(value))
		else:
			result = result.replace(full_match, "0") # fallback in case of parse error

	return result
