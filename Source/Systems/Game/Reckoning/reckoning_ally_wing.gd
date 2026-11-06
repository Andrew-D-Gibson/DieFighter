class_name ReckoningAllyWing
extends Node
## The ships the player saved and spared, in the Reckoning (RECKONING_ENDINGS.md
## §3). Owned by ReckoningDirector, which hands it each wave's allies and
## debts and forwards the fight's signals.
##
## Saved ships (FateLedger.KIND_ALLY) fly one at a time in the escort's slot
## (EnemyManager.ESCORT_SLOT), built like the Mayday escort: on the player's
## side, with a table of Shield, Raid and "Run for it". A die spent on Run
## for it (EscapeWithDiceEvent) takes the ship out of the fight carrying it:
## saved, and the die gone from the Fleet. A ship destroyed here is lost. The
## others wait at the edge of the fleet for the slot.
##
## Spared ships (KIND_DEBT) take no slot and no die: one strafing pass across
## every hostile, then they're gone.

## Where an arriving ally's jump comes from: the fleet, off to the right.
const _JUMP_HEADING: Vector2 = Vector2.LEFT
## Seconds after its jump-in before an arriving ally speaks.
const _ARRIVAL_DELAY_SECONDS: float = 0.9
## How long a line stays up once it has typed out: a base plus a share per
## character, so a long line gets longer, within bounds.
const _LINE_HOLD_BASE_SECONDS: float = 1.0
const _LINE_HOLD_PER_CHAR_SECONDS: float = 0.045
const _LINE_HOLD_MIN_SECONDS: float = 1.8
const _LINE_HOLD_MAX_SECONDS: float = 3.4
## Silence after a line before the next one, so two never run together.
const _LINE_PAUSE_SECONDS: float = 0.7
## Longest a line waits for the other ships to finish talking.
const _QUIET_TIMEOUT_SECONDS: float = 4.0
## A ship taking a die: a breath before it speaks, then (after its line) the
## drive building up before the regular jump-out takes over. The last die's
## line is quiet and worried, so it is held a little longer.
const _PARTING_LEAD_SECONDS: float = 0.5
const _PARTING_CHARGE_SECONDS: float = 1.8
const _LAST_DIE_EXTRA_HOLD_SECONDS: float = 0.8
## The hull strains toward the jump: stretched a little along its flight line
## while it shakes harder and harder (pixels, so it stays on the art grid).
const _PARTING_STRETCH: Vector2 = Vector2(0.9, 1.2)
const _PARTING_SHAKE_PIXELS: int = 2
const _PARTING_SHAKE_STEP_SECONDS: float = 0.05
## The glow rings drawn in on the hull during the charge.
const _PARTING_PULSES: int = 3
## Longest the slot waits for a departing (or destroyed) ship to be gone.
const _GONE_TIMEOUT_SECONDS: float = 4.0
## Seconds after a ship is gone before the next ally comes into its slot.
const _SLOT_REFILL_SECONDS: float = 1.2
## A spared ship's pass: where it flies, and how long it takes.
const _STRAFE_HEIGHT: float = 34.0
const _STRAFE_SECONDS: float = 1.6
const _SCREEN_MARGIN: float = 30.0

## Palette swap that turns Getaway's purple into the Caravan's green: Run for
## it reads as the same "leaves with your die", but as a gift.
const _GREEN_RAMP: Dictionary[Color, Color] = {
	Color("#c552f1"): Color("#7abd33"),
	Color("#80359d"): Color("#659c2a"),
	Color("#251c6b"): Color("#4c7520"),
}

## The table every saved ship flies with here, whatever ship it is.
var ally_table: EnemyTurnActionList
## The side it flies on.
var ally_state: ScenarioShipState
## The bank's share past which an ally aboard tells the player not to wait.
var nearly_full_fraction: float = 0.8
## A spared ship's pass deals this many times a d6 to every hostile.
var debt_strafe_multiplier: int = 3
## Saved ships still in waves the hole hasn't sent yet, for the names on the
## queue's telegraph: () -> Array[Dictionary] of FateLedger.allies entries.
var upcoming: Callable = func() -> Array[Dictionary]: return []
## Takes the next saved ship out of those waves, for Mercy: () -> Dictionary,
## empty when there is none.
var take_upcoming: Callable = func() -> Dictionary: return {}

## FateLedger.allies entries of the saved ships that jumped out with a die,
## in the order they left; and of those destroyed here.
var saved_out: Array[Dictionary] = []
var lost: Array[Dictionary] = []

