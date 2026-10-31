class_name TileFamilyResource
extends Resource
## A group of tiles that share a mechanic, held out of offers until the player
## has unlocked it. A new player starts on the Basic tiles (every offered tile
## in no family) and gains one family each time they jump into a new sector,
## in the order tile_unlock_order.tres lists them. See TileUnlocks.
##
## A tile sits in one family. One that leans on two mechanics (a relay that
## spawns holograms) goes in whichever unlocks later, so it never arrives
## before the tiles it builds on, and its card never shows it early.

## Translation key for the family's name, shown on the unlock pop-up.
@export var family_name: String
## Translation key for one line on what the family's tiles do together.
@export_multiline var description: String
## The pop-up's frame and heading are drawn in this, so each unlock looks
## different. Take it from the approved palette.
@export var accent_color: Color = Color("#43A6FC")
@export var tiles: Array[TileResource] = []


## The filename, which the collection saves, so renaming the file loses the
## unlock for players who had it.
func id() -> String:
	return resource_path.get_file().get_basename()
