@tool
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
		uses_remaining = clampi(new_value, -1, tile_resource.uses_per_turn)

		if uses_remaining == 0:
			set_gray_out(true)
		else:
			set_gray_out(false)

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
@export var dice_queue: DiceQueue

static var dice_activation_queue: Array[Dice] = []


func _ready() -> void:
	assert(tile_resource)
	_set_up_resource()
	
	if clickable:
		clickable.clicked.connect(func() -> void: 
			Events.show_info.emit(_get_tile_info())
			Events.tile_clicked_for_info.emit()
		)
	if draggable:
		draggable.reached_new_home.connect(func() -> void:
			shakeable.small_shake()
			Events.play_sound.emit('tile_dropped')
		)
	
	Events.start_scenario.connect(reset_uses_remaining)
	Events.start_combat.connect(func() -> void:
		draggable.dragging_allowed = false
		draggable.floating_enabled = false
	)
	Events.combat_finished.connect(func() -> void:
		if tile_resource.dragging_allowed:
			draggable.dragging_allowed = true
			draggable.floating_enabled = true
	)
	_connect_tile_event_signals()
	
	dice_queue.die_added.connect(_update_dice_queue_locations)
	dice_queue.die_removed.connect(_update_dice_queue_locations)
	

func _connect_tile_event_signals() -> void:
	Events.player_turn_start.connect(func() -> void:
		handle_tile_event(self, TileEvent.EventType.ON_TURN_START)
	)
	Events.tile_pushed.connect(func(tile: Tile) -> void:
		handle_tile_event(tile, TileEvent.EventType.ON_TILE_PUSHED)
	)	
	Events.tile_manually_moved.connect(func(tile: Tile) -> void:
		handle_tile_event(tile, TileEvent.EventType.ON_TILE_MANUALLY_MOVED)
	)


func _set_up_resource() -> void:
	sprite_frames.sprite_frames = tile_resource.textures
	uses_remaining = tile_resource.uses_per_turn

	if tile_resource.dragging_allowed and \
	Globals.state_manager.state == GameStateManager.GameState.OUT_OF_COMBAT:
		draggable.dragging_allowed = true
		draggable.floating_enabled = true
	else:
		draggable.dragging_allowed = false
		draggable.floating_enabled = false


func _get_tile_info() -> InfoResource:
	# Don't show the tile's info if there's status effects
	if Globals.tile_grid.tile_locations.values().has(self):
		var grid_pos: Vector2i = Globals.tile_grid.tile_locations.find_key(self)
		
		var grid_status_effects: Array[GridStatusEffect] = \
			Globals.tile_grid.get_status_effects_at_grid_pos(grid_pos)
			
		for status: GridStatusEffect in grid_status_effects:
			if status.status_info:
				return null

	
	var info: InfoResource = InfoResource.new()
	info.title_label_text = tile_resource.tile_name
	info.top_label_text = tile_resource.activation_description
	info.texture = tile_resource.textures.get_frame_texture('default', 0)
	info.bottom_label_text = _replace_event_data_in_string(tile_resource.description)
	info.side_label_text = tile_resource.hint_text
	return info


func handle_tile_event(tile: Tile, event: TileEvent.EventType) -> void:
	for event_check: TileEvent in tile_resource.event_responses.keys():
		if event_check.event == event:
			# We can do the response if we don't care about listening for this tile
			if not event_check.listen_only_for_self\
			
			# Or if we are this tile!
			or (event_check.listen_only_for_self == (tile == self)):
				var effect_variables: EffectVariables = _generate_effect_variables()
				await tile_resource.event_responses[event_check].play(effect_variables)
		

func can_activate(activator_die: Dice) -> bool:
	# Check for and handle grid status activation criteria
	if Globals.tile_grid.tile_locations.values().has(self):
		var grid_pos: Vector2i = Globals.tile_grid.tile_locations.find_key(self)
		
		var grid_status_effects: Array[GridStatusEffect] = \
			Globals.tile_grid.get_status_effects_at_grid_pos(grid_pos)
			
		for status_effect: GridStatusEffect in grid_status_effects:
			if not status_effect.clears_status_activation_criteria(activator_die):
				return false
		
	# Handle tile activation criteria
	if not _clears_activation_criteria(activator_die):
		# Something didn't go how the player expected,
		# so clear out the queue of tile activations
		for die: Dice in dice_activation_queue:
			Globals.player.dice_manager.add(die, true, false)
			
		dice_activation_queue.clear()
		
		return false
		
	# We're cleared hot to activate!
	return true
		
		
