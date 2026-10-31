extends "res://test/helpers/die_fighter_test.gd"
## The map's "you are here" cues: with nothing hovered the caption names the
## player's own spot, led by the same purple arrow that hangs over their
## marker on the map.

const _VIEWER_SCENE: PackedScene = preload("res://Source/Systems/Game/MainViewer/main_viewer.tscn")
const _ARROW: Texture2D = preload("res://Assets/Textures/Map/EncounterIcons/current_location_arrow.png")
const _SECTOR_SIZE: int = 8

var _map: Map


func before_each() -> void:
	super()
	var viewer: MainViewer = _VIEWER_SCENE.instantiate()
	add_child_autofree(viewer)
	_map = viewer.map
	# No gate in play: the caption falls through to the player's own spot.
	Globals.jump_gate = null


func _load(start_index: int) -> void:
	var sector: Array[ScenarioResource] = []
	for i: int in _SECTOR_SIZE - 1:
		sector.append(_map.empty_scenario)
	# Sectors end at their jump gate.
	sector.append(_map.open_gate_scenario)
	_map.load_sector(sector, start_index)


func _here_arrows() -> Array[Sprite2D]:
	var arrows: Array[Sprite2D] = []
	for child: Node in _map.map_viewport.get_children():
		if child is Sprite2D and (child as Sprite2D).texture == _ARROW and not child.is_queued_for_deletion():
			arrows.append(child)
	return arrows


func test_idle_caption_says_you_are_here_beside_the_arrow() -> void:
	_load(3)
	var caption: Array = _map._compute_hint(-1)
	assert_eq(caption[0], _ARROW)
	assert_eq(caption[1], tr("MAP_HINT_YOU_ARE_HERE"))
	assert_ne(caption[1], "MAP_HINT_YOU_ARE_HERE", "the key has an English line")
	assert_eq(caption[2], Globals.purple)


func test_idle_caption_asks_for_charge_until_the_engine_can_jump() -> void:
	_load(3)
	var previous: Player = Globals.player
	# Built by hand, not with make_player(): the viewer's engine gauge reacts
	# to every charge change and reads Globals.player, so it must be in place
	# before the first one. A fresh Player starts empty.
	var player: Player = autofree(Player.new())
	Globals.player = player
	Events.engine_charge_changed.emit()
	var caption: Array = _map._compute_hint(-1)
	assert_null(caption[0], "no arrow: it would point at the player's dot")
	assert_eq(caption[1], tr("MAP_HINT_CHARGE_ENGINES"))
	assert_ne(caption[1], "MAP_HINT_CHARGE_ENGINES", "the key has an English line")
	assert_eq(caption[2], Globals.purple, "the resting caption's purple, like You are here")

	# The setter emits engine_charge_changed, which flips the caption back.
	player.engine_charge = player.max_engine_charge
	assert_eq(_map._compute_hint(-1)[1], tr("MAP_HINT_YOU_ARE_HERE"))
	Globals.player = previous


func test_one_arrow_hangs_centred_just_above_the_marker() -> void:
	_load(3)
	var arrows: Array[Sprite2D] = _here_arrows()
	assert_eq(arrows.size(), 1)
	var arrow: Sprite2D = arrows[0]
	var pip: Sprite2D = _map.scenario_sprites[3]
	assert_eq(arrow.position.x + _ARROW.get_width() / 2.0, pip.position.x, "centre columns line up")
	assert_eq(arrow.position, arrow.position.round(), "rests on whole pixels")
	var pip_top_at_full_breath: float = pip.position.y - pip.texture.get_height() / 2.0 * 1.25
	assert_lt(arrow.position.y + _ARROW.get_height(), pip_top_at_full_breath, "never touches the breathing marker")


func test_the_arrow_follows_the_player_and_is_rebuilt_with_the_map() -> void:
	_load(3)
	_load(5)
	await wait_process_frames(1)
	var arrows: Array[Sprite2D] = _here_arrows()
	assert_eq(arrows.size(), 1, "the old map's arrow went with it")
	assert_eq(arrows[0].position.x + _ARROW.get_width() / 2.0, _map.scenario_sprites[5].position.x)


func test_standing_on_the_gate_the_arrow_clears_the_gate() -> void:
	_load(_SECTOR_SIZE - 1)
	var arrows: Array[Sprite2D] = _here_arrows()
	assert_eq(arrows.size(), 1)
	var pip: Sprite2D = _map.scenario_sprites[_SECTOR_SIZE - 1]
	assert_true(_map._is_gate_slot(_SECTOR_SIZE - 1), "the last slot is the gate")
	var gate_top: float = pip.position.y - _map.gate_map_icon.get_height() / 2.0
	assert_lt(arrows[0].position.y + _ARROW.get_height(), gate_top)
