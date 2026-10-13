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

@export_category('Stars')
@export var stars: bool
@export var num_of_stars: int
@export var num_of_twinkling_stars: int

@export_category('Triangle Debris')
@export var debris: bool
@export var num_of_med_pieces: int
@export var num_of_large_pieces: int

@export_category('Static Objects')
@export var static_objects: Array[StaticBackgroundObjectResource] = []
