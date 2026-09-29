extends Node2D
## Stands in for a Dice wherever code only reads [member value].
##
## The real Dice scene rewires its sprite and shader on every value change,
## which is noise for logic tests. Handlers and events type the activator as
## Node and read .value by duck typing, so this is enough for them.

var value: int = 1


func _init(face: int = 1) -> void:
	value = face
