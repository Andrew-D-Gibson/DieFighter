class_name ArrivalIntro
extends RefCounted
## The beats that play one after another between arriving in a scenario and
## its ships flying in: the region's rule card, then a boss's intro band.
##
## Arrival used to start everything at once (the ships, the monitor swinging
## up, the card, the band, the targeting computer locking on) and nothing told
## the player where to look. Here each beat gets the screen to itself, and the
## ships wait for the last one (see EnemyManager.start_enemy_fly_in). An
## arrival with no beats sends the ships straight in, as it always has.
##
## Systems add their beat while the arrival is being answered: in their
## start_scenario listener, or in the deferred work it sets off. The beats
## play a couple of frames later, in [enum Beat] order. A beat is a Callable,
## usually a coroutine; the next one starts when it returns.

## This arrival's beats are done (or a jump cut them short): the ships may
## come in.
signal finished()

## The order the beats play in.
enum Beat {
	## The region's rule or hazard, spelled out (RegionAlert).
	REGION_RULE,
	## A boss's name slammed across the screen (BossIntroCard). Last, right
	## before the ships, since it's the one that says "here they come".
	BOSS,
}

## Longest any one beat may hold the ships. A beat whose card goes missing
## must not strand the ships off-screen.
var max_beat_seconds: float = 8.0

static var _shared: ArrivalIntro

var _beats: Dictionary[int, Callable] = {}
## From an arrival until its beats start playing: the window in which a
## system adds its beat instead of playing it straight away.
var _collecting: bool = false
var _playing: bool = false
## Bumped on every arrival and jump, so an intro cut short stops where it is.
var _generation: int = 0


## The one the game uses. Systems take it in their _ready, so it is already
## listening when the first arrival comes.
static func shared() -> ArrivalIntro:
	if _shared == null:
		_shared = ArrivalIntro.new()
	return _shared


func _init() -> void:
	Events.start_scenario.connect(_on_arrival)
	Events.jump.connect(_on_jump)


## Plays [param play] as this arrival's [param beat]. Adding the same beat
## twice keeps the later one.
func add(beat: Beat, play: Callable) -> void:
	_beats[beat] = play


## True while an arrival is still gathering its beats.
func is_collecting() -> bool:
	return _collecting


## Returns once the arrival being answered has played its beats; at once if
## it has none, or if there is no arrival under way.
func wait() -> void:
	# Every start_scenario listener has run by the next frame, whatever order
	# they were connected in.
	await _tree().process_frame
	if _playing:
		await finished


func _on_arrival() -> void:
	_generation += 1
	_collecting = true
	_playing = true
	_play(_generation)


func _play(generation: int) -> void:
	var tree: SceneTree = _tree()
	# Two frames: the deferred work start_scenario set off (the monitor's
	# present) has added its beat by then.
	await tree.process_frame
	await tree.process_frame
	if generation != _generation:
		return
	_collecting = false

	var beats: Dictionary[int, Callable] = _beats.duplicate()
	_beats.clear()
	var order: Array[int] = beats.keys()
	order.sort()
	for beat: int in order:
		await _run(beats[beat], generation, tree)
		if generation != _generation:
			return
	_playing = false
	finished.emit()


## Plays one beat, giving up on it if it outlives max_beat_seconds or the
## node it belongs to is freed partway.
func _run(play: Callable, generation: int, tree: SceneTree) -> void:
	if not play.is_valid():
		return
	var done: Array[bool] = [false]
	var run: Callable = func() -> void:
		await play.call()
		done[0] = true
	run.call()
	# Stops with the game while it's paused, as the card and band do.
	var deadline: SceneTreeTimer = tree.create_timer(max_beat_seconds, false)
	while not done[0] and play.is_valid() and deadline.time_left > 0.0 \
	and generation == _generation:
		await tree.process_frame


## Jumping away makes the intro moot: whoever is waiting on it is let go, and
## each beat's own node clears itself off the screen.
func _on_jump() -> void:
	_generation += 1
	_beats.clear()
	_collecting = false
	if _playing:
		_playing = false
		finished.emit()


func _tree() -> SceneTree:
	return Engine.get_main_loop() as SceneTree
