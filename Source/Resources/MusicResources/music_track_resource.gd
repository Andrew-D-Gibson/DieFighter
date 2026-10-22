class_name MusicTrackResource
extends Resource
## A song for MusicDirector: one or more layers played sample-locked.
##
## A single layer is just a song. More layers let the game fade stems in and
## out while it plays (MusicDirector.set_layer_enabled()).
##
## Stream imports must have looping off, or the track never finishes and its
## playlist never moves on.

@export var id: StringName
@export var layers: Array[MusicLayerResource] = []
@export_range(-40, 20) var volume_db: float = 0.0

## Not read yet. Kept with the track for transitions that wait for the next
## bar. 0 means unknown.
@export var bpm: float = 0.0
@export var beats_per_bar: int = 4


## Index of the layer with this id, or -1.
func layer_index(layer_id: StringName) -> int:
	for i: int in layers.size():
		if layers[i].id == layer_id:
			return i
	return -1
