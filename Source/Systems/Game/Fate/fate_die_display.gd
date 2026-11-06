class_name FateDieDisplay
extends Node2D
## Fate's Die in the cockpit (LORE.md §5): a bone-white die on a chain from
## the canopy, beside the gold pair, always in view once the pilgrim has
## handed it over. It turns slowly on its chain, showing the faces carved so
## far, and swings when the ship is hit.
##
## A carving is a moment: the die spins, lands on the new face, flares in its
## colour and calls it out. Carvings come from what ships say and do, so the
## moment waits for every ship to finish talking (the die rattles meanwhile)
## rather than land on top of their lines. A carving waiting for a choice (the
## die is full) keeps it rattling until the player picks. In the Reckoning,
## Fate throws it at the start of every round: it shakes on its own and lands
## on the face that rules the round.
##
## Click it for every face it bears.

## The hook the chain hangs from, in screen pixels.
@export var anchor: Vector2 = Vector2(279, 3)
@export var chain_length: float = 18.0

const _CHAIN: Color = Color("#63605c")
const _CHAIN_DARK: Color = Color("#343330")
const _CARVE_SFX: SoundEffectResource = preload("res://Source/Resources/SoundEffectResources/SoundEffects/upgrade_trigger.tres")
const _RECEIVE_SFX: SoundEffectResource = preload("res://Source/Resources/SoundEffectResources/SoundEffects/die_dread_thunk.tres")
const _ROLL_SFX: SoundEffectResource = preload("res://Source/Resources/SoundEffectResources/SoundEffects/dice_reroll_blip.tres")
const _CLICKABLE: PackedScene = preload("res://Source/Systems/Components/Clickable/clickable.tscn")

## Seconds each carved face shows before the die turns to the next.
const _FACE_HOLD: float = 2.6
const _GRAVITY: float = 260.0
const _DAMPING: float = 1.2
const _IDLE_SWAY: float = 10.0
const _HIT_KICK: float = 22.0

## How long a carving's callout holds. Carvings are rare and they matter, so
## they read longer than a hit's callout.
const _CARVE_CALLOUT_SECONDS: float = 4.0
## The longest a carving waits for ships to stop talking before it plays
## anyway, so a chatty fight can't swallow it.
const _MAX_COMMS_WAIT_SECONDS: float = 12.0
const _COMMS_POLL_SECONDS: float = 0.25
## A beat between the last line going and the carving, so the two don't run
## together.
const _AFTER_COMMS_SECONDS: float = 0.4
## Between two carvings that came at once, so each gets its own moment.
const _BETWEEN_CARVINGS_SECONDS: float = 2.0

var _angle: float = 0.15
var _angular_velocity: float = 0.0
var _age: float = 0.0
## Which slot the die shows, and how long it has shown it.
var _shown_slot: int = 0
var _hold: float = 0.0
## While > 0 the die tumbles through its faces before settling on _shown_slot.
var _tumble: float = 0.0
var _tumble_face: FateDie.Face = FateDie.Face.BLANK
var _tumble_step: float = 0.0
## A flare in a face's colour, fading.
var _glow: float = 0.0
var _glow_color: Color = Color.WHITE
## How far down from its hook the die has come (0 hidden up in the canopy).
var _drop: float = 0.0
var _clickable: Clickable
## Carvings waiting for the ships to stop talking, oldest first, each
## [slot, face, old face, faces carved once it's in].
var _carvings_due: Array[Array] = []
var _announcing: bool = false


