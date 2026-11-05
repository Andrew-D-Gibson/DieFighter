class_name TrailerScript
extends RefCounted
## Plays a trailer shot's beats: one command per line, in order, each waiting
## for the last. Dice go where they're told through the same drop a player's
## drag ends in, carried there by a puppet of the game's own cursor, so a
## take looks played rather than teleported.
##
##   # comment                    blank lines and comments are skipped
##   wait <seconds>               game seconds (slow-mo stretches them)
##   ready [timeout]              until the player could act: hand dealt,
##                                nothing resolving, their turn (default 30 s).
##                                A ship's death plays out on its own clock:
##                                `wait` after a kill to let it read
##                                before the next.
##   drag <die> <x,y> [seconds]   carry a hand die to the tile at grid cell
##                                x,y and let go (default 0.6 s)
##   drop <die> <x,y>             the same, instantly
##   roll <f1> [f2 ...]           roll the hand, die by die, onto these faces
##   dice <f1> [f2 ...]           set the hand's faces, no animation
##   rolls <f1> [f2 ...]          queue faces for the next rolls
##   target <n>                   target the n-th living ship, left to right
##   end_turn                     press End Turn
##   hull|shields|charge|money <n>
##   foe_hull|foe_shields <n>     stage the targeted ship (a finisher's setup)
##   fx <name> [arg]              a set piece (TrailerEffects.CATALOG)
##   time <scale>                 game speed (1 normal, 0.25 quarter)
##   hud clean|full               overlays off / on
##   cursor show|hide             the drawn cursor
##   music on|off                 the music bus
##   mark <label>                 note the frame in the take's marker log
##   still                        save a screenshot
##   quit                         end the take
##
## <die> is a hand index (0 is the leftmost) or f<face> (f6: the first die
## showing a 6).

## Asked of whoever runs the script (TrailerDirector) for the commands that
## change the take rather than the game: time, hud, cursor, music, mark,
## still, quit. Called with (command, args) and answers "" or why not.
var on_director_command: Callable

## Hand dice the drag carries its die across in, from the hand to the tile.
const _DEFAULT_DRAG_SECONDS: float = 0.6
## The cursor's glide to the die before it picks it up.
const _REACH_SECONDS: float = 0.35
## How high a carried die arcs over its path, in world pixels.
const _DRAG_ARC: float = 10.0
## A beat is ready only once the game has stayed ready this many frames, so
## a gap between two chains isn't mistaken for the end of both.
const _SETTLED_FRAMES: int = 8
const _DEFAULT_READY_TIMEOUT: float = 30.0
## Between dice in a `roll`, as the turn's own roll does.
const _ROLL_STAGGER: float = 0.2

## The turn's own roll sound (Player.reroll_dice()).
const _ROLL_SFX: SoundEffectResource = preload("res://Source/Resources/SoundEffectResources/SoundEffects/dice_reroll_blip.tres")

const _DIRECTOR_COMMANDS: Array[String] = ["time", "hud", "cursor", "music", "mark", "still", "quit"]

var _host: Node
var _turn_active: bool = false
var _stopped: bool = false


## [param host] owns the timers and tweens: a node that outlives the game
## scene (the director).
func _init(host: Node) -> void:
	_host = host
	Events.first_turn_start.connect(_on_turn_start)
	Events.player_turn_start.connect(_on_turn_start)
	Events.player_turn_over.connect(_on_turn_over)
	Events.start_combat.connect(_on_turn_over)
	Events.jump.connect(_on_turn_over)


## Stops after the beat in progress, and lets go of the cursor.
func stop() -> void:
	_stopped = true
	TrailerView.puppet_active = false
	TrailerView.puppet_grabbing = false
	for connection: Dictionary in [
		{"signal": Events.first_turn_start, "callable": _on_turn_start},
		{"signal": Events.player_turn_start, "callable": _on_turn_start},
		{"signal": Events.player_turn_over, "callable": _on_turn_over},
		{"signal": Events.start_combat, "callable": _on_turn_over},
		{"signal": Events.jump, "callable": _on_turn_over},
	]:
		var sig: Signal = connection["signal"]
		if sig.is_connected(connection["callable"]):
			sig.disconnect(connection["callable"])


func is_stopped() -> bool:
	return _stopped


## Plays [param lines] to the end (or to `quit`, or stop()).
func run(lines: PackedStringArray) -> void:
	for number: int in lines.size():
		if _stopped:
			return
		var line: String = lines[number].strip_edges()
		if line.is_empty() or line.begins_with("#"):
			continue
		var problem: String = await execute(line)
		if not problem.is_empty():
			push_warning("Trailer beat %d '%s': %s" % [number + 1, line, problem])
	# The beats are over: the cursor is the mouse's again, for playing on.
	TrailerView.puppet_active = false
	TrailerView.puppet_grabbing = false


