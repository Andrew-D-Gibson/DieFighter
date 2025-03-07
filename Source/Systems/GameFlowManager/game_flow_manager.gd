extends Node2D

# This node has to be the last thing loaded in our game, so it can depend
# on all the other components having had their "_ready" called!

func _ready() -> void:
	Events.load_encounter.connect(func(_encounter: EncounterResource):
		Events.start_encounter.emit()
	)
	Events.start_encounter.emit()
	
