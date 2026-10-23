extends Node
## MusicDirector
## The one owner of music.
##
## Plays a MusicPlaylistResource back to back and crossfades when a cue asks
## for a different track. Scenes cue music with play_track() by track id; the
## playlist decides what follows when a track ends by itself, so a cue only
## picks where the sequence goes on from.
##
## Each playing track lives on its own MusicDeck. The newest deck is the active
## one; older decks are fading out and free themselves when silent.
##
## Starts the boot playlist itself rather than waiting for a scene, so the
## first song is the same whichever scene the game boots into.

signal track_changed(track_id: StringName)

const _DEFAULT_PLAYLIST: MusicPlaylistResource = preload("res://Source/Resources/MusicResources/Playlists/default_playlist.tres")

## A restart cue this soon after its track began would only stutter it.
const _RESTART_GRACE_SEC: float = 1.0

## Played on _ready(). Tests clear it before adding a fresh instance to the
## tree, to start from silence.
var boot_playlist: MusicPlaylistResource = _DEFAULT_PLAYLIST

var _playlist: MusicPlaylistResource
var _playlist_index: int = -1
var _active: MusicDeck


func _ready() -> void:
	# Music carries on under the pause menu.
	process_mode = Node.PROCESS_MODE_ALWAYS
	if boot_playlist:
		play_playlist(boot_playlist)


## Switches to `playlist`, starting at `start_index`.
func play_playlist(playlist: MusicPlaylistResource, start_index: int = 0, fade: float = 0.0) -> void:
	if playlist.tracks.is_empty():
		push_error("MusicDirector: playlist has no tracks")
		return
	_playlist = playlist
	_playlist_index = start_index
	_crossfade_to(playlist.tracks[start_index], fade)


## Crossfades to the current playlist's track `track_id` over `fade` seconds,
## and carries the playlist on from there. Does nothing if that track is
## already playing, unless `restart`, which starts it again from the top.
func play_track(track_id: StringName, fade: float = 2.0, restart: bool = false) -> void:
	if _active and _active.track.id == track_id:
		if not restart or _active.get_playback_position() < _RESTART_GRACE_SEC:
			return

	var index: int = _playlist.index_of(track_id) if _playlist else -1
	if index == -1:
		push_error("MusicDirector: no track '%s' in the current playlist" % track_id)
		return
	_playlist_index = index
	_crossfade_to(_playlist.tracks[index], fade)


## Fades one layer of the current track in or out.
func set_layer_enabled(layer_id: StringName, enabled: bool, fade: float = 1.0) -> void:
	if not _active:
		return
	var index: int = _active.track.layer_index(layer_id)
	if index == -1:
		push_warning("MusicDirector: track '%s' has no layer '%s'" % [_active.track.id, layer_id])
		return
	_active.set_layer_enabled(index, enabled, fade)


func stop(fade: float = 1.0) -> void:
	for deck: MusicDeck in get_decks():
		deck.retire(fade)
	if _active:
		_active = null
		track_changed.emit(&"")


func current_track_id() -> StringName:
	return _active.track.id if _active else &""


func active_deck() -> MusicDeck:
	return _active


## Every deck still sounding: the active one plus any fading out.
func get_decks() -> Array[MusicDeck]:
	var decks: Array[MusicDeck] = []
	for child: Node in get_children():
		if child is MusicDeck and not child.is_queued_for_deletion():
			decks.append(child)
	return decks


func _crossfade_to(track: MusicTrackResource, fade: float) -> void:
	var outgoing: MusicDeck = _active
	_active = MusicDeck.new()
	add_child(_active)
	_active.track_finished.connect(_on_deck_track_finished)
	_active.start(track, 0.0 if fade > 0.0 else 1.0)
	_active.fade_to(1.0, fade)

	if outgoing:
		outgoing.retire(fade)
	track_changed.emit(track.id)


## Tracks hand over back to back when one ends by itself, with no fade: the
## songs are written to end, not to blend. A repeating track restarts on its
## own deck, so any layers a cue turned off stay off.
func _on_deck_track_finished(deck: MusicDeck) -> void:
	if deck != _active:
		deck.queue_free()
		return
	if deck.track.repeats:
		deck.play()
		return

	var next: int = _playlist.next_index(_playlist_index) if _playlist else -1
	if next == -1:
		stop(0.0)
		return
	_playlist_index = next
	_crossfade_to(_playlist.tracks[next], 0.0)
