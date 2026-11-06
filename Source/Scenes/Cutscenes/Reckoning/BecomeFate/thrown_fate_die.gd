extends FateDieSpin
## Fate's Die, thrown once (RECKONING_ENDINGS.md §6.5, Become Fate, step 6):
## the cube the first ending turned in the light, here tumbling one whole
## turn in the dark and coming to rest with one face square to the viewer,
## the way a thrown die lands. Before it's thrown it turns as FateDieSpin
## does.

## How far through the throw it is: 0 just thrown, 1 at rest on its face.
## Past 1 (an easing's overshoot) it rocks on past the face and back.
## Negative: not thrown yet.
var throw_progress: float = -1.0

## The rest pose: the landing side square to the viewer, tipped a little so
## the top and left sides still show and it reads as a cube.
var _landing: Basis = Basis.IDENTITY
## What it tumbles round: across the picture and a little off it, so the
## tumble shows more than one side going by.
var _axis: Vector3 = Vector3(1.0, 0.3, 0.15).normalized()

const _REST_TIP: Vector3 = Vector3(0.3, -0.4, 0.0)


## Shows [param faces] on the cube's sides, one per side. Call once it's in
## the tree.
func show_faces(faces: Array[FateDie.Face]) -> void:
	for side: int in mini(faces.size(), _SIDES.size()):
		_set_face(side, faces[side])


## Throws it to land on [param side]. Drive [member throw_progress] from 0
## to 1 to play the throw.
func throw_onto(side: int) -> void:
	var normal: Vector3 = _SIDES[side][0]
	var up: Vector3 = _SIDES[side][1]
	# The side's own frame, transposed, turns it to face the viewer upright.
	var side_frame: Basis = Basis(up.cross(normal), up, normal)
	_landing = Basis.from_euler(_REST_TIP) * side_frame.transposed()
	throw_progress = 0.0


func _turn(delta: float) -> void:
	if throw_progress < 0.0:
		super(delta)
		return
	_pivot.basis = Basis(_axis, (1.0 - throw_progress) * TAU) * _landing
