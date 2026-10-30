class_name Cockpit
extends Node2D
## A ship's cockpit: everything around the shared systems panel that makes the
## ship feel like its own. One scene per ship (ShipResource.cockpit_scene),
## mounted by CockpitMount in the game scene. The root carries this script;
## the scene holds the rest:
## - the shell art ([member walls_texture]), drawn by the shared CockpitWalls
##   sprite so the glass shards and the death breakup work on any shell;
## - the ambient life drawn on it: lights, vents, ornaments;
## - a CockpitDamage with its breaks laid over this shell's glass and seams;
## - HUD slots: a Marker2D under a node named [constant HUD_SLOTS] for each
##   instrument the ship mounts somewhere else. A marker's name is the group
##   its instrument joins ([constant HULL_GAUGE], [constant TARGETING_COMPUTER],
##   [constant STATUS_BAR], [constant OVERHEAD_CONSOLE]), and the instrument is
##   moved onto the marker
##   before any of it is ready. An instrument with no marker stays where the
##   game scene puts it.
##
## Coordinates are screen pixels, top-left (0, 0), like the default shell.

const HUD_SLOTS: StringName = &"HudSlots"
## Groups the movable instruments join, named after their markers.
const HULL_GAUGE: StringName = &"hud_hull_gauge"
const TARGETING_COMPUTER: StringName = &"hud_targeting_computer"
const STATUS_BAR: StringName = &"hud_status_bar"
## The marker is the console's ceiling mount: it hangs down from there.
const OVERHEAD_CONSOLE: StringName = &"hud_overhead_console"
const HUD_GROUPS: Array[StringName] = [HULL_GAUGE, TARGETING_COMPUTER, STATUS_BAR, OVERHEAD_CONSOLE]

## The shell. Null keeps the default shell, repainted with the ship's
## cockpit_palette. A shell of the ship's own is drawn in its own colours.
@export var walls_texture: Texture2D


func _ready() -> void:
	var ship: ShipResource = Globals.current_ship()
	_dress_walls(ship)
	_dress_instruments(ship)
	_mount_instruments()


func _dress_walls(ship: ShipResource) -> void:
	var walls: CockpitWalls = CockpitWalls.find(self)
	if not walls:
		return
	if walls_texture:
		walls.texture = walls_texture
	elif ship and not ship.cockpit_palette.is_empty():
		walls.texture = CockpitWalls.recolor(walls.texture, ship.cockpit_palette)


## The instruments' frames (the hull gauge's ring, the targeting computer's
## case) are drawn in the default cockpit's navy ramp, the same colours
## cockpit_palette maps, so they take the ship's colours from it. Their own
## readouts (targets purple, hull red, shields blue) are other colours and
## stay as they are.
func _dress_instruments(ship: ShipResource) -> void:
	if not ship or ship.cockpit_palette.is_empty() or not is_inside_tree():
		return
	for node: Node in get_tree().get_nodes_in_group(CockpitGlassShards.SURFACE_GROUP):
		var sprite: Sprite2D = node as Sprite2D
		if sprite and sprite.texture:
			sprite.texture = CockpitWalls.recolor(sprite.texture, ship.cockpit_palette)


func _mount_instruments() -> void:
	var slots: Node = get_node_or_null(NodePath(HUD_SLOTS))
	if not slots or not is_inside_tree():
		return
	for marker: Node in slots.get_children():
		if not marker is Marker2D:
			continue
		for instrument: Node in get_tree().get_nodes_in_group(marker.name):
			if instrument is Node2D:
				(instrument as Node2D).global_position = (marker as Marker2D).global_position
