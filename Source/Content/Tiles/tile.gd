@tool
class_name Tile
extends Node2D

const _TILE_DROPPED_SFX: SoundEffectResource = preload("res://Source/Resources/SoundEffectResources/SoundEffects/tile_dropped.tres")
const _TRIGGER_SFX: SoundEffectResource = preload("res://Source/Resources/SoundEffectResources/SoundEffects/upgrade_trigger.tres")
const _SPARK_TEXTURE: Texture2D = preload("res://Assets/Particles/hit_particle_pixel.png")
const _UPGRADE_SPARKS_NAME: StringName = &"UpgradeSparks"

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
## Set once this tile has caught a killing blow (see _on_player_fatal_damage).
var _death_save_spent: bool = false
@export var uses_remaining: int = -1:
	set(new_value):
		var most: int = max_uses_per_turn()
		# A rule capping an unlimited tile turns "unlimited" into its cap.
		if new_value < 0 and most != tile_resource.uses_per_turn:
			new_value = most
		uses_remaining = clampi(new_value, -1, most)

		if uses_remaining == 0:
			set_gray_out(true)
		else:
			set_gray_out(false)

		# Only a tile with a budget of its own has light frames to show.
		if uses_remaining == -1 or tile_resource.uses_per_turn < 0:
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

## True while the tile is shop stock or salvage on offer: shown, but not the
## player's yet. It takes no dice and ignores the game's events until
## TileGrid.receive_tile() installs it; without this, an unbought tile could
## be played for free, and its passives (Counterweight Battery's shields)
## worked from the shelf.
var on_offer: bool = false:
	set(value):
		on_offer = value
		_update_dice_acceptance()