func _ready() -> void:
	z_index = 2
	_clickable = _CLICKABLE.instantiate()
	var shape: CollisionShape2D = CollisionShape2D.new()
	var rect: RectangleShape2D = RectangleShape2D.new()
	rect.size = Vector2(FateDieArt.SIZE + 2, FateDieArt.SIZE + 2)
	shape.shape = rect
	_clickable.add_child(shape)
	add_child(_clickable)
	_clickable.clicked.connect(_show_info)

	Events.load_game_save.connect(func(_save: GameSaveResource) -> void:
		# A carving still waiting belongs to the run as it was.
		_carvings_due.clear()
		_refresh.call_deferred())
	Events.fate_die_received.connect(_on_received)
	Events.fate_face_carved.connect(_on_carved)
	Events.fate_carve_pending.connect(func(_face: int) -> void: _kick(_HIT_KICK))
	Events.fate_die_rolled.connect(_on_rolled)
	Events.player_health_hit.connect(func() -> void: _kick(_HIT_KICK))
	Events.player_shields_hit.connect(func() -> void: _kick(_HIT_KICK * 0.5))
	Events.jump.connect(func() -> void: _kick(_HIT_KICK * 1.5))
	_refresh()


func _ledger() -> FateLedger:
	return Globals.fate_ledger


func _refresh() -> void:
	var ledger: FateLedger = _ledger()
	_drop = 1.0 if ledger and ledger.has_die else 0.0
	visible = _drop > 0.0
	queue_redraw()


func _process(delta: float) -> void:
	if not visible:
		return
	_age += delta
	# A pendulum with a lazy, off-beat sway, so it never hangs dead still.
	var push: float = sin(_age * 0.9) * 0.4 + sin(_age * 2.3) * 0.25
	var accel: float = -_GRAVITY / chain_length * sin(_angle) + push * _IDLE_SWAY / chain_length
	var ledger: FateLedger = _ledger()
	if ledger and (ledger.has_pending() or not _carvings_due.is_empty()):
		# Rattling for a choice, or with a carving about to show.
		accel += sin(_age * 40.0) * 30.0
	_angular_velocity += accel * delta
	_angular_velocity -= _angular_velocity * _DAMPING * delta
	_angle = clampf(_angle + _angular_velocity * delta, -1.2, 1.2)

	if _tumble > 0.0:
		_tumble -= delta
		_tumble_step -= delta
		if _tumble_step <= 0.0:
			_tumble_step = 0.06
			_tumble_face = FateDie.carvable_faces()[int(_age * 97.0) % 6]
	elif ledger and ledger.has_die and _carvings_due.is_empty():
		_hold += delta
		if _hold >= _FACE_HOLD:
			_hold = 0.0
			_turn_to_next_carved()
	_glow = maxf(0.0, _glow - delta * 1.2)
	_clickable.position = _die_centre() - global_position
	queue_redraw()


## Turns the die to its next slot, skipping blank faces while any are carved.
func _turn_to_next_carved() -> void:
	var die: FateDie = _ledger().die
	for i: int in range(1, FateDie.FACE_COUNT + 1):
		var slot: int = (_shown_slot + i) % FateDie.FACE_COUNT
		if die.face_at(slot) != FateDie.Face.BLANK or die.is_blank():
			_shown_slot = slot
			return


func _die_centre() -> Vector2:
	var length: float = chain_length * _drop
	return (anchor + Vector2(sin(_angle), cos(_angle)) * length + Vector2(0, FateDieArt.SIZE / 2.0)).round()


func _draw() -> void:
	var ledger: FateLedger = _ledger()
	if not ledger or not ledger.has_die:
		return
	var local_anchor: Vector2 = anchor - global_position
	var centre: Vector2 = _die_centre() - global_position
	var top: Vector2 = centre - Vector2(0, FateDieArt.SIZE / 2.0)
	# The chain, a pixel at a time so it stays crisp at any angle.
	var steps: int = maxi(1, int(local_anchor.distance_to(top)))
	for i: int in steps:
		var p: Vector2 = local_anchor.lerp(top, i / float(steps)).round()
		draw_rect(Rect2(p, Vector2.ONE), _CHAIN if i % 2 == 0 else _CHAIN_DARK)

	if _glow > 0.0:
		var radius: float = FateDieArt.SIZE * 0.5 + 2.0 + (1.0 - _glow) * 4.0
		draw_circle(centre, radius, Color(_glow_color, _glow * 0.35))
	var face: FateDie.Face = _tumble_face if _tumble > 0.0 else _face_shown_at(ledger, _shown_slot)
	var texture: Texture2D = FateDieArt.face_texture(face)
	draw_texture(texture, (centre - Vector2(FateDieArt.SIZE, FateDieArt.SIZE) / 2.0).round())


