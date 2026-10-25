class_name HazardTelegraph
extends Node2D
## Base for background art that belongs to a timed hazard: the star that
## flares, the storm that discharges, the rift that tears wider.
##
## The environment monitor says *when* a hazard lands; the region itself
## should say *that* something is building, so a player glancing at the sky
## gets the warning too. Subclasses get three beats to act on — the hazard
## becoming imminent (and calming after it fires), the build-up to the strike,
## and the strike itself.
##
## Only ever instanced inside the background that carries the hazard, so any
## hazard signal is this object's hazard.
##
## Anything visual should ride self_modulate rather than modulate:
## BackgroundManager writes modulate from the StaticBackgroundObjectResource.

## True while the hazard will go off at the start of the next turn.
var urgent: bool = false


func _ready() -> void:
	Events.hazard_armed.connect(_on_countdown)
	Events.hazard_countdown_changed.connect(_on_countdown)
	Events.hazard_winding_up.connect(func(_hazard: BackgroundHazardResource, seconds: float) -> void: _winding_up(seconds))
	Events.hazard_struck.connect(func(_hazard: BackgroundHazardResource) -> void: _fired())


func _on_countdown(hazard: BackgroundHazardResource, turns_remaining: int) -> void:
	var now_urgent: bool = hazard != null and turns_remaining <= HazardManager.URGENT_AT
	if now_urgent == urgent:
		return
	urgent = now_urgent
	_urgency_changed()


## The hazard just became imminent, or stopped being so (it fired and reset,
## or the fight ended). Read `urgent` for which.
func _urgency_changed() -> void:
	pass


## The hazard is building to its strike, which lands in [param seconds].
func _winding_up(_seconds: float) -> void:
	pass


## The hazard strikes right now.
func _fired() -> void:
	pass
