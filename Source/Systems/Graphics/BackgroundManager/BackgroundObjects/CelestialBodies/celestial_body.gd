class_name CelestialBody
extends Node2D
## A planet or star drawn live by pixel_planet.gdshader, for a background's
## static objects.
##
## The look lives entirely in the Body rect's ShaderMaterial; this only keeps
## the shader honest about the rect it's drawn on. Each design is its own
## scene under CelestialBodies/, so tune one by opening it and editing the
## material.

## Turn each copy to a random face, so a planet met twice isn't stamped out
## identically. Off for a body whose features are placed by hand.
@export var randomize_face: bool = true

## Set before the body enters the tree. The face to turn to, in radians; left
## negative, a random one is drawn from the COSMETIC bucket. BackgroundManager
## passes one rolled from the background's layout so a seed reproduces it.
var face: float = -1.0
## Set before the body enters the tree. Scales the disc, which stays an even
## number of whole pixels across so it still centres on a pixel.
var size_scale: float = 1.0
## Set before the body enters the tree. Raises (+) or lowers (-) the sun,
## turning the terminator. The shader's sun_direction.z points down screen.
var light_tilt: float = 0.0

@onready var body: ColorRect = $Body


func _ready() -> void:
	var material: ShaderMaterial = body.material as ShaderMaterial
	var diameter: float = body.size.x
	if not is_equal_approx(size_scale, 1.0):
		diameter = _resize(diameter * size_scale)
	# One shader pixel per screen pixel, whatever size the rect was given.
	material.set_shader_parameter("pixel_scale", diameter)
	if not is_zero_approx(light_tilt):
		var sun: Vector3 = material.get_shader_parameter("sun_direction")
		material.set_shader_parameter("sun_direction", sun - Vector3(0.0, 0.0, light_tilt))
	if randomize_face:
		var turn: float = face
		if turn < 0.0:
			turn = RNGManager.randf_range(RNGManager.Bucket.COSMETIC, 0.0, TAU)
		material.set_shader_parameter("surface_base_rotation", turn)


## Re-centres the rect on the node at [param wanted] pixels across, rounded to
## an even number. Returns the diameter used.
func _resize(wanted: float) -> float:
	var half: float = maxf(roundf(wanted * 0.5), 2.0)
	body.offset_left = -half
	body.offset_top = -half
	body.offset_right = half
	body.offset_bottom = half
	return half * 2.0
