class_name BossIntroCard
extends Control
## The beat before a boss fight: a band slams across the screen with the boss's
## silhouette and its name stamped on it, then clears. Plays when a scenario
## with a boss_title starts with its ships still hostile, so a beaten gate (or a
## Continue after the win) arrives quietly.
##
## Swallows input while it's up, so the first die isn't spent under it.

@export var band: Control
@export var portrait: TextureRect
@export var title_label: Label
@export var subtitle_label: Label
@export var dim: ColorRect

@export var slide_time: float = 0.25
@export var hold_time: float = 1.5

const _GLITCH_MS: int = 160

var _tween: Tween


func _ready() -> void:
	hide()
	Events.start_scenario.connect(_on_start_scenario)
	Events.jump.connect(_clear)


func _on_start_scenario() -> void:
	var scenario: ScenarioResource = Globals.scenario_manager.current_scenario \
		if Globals.scenario_manager else null
	if scenario == null or scenario.boss_title.is_empty():
		return
	if not Globals.state_manager.enemy_intents_visible():
		return
	play(scenario)


func play(scenario: ScenarioResource) -> void:
	title_label.text = scenario.boss_title
	subtitle_label.text = scenario.boss_subtitle
	portrait.texture = _portrait_for(scenario)

	if _tween:
		_tween.kill()
	show()
	dim.color.a = 0.0
	band.position.x = -size.x
	title_label.modulate.a = 0.0
	title_label.scale = Vector2.ONE * 1.6
	subtitle_label.visible_ratio = 0.0

	_tween = create_tween()
	_tween.tween_property(dim, "color:a", 0.6, slide_time)
	_tween.parallel().tween_property(band, "position:x", 0.0, slide_time)\
		.set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	# The name lands like a stamp: big and faint, then hard onto the band.
	_tween.tween_callback(func() -> void:
		Events.camera_shake_small.emit()
		Events.glitch_burst.emit(_GLITCH_MS)
	)
	_tween.tween_property(title_label, "modulate:a", 1.0, 0.08)
	_tween.parallel().tween_property(title_label, "scale", Vector2.ONE, 0.12)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_tween.tween_property(subtitle_label, "visible_ratio", 1.0, 0.35)
	_tween.tween_interval(hold_time)
	_tween.tween_property(band, "position:x", size.x, slide_time)\
		.set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN)
	_tween.parallel().tween_property(dim, "color:a", 0.0, slide_time)
	_tween.tween_callback(hide)


## The boss is the toughest ship the scenario starts with.
func _portrait_for(scenario: ScenarioResource) -> Texture2D:
	var toughest: EnemyResource = null
	for spawn: EnemyStateRewardResource in scenario.starting_enemies:
		if spawn.enemy_resource and (toughest == null \
		or spawn.enemy_resource.max_health > toughest.max_health):
			toughest = spawn.enemy_resource
	return toughest.targeting_computer_image if toughest else null


func _clear() -> void:
	if _tween:
		_tween.kill()
	hide()
