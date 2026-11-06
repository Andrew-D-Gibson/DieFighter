extends Node2D
## The small Fate's Die as it hangs over "You" and then from the canopy, for the
## Become Fate cutscene's first shot (RECKONING_ENDINGS.md §6.5, steps 1-2): the
## same canopy-sized FateDieSpin FateSelfDie shows in the fight (glyph_scale 1,
## palette-snapped, nearest filtered), carrying the run's carved faces.
##
## It is held still (the die above "You" has stopped turning) until the shot
## sends it home; fly_turn() then turns it once on the way, and it arrives on
## the face it last showed. FateSelfDie needs a live Enemy to follow, so this
## reuses its recipe (and FateDieSpin) rather than the node.

const _SNAP_SHADER: Shader = preload("res://Assets/Shaders/palette_snap.gdshader")

## A landed face shows square-ish but tipped, top and left sides in view, so it
## still reads as a cube; the same tip FateSelfDie rests in.
static var _tilt: Quaternion = Basis.from_euler(Vector3(0.4, 0.55, 0.0)).get_rotation_quaternion()

var _spin: FateDieSpin
var _sprite: Sprite2D
var _rest: Quaternion = Quaternion.IDENTITY
var _age: float = 0.0
var _flight: float = 0.0


func _ready() -> void:
	_spin = FateDieSpin.new()
	_spin.glyph_scale = 1
	_spin.turning = false
	add_child(_spin)
	_sprite = Sprite2D.new()
	_sprite.texture = _spin.get_texture()
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var snap: ShaderMaterial = ShaderMaterial.new()
	snap.shader = _SNAP_SHADER
	_sprite.material = snap
	add_child(_sprite)
	_rest = _tilt * FateDieSpin.facing(0)
	_apply()


## Puts [param faces] on the cube, one per side (a die's slots), and holds it
## showing the first carved one.
func show_faces(faces: Array[FateDie.Face]) -> void:
	_spin.show_faces(faces)
	var side: int = 0
	for slot: int in faces.size():
		if faces[slot] != FateDie.Face.BLANK:
			side = slot
			break
	_rest = _tilt * FateDieSpin.facing(side)
	_apply()


## How far through its flight home it is, 0 to 1: one slow turn about the
## upright, ending where it began.
func fly_turn(progress: float) -> void:
	_flight = progress
	_apply()


func _process(delta: float) -> void:
	_age += delta
	_apply()


func _apply() -> void:
	if _spin == null:
		return
	# A breath of wobble, so a held die still reads as solid; it fades while
	# the die turns, which has movement enough.
	var breath: float = 1.0 - clampf(_flight * 4.0, 0.0, 1.0)
	var wobble: Quaternion = Basis.from_euler(Vector3(
		sin(_age * 1.1) * 0.05, sin(_age * 0.8) * 0.07, 0.0) * breath).get_rotation_quaternion()
	var turn: Quaternion = Quaternion(Vector3.UP, -TAU * _flight)
	_spin.set_orientation(wobble * turn * _rest)
