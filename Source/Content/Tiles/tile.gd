@tool
class_name Tile
extends Node2D

const _TILE_DROPPED_SFX: SoundEffectResource = preload("res://Source/Resources/SoundEffectResources/SoundEffects/tile_dropped.tres")
const _TRIGGER_SFX: SoundEffectResource = preload("res://Source/Resources/SoundEffectResources/SoundEffects/upgrade_trigger.tres")

## One modifier can fire on several events of a single activation (an
## Amplifier touches every amplifiable event in the chain). Within this window
## the tile still bumps and flashes, but only the first fire gets the callout,
## sound and burst, so a proc reads as one beat rather than a pile.
const _TRIGGER_CALLOUT_COOLDOWN_MSEC: int = 150

@export var tile_resource: TileResource:
	set(new_resource):
		tile_resource = new_resource
		if sprite_frames:
			_set_up_resource()
		
var _saturation_tween: Tween
var _flash_tween: Tween
var _last_trigger_callout_msec: int = -_TRIGGER_CALLOUT_COOLDOWN_MSEC
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
@export var can_accept_dice: CanAcceptDice


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
			Juice.bump(sprite_frames, 0.15, 0.25)
			Events.play_sound.emit(_TILE_DROPPED_SFX)
		)
	
	# Uses are a per-turn budget. The first turn of a scenario has no
	# turn-start beat of its own, so arriving counts as a refill too.
	Events.start_scenario.connect(reset_uses_remaining)
	Events.player_turn_refresh.connect(reset_uses_remaining)
	Events.start_combat.connect(update_dragging_allowed)
	Events.combat_finished.connect(update_dragging_allowed)
	# A die a tile is holding (KEEP_DIE_WITH_TILE) is the player's, on loan.
	# Hand it back before the enemies act, and before a jump frees every die.
	Events.player_turn_over.connect(release_held_dice)
	Events.combat_finished.connect(release_held_dice)
	_connect_tile_event_signals()
	
	dice_queue.die_added.connect(_update_dice_queue_locations)
	dice_queue.die_removed.connect(_update_dice_queue_locations)
	

func _connect_tile_event_signals() -> void:
	Events.player_turn_start.connect(func() -> void:
		handle_tile_event(self, TileEvent.EventType.ON_TURN_START)
	)
	Events.first_turn_start.connect(func() -> void:
		handle_tile_event(self, TileEvent.EventType.ON_TURN_START)
	)
	Events.tile_pushed.connect(func(tile: Tile) -> void:
		handle_tile_event(tile, TileEvent.EventType.ON_TILE_PUSHED)
	)	
	Events.tile_manually_moved.connect(func(tile: Tile) -> void:
		handle_tile_event(tile, TileEvent.EventType.ON_TILE_MANUALLY_MOVED)
	)
	Events.enemy_turn_over.connect(func() -> void:
		handle_tile_event(self, TileEvent.EventType.ON_ENEMY_TURN_OVER)
	)
	Events.player_health_hit.connect(func() -> void:
		handle_tile_event(self, TileEvent.EventType.ON_PLAYER_HEALTH_HIT)
	)
	Events.engine_charge_drained.connect(func() -> void:
		handle_tile_event(self, TileEvent.EventType.ON_ENGINE_CHARGE_DRAINED)
	)
	Events.player_fatal_damage.connect(func() -> void:
		handle_tile_event(self, TileEvent.EventType.ON_PLAYER_FATAL_DAMAGE)
	)
	Events.tile_activated.connect(func(tile: Tile) -> void:
		if _is_orthogonal_neighbour(tile):
			handle_tile_event(self, TileEvent.EventType.ON_ADJACENT_TILE_ACTIVATED)
	)
	Events.modifier_triggered.connect(func(mod: Modifier) -> void:
		if mod.source == self:
			play_trigger_feedback(mod.get_trigger_color(), mod.get_trigger_text())
	)


## Whether another tile sits directly above, below, left or right of this one
## on the grid — the four directions a die can be Fed.
func _is_orthogonal_neighbour(other: Tile) -> bool:
	if other == self or not Globals.tile_grid:
		return false
	var grid: TileGrid = Globals.tile_grid
	var mine: Vector2i = grid.find_tile_pos(self)
	var theirs: Vector2i = grid.find_tile_pos(other)
	if not grid.is_grid_pos_valid(mine) or not grid.is_grid_pos_valid(theirs):
		return false
	return absi(mine.x - theirs.x) + absi(mine.y - theirs.y) == 1


func _set_up_resource() -> void:
	sprite_frames.sprite_frames = tile_resource.textures
	uses_remaining = tile_resource.uses_per_turn
	update_dragging_allowed()


## Tiles in the grid are locked in place for the length of a fight. A tile
## anywhere else — on offer from a ship that just died, on the shop's shelf —
## can still be picked up, or a reward dropped mid-fight could never be taken.
func update_dragging_allowed() -> void:
	var locked: bool = get_parent() is TileGrid and grid_locked()
	draggable.dragging_allowed = tile_resource.dragging_allowed and not locked


## Whether the grid is locked right now, which is for as long as a fight lasts.
static func grid_locked() -> bool:
	return Globals.state_manager != null \
		and Globals.state_manager.state != GameStateManager.GameState.OUT_OF_COMBAT


