class_name MusicLayerResource
extends Resource
## One stem of a MusicTrackResource.
##
## Every layer of a track plays sample-locked with the others, so stems must be
## exported at the same length from the same project. A layer that starts off
## still plays, silently, so turning it on later lands in time.

@export var id: StringName
@export var stream: AudioStream
@export_range(-40, 20) var volume_db: float = 0.0
@export var starts_enabled: bool = true