var _running: bool = false
## Arrivals wait while true (hold_until()).
var _held: bool = false
var _waiting: Array[Dictionary] = []
var _aboard: Enemy = null
var _aboard_entry: Dictionary = {}
## Ships that already told the player their drive is lit.
var _warned: Dictionary[int, bool] = {}
## The wing speaks one line at a time: true while a line (and the pause after
## it) is running. Bumping the generation drops the lines still waiting.
var _speaking: bool = false
var _speech_gen: int = 0
## The ship playing its parting beat; nothing else speaks for it.
var _beat_ship: Enemy = null
## The slot is not free to refill while a ship is still on its way out.
var _slot_busy: bool = false
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
## The green Run for it icons, made once from Getaway's.
static var _greened: Dictionary[Texture2D, Texture2D] = {}


func begin(seed_value: int) -> void:
	_running = true
	_held = false
	_waiting.clear()
	_aboard = null
	_aboard_entry = {}
	saved_out.clear()
	lost.clear()
	_warned.clear()
	_speaking = false
	_speech_gen += 1
	_beat_ship = null
	_slot_busy = false
	_rng.seed = seed_value
	_dress_run_for_it()


func stop() -> void:
	_running = false


## Holds saved ships at the edge of the fleet until [param cue] fires.
func hold_until(cue: Signal) -> void:
	_held = true
	await cue
	_held = false
	_fill_slot()


## Whether [param ship] is the saved ship in the slot now.
func is_aboard(ship: Node) -> bool:
	return is_instance_valid(_aboard) and ship == _aboard


## Saved ships of a wave that just came up: they take the slot if it's free,
## else wait at the edge of the fleet.
func add(entries: Array) -> void:
	for entry: Variant in entries:
		if entry is Dictionary:
			_waiting.append(entry)
	_fill_slot()


## Mercy: the next saved ship jumps in now, or the one aboard is healed and
## shielded for [param amount]. Nobody left to come says so.
func mercy(amount: int) -> void:
	if not _running:
		return
	if is_instance_valid(_aboard) and _aboard.health.health > 0:
		_mend(_aboard, amount)
		return
	if _waiting.is_empty():
		var next: Dictionary = take_upcoming.call()
		if not next.is_empty():
			_waiting.append(next)
	if _waiting.is_empty():
		Juice.callout_at(Globals.enemy_manager, EnemyManager.ESCORT_SLOT,
			tr("FATE_CALLOUT_NO_ONE_CAME"), Globals.green.darkened(0.3))
		return
	_fill_slot()


## Heals and shields [param ship] for [param amount], through the engine so
## the region's rules have their say (no shields by the pulsar).
func _mend(ship: Enemy, amount: int) -> void:
	var engine: ScenarioEngine = ScenarioEngine.current()
	if engine == null or amount <= 0:
		return
	Juice.sparkle(ship, ship.global_position, Globals.green, 10, 30.0, true)
	for event: EffectEvent in [HealEvent.new(), ShieldEvent.new()]:
		event.amount = amount
		event.actor = Globals.player
		event.effect_source = Globals.player
		event.targets = [ship] as Array[Node]
		engine.inject_event(event)


## Saved ships that never got out: the one aboard, those waiting, and those
## still in waves to come. Enemy ids.
func left_behind() -> Array[String]:
	var ids: Array[String] = []
	if is_instance_valid(_aboard) and _aboard.health.health > 0:
		ids.append(str(_aboard_entry.get("enemy", "")))
	for entry: Dictionary in _waiting:
		ids.append(str(entry.get("enemy", "")))
	for entry: Dictionary in upcoming.call():
		ids.append(str(entry.get("enemy", "")))
	return ids


## The enemy id of the ship aboard, or "".
func aboard_id() -> String:
	return str(_aboard_entry.get("enemy", "")) if is_instance_valid(_aboard) else ""


## A ship left the fight. If it's the one aboard: still whole, it jumped out
## with a die (Run for it is the only way it leaves alive; its parting line
## and jump build-up already played, see _departure_beat()), else it's lost.
## Either way the slot is free for the next once the ship is really gone, so
## the next ally never arrives into a jump.
func on_ship_left(ship: Enemy) -> void:
	if not is_aboard(ship):
		return
	var entry: Dictionary = _aboard_entry
	_aboard = null
	_aboard_entry = {}
	if ship.health.health > 0:
		saved_out.append(entry)
	else:
		lost.append(entry)
	if not _running:
		return
	_slot_busy = true
	var waited: float = 0.0
	while is_instance_valid(ship) and waited < _GONE_TIMEOUT_SECONDS:
		await get_tree().process_frame
		waited += get_process_delta_time()
	await get_tree().create_timer(_SLOT_REFILL_SECONDS).timeout
	_slot_busy = false
	_fill_slot()


