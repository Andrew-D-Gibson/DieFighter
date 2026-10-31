extends "res://test/helpers/die_fighter_test.gd"
## MusicDirector's sequencing and cues, on a fresh instance with short silent
## tracks. Fades and real playback were checked live (see DEVLOG.md,
## 2026-10-21); here a track "finishing" is its deck's finished signal emitted
## by hand.

const _DIRECTOR: GDScript = preload("res://Source/Systems/Autoloads/music_director.gd")

var _director: Node


func before_each() -> void:
	super()
	_director = _DIRECTOR.new()
	_director.boot_playlist = null
	add_child_autofree(_director)


func test_next_index_wraps_a_looping_playlist() -> void:
	var playlist: MusicPlaylistResource = _playlist([&"a", &"b"])
	assert_eq(playlist.next_index(0), 1)
	assert_eq(playlist.next_index(1), 0)


func test_next_index_runs_out_without_loop() -> void:
	var playlist: MusicPlaylistResource = _playlist([&"a", &"b"])
	playlist.loop = false
	assert_eq(playlist.next_index(1), -1)
	assert_eq(MusicPlaylistResource.new().next_index(0), -1, "an empty playlist has nothing next")


func test_a_playlist_starts_on_its_first_track_at_full_volume() -> void:
	_director.play_playlist(_playlist([&"a", &"b"]))
	assert_eq(_director.current_track_id(), &"a")
	assert_eq(_director.get_decks().size(), 1)
	assert_eq(_director.active_deck().get_gain(), 1.0)


func test_a_finished_track_hands_over_to_the_next_and_wraps() -> void:
	_director.play_playlist(_playlist([&"a", &"b"]))
	_finish_active()
	assert_eq(_director.current_track_id(), &"b")
	assert_eq(_director.active_deck().get_gain(), 1.0, "back to back, no fade")
	_finish_active()
	assert_eq(_director.current_track_id(), &"a")
	assert_eq(_director.get_decks().size(), 1)


func test_a_repeating_track_restarts_instead_of_handing_over() -> void:
	var playlist: MusicPlaylistResource = _playlist([&"a", &"b"])
	playlist.tracks[0].repeats = true
	_director.play_playlist(playlist)
	var deck: MusicDeck = _director.active_deck()
	_finish_active()
	assert_eq(_director.current_track_id(), &"a")
	assert_eq(_director.active_deck(), deck, "it plays again on the same deck")
	assert_true(deck.playing)
	assert_eq(_director.get_decks().size(), 1)


func test_a_playlist_without_loop_goes_quiet_at_the_end() -> void:
	var playlist: MusicPlaylistResource = _playlist([&"a"])
	playlist.loop = false
	_director.play_playlist(playlist)
	_finish_active()
	assert_eq(_director.current_track_id(), &"")
	assert_eq(_director.get_decks().size(), 0)


func test_cueing_the_playing_track_changes_nothing() -> void:
	_director.play_playlist(_playlist([&"a", &"b"]))
	var deck: MusicDeck = _director.active_deck()
	_director.play_track(&"a", 2.0)
	_director.play_track(&"a", 2.0, true)
	assert_eq(_director.active_deck(), deck, "a restart this early would only stutter")
	assert_eq(_director.get_decks().size(), 1)


func test_cueing_another_track_crossfades_and_moves_the_playlist() -> void:
	_director.play_playlist(_playlist([&"a", &"b", &"c"]))
	watch_signals(_director)
	_director.play_track(&"b", 2.0)
	assert_eq(_director.current_track_id(), &"b")
	assert_eq(_director.get_decks().size(), 2, "the old track is still fading out")
	assert_eq(_director.active_deck().get_gain(), 0.0, "the new track fades in from silence")
	assert_signal_emitted_with_parameters(_director, "track_changed", [&"b"])
	_finish_active()
	assert_eq(_director.current_track_id(), &"c", "the sequence carries on from the cued track")


func test_a_fading_out_track_finishing_does_not_move_the_playlist() -> void:
	_director.play_playlist(_playlist([&"a", &"b", &"c"]))
	var outgoing: MusicDeck = _director.active_deck()
	_director.play_track(&"b", 2.0)
	outgoing.finished.emit()
	assert_eq(_director.current_track_id(), &"b")
	assert_true(outgoing.is_queued_for_deletion())


func test_cueing_a_track_outside_the_playlist_is_an_error() -> void:
	_director.play_playlist(_playlist([&"a"]))
	_director.play_track(&"nope")
	assert_push_error("no track 'nope'")
	assert_eq(_director.current_track_id(), &"a")