## What [param slot] shows: the face carved there, unless that carving is
## still waiting for its moment, which keeps the old face until then.
func _face_shown_at(ledger: FateLedger, slot: int) -> FateDie.Face:
	for carving: Array in _carvings_due:
		if carving[0] == slot:
			return carving[2] as FateDie.Face
	return ledger.die.face_at(slot)


func _kick(strength: float) -> void:
	_angular_velocity += strength / chain_length * (1.0 if _angular_velocity >= 0.0 else -1.0)


func _on_received() -> void:
	visible = true
	_drop = 0.0
	var tween: Tween = create_tween()
	tween.tween_property(self, "_drop", 1.0, 0.7).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	Events.play_sound.emit(_RECEIVE_SFX)
	_flare(Globals.yellow)
	Juice.callout_at(self, _die_centre() + Vector2(-18, 14), tr("FATE_CALLOUT_RECEIVED"), Globals.yellow)


func _on_carved(slot: int, face: int, old_face: int) -> void:
	var ledger: FateLedger = _ledger()
	var carved: int = FateDie.FACE_COUNT - ledger.die.blank_count() if ledger else 0
	_carvings_due.append([slot, face, old_face, carved])
	if not _announcing:
		_announce_carvings()


## Plays every carving due, one at a time, each once the ships are quiet.
func _announce_carvings() -> void:
	_announcing = true
	while not _carvings_due.is_empty():
		await _wait_for_quiet_comms()
		if _carvings_due.is_empty():
			break
		var carving: Array = _carvings_due.pop_front()
		_play_carving(carving[0], carving[1], carving[2], carving[3])
		if not _carvings_due.is_empty():
			await get_tree().create_timer(_BETWEEN_CARVINGS_SECONDS).timeout
	_announcing = false


func _wait_for_quiet_comms() -> void:
	# A carving and the line that comes with it are set off together, and the
	# line may show a frame or two later: look only after a beat.
	await get_tree().create_timer(_AFTER_COMMS_SECONDS).timeout
	var waited: float = 0.0
	while waited < _MAX_COMMS_WAIT_SECONDS and _someone_is_talking():
		await get_tree().create_timer(_COMMS_POLL_SECONDS).timeout
		waited += _COMMS_POLL_SECONDS
	if waited > 0.0:
		await get_tree().create_timer(_AFTER_COMMS_SECONDS).timeout


func _someone_is_talking() -> bool:
	for node: Node in get_tree().get_nodes_in_group(&"enemy_dialogue_boxes"):
		var box: EnemyDialogueManager = node as EnemyDialogueManager
		if box and box.is_speaking():
			return true
	return false


## [param carved] is how many faces were carved once this one was in.
func _play_carving(slot: int, face: int, old_face: int, carved: int) -> void:
	_shown_slot = slot
	_hold = 0.0
	_tumble = 0.6
	_kick(_HIT_KICK)
	Events.play_sound.emit(_CARVE_SFX)
	var res: FateFaceResource = FateFaceCatalog.get_face(face as FateDie.Face)
	var color: Color = res.color if res else Globals.white
	get_tree().create_timer(0.6).timeout.connect(func() -> void:
		_flare(color)
		var face_name: String = res.display_face_name().to_upper() if res else ""
		var text: String = tr("FATE_CALLOUT_CARVED").format({"face": face_name})
		if old_face != FateDie.Face.BLANK:
			var old: FateFaceResource = FateFaceCatalog.get_face(old_face as FateDie.Face)
			text = tr("FATE_CALLOUT_CARVED_OVER").format({
				"face": face_name,
				"old": old.display_face_name().to_upper() if old else "",
			})
		Juice.callout_at(self, _die_centre() + Vector2(-26, 20), text, color, false, null, _CARVE_CALLOUT_SECONDS)
		Juice.callout_at(self, _die_centre() + Vector2(-26, 29),
			tr("FATE_CALLOUT_CARVED_COUNT").format({"carved": carved, "total": FateDie.FACE_COUNT}),
			Globals.purple, false, null, _CARVE_CALLOUT_SECONDS)
		Juice.sparkle(self, _die_centre(), color, 10, 30.0, true)
	)


