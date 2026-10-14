class_name ShipHullResource
extends Resource
## A ship too big to be one target: a hull that the scenario's mounted ships
## (EnemyStateRewardResource.mounted) ride on as its parts. The hull itself
## can't be shot. It flies in and bobs as one with its parts, scars each
## socket whose part is destroyed, and breaks apart once the last one goes.

## The hull's art and behaviour. Its root must be a ShipHull.
@export var hull_scene: PackedScene
## Where along the enemy path the hull centres, 0.0 (far left) to 1.0.
@export_range(0.0, 1.0, 0.01) var path_location: float = 0.5
## Nudge from that point on the path to the hull's centre.
@export var offset: Vector2 = Vector2.ZERO
## Screen width the hull holds, so nothing else in the formation stands on it.
@export var width: float = 200.0
