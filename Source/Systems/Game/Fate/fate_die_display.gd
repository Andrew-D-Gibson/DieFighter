class_name FateDieDisplay
extends Node2D
## Fate's Die in the cockpit (LORE.md §5): a bone-white die on a chain from
## the canopy, beside the gold pair, always in view once the pilgrim has
## handed it over. It turns slowly on its chain, showing the faces carved so
## far, and swings when the ship is hit.
##
## A carving is a moment: the die spins, lands on the new face, flares in its
## colour and calls it out. A carving waiting for a choice (the die is full)
## keeps it rattling until the player picks. In the Reckoning, Fate throws it
## at the start of every round: it shakes on its own and lands on the face
## that rules the round.
##
## When the hole sends "You" (RECKONING_ENDINGS.md §4), the die tears itself
## off the chain and goes to it (FateSelfPresentation, made here, runs the
## rest). The broken chain hangs empty for the rest of that fight; the die is
## back on it once the fight is over or reloaded.
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
## Leaving: how long it fights the chain, how hard, and how much of the chain
## stays on the hook once it snaps.
const _BREAK_RATTLE_SECONDS: float = 1.0
const _BREAK_RATTLE: float = 95.0
const _STUB_SHARE: float = 0.45
## How long the die falls after the snap before it shatters.
const _FALL_SECONDS: float = 0.14
const _SNAP_SFX: SoundEffectResource = preload("res://Source/Resources/SoundEffectResources/SoundEffects/die_dead_click.tres")

## Where the die is: on its chain, fighting it, falling free, or gone to
## "You" (only the chain's stub left).
enum Hold { HANGING, BREAKING, FALLING, GONE }

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
var _hold_state: Hold = Hold.HANGING
## While breaking loose: 0 to 1, how violently it rattles.
var _rattle: float = 0.0
var _rattle_tween: Tween
## How far the die has fallen since the chain snapped.
var _fall: Vector2 = Vector2.ZERO
var _fall_velocity: Vector2 = Vector2.ZERO


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

	Events.load_game_save.connect(func(_save: GameSaveResource) -> void: _refresh.call_deferred())
	Events.fate_die_received.connect(_on_received)
	Events.fate_face_carved.connect(_on_carved)
	Events.fate_carve_pending.connect(func(_face: int) -> void: _kick(_HIT_KICK))
	Events.fate_die_rolled.connect(_on_rolled)
	Events.player_health_hit.connect(func() -> void: _kick(_HIT_KICK))
	Events.player_shields_hit.connect(func() -> void: _kick(_HIT_KICK * 0.5))
	Events.jump.connect(func() -> void: _kick(_HIT_KICK * 1.5))
	var presentation: FateSelfPresentation = FateSelfPresentation.new()
	presentation.display = self
	add_child(presentation)
	_refresh()


func _ledger() -> FateLedger:
	return Globals.fate_ledger


func _refresh() -> void:
	var ledger: FateLedger = _ledger()
	_drop = 1.0 if ledger and ledger.has_die else 0.0
	visible = _drop > 0.0
	queue_redraw()


## Whether the die is on its chain (not gone to "You").
func is_hanging() -> bool:
	return _hold_state == Hold.HANGING and visible


## The die fights its chain, the chain snaps and the die falls clear. Resolves
## at the moment it should shatter; from then on only the chain's stub is
## drawn, until restore().
func break_loose() -> void:
	if not is_hanging():
		_hold_state = Hold.GONE
		return
	_hold_state = Hold.BREAKING
	_tumble = _BREAK_RATTLE_SECONDS
	_flare(Globals.purple)
	Events.camera_shake_small.emit()
	_rattle_tween = create_tween()
	_rattle_tween.tween_property(self, "_rattle", 1.0, _BREAK_RATTLE_SECONDS * 0.8).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	# The die's own throw rattle, faster and faster as it strains.
	for i: int in 5:
		get_tree().create_timer(_BREAK_RATTLE_SECONDS * (1.0 - pow(0.62, i + 1))).timeout.connect(
			func() -> void: Events.play_sound.emit(_ROLL_SFX))
	await get_tree().create_timer(_BREAK_RATTLE_SECONDS).timeout
	if _hold_state != Hold.BREAKING:
		return
	_hold_state = Hold.FALLING
	_rattle = 0.0
	_fall = Vector2.ZERO
	# Flung the way it was swinging, and down.
	_fall_velocity = Vector2(cos(_angle), -sin(_angle)) * _angular_velocity * chain_length * 0.4 + Vector2(0, 30)
	_angular_velocity *= 0.3
	Events.play_sound.emit(_SNAP_SFX)
	await get_tree().create_timer(_FALL_SECONDS).timeout
	if _hold_state == Hold.FALLING:
		_hold_state = Hold.GONE
	queue_redraw()


