class_name TargetingComputer
extends Node2D

@export var targeting_indicator: Sprite2D
@export var unknown_intent_indicator: Texture2D
@export var targeting_indicator_offset: Vector2 = Vector2(20, 18)
var targeted_enemy_index: int
var targeted_enemy: Enemy
var intent_scale_tweens: Array[Tween] = []

## The reticle glides onto a newly targeted ship, then hovers on it. It's
## placed every frame from the ship's live position, so it rides along when the
## ship slides across to close a gap in the formation.
const _INDICATOR_GLIDE_SECONDS: float = 0.3
const _INDICATOR_BOB_SECONDS: float = 1.5
const _INDICATOR_BOB: Vector2 = Vector2(4, 4)

## The ship the reticle is on (or gliding to), and the glide's progress from
## where it set off: 0 there, 1 on the ship.
var _indicator_ship: Enemy
var _indicator_glide_tween: Tween
var _indicator_glide: float = 1.0
var _indicator_glide_from: Vector2
var _indicator_bob_time: float = 0.0

## Bumped by every redraw, so a scan animation still playing out from an
## earlier one can tell it's been superseded.
var _redraw_generation: int = 0

## Small die faces hung over the ships the targeted enemy's slots are bound
## to: "on a 1, the Tender repairs *this* one". Escorts often share a name,
## so the intent text alone can't say which ship it means.
var _bound_markers: Array[Node2D] = []

## Where a marker sits relative to the ship it points out, and how far apart
## two markers on the same ship stand.
const _BOUND_MARKER_OFFSET: Vector2 = Vector2(0, 22)
const _BOUND_MARKER_SPACING: float = 8.0

## Intents no die is lighting sit back so the live ones stand out.
const _DIMMED_INTENT: Color = Color(1.0, 1.0, 1.0, 0.45)

## The ship acting right now and the slot it's playing. The die leaves its hand
## as the action starts, but the intent stays lit until the action's effects
## have all played out, so the player can read what is happening to them.
var _acting_enemy: Enemy
var _acting_slot: int = -1

@onready var die_sprites: Array[AnimatedSprite2D] = [
	%DieSprite1, 
	%DieSprite2, 
	%DieSprite3, 
	%DieSprite4, 
	%DieSprite5, 
	%DieSprite6, 
]

func _ready() -> void:
	Globals.targeting_computer = self
	intent_scale_tweens.resize(6)
	
	Events.enemy_left.connect(func(_ship: Enemy, _faction: ScenarioManager.Faction) -> void:
		await get_tree().process_frame
		check_target_is_valid()
	)
	Events.enemy_used_die.connect(_on_enemy_used_die)
	# A die landing in an enemy's hand slams the intent it just bought, the
	# same pulse as when the enemy spends it.
	Events.enemy_armed.connect(_pulse_intent)
	Events.enemy_flew_in.connect(ensure_target)
	Events.enemy_received_die.connect(_update_ui)
	Events.enemy_lost_die.connect(_refresh_intent_highlights)
	Events.enemy_held_dice_changed.connect(_refresh_intent_highlights)
	Events.start_scenario.connect(_update_ui)
	# A fight breaking out mid-turn (firing on a civilian) reveals the tables
	# that were rolled while they read "?". A frame later, because combat
	# starts as the shot lands, before the ship it hit turns hostile.
	Events.start_combat.connect(func() -> void:
		await get_tree().process_frame
		_update_ui()
	)
	Events.player_turn_start.connect(func() -> void:
		await get_tree().create_timer(0.5).timeout
		_update_ui()
	)
	Events.enemy_turn_over.connect(check_target_is_valid)	 # Update the computer with the new enemy intents

	Events.jump.connect(_target_nothing)

	Events.targeting_computer_startup.connect(_startup)
	Events.cockpit_snap_online.connect(func() -> void:
		%RevealOverlay.hide()
	)

	%RevealOverlay.material = %RevealOverlay.material.duplicate()
	%RevealOverlay.material.set_shader_parameter("progress", 0.0)

	ensure_target()
	
	

## Targets the first ship if nothing is targeted yet.
func ensure_target() -> void:
	if !targeted_enemy:
		targeted_enemy_index = 0
		check_target_is_valid()
		

