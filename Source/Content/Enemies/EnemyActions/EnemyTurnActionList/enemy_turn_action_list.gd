class_name EnemyTurnActionList
extends Resource

@export var actions_possible: Array[EnemyActionOptionResource]

## Use this pool's own [member face_bias] instead of the enemy's, so a pool
## can change where the strong actions land: a boss that turns erratic in its
## last pool. A flag rather than a sentinel, since 0 is a real choice here.
@export var override_face_bias: bool = false

## See EnemyResource.face_bias. Ignored unless [member override_face_bias].
@export_range(-3.0, 3.0, 0.25, "or_greater", "or_less") var face_bias: float = 0.0