## Runs one command. Answers "" when it worked, or why it didn't.
func execute(line: String) -> String:
	var words: PackedStringArray = line.split(" ", false)
	if words.is_empty():
		return ""
	var command: String = words[0]
	var args: PackedStringArray = words.slice(1)
	if command in _DIRECTOR_COMMANDS:
		return on_director_command.call(command, args) if on_director_command.is_valid() \
			else "nothing is directing the take"
	if not is_instance_valid(Globals.player) or not Globals.player.is_inside_tree():
		return "no game running"
	match command:
		"wait":
			if args.size() != 1 or not args[0].is_valid_float():
				return "wait <seconds>"
			await _host.get_tree().create_timer(float(args[0]), false).timeout
		"ready":
			var timeout: float = float(args[0]) if args.size() == 1 and args[0].is_valid_float() \
				else _DEFAULT_READY_TIMEOUT
			if not await _wait_until_ready(timeout):
				return "still not ready after %.0f s" % timeout
		"drag", "drop":
			if args.size() < 2:
				return "%s <die> <x,y>" % command
			var die: Dice = hand_die(args[0])
			var tile: Tile = tile_at(args[1])
			if die == null:
				return "no die '%s' in the hand" % args[0]
			if tile == null:
				return "no tile at %s" % args[1]
			var seconds: float = 0.0 if command == "drop" else \
				(float(args[2]) if args.size() > 2 and args[2].is_valid_float() else _DEFAULT_DRAG_SECONDS)
			await _carry(die, tile, seconds)
		"roll":
			await _roll(_faces(args))
		"dice":
			var hand: Array[Dice] = _hand()
			var faces: Array[int] = _faces(args)
			for i: int in mini(faces.size(), hand.size()):
				hand[i].value = faces[i]
		"rolls":
			Dice.forced_rolls.append_array(_faces(args))
		"target":
			var ships: Array[Enemy] = ships_left_to_right()
			if args.size() != 1 or not args[0].is_valid_int() or int(args[0]) >= ships.size():
				return "target <n>, with %d ships to pick from" % ships.size()
			Globals.targeting_computer.target_enemy(ships[int(args[0])])
		"end_turn":
			Globals.player.end_turn()
		"hull", "shields", "charge", "money":
			if args.size() != 1 or not args[0].is_valid_int():
				return "%s <n>" % command
			_set_stat(command, int(args[0]))
		"foe_hull", "foe_shields":
			var ship: Enemy = TrailerEffects.target()
			if ship == null or args.size() != 1 or not args[0].is_valid_int():
				return "%s <n>, with a ship to target" % command
			if command == "foe_hull":
				ship.health.health = clampi(int(args[0]), 1, ship.health.max_health)
			else:
				ship.health.shields = maxi(int(args[0]), 0)
		"fx":
			if args.is_empty():
				return "fx <%s>" % "|".join(PackedStringArray(TrailerEffects.CATALOG.keys()))
			return TrailerEffects.play(args[0], args[1] if args.size() > 1 else "")
		_:
			return "unknown command"
	return ""


# ── Lookups ──────────────────────────────────────────────────────────────────

## The hand, left to right as the player sees it.
static func _hand() -> Array[Dice]:
	var hand: Array[Dice] = []
	for die: Dice in Globals.player.dice_manager.queue:
		if is_instance_valid(die) and die.is_playable():
			hand.append(die)
	return hand


## A hand die by index ("0") or by face ("f6": the first showing a 6).
static func hand_die(spec: String) -> Dice:
	var hand: Array[Dice] = _hand()
	if spec.begins_with("f") and spec.substr(1).is_valid_int():
		var face: int = int(spec.substr(1))
		for die: Dice in hand:
			if die.value == face:
				return die
		return null
	if spec.is_valid_int() and int(spec) >= 0 and int(spec) < hand.size():
		return hand[int(spec)]
	return null


## The tile at grid cell "x,y", or null.
static func tile_at(cell_text: String) -> Tile:
	var parts: PackedStringArray = cell_text.split(",")
	if parts.size() != 2 or not parts[0].is_valid_int() or not parts[1].is_valid_int():
		return null
	var cell: Vector2i = Vector2i(int(parts[0]), int(parts[1]))
	return Globals.tile_grid.tile_locations.get(cell) as Tile


static func ships_left_to_right() -> Array[Enemy]:
	var ships: Array[Enemy] = Globals.enemy_manager.get_alive_enemies().duplicate()
	ships.sort_custom(func(a: Enemy, b: Enemy) -> bool: return a.global_position.x < b.global_position.x)
	return ships


static func _faces(args: PackedStringArray) -> Array[int]:
	var faces: Array[int] = []
	for word: String in args:
		if word.is_valid_int():
			faces.append(clampi(int(word), 1, 6))
	return faces