func _ready() -> void:
	assert(tile_resource)
	_set_up_resource()
	_update_dice_acceptance()
	
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
		# A copy on offer points out the twin it would upgrade.
		draggable.drag_started.connect(_highlight_twins.bind(true))
		draggable.drag_ended.connect(func(_draggable: Draggable, _at: Vector2) -> void:
			_highlight_twins(false)
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
	Events.player_shields_gained.connect(func() -> void:
		handle_tile_event(self, TileEvent.EventType.ON_PLAYER_SHIELDS_GAINED)
	)
	Events.player_fatal_damage.connect(_on_player_fatal_damage)
	# Answered straight after the neighbour's activation rather than at the back
	# of the queue. A relay chain winding past this tile activates several
	# neighbours in one pass; queued, every response would wait for the chain
	# to finish and then fire back to back, reading as a single proc.
	Events.tile_activated.connect(func(tile: Tile) -> void:
		if _is_orthogonal_neighbour(tile):
			handle_tile_event(self, TileEvent.EventType.ON_ADJACENT_TILE_ACTIVATED, true)
		if _is_surrounding_neighbour(tile):
			handle_tile_event(self, TileEvent.EventType.ON_SURROUNDING_TILE_ACTIVATED, true)
	)
	Events.modifier_triggered.connect(func(mod: Modifier) -> void:
		if mod.source == self:
			play_trigger_feedback(mod.get_trigger_color(), mod.get_trigger_text())
	)


## Whether another tile sits directly above, below, left or right of this one
## on the grid — the four directions a die can be Fed.
func _is_orthogonal_neighbour(other: Tile) -> bool:
	var apart: Vector2i = _grid_distance_to(other)
	return apart.x + apart.y == 1


## Whether another tile sits in any of the eight cells around this one,
## diagonals included.
func _is_surrounding_neighbour(other: Tile) -> bool:
	var apart: Vector2i = _grid_distance_to(other)
	return maxi(apart.x, apart.y) == 1


## How many columns and rows apart [param other] is, or (-1, -1) when either
## tile is off the grid or they are the same tile.
func _grid_distance_to(other: Tile) -> Vector2i:
	var grid: TileGrid = Globals.tile_grid
	if other == self or not grid:
		return Vector2i(-1, -1)
	var mine: Vector2i = grid.find_tile_pos(self)
	var theirs: Vector2i = grid.find_tile_pos(other)
	if not grid.is_grid_pos_valid(mine) or not grid.is_grid_pos_valid(theirs):
		return Vector2i(-1, -1)
	return (mine - theirs).abs()


func _set_up_resource() -> void:
	sprite_frames.sprite_frames = tile_resource.textures
	ColorSymbolBadge.attach_to_tile_sprite(sprite_frames, tile_resource)
	uses_remaining = max_uses_per_turn()
	update_dragging_allowed()
	_apply_upgrade_look()


## Whether a copy of [param other] dropped on this tile would upgrade it: the
## same tile, not upgraded yet, with an upgrade to become.
func can_merge(other: TileResource) -> bool:
	return other == tile_resource and tile_resource.upgraded_version != null


## Becomes the upgraded version of itself, with a burst to show it. Counters
## it keeps (effect_data) carry over; its uses refill, as a new tile's would.
func upgrade() -> void:
	if tile_resource.upgraded_version == null:
		return
	tile_resource = tile_resource.upgraded_version
	var color: Color = family_color(tile_resource)
	Juice.bump(sprite_frames, 0.35, 0.35)
	flash(Globals.white, 1.0, 0.4)
	Juice.sparkle(self, global_position, color, 16, 50.0, true)
	Juice.ring(self, global_position, Globals.white, 20.0, 0.35, 6.0)
	Juice.callout(self, tr("CALLOUT_UPGRADED"), color, true)
	Events.play_sound.emit(_TRIGGER_SFX)
	Events.tile_upgraded.emit(self)


## Another copy of this tile that would merge with it right now, if any: one
## on offer (salvage, a shop) to drop on a twin on the grid, or, while the
## grid can be rearranged, a second copy on it. The info panel previews the
## upgrade only then, when it's a choice the player actually has.
func _copy_to_merge_with() -> Tile:
	if tile_resource.upgraded_version == null or not is_inside_tree():
		return null
	var mine_on_grid: bool = not on_offer and get_parent() is TileGrid
	for node: Node in get_tree().get_nodes_in_group(&"Tile"):
		var other: Tile = node as Tile
		if other == null or other == self or other.is_queued_for_deletion() \
		or not other.is_visible_in_tree() or not other.can_merge(tile_resource):
			continue
		var other_on_grid: bool = not other.on_offer and other.get_parent() is TileGrid
		if mine_on_grid and other_on_grid and not grid_locked():
			return other
		if mine_on_grid != other_on_grid and (on_offer or other.on_offer):
			return other
	return null


## The colour of [param resource]'s family, for effects that should match it.
static func family_color(resource: TileResource) -> Color:
	match ColorSymbolBadge.family_of_tile(resource):
		ColorSymbolBadge.Family.RED:
			return Globals.red
		ColorSymbolBadge.Family.BLUE:
			return Globals.blue
		ColorSymbolBadge.Family.GREEN:
			return Globals.green
		ColorSymbolBadge.Family.PURPLE:
			return Globals.purple
		ColorSymbolBadge.Family.YELLOW:
			return Globals.yellow
	return Globals.white


## An upgraded tile shimmers round its edge (tile.gdshader) and gives off a
## few sparks in its family's colour, so it reads as upgraded at a glance.
func _apply_upgrade_look() -> void:
	var upgraded: bool = tile_resource.is_upgrade
	var mat: ShaderMaterial = sprite_frames.material as ShaderMaterial
	if mat:
		mat.set_shader_parameter("upgraded", upgraded)
	var sparks: CPUParticles2D = sprite_frames.get_node_or_null(NodePath(_UPGRADE_SPARKS_NAME))
	if upgraded and sparks == null:
		# Lightened, or the family's deeper colours vanish against the art.
		sparks = _make_upgrade_sparks(family_color(tile_resource).lerp(Globals.white, 0.5))
		sprite_frames.add_child(sparks)
	elif not upgraded and sparks:
		sparks.queue_free()


func _make_upgrade_sparks(color: Color) -> CPUParticles2D:
	var sparks: CPUParticles2D = CPUParticles2D.new()
	sparks.name = _UPGRADE_SPARKS_NAME
	sparks.texture = _SPARK_TEXTURE
	sparks.amount = 5
	sparks.lifetime = 1.6
	sparks.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	sparks.emission_rect_extents = Vector2(10, 11)
	sparks.direction = Vector2.UP
	sparks.spread = 20.0
	sparks.gravity = Vector2(0, -6)
	sparks.initial_velocity_min = 3.0
	sparks.initial_velocity_max = 7.0
	sparks.color = color
	var ramp: Gradient = Gradient.new()
	ramp.set_color(0, Color(1.0, 1.0, 1.0, 1.0))
	ramp.set_color(1, Color(1.0, 1.0, 1.0, 0.0))
	sparks.color_ramp = ramp
	sparks.z_index = 1
	return sparks


## Lights the tile on the grid this one would upgrade, while a copy on offer
## is being carried.
func _highlight_twins(shown: bool) -> void:
	if not on_offer or not is_instance_valid(Globals.tile_grid):
		return
	for twin: Tile in Globals.tile_grid.tile_locations.values():
		if is_instance_valid(twin) and twin.can_merge(tile_resource):
			twin.set_highlight(shown)


## Tiles in the grid are locked in place for the length of a fight. A tile
## anywhere else — on offer from a ship that just died, on the shop's shelf —
## can still be picked up, or a reward dropped mid-fight could never be taken.
func _update_dice_acceptance() -> void:
	if can_accept_dice:
		can_accept_dice.enabled = not on_offer


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
	info.bottom_label_text = fill_data_tokens(tile_resource.description, effect_data)
	if _copy_to_merge_with():
		info.bottom_label_text += "\n\n%s\n%s" % [
			tr("INFO_TILE_UPGRADE"), tile_resource.upgraded_version.description
		]
	var engine: ScenarioEngine = ScenarioEngine.current()
	if engine:
		for mod: Modifier in engine.modifiers:
			var line: String = mod.get_info_text() if mod.affected_node == self \
				else mod.get_rule_info_text(self)
			if not line.is_empty():
				info.bottom_label_text += "\n\n" + line
	return info


## A response to a fatal hit is a death save, so the ship has to be saved
## before Health re-checks the hull, straight after this signal returns. The
## response chain can't do it: like every tile response it resolves later
## through the queue, by which time death has long been declared. So the tile
## holds the hull at 1 here, and the chain plays the rest (the shields, the
## show, the tile burning out). It's injected rather than queued so the
## shields land before the next enemy shot, not after the whole volley.
##
## Spent on the first blow it catches, so a second blow landing before the
## chain finishes isn't saved for free, and when two tiles could answer, only
## the first one burns.
func _on_player_fatal_damage() -> void:
	if _death_save_spent or on_offer or not ScenarioEngine.current():
		return
	if _find_matching_event_response(self, TileEvent.EventType.ON_PLAYER_FATAL_DAMAGE) == null:
		return
	var health: Health = Globals.player.health
	if health.health > 0:
		return	# another tile already caught this blow
	_death_save_spent = true
	health.health = 1
	handle_tile_event(self, TileEvent.EventType.ON_PLAYER_FATAL_DAMAGE, true)


## [param immediate] resolves the response right after the event currently
## resolving instead of at the back of the queue.
func handle_tile_event(tile: Tile, event: TileEvent.EventType, immediate: bool = false) -> void:
	if on_offer:
		return
	var event_check: TileEvent = _find_matching_event_response(tile, event)
	var engine: ScenarioEngine = ScenarioEngine.current()
	if event_check == null or not engine:
		return

	var trigger_event: TileEventTriggeredEvent = TileEventTriggeredEvent.new()
	trigger_event.responder = self
	trigger_event.chain = tile_resource.event_responses[event_check]
	if immediate:
		engine.inject_event(trigger_event)
	else:
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
	var refusal: String = activation_refusal(activator_die)
	if refusal.is_empty():
		return true
	Events.error_text_popup.emit(refusal, self.global_position)
	play_refusal_feedback()
	return false


## Why this tile would turn [param activator_die] away right now, or "" if it
## would take it. A pure query, so callers can ask without the refusal
## popping up (the AutoPilot uses it to list the legal moves).
func activation_refusal(activator_die: Dice = null) -> String:
	# Check for uses, remembering -1 uses means unlimited
	if not (uses_remaining == -1 or uses_remaining > 0):
		return "NO USES REMAINING"

	for check: ActivationResource in tile_resource.activation_checks:
		if not check.criteria_satisfied(activator_die, self):
			return check.get_criteria_fail_text()

	return ""
	

## Whether a lockout may take hold on this tile. Every lockout goes through
## AddLockoutModifierEvent, which asks this, so the rule lives with the tile
## rather than in each enemy action or hazard that locks one.
func can_be_locked_out() -> bool:
	return tile_resource != null and tile_resource.can_be_locked_out


## Whether a lockout already holds this tile. A second lock would fire twice on
## the die that opens it, so lockouts check this before landing.
func is_locked_out() -> bool:
	var engine: ScenarioEngine = ScenarioEngine.current()
	if engine == null:
		return false
	for mod: Modifier in engine.modifiers:
		if mod is LockoutModifier and mod.affected_node == self:
			return true
	return false


## Whether a new lockout could take hold here: the tile allows locks and isn't
## locked already. Random lockouts pick only from these.
func accepts_lockout() -> bool:
	return can_be_locked_out() and not is_locked_out()


func reset_uses_remaining() -> void:
	uses_remaining = max_uses_per_turn()


## The most uses this tile gets a turn: its own budget, cut down by any rule
## in play that caps it (Dead Systems, see Modifier.get_tile_use_cap()). -1
## for unlimited.
func max_uses_per_turn() -> int:
	var most: int = tile_resource.uses_per_turn
	if Engine.is_editor_hint():
		return most
	var engine: ScenarioEngine = ScenarioEngine.current()
	if engine == null:
		return most
	for mod: Modifier in engine.modifiers:
		var cap: int = mod.get_tile_use_cap(self)
		if cap >= 0 and (most < 0 or cap < most):
			most = cap
	return most


## Brings the uses left in line with max_uses_per_turn() after a cap comes or
## goes mid-turn: down to the cap, or an unlimited tile back to unlimited. A
## tile with its own budget keeps what it had left once a cap lifts.
func refresh_use_cap() -> void:
	var most: int = max_uses_per_turn()
	if most < 0:
		uses_remaining = -1
	elif uses_remaining < 0 or uses_remaining > most:
		uses_remaining = most


## Works out each [data]expression[/data] in [param text] from a tile's
## counters. A counter the tile hasn't set yet reads as 0, which is also how
## the text reads for a tile that isn't on a grid at all (the codex).
static func fill_data_tokens(text: String, data: Dictionary[String, int]) -> String:
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
				if data.has(token):
					rebuilt_expression += str(data[token]) + " "
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
	# Remember who the player meant this die for. It may sit in this queue
	# (or behind a resolving chain) while they switch to another ship.
	# The target can be a ship destroyed a moment ago that the computer hasn't
	# moved off yet, and a freed ship can't even be assigned to aimed_at. The
	# die then falls back to whatever is targeted when it fires (target_for).
	if Globals.targeting_computer:
		if is_instance_valid(Globals.targeting_computer.targeted_enemy):
			die.aimed_at = Globals.targeting_computer.targeted_enemy
		else:
			die.aimed_at = null

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
	mat.set_shader_parameter("flash_amount", Juice.soften_flash(strength))
	_flash_tween = create_tween()
	_flash_tween.tween_property(mat, "shader_parameter/flash_amount", 0.0, duration) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
