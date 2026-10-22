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

@onready var body: ColorRect = $Body


func _ready() -> void:
	var material: ShaderMaterial = body.material as ShaderMaterial
	# One shader pixel per screen pixel, whatever size the rect was given.
	material.set_shader_parameter("pixel_scale", body.size.x)
	if randomize_face:
		material.set_shader_parameter(
			"surface_base_rotation",
			RNGManager.randf_range(RNGManager.Bucket.COSMETIC, 0.0, TAU)
		)
