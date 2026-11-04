extends "res://test/helpers/die_fighter_test.gd"
## Ship cockpits: every ship's cockpit scene is a Cockpit with a full-screen
## shell and breaks to open, its HUD slots name instruments that exist, and
## mounting it moves those instruments onto the slots.

const _DEFAULT_COCKPIT: PackedScene = preload("res://Source/Systems/Graphics/Cockpit/cockpit_ambience.tscn")
const _PLAYER_SCENE: PackedScene = preload("res://Source/Systems/Game/Player/player.tscn")
const _TARGETING_SCENE: PackedScene = preload("res://Source/Systems/Game/TargetingComputer/targeting_computer.tscn")


func _cockpit_scenes() -> Dictionary[String, PackedScene]:
	var scenes: Dictionary[String, PackedScene] = {"default": _DEFAULT_COCKPIT}
	for ship: ShipResource in ShipCatalog.all():
		if ship.cockpit_scene:
			scenes[String(ship.id)] = ship.cockpit_scene
	return scenes


func test_every_cockpit_is_a_cockpit_with_breaks() -> void:
	var scenes: Dictionary[String, PackedScene] = _cockpit_scenes()
	assert_gt(scenes.size(), 1, "at least one ship flies a cockpit of its own")
	for id: String in scenes:
		var cockpit: Node = autofree(scenes[id].instantiate())
		assert_true(cockpit is Cockpit, "%s: the root is a Cockpit" % id)
		var damage: CockpitDamage = cockpit.find_child("CockpitDamage", false, false) as CockpitDamage
		assert_not_null(damage, "%s: has a CockpitDamage" % id)
		if not damage:
			continue
		var sites: int = 0
		for child: Node in damage.get_children():
			if child is CockpitDamageSite:
				sites += 1
				var texture: Texture2D = (child as Sprite2D).texture
				assert_eq(texture.get_size(), Globals.SCREEN_SIZE,
					"%s/%s: a break is a full-screen overlay" % [id, child.name])
		assert_gt(sites, 0, "%s: has breaks to open" % id)
		var shell: Texture2D = (cockpit as Cockpit).walls_texture
		if shell:
			assert_eq(shell.get_size(), Globals.SCREEN_SIZE, "%s: the shell fills the screen" % id)


func test_hud_slots_name_known_instruments() -> void:
	var scenes: Dictionary[String, PackedScene] = _cockpit_scenes()
	for id: String in scenes:
		var cockpit: Node = autofree(scenes[id].instantiate())
		var slots: Node = cockpit.get_node_or_null(NodePath(Cockpit.HUD_SLOTS))
		if not slots:
			continue
		for marker: Node in slots.get_children():
			assert_true(marker is Marker2D, "%s/%s: a slot is a Marker2D" % [id, marker.name])
			assert_has(Cockpit.HUD_GROUPS, StringName(marker.name),
				"%s/%s: a slot is named after an instrument's group" % [id, marker.name])


func test_the_instruments_join_their_groups() -> void:
	var player: Node = autofree(_PLAYER_SCENE.instantiate())
	assert_true(player.get_node("PlayerHealthBar").is_in_group(Cockpit.HULL_GAUGE))
	assert_true(player.get_node("StatusBar").is_in_group(Cockpit.STATUS_BAR))
	var computer: Node = autofree(_TARGETING_SCENE.instantiate())
	assert_true(computer.is_in_group(Cockpit.TARGETING_COMPUTER))


func test_mounting_a_cockpit_moves_instruments_onto_its_slots() -> void:
	var gauge: Node2D = Node2D.new()
	gauge.add_to_group(Cockpit.HULL_GAUGE)
	add_child_autofree(gauge)
	var cockpit: Cockpit = Cockpit.new()
	var slots: Node2D = Node2D.new()
	slots.name = Cockpit.HUD_SLOTS
	var marker: Marker2D = Marker2D.new()
	marker.name = Cockpit.HULL_GAUGE
	marker.position = Vector2(277, 135)
	slots.add_child(marker)
	cockpit.add_child(slots)
	add_child_autofree(cockpit)
	assert_eq(gauge.global_position, Vector2(277, 135))
