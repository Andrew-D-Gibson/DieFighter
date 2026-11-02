class_name CaravanShipKind
extends Resource
## One kind of ship in the main menu's caravan: which sprite it borrows and
## how its lights read once it's too far away for the sprite to.

## A combat sprite, drawn as the game draws it: facing down, engines at the top.
@export var texture: Texture2D
## How often this kind turns up, relative to the others.
@export var weight: float = 1.0
## Where the engines are on [member texture], in its pixels. Only ships flying
## away show their engines, so leave this empty for a ship coming back.
@export var engine_points: PackedVector2Array
@export var engine_color: Color = Color("#8DF1F4")
## The running light left blinking once the hull is down to a few pixels.
@export var beacon_color: Color = Color("#7ABD33")
## Which side of the column this kind keeps to, from -1 (left of the route)
## to 1 (right). Escorts fly the flanks; everyone else crowds the middle.
@export var lane_range: Vector2 = Vector2(-0.5, 0.5)
## Mirrors [member lane_range] onto the other side of the column half the time.
@export var either_flank: bool = false
## Flies the route backwards, toward Fate and the player, nose first.
@export var flies_toward_fate: bool = false
