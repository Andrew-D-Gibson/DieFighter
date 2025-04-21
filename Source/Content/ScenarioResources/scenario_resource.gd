class_name ScenarioResource
extends Resource

enum StartingScreen {SYSTEMS, MAP, COMMS}

@export var map_icon: Texture2D
@export var starting_screen: StartingScreen
@export var background_resource: BackgroundResource
@export var starting_enemies: Array[EnemyStateRewardResource]
