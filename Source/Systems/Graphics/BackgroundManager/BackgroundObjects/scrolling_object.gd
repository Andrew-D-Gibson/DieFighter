class_name ScrollingObject
extends Node2D
## One slot of a ScrollingObjectsResource drifting past the cockpit. It holds
## one piece scene at a time, and each time it wraps back to the top it swaps
## in a fresh piece at a fresh depth.
##
## The depth fade lives in this node's material. Every canvas item in a piece
## that has no material of its own is switched over to it, so sprites,
## animations and particles all fade into the background colour together. A
## node that brings its own material keeps it, and so opts out of the fade.

@export var min_velocity_delta: float = 2.0

var objects: ScrollingObjectsResource
var is_medium: bool = true
var velocity_delta: float = 0
## The current piece's drawn area around this node's position, turn included.
## Only sprites are measured; particles may spill past it.
var bounds: Rect2 = Rect2()

var _piece: Node = null


func setup(new_objects: ScrollingObjectsResource, medium: bool, background_color: Color) -> void:
	objects = new_objects
	is_medium = medium
	material.set_shader_parameter("background_color", background_color)
	material.set_shader_parameter("color", objects.silhouette_color)
	material.set_shader_parameter("keep_texture_colors", objects.keep_texture_colors)
	material.set_shader_parameter("base_visibility", objects.base_visibility)
	material.set_shader_parameter("visibility_per_depth", objects.visibility_per_depth)
	reroll()


func reroll() -> void:
	pick_random_piece()
	pick_random_velocity_delta()


func pick_random_piece() -> void:
	if _piece:
		remove_child(_piece)
		_piece.queue_free()
		_piece = null

	var pieces: Array[PackedScene] = objects.medium_pieces if is_medium else objects.large_pieces
	var scene: PackedScene = RNGManager.pick_random(RNGManager.Bucket.BACKGROUND, pieces)
	if not scene:
		bounds = Rect2()
		return

	rotation_degrees = 0
	if objects.random_quarter_turns:
		rotation_degrees = RNGManager.pick_random(RNGManager.Bucket.BACKGROUND, [0, 90, 180, 270])

	_piece = scene.instantiate()
	_share_material(_piece)
	add_child(_piece)
	bounds = _measure(_piece, Transform2D(rotation, Vector2.ZERO))


func pick_random_velocity_delta() -> void:
	var velocity_level: int

	if is_medium:
		velocity_level = RNGManager.randi_range(RNGManager.Bucket.BACKGROUND, 2, 4)
	else:
		velocity_level = RNGManager.randi_range(RNGManager.Bucket.BACKGROUND, 1, 2)

	velocity_delta = velocity_level * min_velocity_delta

	material.set_shader_parameter("velocity_level", velocity_level)
	z_index = 3 + velocity_level


func _share_material(node: Node) -> void:
	if node is CanvasItem and not (node as CanvasItem).material:
		(node as CanvasItem).use_parent_material = true
	for child: Node in node.get_children():
		_share_material(child)


## [param to_slot] carries [param node]'s parent space into this node's
## parent space, less the translation, so the result sits around position.
func _measure(node: Node, to_slot: Transform2D) -> Rect2:
	if node is Node2D:
		to_slot = to_slot * (node as Node2D).transform

	var rect: Rect2 = Rect2()
	var drawn: Rect2 = _drawn_rect(node)
	if drawn.has_area():
		rect = to_slot * drawn

	for child: Node in node.get_children():
		var child_rect: Rect2 = _measure(child, to_slot)
		if not child_rect.has_area():
			continue
		rect = child_rect if not rect.has_area() else rect.merge(child_rect)
	return rect


func _drawn_rect(node: Node) -> Rect2:
	if node is Sprite2D:
		return (node as Sprite2D).get_rect()

	if node is AnimatedSprite2D:
		var animated: AnimatedSprite2D = node as AnimatedSprite2D
		if not animated.sprite_frames or not animated.sprite_frames.has_animation(animated.animation):
			return Rect2()
		var frame: Texture2D = animated.sprite_frames.get_frame_texture(animated.animation, animated.frame)
		if not frame:
			return Rect2()
		var size: Vector2 = frame.get_size()
		var top_left: Vector2 = -size / 2 if animated.centered else Vector2.ZERO
		return Rect2(top_left + animated.offset, size)

	return Rect2()
