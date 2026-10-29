class_name Draggable
extends Area2D

const _HOVER_THUMP_SFX: SoundEffectResource = preload("res://Source/Resources/SoundEffectResources/SoundEffects/hover_thump.tres")

signal drag_started()
signal drag_ended(draggable: Draggable, end_position: Vector2)
signal reached_new_home()

enum DragState {
	DEFAULT,
	ENEMY_HOLDING,
	MOVING_WITH_CODE,
	DRAGGING
}
var state: DragState = DragState.DEFAULT

## How the player moves things about, an option shared by every Draggable.
## DRAG is press, hold and let go over the target. CLICK picks a thing up with
## one click and puts it down with the next, for trackpads, tired hands and
## a gamepad's virtual cursor, which sends plain mouse clicks.
enum PlacementMode { DRAG, CLICK }
static var placement_mode: PlacementMode = PlacementMode.DRAG

## True while a click has picked this up. The button isn't held in between, so
## the next press puts it down (see _input) instead of the release.
var _carried: bool = false
## Where the click that picked this up landed. A second click there, without
## the cursor having gone anywhere, asks for the thing's info instead.
var _picked_up_at: Vector2

## Whatever the player has in hand, dragged or carried, or null. Only one
## thing is ever held, so the cursor can dress itself from this alone.
static var held: Draggable = null

@export var dragging_allowed: bool = true:
	set(new_value):
		dragging_allowed = new_value
		floating_enabled = dragging_allowed

var follow_strength: float = 20
## While true, code is carrying the parent between holders across frames
## (Dice.hand_off_after_death()): it's left where the code puts it whatever
## the state says, since a holder resets the state as it arranges its dice,
## and it can't be picked up.
var held_by_code: bool = false
var home_position: Vector2
## Set by set_home() when the parent's next arrival home should be announced.
var _announce_arrival: bool = false
var tween: Tween

# --- Floating Behavior ---
@export var floating_enabled: bool = true:
	set(new_enabled_state):
		floating_enabled = new_enabled_state
		
		if not floating_enabled and get_parent():
			get_parent().rotation = 0
			
		if floating_enabled:
			_floating_time = RNGManager.randf(RNGManager.Bucket.COSMETIC) * TAU

# --- Adjustable floating parameters ---
@export var bob_amplitude: float = 4.0   # Max vertical movement in pixels
@export var bob_speed: float = 1.0       # How fast it bobs up and down
@export var drift_amplitude: float = 3.0 # Max horizontal drift in pixels
@export var drift_speed: float = 0.5     # How fast it drifts left/right

# --- Internal floating variables ---
var _floating_time: float = 0.0


func _ready() -> void:
	# Listening to every click only matters while something is carried.
	set_process_input(false)
	if not home_position:
		home_position = global_position

		
		
## Moves where the parent floats back to. With [param announce_arrival],
## reached_new_home fires once it settles there: a tile landing in a new grid
## cell thumps, while one placed by code just appears.
func set_home(new_home: Vector2, announce_arrival: bool = false) -> void:
	if announce_arrival and new_home != home_position:
		_announce_arrival = true
	home_position = new_home


func _process(delta: float) -> void:
	# Code took a carried thing out of the player's hands (an enemy grabbed
	# the die, the ship stood down): the next click is no longer a drop.
	if _carried and state != DragState.DRAGGING:
		_stop_carrying()

	# Don't handle moving the draggable object if it's being moved with code
	if state == DragState.MOVING_WITH_CODE or held_by_code:
		return
						
	# Handle moving the object with the mouse
	if state == DragState.DRAGGING:
		get_parent().global_position = lerp(global_position, get_global_mouse_position(), follow_strength * delta)
		
		# Handle dropping this object if the mouse is no longer down. A
		# carried one waits for the next click instead.
		if not _carried and not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
			_end_drag(get_global_mouse_position())
		return
	
	if _announce_arrival \
	and state == DragState.DEFAULT \
	and get_parent().global_position.distance_to(home_position) < 2:
		if not floating_enabled:
			get_parent().global_position = home_position
		_announce_arrival = false
		reached_new_home.emit()
		
	if state == DragState.DEFAULT and global_position.distance_to(home_position) < 4 and floating_enabled:
		_floating_time += delta
	
		var bob_offset: float = sin(_floating_time * bob_speed) * bob_amplitude
		var drift_offset: float = sin(_floating_time * drift_speed + 1.5) * drift_amplitude
		get_parent().global_position = lerp(global_position, home_position + Vector2(drift_offset, bob_offset), follow_strength * delta * 0.2)
	else:
		get_parent().global_position = lerp(global_position, home_position, follow_strength * delta)
	

