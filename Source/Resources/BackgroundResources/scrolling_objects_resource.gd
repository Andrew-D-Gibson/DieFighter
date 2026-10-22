class_name ScrollingObjectsResource
extends Resource
## A family of pieces that drift down past the cockpit at several depths:
## triangle debris, asteroids, ice. A background picks one set, and says how
## many pieces of each size to scatter.
##
## Each piece is a small scene, so it can animate or emit particles; a plain
## piece is just a Sprite2D root. ScrollingObject explains how a piece's nodes
## pick up the depth fade.

## Smaller pieces. They take the nearer, faster depths.
@export var medium_pieces: Array[PackedScene] = []
## Bigger pieces. They take the farther, slower depths.
@export var large_pieces: Array[PackedScene] = []

@export_group("Look")
## Keep each piece's own colours. Off, every piece is a flat silhouette in
## silhouette_color, the way the triangle debris has always looked.
@export var keep_texture_colors: bool = false
@export var silhouette_color: Color = Color(0.388235, 0.376471, 0.360784, 1)
## How much of a piece shows over the background colour at the farthest depth,
## and how much more each nearer depth shows. What isn't shown is background
## colour, not transparency, so stars never peek through a piece.
@export_range(0.0, 1.0) var base_visibility: float = 0.0
@export_range(0.0, 1.0) var visibility_per_depth: float = 0.1
## Draws the pieces with this instead of the plain depth fade, e.g. Fate
## eating its shards. It must take scrolling_object.gdshader's uniforms, and
## gets a fresh "seed" per piece so a field of them never moves in step.
@export var shader: Shader

@export_group("Variation")
## Turn each piece a random quarter turn. Leave off for art lit from a fixed
## direction, which would otherwise be lit from all four sides.
@export var random_quarter_turns: bool = true