## The ship a tile activated by [param die] should act on. That's the ship
## the die was dropped against, so a die queued behind a busy chain doesn't
## swerve onto whatever the player targeted while it waited. If that ship has
## died or left since, it's the current target instead (which may be nothing:
## the effects already handle having no target). A tile fired with no die, or
## by an untracked die, also uses the current target.
func target_for(die: Node) -> Enemy:
	# Checked before anything typed touches it: a freed ship can't even be
	# assigned to an Enemy variable.
	if is_instance_valid(die) and die is Dice and is_instance_valid((die as Dice).aimed_at):
		var aimed: Enemy = (die as Dice).aimed_at
		if _still_in_fight(aimed):
			return aimed
	return targeted_enemy if is_instance_valid(targeted_enemy) else null


func _still_in_fight(ship: Enemy) -> bool:
	if ship.is_queued_for_deletion() or ship.health.health <= 0:
		return false
	# A ship that fled is still alive, but it's off the roster.
	return Globals.enemy_manager != null and ship in Globals.enemy_manager.get_alive_enemies()


func _target_nothing() -> void:
	_acting_enemy = null
	_acting_slot = -1
	var previous: Enemy = targeted_enemy if is_instance_valid(targeted_enemy) else null
	targeted_enemy = null
	targeted_enemy_index = -1
	_after_retarget(previous)
	_update_ui()


## Every animation on the computer's icons belongs to the ship being shown. A
## pulse started for the last target and left to finish on the new one's
## intents would read as the new ship's action, so a switch stops them all
## and puts the icons back at rest.
func _after_retarget(previous: Enemy) -> void:
	if previous == targeted_enemy:
		return
	_reset_icon_tweens()


func _reset_icon_tweens() -> void:
	for i: int in range(intent_scale_tweens.size()):
		if intent_scale_tweens[i]:
			intent_scale_tweens[i].kill()
			intent_scale_tweens[i] = null
		_intent(i).scale = Vector2.ONE
	

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed('target_left'):
		targeted_enemy_index -= 1
		check_target_is_valid()

		
	if event.is_action_pressed('target_right'):
		targeted_enemy_index += 1
		check_target_is_valid()
		

