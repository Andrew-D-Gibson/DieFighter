class_name TargetingComputer
extends Node2D

## Both target arrows are out and live: the player can switch targets with them.
signal shift_buttons_live

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

## Arcs from the targeted enemy to each ship its slots are bound to: "on a
## 1, the Tender repairs *that* one". See BoundIntentArrow.
var _bound_arrows: Array[BoundIntentArrow] = []

## Intents no die is lighting sit back so the live ones stand out.
const _DIMMED_INTENT: Color = Color(1.0, 1.0, 1.0, 0.45)
## A silenced intent (Counter-Battery) keeps its icon, greyed and crossed out,
## so the player can see what they cancelled.
const _SILENCED_INTENT: Color = Color(0.45, 0.45, 0.45, 1.0)
const _SILENCED_MARK: Texture2D = preload("res://Assets/Textures/Enemies/IntentIndicator/silenced.png")

## The ship acting right now and the slot it's playing. The die leaves its hand
## as the action starts, but the intent stays lit until the action's effects
## have all played out, so the player can read what is happening to them.
var _acting_enemy: Enemy
var _acting_slot: int = -1

## Clicking the portrait has the targeted ship say its last line again. This
## is the ship the portrait is listening to.
var _comms_ship: Enemy

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
	Events.enemy_intents_changed.connect(func(ship: Enemy) -> void:
		if ship == targeted_enemy:
			_update_ui()
	)
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
	# A civilian turning hostile (or a raider standing down) recolours the
	# computer straight away, not at the next redraw.
	Events.ship_scenario_state_changed.connect(func(ship: Enemy) -> void:
		if ship == targeted_enemy:
			_show_attitude()
	)

	Events.jump.connect(_target_nothing)

	Events.targeting_computer_startup.connect(_startup)
	Events.cockpit_snap_online.connect(func() -> void:
		%RevealOverlay.hide()
	)

	%CommsButton.clicked.connect(_on_comms_clicked)
	_listen_for_comms()

	%LeftShiftButton.pushed.connect(_shift_target.bind(-1))
	%RightShiftButton.pushed.connect(_shift_target.bind(1))
	for button: TargetShiftButton in _shift_buttons():
		button.extended.connect(_on_shift_button_extended)

	%RevealOverlay.material = %RevealOverlay.material.duplicate()
	%RevealOverlay.material.set_shader_parameter("progress", 0.0)

	ensure_target()
	
	

## Targets the first ship if nothing is targeted yet.
func ensure_target() -> void:
	if !targeted_enemy:
		targeted_enemy_index = 0
		check_target_is_valid()
	else:
		# A second ship arriving gives the player a choice to make.
		refresh_shift_buttons()
		

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
	_listen_for_comms()
	if previous == targeted_enemy:
		return
	_reset_icon_tweens()


## Points the portrait's comms at the targeted ship.
func _listen_for_comms() -> void:
	var ship: Enemy = targeted_enemy if is_instance_valid(targeted_enemy) else null
	if ship != _comms_ship:
		if is_instance_valid(_comms_ship) \
		and _comms_ship.dialogue_manager.line_shown.is_connected(_on_target_spoke):
			_comms_ship.dialogue_manager.line_shown.disconnect(_on_target_spoke)
		_comms_ship = ship
		if ship:
			ship.dialogue_manager.line_shown.connect(_on_target_spoke)
	_refresh_comms()


func _has_comms() -> bool:
	return is_instance_valid(_comms_ship) and _comms_ship.dialogue_manager.has_line_to_replay()


## Clickable while there's a line to replay; no hover when there isn't.
func _refresh_comms() -> void:
	_set_intent_clickable(%CommsButton, _has_comms())
	# The intents' clickables show info on hover; this one only replays.
	%CommsButton.hover_for_info = false


func _on_target_spoke() -> void:
	_refresh_comms()


func _on_comms_clicked() -> void:
	if _has_comms():
		_comms_ship.dialogue_manager.replay_last_line()


func _reset_icon_tweens() -> void:
	for i: int in range(intent_scale_tweens.size()):
		if intent_scale_tweens[i]:
			intent_scale_tweens[i].kill()
			intent_scale_tweens[i] = null
		_intent(i).scale = Vector2.ONE
	

func _unhandled_input(event: InputEvent) -> void:
	# The keys push the matching button too, so the player sees which way the
	# target went.
	if event.is_action_pressed('target_left'):
		%LeftShiftButton.press()
		_shift_target(-1)

	if event.is_action_pressed('target_right'):
		%RightShiftButton.press()
		_shift_target(1)


## Steps the target [param step] ships along the roster, wrapping at the ends.
func _shift_target(step: int) -> void:
	targeted_enemy_index += step
	check_target_is_valid()


func _shift_buttons() -> Array[TargetShiftButton]:
	return [%LeftShiftButton, %RightShiftButton]


## The arrows are only out while there's another ship to switch to, and the
## tutorial isn't holding them back (Globals.tutorial_holds_target_arrows).
func refresh_shift_buttons() -> void:
	var has_choice: bool = is_instance_valid(targeted_enemy) and Globals.enemy_manager != null \
		and Globals.enemy_manager.get_alive_enemies().size() > 1
	if Globals.tutorial_holds_target_arrows:
		has_choice = false
	for button: TargetShiftButton in _shift_buttons():
		if has_choice:
			button.deploy()
		else:
			button.stow()


