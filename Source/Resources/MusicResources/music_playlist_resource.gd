class_name MusicPlaylistResource
extends Resource
## Tracks MusicDirector plays back to back.
##
## A cue that jumps to one of these tracks moves the playlist there, so the
## sequence carries on from the track the cue picked.

@export var tracks: Array[MusicTrackResource] = []
@export var loop: bool = true


## Index of the track with this id, or -1.
func index_of(track_id: StringName) -> int:
	for i: int in tracks.size():
		if tracks[i].id == track_id:
			return i
	return -1


## The index that follows `index`, or -1 once a playlist without loop has run
## out.
func next_index(index: int) -> int:
	if tracks.is_empty():
		return -1
	if index + 1 < tracks.size():
		return index + 1
	return 0 if loop else -1
