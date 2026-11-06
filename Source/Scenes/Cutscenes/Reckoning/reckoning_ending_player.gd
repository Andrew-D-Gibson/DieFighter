class_name ReckoningEndingPlayer
extends CanvasLayer
## Plays a Reckoning ending (RECKONING_ENDINGS.md §6-7) over the game scene,
## segment by segment, then hands the run to the end screen.
##
## | Ending      | Segments                             | Then      |
## |-------------|--------------------------------------|-----------|
## | ALONE       | arrival (ALONE)                      | victory   |
## | CONVOY      | arrival (CONVOY)                     | victory   |
## | LAST_DIE    | consumed (LAST_DIE), arrival (LAST_DIE) | victory |
## | BECOME_FATE | become fate                          | victory   |
## | FELL_IN     | consumed (FELL_IN)                   | game_over |
##
## The credits (§7) roll inside the last segment of each real ending, not as a
## segment of their own, so the convoy can fly on into them without a cut.
## ReckoningCredits holds their lines.
##
## A segment whose scene doesn't exist yet is passed over, so each can be
## built and previewed on its own (`fate end <kind>` in the dev console).
## Whoever ends the Reckoning calls play() and emits nothing itself: the
## fate_ending and victory / game_over signals are emitted here, on black,
## and the curtain lifts off the end screen.

## The ending has been handed to the end screen.
signal done

const ARRIVAL: String = "res://Source/Scenes/Cutscenes/Reckoning/arrival_cutscene.tscn"
const CONSUMED: String = "res://Source/Scenes/Cutscenes/Reckoning/consumed_cutscene.tscn"
const BECOME_FATE: String = "res://Source/Scenes/Cutscenes/Reckoning/become_fate_cutscene.tscn"

## Under every segment (89-96), above the game.
const CURTAIN_LAYER: int = 88
## Seconds the game takes to go black before the first segment.
const FADE_TO_BLACK: float = 0.6
## Seconds the end screen takes to come up out of black.
const END_SCREEN_FADE_IN: float = 0.45

static var _playing: ReckoningEndingPlayer = null

var _ending: ReckoningEnding
var _curtain: ColorRect


## Whether an ending is playing now.
static func is_playing() -> bool:
	return is_instance_valid(_playing)


## Plays [param ending] over the running game scene and waits until the run
## is on its end screen.
static func play(ending: ReckoningEnding) -> void:
	if is_playing() or ending == null:
		return
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	var player: ReckoningEndingPlayer = ReckoningEndingPlayer.new()
	player._ending = ending
	_playing = player
	tree.current_scene.add_child(player)
	await player.done


## The scene paths and modes played for [param ending], in order.
static func segments_for(ending: ReckoningEnding) -> Array[Dictionary]:
	var mode: ReckoningCutsceneSegment.Mode = ReckoningCutsceneSegment.mode_for(ending.kind)
	var list: Array[Dictionary] = []
	match ending.kind:
		ReckoningEnding.Kind.ALONE, ReckoningEnding.Kind.CONVOY:
			list.append({"path": ARRIVAL, "mode": mode})
		ReckoningEnding.Kind.LAST_DIE:
			list.append({"path": CONSUMED, "mode": mode})
			list.append({"path": ARRIVAL, "mode": mode})
		ReckoningEnding.Kind.BECOME_FATE:
			list.append({"path": BECOME_FATE, "mode": mode})
		ReckoningEnding.Kind.FELL_IN:
			list.append({"path": CONSUMED, "mode": mode})
	return list


func _init() -> void:
	name = "ReckoningEndingPlayer"
	layer = CURTAIN_LAYER
	process_mode = Node.PROCESS_MODE_ALWAYS


func _ready() -> void:
	_curtain = ColorRect.new()
	_curtain.color = Color(0, 0, 0, 0)
	_curtain.mouse_filter = Control.MOUSE_FILTER_STOP
	_curtain.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_curtain)
	_run.call_deferred()


func _run() -> void:
	var fade: Tween = create_tween()
	fade.tween_property(_curtain, "color:a", 1.0, FADE_TO_BLACK)
	await fade.finished

	for segment: Dictionary in segments_for(_ending):
		var skipped: bool = await _play_segment(str(segment["path"]), segment["mode"])
		if skipped:
			break
	_hand_over()


## Plays one segment; true when the player skipped. A missing scene plays as
## nothing.
func _play_segment(path: String, mode: ReckoningCutsceneSegment.Mode) -> bool:
	if not ResourceLoader.exists(path):
		push_warning("ReckoningEndingPlayer: no segment at %s yet; passed over." % path)
		return false
	var scene: PackedScene = load(path) as PackedScene
	var segment: ReckoningCutsceneSegment = scene.instantiate() as ReckoningCutsceneSegment if scene else null
	if segment == null:
		push_error("ReckoningEndingPlayer: %s isn't a ReckoningCutsceneSegment." % path)
		return false
	segment.ending = _ending
	segment.mode = mode
	get_tree().current_scene.add_child(segment)
	var skipped: bool = await segment.finished
	segment.queue_free()
	return skipped


## On black: the run ends, the end screen comes up under the curtain, and the
## curtain lifts off it.
func _hand_over() -> void:
	Events.fate_ending.emit(_ending.ending_id())
	if _ending.kind == ReckoningEnding.Kind.FELL_IN:
		Events.game_over.emit()
	else:
		Events.victory.emit()
	var lift: Tween = create_tween()
	lift.tween_property(_curtain, "color:a", 0.0, END_SCREEN_FADE_IN)
	lift.tween_callback(func() -> void:
		done.emit()
		if _playing == self:
			_playing = null
		queue_free())