## Back on its chain, as it was: the fight "You" took it in is over.
func restore() -> void:
	if _hold_state == Hold.HANGING:
		return
	_hold_state = Hold.HANGING
	if _rattle_tween and _rattle_tween.is_valid():
		_rattle_tween.kill()
	_rattle = 0.0
	_fall = Vector2.ZERO
	_tumble = 0.0
	_refresh()


## The die as it shows now, for its pieces when it shatters.
func shown_texture() -> Texture2D:
	var ledger: FateLedger = _ledger()
	var face: FateDie.Face = _tumble_face if _tumble > 0.0 else (ledger.die.face_at(_shown_slot) if ledger else FateDie.Face.BLANK)
	return FateDieArt.face_texture(face)


func _process(delta: float) -> void:
	if not visible:
		return
	_age += delta
	# A pendulum with a lazy, off-beat sway, so it never hangs dead still.
	var push: float = sin(_age * 0.9) * 0.4 + sin(_age * 2.3) * 0.25
	var accel: float = -_GRAVITY / chain_length * sin(_angle) + push * _IDLE_SWAY / chain_length
	var ledger: FateLedger = _ledger()
	if ledger and ledger.has_pending():
		# Rattling for a choice.
		accel += sin(_age * 40.0) * 30.0
	if _rattle > 0.0:
		accel += sin(_age * 57.0) * _BREAK_RATTLE * _rattle + sin(_age * 23.0) * _BREAK_RATTLE * 0.4 * _rattle
	if _hold_state == Hold.FALLING:
		_fall_velocity.y += _GRAVITY * delta
		_fall += _fall_velocity * delta
	_angular_velocity += accel * delta
	_angular_velocity -= _angular_velocity * _DAMPING * delta
	_angle = clampf(_angle + _angular_velocity * delta, -1.2, 1.2)

	if _tumble > 0.0:
		_tumble -= delta
		_tumble_step -= delta
		if _tumble_step <= 0.0:
			_tumble_step = 0.06
			_tumble_face = FateDie.carvable_faces()[int(_age * 97.0) % 6]
	elif ledger and ledger.has_die:
		_hold += delta
		if _hold >= _FACE_HOLD:
			_hold = 0.0
			_turn_to_next_carved()
	if _rattle > 0.0:
		_glow = maxf(_glow, 0.5 + 0.5 * sin(_age * 30.0))
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


## Where the die hangs now, in this node's space: for a call-out of its own.
func die_position() -> Vector2:
	return _die_centre()


## Where the die hangs at rest, straight down from the hook.
func rest_position() -> Vector2:
	return (anchor + Vector2(0, chain_length + FateDieArt.SIZE / 2.0)).round()


func _die_centre() -> Vector2:
	var length: float = chain_length * _drop
	var centre: Vector2 = anchor + Vector2(sin(_angle), cos(_angle)) * length + Vector2(0, FateDieArt.SIZE / 2.0) + _fall
	if _rattle > 0.5:
		# Straining at the hook: it can't hold still for a frame.
		centre += Vector2(signf(sin(_age * 71.0)), signf(sin(_age * 53.0))) * (_rattle - 0.5) * 2.0
	return centre.round()