## They slide out pushed in, and pop up together once both are out.
func _on_shift_button_extended() -> void:
	var buttons: Array[TargetShiftButton] = _shift_buttons()
	if buttons.all(func(button: TargetShiftButton) -> bool: return button.is_extended()):
		for button: TargetShiftButton in buttons:
			button.pop_up()
		shift_buttons_live.emit()


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
	refresh_shift_buttons()
	_show_bound_arrows()
	_show_attitude()
	if !targeted_enemy or targeted_enemy_index == -1:
		_hide_indicator()
		
		$TargetImage.texture = null
		for i: int in range(6):
			_intent(i).texture = null
			_intent_amount(i).text = ''
			
			# De-highlight the die sprites
			die_sprites[i].frame = i
			_intent(i).modulate = Color.WHITE
			_show_silenced(i, false)
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
				_show_silenced(i, targeted_enemy.turn_actions[i].silenced_action != null)

				# Change over the info on clicking this particular action indicator 
				var clickable: Clickable = _intent_clickable(i)
				Utils.disconnect_all_callables(clickable.clicked)
				clickable.clicked.connect(targeted_enemy.turn_actions[i].show_info)
				_set_intent_clickable(clickable, targeted_enemy.turn_actions[i].name != "")
			else:
				_intent(i).texture = unknown_intent_indicator
				_intent(i).modulate = Color.WHITE
				_show_silenced(i, false)
				_intent_amount(i).text = ""
				Utils.disconnect_all_callables(_intent_clickable(i).clicked)
				_set_intent_clickable(_intent_clickable(i), false)
				
				
		$TargetImageFill.z_index = 1
		$TargetImageFill.frame = 0
		await $TargetImageFill.animation_looped
		# A later redraw owns the fill now; with no target it has to stay up.
		if generation == _redraw_generation:
			$TargetImageFill.z_index = -2


func _show_attitude() -> void:
	var ship: Enemy = targeted_enemy if is_instance_valid(targeted_enemy) and targeted_enemy_index != -1 else null
	%AttitudeDisplay.show_ship(ship)


## Lights slot [param i]'s die face and intent when the targeted enemy holds
## that value or is playing that slot now, dims them otherwise.
func _set_intent_highlight(i: int) -> void:
	var lit: bool = is_slot_live(targeted_enemy, i)
	die_sprites[i].frame = i + 6 if lit else i
	_intent(i).modulate = Color.WHITE if lit else _DIMMED_INTENT


## Whether [param ship]'s slot [param i] is in play: it holds that die, or
## is playing that slot right now.
func is_slot_live(ship: Enemy, i: int) -> bool:
	if not is_instance_valid(ship):
		return false
	return ship.dice_manager.has_value(i + 1) or (ship == _acting_enemy and i == _acting_slot)


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


func _show_bound_arrows() -> void:
	for arrow: BoundIntentArrow in _bound_arrows:
		if is_instance_valid(arrow):
			arrow.queue_free()
	_bound_arrows.clear()

	if not targeted_enemy or not is_instance_valid(targeted_enemy):
		return
	if not Globals.state_manager or not Globals.state_manager.enemy_intents_visible():
		return

	# Slots bound to the same ship share one arc and its one badge.
	var arrows_by_ship: Dictionary[Enemy, BoundIntentArrow] = {}
	for i: int in range(len(targeted_enemy.turn_actions)):
		var action: EnemyActionResource = targeted_enemy.turn_actions[i]
		if action == null or not is_instance_valid(action.bound_target):
			continue
		if action.bound_target.health.health <= 0:
			continue
		var ship: Enemy = action.bound_target
		if not arrows_by_ship.has(ship):
			var arrow: BoundIntentArrow = BoundIntentArrow.new()
			arrow.source = targeted_enemy
			arrow.target = ship
			arrow.hostile = action.get_binding() != EnemyActionResource.Binding.ALLY
			arrow.is_live = is_slot_live
			# Over the ships, with the reticle.
			arrow.z_index = targeting_indicator.z_index
			add_child(arrow)
			arrows_by_ship[ship] = arrow
			_bound_arrows.append(arrow)
		arrows_by_ship[ship].slots.append(i)


## Greys slot [param i]'s icon and crosses it out while [param silenced]. The
## mark is made the first time a slot needs it.
func _show_silenced(i: int, silenced: bool) -> void:
	var intent: Sprite2D = _intent(i)
	intent.self_modulate = _SILENCED_INTENT if silenced else Color.WHITE
	var mark: Sprite2D = intent.get_node_or_null(^"SilencedMark") as Sprite2D
	if mark == null:
		if not silenced:
			return
		mark = Sprite2D.new()
		mark.name = &"SilencedMark"
		mark.texture = _SILENCED_MARK
		intent.add_child(mark)
	mark.visible = silenced


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


## The screen area the reticle covers while it hovers on [param ship], its
## whole bob included.
func indicator_reach(ship: Enemy) -> Rect2:
	var size: Vector2 = targeting_indicator.texture.get_size() if targeting_indicator.texture else Vector2.ZERO
	var corner: Vector2 = ship.global_position + targeting_indicator_offset - size / 2.0
	return Rect2(corner, size + _INDICATOR_BOB)


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
