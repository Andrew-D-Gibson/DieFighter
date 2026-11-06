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
##
## A beat that waits on the player (a rule card shown for the first time,
## which stays up until it's closed) holds the ships for as long as it takes.
## Any other is given up on after max_beat_seconds, so a card that goes
## missing can't strand the ships off-screen.

## This arrival's beats are done (or a jump cut them short): the ships may
## come in.
signal finished()

## A new arrival or a jump has made whatever beat is playing moot.
signal _cut()

## The order the beats play in.
enum Beat {
	## The region's rule or hazard, spelled out (RegionAlert).
	REGION_RULE,
	## The escort riding with the player says goodbye and leaves
	## (EscortKeeper), before the encounter's ships take the stage.
	ESCORT_FAREWELL,
	## A boss's name slammed across the screen (BossIntroCard). Last, right
	## before the ships, since it's the one that says "here they come".
	BOSS,
}

## Longest any one beat may hold the ships, unless it waits on the player. A
## beat whose card goes missing must not strand the ships off-screen.
var max_beat_seconds: float = 8.0

static var _shared: ArrivalIntro

var _beats: Dictionary[int, Callable] = {}
## The beats added as waiting on the player, which no deadline cuts short.
var _untimed: Dictionary[int, bool] = {}
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
## twice keeps the later one. A beat that [param waits_on_player] holds the
## ships until it returns, however long the player takes; any other is given
## up on after max_beat_seconds.
func add(beat: Beat, play: Callable, waits_on_player: bool = false) -> void:
	_beats[beat] = play
	_untimed[beat] = waits_on_player


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
	_cut.emit()
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
	var untimed: Dictionary[int, bool] = _untimed.duplicate()
	_beats.clear()
	_untimed.clear()
	var order: Array[int] = beats.keys()
	order.sort()
	for beat: int in order:
		await _run(beats[beat], untimed.get(beat, false), tree)
		if generation != _generation:
			return
	_playing = false
	finished.emit()


## Plays one beat and returns on the first of: it returning, the node it
## belongs to leaving the tree partway, an arrival or jump cutting it short,
## or (unless it [param waits_on_player]) max_beat_seconds running out.
func _run(play: Callable, waits_on_player: bool, tree: SceneTree) -> void:
	if not play.is_valid():
		return
	var over: _Latch = _Latch.new()
	var run: Callable = func() -> void:
		await play.call()
		over.trip()
	run.call()
	if over.is_tripped:
		return

	_cut.connect(over.trip)
	var owner: Node = play.get_object() as Node
	var watch_owner: bool = owner != null and owner.is_inside_tree()
	if watch_owner:
		owner.tree_exited.connect(over.trip)
	if not waits_on_player:
		# Stops with the game while it's paused, as the card and band do.
		tree.create_timer(max_beat_seconds, false).timeout.connect(over.trip)

	await over.tripped

	_cut.disconnect(over.trip)
	if watch_owner and is_instance_valid(owner) and owner.tree_exited.is_connected(over.trip):
		owner.tree_exited.disconnect(over.trip)


## Jumping away makes the intro moot: whoever is waiting on it is let go, and
## each beat's own node clears itself off the screen.
func _on_jump() -> void:
	_generation += 1
	_cut.emit()
	_beats.clear()
	_untimed.clear()
	_collecting = false
	if _playing:
		_playing = false
		finished.emit()


func _tree() -> SceneTree:
	return Engine.get_main_loop() as SceneTree


## Trips once, on the first of the signals connected to trip(), so a beat can
## end any of the ways it can without anything checking every frame.
class _Latch:
	extends RefCounted

	signal tripped()

	var is_tripped: bool = false

	func trip() -> void:
		if is_tripped:
			return
		is_tripped = true
		tripped.emit()