static func _set_stat(stat: String, amount: int) -> void:
	var player: Player = Globals.player
	match stat:
		"hull":
			player.health.health = clampi(amount, 1, player.health.max_health)
		"shields":
			player.health.shields = maxi(amount, 0)
		"charge":
			player.engine_charge = maxi(amount, 0)
		"money":
			player.money = maxi(amount, 0)


# ── Waiting ──────────────────────────────────────────────────────────────────

## Whether a player could act now: the game scene is up and not over, the
## hand is dealt, nothing is resolving, no ships are still flying in, and
## (in a fight) it's their turn. The same patience the AutoPilot plays with.
func player_can_act() -> bool:
	if not is_instance_valid(Globals.player) or not is_instance_valid(Globals.state_manager):
		return false
	if Globals.player.is_dealing_hand() or Globals.player.is_jump_committed():
		return false
	var state: GameStateManager.GameState = Globals.state_manager.state
	if state == GameStateManager.GameState.GAME_OVER or state == GameStateManager.GameState.VICTORY:
		return false
	var engine: ScenarioEngine = ScenarioEngine.current()
	if engine == null or engine.currently_processing_queue or not engine.event_queue.is_empty():
		return false
	if is_instance_valid(Globals.enemy_manager) and Globals.enemy_manager.arrival_in_progress:
		return false
	return state == GameStateManager.GameState.OUT_OF_COMBAT or _turn_active


## The timeout is in effect time, not on the wall clock: under Movie Maker a
## frame takes as long as it takes to draw, and effect time follows the
## recording (TimeDirector.use_frame_clock()).
func _wait_until_ready(timeout: float) -> bool:
	var tree: SceneTree = _host.get_tree()
	var deadline: float = TimeDirector.effect_msec() + timeout * 1000.0
	var settled: int = 0
	while settled < _SETTLED_FRAMES:
		if _stopped or TimeDirector.effect_msec() > deadline:
			return false
		await tree.process_frame
		settled = settled + 1 if player_can_act() else 0
	return true


func _on_turn_start() -> void:
	_turn_active = true


func _on_turn_over() -> void:
	_turn_active = false


# ── Hands ────────────────────────────────────────────────────────────────────

## The cursor reaches the die, picks it up, carries it over the tile along a
## shallow arc, and lets go: the drop goes through Dice._check_for_acceptor,
## exactly where a real drag's would. Zero seconds just lets go over the tile.
func _carry(die: Dice, tile: Tile, seconds: float) -> void:
	var drop_at: Vector2 = tile.can_accept_dice.collision.global_position
	if seconds > 0.0:
		var viewport: Viewport = _host.get_viewport()
		var start: Vector2 = TrailerView.puppet_position if TrailerView.puppet_active \
			else InputManager.pointer_position(viewport)
		TrailerView.puppet_active = true
		TrailerView.puppet_grabbing = false
		await _glide(start, _on_screen(die.global_position), _REACH_SECONDS)
		if not is_instance_valid(die) or not is_instance_valid(tile) or _stopped:
			return

		die.draggable.state = Draggable.DragState.MOVING_WITH_CODE
		TrailerView.puppet_grabbing = true
		die.play_pop(0.2)
		die.z_index += 10
		var from: Vector2 = die.global_position
		var tween: Tween = _host.create_tween()
		tween.tween_method(func(t: float) -> void:
			if not is_instance_valid(die):
				return
			var eased: float = ease(t, -2.0)
			die.global_position = from.lerp(drop_at, eased) + Vector2(0.0, -sin(t * PI) * _DRAG_ARC)
			TrailerView.puppet_position = _on_screen(die.global_position)
		, 0.0, 1.0, seconds)
		await tween.finished
		if not is_instance_valid(die):
			return
		die.z_index -= 10
		TrailerView.puppet_grabbing = false

	die.draggable.state = Draggable.DragState.DEFAULT
	die.draggable.drag_ended.emit(die.draggable, drop_at)


func _glide(from: Vector2, to: Vector2, seconds: float) -> void:
	var tween: Tween = _host.create_tween()
	tween.tween_method(func(at: Vector2) -> void: TrailerView.puppet_position = at, from, to, seconds) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await tween.finished


## A world position in the root viewport's coordinates, where the drawn
## cursor's position is kept.
func _on_screen(world: Vector2) -> Vector2:
	return _host.get_viewport().get_canvas_transform() * world


func _roll(faces: Array[int]) -> void:
	var hand: Array[Dice] = _hand()
	for i: int in hand.size():
		hand[i].reroll_with_tween(faces[i] if i < faces.size() else 0)
		Events.play_sound.emit(_ROLL_SFX)
		await _host.get_tree().create_timer(_ROLL_STAGGER, false).timeout
