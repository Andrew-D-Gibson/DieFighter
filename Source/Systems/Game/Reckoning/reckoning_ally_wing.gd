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
## Seconds between an ally's lines on arrival, so each can be read.
const _LINE_GAP_SECONDS: float = 2.6
## Seconds before the next ally comes into a slot just freed.
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
## with a die (Run for it is the only way it leaves alive), else it's lost.
## Either way the slot is free for the next.
func on_ship_left(ship: Enemy) -> void:
	if not is_aboard(ship):
		return
	var entry: Dictionary = _aboard_entry
	_aboard = null
	_aboard_entry = {}
	if ship.health.health > 0:
		saved_out.append(entry)
		var last: bool = is_instance_valid(Globals.player) and Globals.player.num_of_dice <= 0
		_say_parting(ship, tr("RECKONING_ALLY_LAST_DIE" if last else "RECKONING_ALLY_CARRIES"))
	else:
		lost.append(entry)
	if not _running:
		return
	await get_tree().create_timer(_SLOT_REFILL_SECONDS).timeout
	_fill_slot()


## A ship jumping out is gone in under a second, its speech bubble with it,
## so its parting line is left hanging where it was until it has been read.
func _say_parting(ship: Enemy, line: String) -> void:
	var bubble: EnemyDialogueManager = ship.dialogue_manager
	if bubble == null or not is_instance_valid(Globals.enemy_manager):
		return
	var stand_in: Node2D = Node2D.new()
	stand_in.name = &"PartingLine"
	Globals.enemy_manager.add_child(stand_in)
	stand_in.global_position = ship.global_position
	bubble.reparent(stand_in)
	# Fades where it hangs: the comms badge belongs to the next target now.
	bubble.stow_point = Callable()
	bubble.show_dialogue(line, ally_state.faction, false)
	await bubble.put_away
	if is_instance_valid(stand_in):
		stand_in.queue_free()


## The bank moved: an ally aboard with the bank nearly full tells the player
## to go without them, once.
func on_bank(fraction: float) -> void:
	if not _running or not is_instance_valid(_aboard) or _aboard.health.health <= 0:
		return
	if fraction < nearly_full_fraction or _warned.has(_aboard.get_instance_id()):
		return
	_warned[_aboard.get_instance_id()] = true
	_aboard.dialogue_manager.show_dialogue(tr("RECKONING_ALLY_DRIVE_LIT"), ally_state.faction, false)


# ── Saved ships ─────────────────────────────────────────────────────────────

func _fill_slot() -> void:
	if not _running or _held or is_instance_valid(_aboard) or _waiting.is_empty():
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


## Its lines as it arrives, one after another: how its escort went (if it
## rode along), what it's here for, and who is still coming.
func _announce(ship: Enemy, entry: Dictionary) -> void:
	var lines: Array[String] = []
	var escort_line: String = ReckoningDirector.ESCORT_LINES.get(str(entry.get("escort", "")), "")
	if not escort_line.is_empty():
		lines.append(tr(escort_line))
	lines.append(tr("RECKONING_ALLY_ARRIVES"))
	lines.append(_queue_line())
	for i: int in lines.size():
		await get_tree().create_timer(_LINE_GAP_SECONDS if i > 0 else 0.6).timeout
		if not _running or not is_aboard(ship) or ship.health.health <= 0:
			return
		ship.dialogue_manager.show_dialogue(lines[i], ally_state.faction, false)


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