func test_a_layer_turns_off_and_on() -> void:
	var track: MusicTrackResource = _track(&"a", [&"drums", &"lead"])
	var playlist: MusicPlaylistResource = MusicPlaylistResource.new()
	playlist.tracks = [track] as Array[MusicTrackResource]
	_director.play_playlist(playlist)
	var deck: MusicDeck = _director.active_deck()

	_director.set_layer_enabled(&"lead", false, 0.0)
	assert_false(deck.is_layer_enabled(1))
	assert_eq(deck.get_layer_gain(1), 0.0)
	assert_eq((deck.stream as AudioStreamSynchronized).get_sync_stream_volume(1), -80.0)
	assert_eq(deck.get_layer_gain(0), 1.0, "the other layer is untouched")

	_director.set_layer_enabled(&"lead", true, 0.0)
	assert_eq((deck.stream as AudioStreamSynchronized).get_sync_stream_volume(1), 0.0)


func test_a_layer_that_starts_off_is_silent() -> void:
	var track: MusicTrackResource = _track(&"a", [&"drums", &"lead"])
	track.layers[1].starts_enabled = false
	var playlist: MusicPlaylistResource = MusicPlaylistResource.new()
	playlist.tracks = [track] as Array[MusicTrackResource]
	_director.play_playlist(playlist)
	assert_false(_director.active_deck().is_layer_enabled(1))
	assert_eq(_director.active_deck().get_layer_gain(1), 0.0)


func test_an_unknown_layer_is_a_warning() -> void:
	_director.play_playlist(_playlist([&"a"]))
	_director.set_layer_enabled(&"nope", false)
	assert_push_warning("has no layer 'nope'")


## The trailer is cued once by the opening cutscene; after it the start theme
## comes back and holds, since the trailer is too heavy to keep coming round.
func test_the_shipped_playlist_plays_the_trailer_once_then_holds_the_start_theme() -> void:
	var playlist: MusicPlaylistResource = load("res://Source/Resources/MusicResources/Playlists/default_playlist.tres")
	assert_true(playlist.loop)
	assert_eq(playlist.index_of(&"game_start_theme"), 0, "the game always opens on the start theme")
	assert_eq(playlist.index_of(&"trailer_1"), 1)
	assert_eq(playlist.next_index(1), 0, "the trailer hands back to the start theme")
	assert_true(playlist.tracks[0].repeats, "the start theme loops")
	assert_false(playlist.tracks[1].repeats, "the trailer plays once")
	for track: MusicTrackResource in playlist.tracks:
		var wav: AudioStreamWAV = track.layers[0].stream as AudioStreamWAV
		assert_eq(wav.loop_mode, AudioStreamWAV.LOOP_DISABLED, "%s must end for the playlist to move on" % track.id)


## The opening cutscene's beat: the menu's music fades away, then the run's
## track cuts in at full volume.
func test_a_cue_after_a_stop_with_no_fade_starts_at_full_volume() -> void:
	_director.play_playlist(_playlist([&"menu", &"run"]))
	var menu: MusicDeck = _director.active_deck()
	_director.stop(1.5)
	assert_eq(_director.current_track_id(), &"", "silent while the menu fades")
	_director.play_track(&"run", 0.0)
	assert_eq(_director.current_track_id(), &"run")
	assert_eq(_director.active_deck().get_gain(), 1.0, "no fade-in")
	assert_ne(_director.active_deck(), menu)


func test_a_new_run_starts_its_music_without_a_fade_in() -> void:
	var cutscene: GDScript = load("res://Source/Scenes/Cutscenes/opening_cutscene.gd")
	assert_eq(cutscene.get_property_default_value(&"music_fade_in_seconds"), 0.0)
	assert_gt(cutscene.get_property_default_value(&"music_fade_out_seconds"), 0.0, "the menu's music still fades out first")


func _finish_active() -> void:
	_director.active_deck().finished.emit()


func _playlist(ids: Array[StringName]) -> MusicPlaylistResource:
	var playlist: MusicPlaylistResource = MusicPlaylistResource.new()
	for id: StringName in ids:
		playlist.tracks.append(_track(id, [&"full"]))
	return playlist


func _track(id: StringName, layer_ids: Array[StringName]) -> MusicTrackResource:
	var track: MusicTrackResource = MusicTrackResource.new()
	track.id = id
	for layer_id: StringName in layer_ids:
		var layer: MusicLayerResource = MusicLayerResource.new()
		layer.id = layer_id
		layer.stream = _silence()
		track.layers.append(layer)
	return track


## A tenth of a second of silence: enough to start a real playback.
func _silence() -> AudioStreamWAV:
	var wav: AudioStreamWAV = AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = 44100
	var data: PackedByteArray = PackedByteArray()
	data.resize(4410 * 2)
	wav.data = data
	return wav