func _get_tile_info() -> InfoResource:	
	var info: InfoResource = InfoResource.new()
	info.title_label_text = tile_resource.tile_name
	info.top_label_text = tile_resource.activation_description
	info.texture = tile_resource.textures.get_frame_texture('default', 0)
	info.bottom_label_text = _replace_event_data_in_string(tile_resource.description)
	return info


func handle_tile_event(tile: Tile, event: TileEvent.EventType) -> void:
	var event_check: TileEvent = _find_matching_event_response(tile, event)
	var engine: ScenarioEngine = ScenarioEngine.current()
	if event_check == null or not engine:
		return

	var trigger_event: TileEventTriggeredEvent = TileEventTriggeredEvent.new()
	trigger_event.responder = self
	trigger_event.chain = tile_resource.event_responses[event_check]
	engine.queue_event(trigger_event)


## Finds the TileEvent key matching this event type whose response should
## fire, respecting listen_only_for_self (self-only vs. any tile).
func _find_matching_event_response(tile: Tile, event: TileEvent.EventType) -> TileEvent:
	for event_check: TileEvent in tile_resource.event_responses.keys():
		if event_check.event == event:
			if (tile == self) or (not event_check.listen_only_for_self):
				return event_check
	return null
		
		
func clears_activation_criteria(activator_die: Dice = null) -> bool:	
	# Check for uses, remembering -1 uses means unlimited
	if not (uses_remaining == -1 or uses_remaining > 0):
		Events.error_text_popup.emit("NO USES REMAINING", self.global_position)
		play_refusal_feedback()
		return false
		
	# Check the tile's activation criteria
	for check: ActivationResource in tile_resource.activation_checks:
		if not check.criteria_satisfied(activator_die):
			Events.error_text_popup.emit(check.get_criteria_fail_text(), self.global_position)
			play_refusal_feedback()
			return false
			
	return true
	

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


## Re-activates this tile with no activator die (e.g. TILE_CONTROL.ACTIVATE_SELF).
func try_to_activate() -> void:
	var engine: ScenarioEngine = ScenarioEngine.current()
	if not engine:
		return

	var event: TileActivationEvent = TileActivationEvent.new()
	event.tile = self
	engine.queue_event(event)


## Returns every die this tile is holding to the player's hand.
func release_held_dice() -> void:
	for die: Dice in dice_queue.queue.duplicate():
		if is_instance_valid(die) and is_instance_valid(Globals.player):
			Globals.player.dice_manager.add(die, true, false)
		else:
			dice_queue.remove(die)


## The first die this tile is holding other than `except`, or null.
func get_held_die(except: Dice = null) -> Dice:
	for die: Dice in dice_queue.queue:
		if is_instance_valid(die) and die != except:
			return die
	return null


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
	
	# Emit event for die placement for tutorial use
	Events.die_placed_on_tile.emit(die, self)
	
	var engine: ScenarioEngine = ScenarioEngine.current()
	if engine:
		var event: TileActivationEvent = TileActivationEvent.new()
		event.tile = self
		event.activator_die = die
		event.die_value = die.value
		engine.queue_event(event)
		

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
	


## The die has landed and the tile is committed to firing: it takes the hit,
## squashing down and flashing like it was struck.
func play_activation_feedback() -> void:
	Juice.bump(sprite_frames, 0.2, 0.25)
	flash(Color.WHITE, 0.6, 0.15)
	Juice.ring(self, global_position, Globals.white, 14.0, 0.25, 6.0)


## The tile turned a die away: a red flash and a shake of the head.
func play_refusal_feedback() -> void:
	Juice.wiggle(sprite_frames, 12.0, 0.3)
	flash(Globals.red, 0.7, 0.3)


## Something this tile set up just paid off — a modifier it put in play
## fired, or one of its reactive chains went off. Loud on purpose: a passive
## upgrade the player never sees working is one they stop valuing.
func play_trigger_feedback(color: Color, callout_text: String = "") -> void:
	Juice.bump(sprite_frames, 0.3, 0.35)
	flash(color, 0.8, 0.35)

	var now: int = Time.get_ticks_msec()
	if now - _last_trigger_callout_msec < _TRIGGER_CALLOUT_COOLDOWN_MSEC:
		return
	_last_trigger_callout_msec = now

	Juice.ring(self, global_position, color, 20.0, 0.4, 8.0)
	Juice.sparkle(self, global_position, color, 10, 45.0)
	if not callout_text.is_empty():
		Juice.callout(self, callout_text, color)
	Events.play_sound.emit(_TRIGGER_SFX)


## Floods the tile with `color` at `strength` and lets it fade. Snapped on
## rather than eased in, so it still reads when it lands inside a hitstop.
func flash(color: Color, strength: float = 1.0, duration: float = 0.25) -> void:
	if _flash_tween and _flash_tween.is_valid():
		_flash_tween.kill()

	var mat: ShaderMaterial = sprite_frames.material as ShaderMaterial
	if mat == null:
		return
	mat.set_shader_parameter("flash_color", color)
	mat.set_shader_parameter("flash_amount", strength)
	_flash_tween = create_tween()
	_flash_tween.tween_property(mat, "shader_parameter/flash_amount", 0.0, duration) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