# ── Speech ──────────────────────────────────────────────────────────────────

## Says [param line] from [param ship]'s bubble when the wing's voice is free
## and no other ship is mid-line, and returns once it has been read and the
## pause after it has passed. Dropped if the lines waiting were cancelled
## (_speech_gen) or the ship has gone. The bubble stays where it is: no fold
## into the comms badge between lines, so it doesn't fly about.
func _speak(ship: Enemy, line: String, extra_hold: float = 0.0) -> void:
	var gen: int = _speech_gen
	while _speaking:
		await get_tree().process_frame
	if gen != _speech_gen or not _can_talk(ship):
		return
	_speaking = true
	await _wait_for_quiet(ship)
	if gen == _speech_gen and _can_talk(ship):
		var bubble: EnemyDialogueManager = ship.dialogue_manager
		var hold: float = clampf(_LINE_HOLD_BASE_SECONDS + _LINE_HOLD_PER_CHAR_SECONDS * line.length(),
			_LINE_HOLD_MIN_SECONDS, _LINE_HOLD_MAX_SECONDS) + extra_hold
		bubble.stow_point = Callable()
		# The box fades as the hold ends, rather than lingering over the next line.
		bubble.dialogue_time_shown = hold
		bubble.show_dialogue(line, ally_state.faction, false)
		await get_tree().create_timer(bubble.character_reveal_time * line.length() + hold).timeout
	await get_tree().create_timer(_LINE_PAUSE_SECONDS).timeout
	_speaking = false


func _can_talk(ship: Enemy) -> bool:
	return is_instance_valid(ship) and ship.health.health > 0 and ship.dialogue_manager != null


## Waits (bounded) while any other ship's bubble is out, so the wing's lines
## never land on top of an echo's.
func _wait_for_quiet(ship: Enemy) -> void:
	var waited: float = 0.0
	while waited < _QUIET_TIMEOUT_SECONDS and _others_speaking(ship):
		await get_tree().process_frame
		waited += get_process_delta_time()


func _others_speaking(ship: Enemy) -> bool:
	if not is_instance_valid(ship):
		return false
	for node: Node in get_tree().get_nodes_in_group(&"enemy_dialogue_boxes"):
		var other: EnemyDialogueManager = node as EnemyDialogueManager
		if other != null and other != ship.dialogue_manager and other.is_speaking():
			return true
	return false


# ── Leaving with a die ──────────────────────────────────────────────────────

## The ship's beat between being given the die and leaving with it, awaited
## by EscapeWithDiceEvent before anything leaves the board (so the fleet, the
## slot and the endings all wait, and nothing the player does can cut in: the
## enemy turn is still running). Its parting line first, held to be read, then
## the drive building up in its faction's colour. The ordinary jump-out
## (Enemy.jump_away) follows.
func _departure_beat(ship: Enemy) -> void:
	if not _running or not is_aboard(ship):
		return
	_beat_ship = ship
	# Whatever it had queued to say gives way to this.
	_speech_gen += 1
	var last: bool = is_instance_valid(Globals.player) and Globals.player.num_of_dice <= 1
	await get_tree().create_timer(_PARTING_LEAD_SECONDS).timeout
	if not _running:
		return
	await _speak(ship, tr("RECKONING_ALLY_LAST_DIE" if last else "RECKONING_ALLY_CARRIES"),
		_LAST_DIE_EXTRA_HOLD_SECONDS if last else 0.0)
	if _running and _can_talk(ship):
		await _build_jump(ship)


## The charge-up: motes drawn in and the hull flickering white (JumpFx), the
## hull stretching and shaking harder, and rings closing on it, for
## _PARTING_CHARGE_SECONDS.
func _build_jump(ship: Enemy) -> void:
	var manager: EnemyGraphicsManager = ship.graphics_manager
	var hull: Node2D = manager.ship_graphics if manager else null
	if hull == null:
		return
	var color: Color = ship.departure_color()
	var effects: JumpFx = JumpFx.new(Globals.enemy_manager)
	effects.charge(hull, _PARTING_CHARGE_SECONDS, color)
	var stretch: Tween = hull.create_tween()
	stretch.tween_property(hull, "scale", hull.scale * _PARTING_STRETCH, _PARTING_CHARGE_SECONDS) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_shake(manager)
	for _pulse: int in _PARTING_PULSES:
		await get_tree().create_timer(_PARTING_CHARGE_SECONDS / _PARTING_PULSES).timeout
		if not is_instance_valid(ship) or not is_instance_valid(hull):
			return
		effects.ring(hull.global_position, color, 30.0, 4.0, 0.45)


