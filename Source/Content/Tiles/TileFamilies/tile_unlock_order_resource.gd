class_name TileUnlockOrderResource
extends Resource
## The order tile families unlock in, first to last. Rearranging the list is
## all it takes to change it: a player who already has a family keeps it, and
## the next jump unlocks the first one in the list they don't have yet.

@export var families: Array[TileFamilyResource] = []
