class_name BackgroundResource
extends Resource

@export var background_color: Color

@export_category('Global Modifier')
## A rule that holds for as long as the player occupies this background, e.g.
## "no ship can raise shields". Leave null for plain, unmodified space.
@export var global_modifier: BackgroundModifierResource

@export_category('Timed Hazard')
## An event that counts down and fires during every fight here, e.g. the
## region's star flaring. Leave null for space where nothing goes off.
## Mutually exclusive with global_modifier.
@export var hazard: BackgroundHazardResource

@export_category('Nebula')
@export var nebula: bool
@export var nebula_color: Color
## Replaces the standard nebula's look for a place whose sky is its own
## weather, e.g. the ion storm's charged front. The shader must take
## sprite_nebula.gdshader's uniforms (uv_offset, nebula_color). Leave null for
## the standard one-colour nebula.
@export var nebula_material: ShaderMaterial

@export_category('Stars')
@export var stars: bool
@export var num_of_stars: int
@export var num_of_twinkling_stars: int

@export_category('Scrolling Objects')
## What drifts past at varying depths: debris, asteroids, ice. Leave null for
## space with nothing in it.
@export var scrolling_objects: ScrollingObjectsResource
@export var num_of_med_pieces: int
@export var num_of_large_pieces: int

@export_category('Static Objects')
## Set pieces placed by hand, like a star or a wreck. Things that only drift by
## belong in scrolling_objects. Always placed exactly as authored; planets and
## stars that should move between visits go in set_piece_compositions.
@export var static_objects: Array[StaticBackgroundObjectResource] = []
## Alternative arrangements of the background's planets and stars. One is
## picked (by weight, from the BACKGROUND bucket) each time the background is
## shown, then jittered and maybe mirrored, on top of static_objects.
@export var set_piece_compositions: Array[SetPieceComposition] = []


## Whether anything in this background holds still or drifts past on its own:
## set pieces of any kind or scrolling objects. With either on screen the
## stars hold still too, so they don't slide past a planet the ship is parked
## beside, or race debris that is doing the drifting. [param composition] is
## the arrangement actually on screen, if any.
func anchors_the_view(composition: SetPieceComposition = null) -> bool:
	if scrolling_objects or not static_objects.is_empty():
		return true
	return composition != null and not composition.objects.is_empty()