## Jitters the ship's graphics holder (not the hull, which the bob owns) with
## a growing strength, and puts it back.
func _shake(manager: EnemyGraphicsManager) -> void:
	var rest: Vector2 = manager.position
	var tween: Tween = manager.create_tween()
	var steps: int = int(_PARTING_CHARGE_SECONDS / _PARTING_SHAKE_STEP_SECONDS)
	for step: int in steps:
		var strength: int = maxi(1, roundi(_PARTING_SHAKE_PIXELS * float(step) / steps))
		var jitter: Vector2 = Vector2(
			RNGManager.randi_range(RNGManager.Bucket.COSMETIC, -strength, strength),
			RNGManager.randi_range(RNGManager.Bucket.COSMETIC, -strength, strength))
		tween.tween_property(manager, "position", rest + jitter, _PARTING_SHAKE_STEP_SECONDS)
	tween.tween_property(manager, "position", rest, _PARTING_SHAKE_STEP_SECONDS)


## The bank moved: an ally aboard with the bank nearly full tells the player
## to go without them, once.
func on_bank(fraction: float) -> void:
	if not _running or not is_instance_valid(_aboard) or _aboard.health.health <= 0:
		return
	if fraction < nearly_full_fraction or _warned.has(_aboard.get_instance_id()) or _aboard == _beat_ship:
		return
	_warned[_aboard.get_instance_id()] = true
	_speak(_aboard, tr("RECKONING_ALLY_DRIVE_LIT"))


# ── Saved ships ─────────────────────────────────────────────────────────────

func _fill_slot() -> void:
	if not _running or _held or _slot_busy or is_instance_valid(_aboard) or _waiting.is_empty():
		return
	var entry: Dictionary = _waiting.pop_front()
	var resource: EnemyResource = _ally_resource(str(entry.get("enemy", "")))
	if resource == null:
		_fill_slot()
		return
	var ship: Enemy = Globals.enemy_manager.spawn_escort(resource, ally_state, 0)
	ship.position = EnemyManager.ESCORT_SLOT
	_aboard = ship
	_aboard_entry = entry
	ship.departure_prelude = _departure_beat
	_jump_in(ship)
	_announce(ship, entry)


## The saved ship as it flies here: its own hull and name, on the wing's
## table. A copy made through ContentText, so its name still translates.
func _ally_resource(enemy_id: String) -> EnemyResource:
	var path: String = ContentRegistry.get_enemy_path(enemy_id)
	if path.is_empty() or ally_table == null:
		return null
	var base: EnemyResource = load(path) as EnemyResource
	if base == null:
		return null
	var resource: EnemyResource = ContentText.copy(base) as EnemyResource
	var table: Array[EnemyTurnActionList] = [ally_table]
	resource.action_options = table
	return resource


## Out of the fleet's jump, in its own faction's colour, already in the slot.
func _jump_in(ship: Enemy) -> void:
	var hull: Node2D = ship.graphics_manager.ship_graphics if ship.graphics_manager else null
	if hull == null:
		return
	JumpFx.new(Globals.enemy_manager).jump_in(hull, ship.departure_color(), _JUMP_HEADING)


## Its lines as it arrives, one at a time, each read before the next. Two at
## most: how its escort went if it rode along, else who is still coming (the
## queue's telegraph shows the names too), then what it's here for, which is
## the one left standing.
func _announce(ship: Enemy, entry: Dictionary) -> void:
	var gen: int = _speech_gen
	var lines: Array[String] = []
	var escort_line: String = ReckoningDirector.ESCORT_LINES.get(str(entry.get("escort", "")), "")
	lines.append(tr(escort_line) if not escort_line.is_empty() else _queue_line())
	lines.append(tr("RECKONING_ALLY_ARRIVES"))
	await get_tree().create_timer(_ARRIVAL_DELAY_SECONDS).timeout
	for line: String in lines:
		if not _running or gen != _speech_gen or not is_aboard(ship) or ship.health.health <= 0:
			return
		await _speak(ship, line)