func _on_rolled(slot: int, face: int) -> void:
	_shown_slot = slot
	_hold = -2.0
	_tumble = 0.9
	_kick(_HIT_KICK * 1.5)
	Events.play_sound.emit(_ROLL_SFX)
	var color: Color = FateFaceCatalog.color_of(face as FateDie.Face)
	get_tree().create_timer(0.9).timeout.connect(func() -> void:
		_flare(color)
		Juice.ring(self, _die_centre(), color, 18.0)
	)


func _flare(color: Color) -> void:
	_glow = 1.0
	_glow_color = color


func _show_info() -> void:
	var ledger: FateLedger = _ledger()
	if not ledger or not ledger.has_die:
		return
	Events.show_info.emit(info_for(ledger))


## The die's info panel: every face it bears, and, pointed at, what carves
## each. What a face does is left for the Reckoning to show.
static func info_for(ledger: FateLedger) -> InfoResource:
	var info: InfoResource = InfoResource.new()
	info.title_label_text = "[color=#%s]%s[/color]" % [FateDieArt.BONE.to_html(false), TranslationServer.translate("FATE_DIE_TITLE")]
	var die: FateDie = ledger.die
	info.top_label_text = TranslationServer.translate("FATE_DIE_CARVED_COUNT").format({
		"carved": FateDie.FACE_COUNT - die.blank_count(), "total": FateDie.FACE_COUNT})
	info.texture = FateDieArt.net_texture(die)
	var blank_text: String = _blank_face_text()
	for slot: int in FateDie.FACE_COUNT:
		var res: FateFaceResource = FateFaceCatalog.get_face(die.face_at(slot))
		var text: String = blank_text
		if die.face_at(slot) != FateDie.Face.BLANK and res:
			text = TranslationServer.translate("FATE_FACE_HOVER_CARVED").format({
				"face": res.coloured_name(), "carved_by": res.display_carved_by()})
		info.add_hotspot(Rect2(FateDieArt.net_face_rect(slot)), text)
	var names: PackedStringArray = []
	for face: FateDie.Face in FateDie.carvable_faces():
		var n: int = die.count(face)
		var res: FateFaceResource = FateFaceCatalog.get_face(face)
		if n > 0 and res:
			names.append(res.coloured_name() + (" x%d" % n if n > 1 else ""))
	var lines: PackedStringArray = []
	if not names.is_empty():
		lines.append("  ".join(names))
	lines.append(TranslationServer.translate("FATE_DIE_HOVER_HINT"))
	if die.is_full():
		lines.append(TranslationServer.translate("FATE_DIE_FULL_HINT"))
	else:
		lines.append(TranslationServer.translate("FATE_DIE_BLANK_HINT"))
	info.bottom_label_text = "\n".join(lines)
	return info


## A blank face's popup: every face a choice could carve there, and how.
static func _blank_face_text() -> String:
	var lines: PackedStringArray = []
	for face: FateDie.Face in FateDie.carvable_faces():
		var res: FateFaceResource = FateFaceCatalog.get_face(face)
		if res:
			lines.append(TranslationServer.translate("FATE_FACE_HOVER_BLANK_LINE").format({
				"face": res.coloured_name(), "carved_by": res.display_carved_by()}))
	return TranslationServer.translate("FATE_FACE_HOVER_BLANK").format({"faces": "\n".join(lines)})