func _clears_activation_criteria(activator_die: Dice = null) -> bool:	
	# Check for uses, remembering -1 uses means unlimited
	if not (uses_remaining == -1 or uses_remaining > 0):
		Events.error_text_popup.emit("NO USES REMAINING", self.global_position)
		return false
		
	# Check the tile's activation criteria
	for check: ActivationResource in tile_resource.activation_checks:
		if not check.criteria_satisfied(activator_die):
			Events.error_text_popup.emit(check.get_criteria_fail_text(), self.global_position)
			return false
			
	return true
			
		
func _generate_effect_variables() -> EffectVariables:
	var effect_variables: EffectVariables = EffectVariables.new()
	effect_variables.actor = Globals.player
	effect_variables.effect_source = self
	
	return effect_variables
	

func activate(activator_die: Dice = null) -> void:
	if uses_remaining != -1:
		uses_remaining -= 1
		
	# Tween the activating die to the slot 
	if activator_die:
		activator_die.draggable.state = Draggable.DragState.MOVING_WITH_CODE
	
		var tween_time: float = 0.2
		var adjusted_tween_time: float = tween_time / Globals.animation_speed
		
		var tween: Tween = create_tween().set_parallel(true)
		tween.tween_property(
			activator_die, 
			'global_position', 
			global_position + Vector2(0, 6), 
			adjusted_tween_time
		).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		
		tween.tween_property(
			activator_die,
			'scale',
			Vector2(0.75, 0.75),
			adjusted_tween_time
		).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		
		await tween.finished
	
	shakeable.large_shake()
	
	# Set up the effects variables for chaining effects
	var effect_variables: EffectVariables = _generate_effect_variables()
	effect_variables.activator_die = activator_die
	
	
	# Change the effect variables based on grid status effects
	if Globals.tile_grid.tile_locations.values().has(self):
		var grid_pos: Vector2i = Globals.tile_grid.tile_locations.find_key(self)
		
		var grid_status_effects: Array[GridStatusEffect] = \
			Globals.tile_grid.get_status_effects_at_grid_pos(grid_pos)
			
		for status_effect: GridStatusEffect in grid_status_effects:
			effect_variables = status_effect.manipulate_effect_variables(effect_variables)
	
	
	# Play the tile's effect chain
	await tile_resource.effect_chain.play(effect_variables)
	
	# Remove the activator die that was just used from the
	# Tile static dice activation queue
	if activator_die and dice_activation_queue.has(activator_die):
		dice_activation_queue.erase(activator_die)

	Events.tile_activation_complete.emit()


func reset_uses_remaining() -> void:
	uses_remaining = tile_resource.uses_per_turn


func _replace_event_data_in_string(text: String) -> String:
	var pattern: String = r"\[data\](.+?)\[/data\]"
	var regex: RegEx = RegEx.new()
	regex.compile(pattern)

	var result: String = text

	for match: RegExMatch in regex.search_all(text):
		var full_match: String = match.get_string(0)
		var expression: String = match.get_string(1)

		# Replace unknown identifiers with 0
		# Tokenize the expression and rebuild it with known values
		var tokens: PackedStringArray = expression.split(" ", false)
		var rebuilt_expression: String = ""
		for token: String in tokens:
			if token.is_valid_identifier():
				if effect_data.has(token):
					rebuilt_expression += str(effect_data[token]) + " "
				else:
					rebuilt_expression += "0 "
			else:
				rebuilt_expression += token + " "

		# Evaluate the safe expression
		var safe_result: Expression = Expression.new()
		var err: Error = safe_result.parse(rebuilt_expression.strip_edges())
		if err == OK:
			var value: int = safe_result.execute()
			result = result.replace(full_match, str(value))
		else:
			result = result.replace(full_match, "0") # fallback in case of parse error

	return result


func _update_dice_queue_locations() -> void:
	var dice_queue_spacing: int = 12
	for i: int in range(len(dice_queue.queue)):
		dice_queue.queue[i].draggable.home_position = \
		dice_queue.global_position +\
		Vector2(0, i * dice_queue_spacing)


func _on_die_accepted(die: Dice) -> void:
	if not die:
		return
		
	dice_queue.add(die, true, false)
	if Globals.activation_queue_manager:
		Globals.activation_queue_manager.add_die_to_queue(die)
	
	# Emit tutorial event for die placement
	Events.die_placed_on_tile.emit(die, self)


func _on_visibility_changed() -> void:	
	for die: Dice in dice_queue.queue:
		die.visible = self.is_visible_in_tree()
		
		
func set_highlight(highlight: bool) -> void:
	sprite_frames.material.set_shader_parameter('highlight_enabled', highlight)


func set_gray_out(gray_out: bool) -> void:
	var outer_radius: float
	var strength: float
	
	if gray_out:
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