func _draw() -> void:
	var ledger: FateLedger = _ledger()
	if not ledger or not ledger.has_die:
		return
	var local_anchor: Vector2 = anchor - global_position
	var centre: Vector2 = _die_centre() - global_position
	var top: Vector2 = centre - Vector2(0, FateDieArt.SIZE / 2.0)
	if _hold_state == Hold.FALLING or _hold_state == Hold.GONE:
		# Snapped: what's left swings from the hook, the die's end gone.
		var stub_end: Vector2 = local_anchor + Vector2(sin(_angle), cos(_angle)) * chain_length * _drop * _STUB_SHARE
		_draw_chain(local_anchor, stub_end)
		if _hold_state == Hold.GONE:
			return
	else:
		_draw_chain(local_anchor, top)

	if _glow > 0.0:
		var radius: float = FateDieArt.SIZE * 0.5 + 2.0 + (1.0 - _glow) * 4.0
		draw_circle(centre, radius, Color(_glow_color, _glow * 0.35))
	var face: FateDie.Face = _tumble_face if _tumble > 0.0 else ledger.die.face_at(_shown_slot)
	var texture: Texture2D = FateDieArt.face_texture(face)
	draw_texture(texture, (centre - Vector2(FateDieArt.SIZE, FateDieArt.SIZE) / 2.0).round())


## The chain, a pixel at a time so it stays crisp at any angle.
func _draw_chain(from: Vector2, to: Vector2) -> void:
	var steps: int = maxi(1, int(from.distance_to(to)))
	for i: int in steps:
		var p: Vector2 = from.lerp(to, i / float(steps)).round()
		draw_rect(Rect2(p, Vector2.ONE), _CHAIN if i % 2 == 0 else _CHAIN_DARK)


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
	_shown_slot = slot
	_hold = 0.0
	_tumble = 0.6
	_kick(_HIT_KICK)
	Events.play_sound.emit(_CARVE_SFX)
	var res: FateFaceResource = FateFaceCatalog.get_face(face as FateDie.Face)
	var color: Color = res.color if res else Globals.white
	get_tree().create_timer(0.6).timeout.connect(func() -> void:
		_flare(color)
		var text: String = tr("FATE_CALLOUT_CARVED").format({"face": res.display_face_name().to_upper() if res else ""})
		if old_face != FateDie.Face.BLANK:
			var old: FateFaceResource = FateFaceCatalog.get_face(old_face as FateDie.Face)
			text = tr("FATE_CALLOUT_CARVED_OVER").format({
				"face": res.display_face_name().to_upper() if res else "",
				"old": old.display_face_name().to_upper() if old else "",
			})
		Juice.callout_at(self, _die_centre() + Vector2(-26, 20), text, color)
		Juice.sparkle(self, _die_centre(), color, 10, 30.0, true)
	)


func _on_rolled(slot: int, face: int) -> void:
	if _hold_state != Hold.HANGING:
		# Gone to "You": the throws are its die's now.
		return
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
	if not ledger or not ledger.has_die or _hold_state != Hold.HANGING:
		return
	Events.show_info.emit(info_for(ledger))


## The die's info panel: every face it bears and what carves the rest.
static func info_for(ledger: FateLedger) -> InfoResource:
	var info: InfoResource = InfoResource.new()
	info.title_label_text = "[color=#%s]%s[/color]" % [FateDieArt.BONE.to_html(false), TranslationServer.translate("FATE_DIE_TITLE")]
	var die: FateDie = ledger.die
	info.top_label_text = TranslationServer.translate("FATE_DIE_CARVED_COUNT").format({
		"carved": FateDie.FACE_COUNT - die.blank_count(), "total": FateDie.FACE_COUNT})
	info.texture = FateDieArt.net_texture(die)
	var names: PackedStringArray = []
	for face: FateDie.Face in FateDie.carvable_faces():
		var n: int = die.count(face)
		var res: FateFaceResource = FateFaceCatalog.get_face(face)
		if n > 0 and res:
			names.append(res.coloured_name() + (" x%d" % n if n > 1 else ""))
	var lines: PackedStringArray = []
	if not names.is_empty():
		lines.append("  ".join(names))
	if die.is_full():
		lines.append(TranslationServer.translate("FATE_DIE_FULL_HINT"))
	else:
		lines.append(TranslationServer.translate("FATE_DIE_BLANK_HINT"))
	info.bottom_label_text = "\n".join(lines)
	return info
