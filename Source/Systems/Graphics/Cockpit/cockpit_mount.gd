class_name CockpitMount
extends Node2D
## Where the ship's Cockpit goes in the game scene: the run's ship brings its
## own (ShipResource.cockpit_scene), or flies the default one.
##
## Mounted in _ready, which runs before anything under Systems is ready (the
## Graphics layer comes first in the scene), so the cockpit can move the
## instruments into its slots before they settle.

const DEFAULT_COCKPIT: String = "res://Source/Systems/Graphics/Cockpit/cockpit_ambience.tscn"


func _ready() -> void:
	var ship: ShipResource = Globals.current_ship()
	var scene: PackedScene = ship.cockpit_scene if ship and ship.cockpit_scene else load(DEFAULT_COCKPIT)
	add_child(scene.instantiate())


## The cockpit that was mounted, or null before _ready.
func get_cockpit() -> Cockpit:
	return get_child(0) as Cockpit if get_child_count() > 0 else null