## Names, never numbers: the next saved ship still to come, or that there's
## nobody left.
func _queue_line() -> String:
	var next: Array[Dictionary] = _waiting.duplicate()
	next.append_array(upcoming.call())
	if next.is_empty():
		return tr("RECKONING_ALLY_LAST")
	var path: String = ContentRegistry.get_enemy_path(str(next[0].get("enemy", "")))
	var resource: EnemyResource = load(path) as EnemyResource if not path.is_empty() else null
	var name: String = resource.display_name() if resource else ""
	return tr("RECKONING_ALLY_NEXT").format({"name": name})


## Run for it wears Getaway's icon recoloured green (no new art: the same
## shape says "leaves with your die", the green says it's a gift).
func _dress_run_for_it() -> void:
	if ally_table == null:
		return
	for option: EnemyActionOptionResource in ally_table.actions_possible:
		var action: EnemyActionResource = option.base_action if option else null
		if action == null or not action.name.begins_with("Run"):
			continue
		action.indicator_texture = _green(action.indicator_texture)
		action.info_texture = _green(action.info_texture)


static func _green(texture: Texture2D) -> Texture2D:
	if texture == null:
		return texture
	if _greened.has(texture):
		return _greened[texture]
	var image: Image = texture.get_image()
	if image == null:
		return texture
	image.convert(Image.FORMAT_RGBA8)
	for y: int in image.get_height():
		for x: int in image.get_width():
			var pixel: Color = image.get_pixel(x, y)
			for from: Color in _GREEN_RAMP:
				if pixel.a > 0.0 and pixel.is_equal_approx(from):
					image.set_pixel(x, y, _GREEN_RAMP[from])
	var greened: ImageTexture = ImageTexture.create_from_image(image)
	_greened[texture] = greened
	_greened[greened] = greened
	return greened


# ── Spared ships ────────────────────────────────────────────────────────────

## A spared ship pays its debt: it jumps in from the fleet, makes one strafing
## pass across every hostile but "You", calls out and jumps away.
## [param hostiles] says who is fighting the player now.
func strafe(entry: Dictionary, hostiles: Callable) -> void:
	if not _running:
		return
	var path: String = ContentRegistry.get_enemy_path(str(entry.get("enemy", "")))
	var resource: EnemyResource = load(path) as EnemyResource if not path.is_empty() else null
	if resource == null or resource.ship_graphics_scene == null:
		return
	var layer: Node2D = Globals.enemy_manager
	var hull: Node2D = resource.ship_graphics_scene.instantiate() as Node2D
	if hull == null:
		return
	var color: Color = resource.faction.color if resource.faction else JumpFx.RED
	var width: float = Globals.SCREEN_SIZE.x
	layer.add_child(hull)
	hull.position = Vector2(width - _SCREEN_MARGIN, _STRAFE_HEIGHT)
	var effects: JumpFx = JumpFx.new(layer)
	effects.jump_in(hull, color, _JUMP_HEADING)
	var pass_tween: Tween = hull.create_tween()
	pass_tween.tween_property(hull, "position:x", _SCREEN_MARGIN, _STRAFE_SECONDS)
	await get_tree().create_timer(_STRAFE_SECONDS * 0.4).timeout
	if _running and is_instance_valid(hull):
		_fire_pass(hull, color, hostiles.call())
		Juice.callout(hull, tr("RECKONING_DEBT_PAID"), color)
	await get_tree().create_timer(_STRAFE_SECONDS * 0.6).timeout
	if not is_instance_valid(hull):
		return
	effects.jump_out(hull, color, _JUMP_HEADING)
	await get_tree().create_timer(JumpFx.STRETCH_SECONDS).timeout
	if is_instance_valid(hull):
		hull.queue_free()


## One shot at each of [param targets], all for the same roll: the old Old
## Debt tile's multiplier times a d6 thrown for the pass.
func _fire_pass(hull: Node2D, color: Color, targets: Array[Enemy]) -> void:
	var engine: ScenarioEngine = ScenarioEngine.current()
	if targets.is_empty() or engine == null:
		return
	var hits: Array[Node] = []
	for target: Enemy in targets:
		if is_instance_valid(target) and not FateSelf.is_self(target):
			hits.append(target)
			Juice.zap(hull, hull.global_position, target.global_position, color)
	if hits.is_empty():
		return
	var event: DamageEvent = DamageEvent.new()
	event.amount = debt_strafe_multiplier * _rng.randi_range(1, 6)
	event.actor = Globals.player
	event.effect_source = Globals.player
	event.targets = hits
	engine.queue_event(event)