func _on_input_event(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	if dragging_allowed and state == DragState.DEFAULT and not held_by_code \
	and event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		state = DragState.DRAGGING
		Globals.mouse_is_dragging_something = true
		
		var parent_node: Node2D = get_parent()
		
		# Reset the info cursor if needed
		if parent_node.has_node("Clickable") and parent_node.clickable:
			parent_node.clickable.reset_hover_state()
		
		# Move the parent's render index to be above where it usually sits
		parent_node.z_index += 10
		parent_node.scale = Vector2(1.3,1.3)
		
		# Set the parent to wiggle a bit
		parent_node.rotation_degrees = 0
		if tween:
			tween.kill()
		var tween_time: float = 0.5
		tween = create_tween()
		tween.tween_property(parent_node, "global_rotation_degrees", 3, tween_time).set_trans(Tween.TRANS_SINE)
		tween.tween_property(parent_node, "global_rotation_degrees", 0, tween_time).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		tween.tween_interval(tween_time)
		tween.tween_property(parent_node, "global_rotation_degrees", -3, tween_time).set_trans(Tween.TRANS_SINE)
		tween.tween_property(parent_node, "global_rotation_degrees", 0, tween_time).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		tween.tween_interval(tween_time)
		tween.set_loops()

		if placement_mode == PlacementMode.CLICK:
			_carried = true
			_picked_up_at = _global_position_of(event as InputEventMouseButton)
			set_process_input(true)
		held = self
		
		drag_started.emit()


## Puts a carried thing down on the next click, wherever that is: on a target
## it lands as if dragged there, and anywhere else the usual drop rules apply.
## A right click or cancel puts it straight back where it came from. Either
## click is used up here, so it can't also press a button or pick up what's
## underneath.
##
## A click is also how a tile shows its info. The one that picks it up doesn't
## (Clickable leaves a carried owner alone), so clicking it again in place, the
## click-mode twin of a drag that never moved, shows it instead.
func _input(event: InputEvent) -> void:
	if not _carried or state != DragState.DRAGGING:
		return
	var click: InputEventMouseButton = event as InputEventMouseButton
	if click and click.pressed and click.button_index == MOUSE_BUTTON_LEFT:
		get_viewport().set_input_as_handled()
		var at: Vector2 = _global_position_of(click)
		var clickable: Clickable = _parent_clickable()
		if clickable and at.distance_to(_picked_up_at) <= clickable.click_movement_radius:
			put_back()
			# Its release mustn't count as a click of its own.
			clickable.click_time_remaining = 0.0
			clickable.clicked.emit()
		else:
			_end_drag(at)
	elif (click and click.pressed and click.button_index == MOUSE_BUTTON_RIGHT) \
	or event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		put_back()


## Ends a drag or carry by dropping the thing where it came from. Every drop
## handler already treats that as no move (a tile back on its own cell, an
## offer back on its shelf, a die back in the hand), so it's a cancel that
## still lets them tidy up after the drag.
func put_back() -> void:
	if state == DragState.DRAGGING:
		_end_drag(home_position)


## Lets go at [param end_position]: squares the parent back up, then lets the
## drop handlers decide what landing there means.
func _end_drag(end_position: Vector2) -> void:
	state = DragState.DEFAULT
	_stop_carrying()
	if held == self:
		held = null
	Globals.mouse_is_dragging_something = false
	
	var parent_node: Node2D = get_parent()
	
	# Stop the wiggle tween
	if tween:
		tween.kill()
	parent_node.rotation_degrees = 0

	# Move the parent's render index back to its original
	parent_node.z_index -= 10
	parent_node.scale = Vector2(1, 1)
	
	drag_ended.emit(self, end_position)


func _parent_clickable() -> Clickable:
	var parent_node: Node = get_parent()
	if parent_node.has_node("Clickable"):
		return parent_node.get("clickable") as Clickable
	return null


func _stop_carrying() -> void:
	_carried = false
	set_process_input(false)


## Where [param click] landed in the world. Read from the event rather than
## the mouse, so a click sent by a virtual cursor lands where it says.
func _global_position_of(click: InputEventMouse) -> Vector2:
	return get_canvas_transform().affine_inverse() * click.position


## Whether this was picked up by a click and is waiting for the click that
## puts it down.
func is_carried() -> bool:
	return _carried


## Whether the player has something in hand right now: [member held], if it
## is still being dragged or carried. Code can take a held thing away without
## a drop (an enemy grabs the die), so the state is checked, not just the
## reference.
static func holding() -> Draggable:
	if is_instance_valid(held) and held.state == DragState.DRAGGING:
		return held
	return null


## Whether a click now would put this back and show its info rather than
## move it: it was lifted by a click, it has info to show, and the pointer
## is still where that click landed. See _input().
func is_over_info_spot() -> bool:
	if not _carried or state != DragState.DRAGGING:
		return false
	var clickable: Clickable = _parent_clickable()
	if not clickable:
		return false
	var pointer: Vector2 = get_canvas_transform().affine_inverse() * InputManager.pointer_position(get_viewport())
	return pointer.distance_to(_picked_up_at) <= clickable.click_movement_radius


func _on_mouse_entered() -> void:
	# Only scale on hover if not currently dragging
	if dragging_allowed and state == DragState.DEFAULT and not Globals.mouse_is_dragging_something:
		Events.play_sound.emit(_HOVER_THUMP_SFX)
		
		var parent: Node = get_parent()
		if parent is Dice and parent.host_queue and parent.host_queue.get_parent() is Tile:
			return
			
		get_parent().scale = Vector2(1.15, 1.15)


func _on_mouse_exited() -> void:
	# Reset scale when mouse exits, but only if not dragging
	if state == DragState.DEFAULT:
		var parent: Node = get_parent()
		if parent is Dice and parent.host_queue and parent.host_queue.get_parent() is Tile:
			return
			
		get_parent().scale = Vector2(1, 1)
