extends "res://test/helpers/die_fighter_test.gd"
## A scrolling object slot: the piece scene it swaps in must fade with the
## slot's depth, and its measured size decides where it re-enters on wrap.

const SLOT_SCENE: PackedScene = preload("res://Source/Systems/Graphics/BackgroundManager/BackgroundObjects/scrolling_object.tscn")
const TEXTURE: Texture2D = preload("res://Assets/Textures/Backgrounds/ScrollingObjects/Ice/ice_floe_1.png")


## A 24x20 sprite with a particle emitter and, 20px to its right, a second
## sprite that brings its own material.
func _piece() -> PackedScene:
	var root: Sprite2D = Sprite2D.new()
	root.texture = TEXTURE
	var sparks: CPUParticles2D = CPUParticles2D.new()
	sparks.name = "Sparks"
	root.add_child(sparks)
	sparks.owner = root
	var glow: Sprite2D = Sprite2D.new()
	glow.name = "Glow"
	glow.texture = TEXTURE
	glow.position = Vector2(20, 0)
	glow.material = CanvasItemMaterial.new()
	root.add_child(glow)
	glow.owner = root
	var packed: PackedScene = PackedScene.new()
	packed.pack(root)
	root.free()
	return packed


func _slot(quarter_turns: bool = false) -> ScrollingObject:
	var objects: ScrollingObjectsResource = ScrollingObjectsResource.new()
	var pieces: Array[PackedScene] = [_piece()]
	objects.medium_pieces = pieces
	objects.large_pieces = pieces
	objects.random_quarter_turns = quarter_turns
	var slot: ScrollingObject = SLOT_SCENE.instantiate()
	slot.setup(objects, true, Color.BLACK)
	return add_child_autofree(slot)


func test_piece_nodes_share_the_fade_unless_they_bring_a_material() -> void:
	var piece: Node = _slot().get_child(0)
	assert_true(piece.use_parent_material, "the root fades")
	assert_true(piece.get_node("Sparks").use_parent_material, "particles fade too")
	assert_false(piece.get_node("Glow").use_parent_material, "an own material opts out")


func test_bounds_cover_every_sprite() -> void:
	var slot: ScrollingObject = _slot()
	assert_eq(slot.bounds, Rect2(-12, -10, 44, 20))


func test_bounds_turn_with_the_piece() -> void:
	var slot: ScrollingObject = _slot()
	slot.rotation_degrees = 90
	slot.bounds = slot._measure(slot.get_child(0), Transform2D(slot.rotation, Vector2.ZERO))
	assert_almost_eq(slot.bounds.position, Vector2(-10, -12), Vector2.ONE * 0.01)
	assert_almost_eq(slot.bounds.size, Vector2(20, 44), Vector2.ONE * 0.01)


func test_reroll_swaps_rather_than_stacks_pieces() -> void:
	var slot: ScrollingObject = _slot()
	for i: int in range(5):
		slot.reroll()
	assert_eq(slot.get_child_count(), 1)