func _on_left_button_input_event(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	# Check for the left mouse pressed event
	if event is InputEventMouseButton and event.pressed and event.button_index == 1:
		targeted_enemy_index -= 1
		check_target_is_valid()


func _on_right_button_input_event(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	# Check for the left mouse pressed event
	if event is InputEventMouseButton and event.pressed and event.button_index == 1:
		targeted_enemy_index += 1
		check_target_is_valid()


func check_target_is_valid() -> void:
	if not Globals.enemy_manager:
		_update_ui()
		return
		
	var previous: Enemy = targeted_enemy if is_instance_valid(targeted_enemy) else null
	var enemies: Array[Enemy] = Globals.enemy_manager.get_alive_enemies()
	
	# Check that there even are enemies to target
	if len(enemies) == 0:
		targeted_enemy = null
		targeted_enemy_index = -1
	
	# Check if we need to wrap around to the last enemy
	elif targeted_enemy_index <= -1:
		targeted_enemy_index = len(enemies) - 1
		targeted_enemy = enemies[targeted_enemy_index]
		
	# Check if we need to wrap around to the first enemy
	elif targeted_enemy_index >= len(enemies):
		targeted_enemy_index = 0
		targeted_enemy = enemies[targeted_enemy_index]
		
	# Given that there are enemies and we're within a valid range, target is valid
	else:
		targeted_enemy = enemies[targeted_enemy_index]

	_after_retarget(previous)
	_update_ui()
	Events.targeting_computer_retargeted.emit()
	
	
func _on_enemy_used_die(enemy: Enemy, die_value: int) -> void:
	_acting_enemy = enemy
	_acting_slot = clampi(die_value - 1, 0, 5)
	# Actions resolve one after another off the engine's queue, so the queue
	# running dry means the last one has finished playing. Each new action
	# takes the light over from the one before it.
	var engine: ScenarioEngine = ScenarioEngine.current()
	if engine and not engine.finished_processing_queue.is_connected(_end_acting_intent):
		engine.finished_processing_queue.connect(_end_acting_intent, CONNECT_ONE_SHOT)
	_refresh_intent_highlights()
	_pulse_intent(enemy, die_value)


func _end_acting_intent() -> void:
	_acting_enemy = null
	_acting_slot = -1
	_refresh_intent_highlights()


func _pulse_intent(enemy: Enemy, die_value: int) -> void:
	# Only animate for the currently targeted enemy
	if enemy != targeted_enemy:
		return
	
	# Convert die value (1-6) to intents index (0-5)
	var intent_index: int = clamp(die_value - 1, 0, 5)
	var intent_node: Node2D = $Intents.get_child(intent_index)
	
	# If a previous tween exists for this intent, stop it
	if intent_scale_tweens[intent_index]:
		intent_scale_tweens[intent_index].kill()
	
	# Pulse the intent scale up then back down
	var up_scale: Vector2 = Vector2(1.4, 1.4)
	var base_scale: Vector2 = Vector2.ONE
	var tween_time: float = 0.5
	
	var tween: Tween = get_tree().create_tween()
	intent_scale_tweens[intent_index] = tween
	tween.tween_property(intent_node, 'scale', up_scale, tween_time).from(base_scale).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(intent_node, 'scale', base_scale, tween_time).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	
	
func target_enemy(enemy: Enemy) -> void:
	if not enemy:
		return
		
	if not Globals.enemy_manager:
		_update_ui()
		return
		
	var enemies: Array[Enemy] = Globals.enemy_manager.get_alive_enemies()
	
	var enemy_index: int = enemies.find(enemy)
	if enemy_index != -1: # We found the enemy
		targeted_enemy_index = enemy_index
	
	check_target_is_valid()

	
func _update_ui() -> void:
	_redraw_generation += 1
	var generation: int = _redraw_generation
	_show_bound_markers()
	if !targeted_enemy or targeted_enemy_index == -1:
		_hide_indicator()
		
		$TargetImage.texture = null
		for i: int in range(6):
			_intent(i).texture = null
			_intent_amount(i).text = ''
			
			# De-highlight the die sprites
			die_sprites[i].frame = i
			_intent(i).modulate = Color.WHITE
			_set_intent_clickable(_intent_clickable(i), false)

		$TargetImageFill.z_index = 1
		
	else:
		_move_indicator()
		
		$TargetImage.texture = targeted_enemy.enemy_resource.targeting_computer_image
		for i: int in range(len(targeted_enemy.turn_actions)): # Should always loop 0 to 5
			if Globals.state_manager.enemy_intents_visible():
				# Set up the intent die properly
				_set_intent_highlight(i)
					
				# Set up the action texture
				_intent(i).texture = targeted_enemy.turn_actions[i].indicator_texture
				
				# Set up the action amount text
				_intent_amount(i).text = targeted_enemy.turn_actions[i].get_intent_amount_text()

				# Change over the info on clicking this particular action indicator 
				var clickable: Clickable = _intent_clickable(i)
				Utils.disconnect_all_callables(clickable.clicked)
				clickable.clicked.connect(targeted_enemy.turn_actions[i].show_info)
				_set_intent_clickable(clickable, targeted_enemy.turn_actions[i].name != "")
			else:
				_intent(i).texture = unknown_intent_indicator
				_intent(i).modulate = Color.WHITE
				_intent_amount(i).text = ""
				Utils.disconnect_all_callables(_intent_clickable(i).clicked)
				_set_intent_clickable(_intent_clickable(i), false)
				
				
		$TargetImageFill.z_index = 1
		$TargetImageFill.frame = 0
		await $TargetImageFill.animation_looped
		# A later redraw owns the fill now; with no target it has to stay up.
		if generation == _redraw_generation:
			$TargetImageFill.z_index = -2


## Lights slot [param i]'s die face and intent when the targeted enemy holds
## that value or is playing that slot now, dims them otherwise.
func _set_intent_highlight(i: int) -> void:
	var lit: bool = targeted_enemy.dice_manager.has_value(i + 1) \
		or (targeted_enemy == _acting_enemy and i == _acting_slot)
	die_sprites[i].frame = i + 6 if lit else i
	_intent(i).modulate = Color.WHITE if lit else _DIMMED_INTENT


## A slot with nothing to explain (a blank action, or one not yet scanned)
## takes no hover at all, so the cursor doesn't promise info that isn't there.
func _set_intent_clickable(clickable: Clickable, has_info: bool) -> void:
	clickable.hover_for_info = has_info
	clickable.input_pickable = has_info
	if not has_info and clickable.hovered:
		clickable.reset_hover_state()


## Re-reads which faces the targeted enemy holds without the full redraw (and
## its scan animation), for when a die leaves its hand.
func _refresh_intent_highlights() -> void:
	if not targeted_enemy or not is_instance_valid(targeted_enemy):
		return
	if not Globals.state_manager or not Globals.state_manager.enemy_intents_visible():
		return
	for i: int in range(len(targeted_enemy.turn_actions)):
		_set_intent_highlight(i)


func _show_bound_markers() -> void:
	for marker: Node2D in _bound_markers:
		if is_instance_valid(marker):
			marker.queue_free()
	_bound_markers.clear()

	if not targeted_enemy or not is_instance_valid(targeted_enemy):
		return
	if not Globals.state_manager or not Globals.state_manager.enemy_intents_visible():
		return

	# Slots bound to the same ship line up side by side over it.
	var slots_by_ship: Dictionary[Enemy, Array] = {}
	for i: int in range(len(targeted_enemy.turn_actions)):
		var action: EnemyActionResource = targeted_enemy.turn_actions[i]
		if action == null or not is_instance_valid(action.bound_target):
			continue
		if action.bound_target.health.health <= 0:
			continue
		if not slots_by_ship.has(action.bound_target):
			slots_by_ship[action.bound_target] = []
		slots_by_ship[action.bound_target].append(i)

	for ship: Enemy in slots_by_ship:
		var slots: Array = slots_by_ship[ship]
		for n: int in range(slots.size()):
			var slot: int = slots[n]
			var action: EnemyActionResource = targeted_enemy.turn_actions[slot]
			var marker := AnimatedSprite2D.new()
			marker.sprite_frames = die_sprites[slot].sprite_frames
			# The lit face: white, so the tint reads true.
			marker.frame = slot + 6
			marker.modulate = Globals.green \
				if action.get_binding() == EnemyActionResource.Binding.ALLY else Globals.red
			marker.position = _BOUND_MARKER_OFFSET + Vector2(
				(n - (slots.size() - 1) * 0.5) * _BOUND_MARKER_SPACING, 0
			)
			marker.z_index = 5
			ship.add_child(marker)
			_bound_markers.append(marker)


## Slot [param i]'s intent icon on the screen, and the parts hung off it.
func _intent(i: int) -> Sprite2D:
	return $Intents.get_child(i) as Sprite2D


func _intent_amount(i: int) -> RichTextLabel:
	return _intent(i).get_node("AmountLabel") as RichTextLabel


func _intent_clickable(i: int) -> Clickable:
	return _intent(i).get_node("Clickable") as Clickable


## Sends the reticle to the targeted ship. Left alone if it's already there,
## so a redraw for the same target doesn't restart its glide or its hover.
func _move_indicator() -> void:
	if targeting_indicator.visible and _indicator_ship == targeted_enemy:
		return

	_indicator_ship = targeted_enemy
	_indicator_glide_from = targeting_indicator.global_position
	_indicator_glide = 0.0
	_indicator_bob_time = 0.0
	targeting_indicator.visible = true

	if _indicator_glide_tween:
		_indicator_glide_tween.kill()
	_indicator_glide_tween = create_tween()
	_indicator_glide_tween.tween_property(self, "_indicator_glide", 1.0, _INDICATOR_GLIDE_SECONDS) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)


func _hide_indicator() -> void:
	if _indicator_glide_tween:
		_indicator_glide_tween.kill()
	_indicator_glide_tween = null
	_indicator_ship = null
	targeting_indicator.visible = false


func _process(delta: float) -> void:
	if not targeting_indicator.visible or not is_instance_valid(_indicator_ship):
		return
	if _indicator_glide >= 1.0:
		_indicator_bob_time += delta
	targeting_indicator.global_position = indicator_position()


## Where the reticle belongs this frame: partway along its glide, or hovering
## on the ship. Both are measured from where the ship is now.
func indicator_position() -> Vector2:
	var anchor: Vector2 = _indicator_ship.global_position + targeting_indicator_offset
	if _indicator_glide < 1.0:
		return _indicator_glide_from.lerp(anchor, _indicator_glide)
	# Out to the full offset and back once per period, easing at both ends.
	var swing: float = 0.5 - 0.5 * cos(TAU * _indicator_bob_time / _INDICATOR_BOB_SECONDS)
	return anchor + _INDICATOR_BOB * swing


func _startup() -> void:
	_reveal_tween()
	
	
func _reveal_tween() -> void:
	await RevealOverlay.play(%RevealOverlay, 3.0, 29.0)
