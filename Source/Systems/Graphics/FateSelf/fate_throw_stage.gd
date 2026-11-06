class_name FateThrowStage
extends Node2D
## Fate's throw at the start of every Reckoning round (RECKONING_ENDINGS.md),
## made slow enough to read. The screen dims; the die (the cube over "You", or
## the bone die off the canopy's chain before "You" comes) flies out to the
## middle of the screen and rattles, then is thrown for real onto an invisible
## tray (FateThrowDie) and lands on the face Fate already chose. That face
## comes up in a card with what it does this round, and the round waits for
## the player's green Close. Then the die goes back where it came from and the
## dim lifts.
##
## Pure show. ReckoningDirector decides the face (seeded RNG, long before this
## runs) and awaits throw_die(); this changes nothing in the game. It takes
## no turns of its own, so the card is held by the same full-screen dim that
## holds a StoryBox.
##
## Made by FateDieDisplay, which it borrows the canopy die from (and, through
## FateSelfPresentation, the cube over "You"). Draws in world space whatever
## its parent does (top_level).

const _ROLL_SFX: SoundEffectResource = preload("res://Source/Resources/SoundEffectResources/SoundEffects/dice_reroll_blip.tres")
const _LAND_SFX: SoundEffectResource = preload("res://Source/Resources/SoundEffectResources/SoundEffects/die_dread_thunk.tres")
const _CARD_SFX: SoundEffectResource = preload("res://Source/Resources/SoundEffectResources/SoundEffects/upgrade_trigger.tres")
const _POP_SFX: SoundEffectResource = preload("res://Source/Resources/SoundEffectResources/SoundEffects/shop_stock_pop.tres")
const _SNAP_SHADER: Shader = preload("res://Assets/Shaders/palette_snap.gdshader")
## Green, as every "carry on, nothing to weigh up" button is.
const _CLOSE_BUTTON: PackedScene = preload("res://Source/Systems/UI/Buttons/medium_green_button.tscn")

const _DIM_COLOR: Color = Color(0.027451, 0.0117647, 0.054902, 0.88)
## Over the other cards (z 40) and StoryBox's dim (45): nothing shows through.
const _Z: int = 46
const _DIM_SECONDS: float = 0.35
const _FLY_SECONDS: float = 0.55
## The least the die rattles before it's thrown, and how fast it jitters.
const _RATTLE_MIN_SECONDS: float = 0.35
const _RATTLE_STEP_SECONDS: float = 0.05
const _RATTLE_PIXELS: float = 1.5
## Where the tray's middle is on screen, and where the die sits over the card
## once it has landed.
const _TRAY_CENTER: Vector2 = Vector2(160.0, 92.0)
const _PRESENT_POINT: Vector2 = Vector2(160.0, 34.0)
const _SLIDE_SECONDS: float = 0.35
const _CARD_TOP: float = 67.0
const _CARD_WIDTH: int = 196
const _CARD_PADDING: Vector2 = Vector2(8, 5)
## A beat before Close works, so a click still in flight can't skip the card.
const _CLOSE_DELAY_SECONDS: float = 0.45
const _RETURN_SECONDS: float = 0.5
const _DIM_OUT_SECONDS: float = 0.4

signal _replay_done()
signal _closed()

static var _instance: FateThrowStage

## What the throw borrows its die from.
var display: FateDieDisplay
var presentation: FateSelfPresentation

var _run: int = 0
var _active: bool = false
var _rattling_rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _from_die: FateSelfDie
var _slot: int = 0
var _face: FateDie.Face = FateDie.Face.BLANK
var _root: Control
var _dim: ColorRect
var _view: Sprite2D
var _fly: Sprite2D
var _snap: ShaderMaterial
var _throw: FateThrowDie
var _panel: TileUnlockPopup._Panel
var _column: VBoxContainer
var _close_button: Button
## Replaying: seconds into the replay.
var _replaying: bool = false
var _replay_time: float = 0.0
var _awaiting_close: bool = false
var _first_knock: bool = true
## The step in progress, so an abort can stop it.
var _tween: Tween


## The stage that's in the scene, or null (a scene with no canopy die).
static func active() -> FateThrowStage:
	return _instance if is_instance_valid(_instance) else null


## Whether there's nobody to show a throw to: the AutoPilot would never close
## the card, and a headless run has no screen to dim.
static func should_skip() -> bool:
	if is_instance_valid(AutoPilot) and AutoPilot.is_playing():
		return true
	return DisplayServer.get_name() == "headless"


func _ready() -> void:
	top_level = true
	z_as_relative = false
	z_index = _Z
	_instance = self
	Events.load_scenario.connect(func(_scenario: ScenarioResource) -> void: abort())
	Events.load_game_save.connect(func(_save: GameSaveResource) -> void: abort())
	Events.combat_finished.connect(abort)


func _exit_tree() -> void:
	if _instance == self:
		_instance = null


## Plays Fate's throw landing on side [param slot], showing [param face], and
## returns once the player has closed the card and the die is home. Returns at
## once when it shouldn't or can't show (should_skip(), no die on screen).
## [param seed_value] seeds the tumble only; it never touches the game's RNG.
func throw_die(slot: int, face: FateDie.Face, seed_value: int) -> void:
	if _active or should_skip() or not _pick_source():
		return
	_active = true
	_run += 1
	var run: int = _run
	_slot = slot
	_face = face
	_first_knock = true
	_rattling_rng.seed = seed_value
	_build()
	_lift_source()
	_throw.throw(seed_value)
	Events.play_sound.emit(_ROLL_SFX)

	await _fly_out()
	if run != _run:
		return
	await _rattle_until_thrown(run)
	if run != _run:
		return
	await _tumble()
	if run != _run:
		return
	await _present(run)
	if run != _run:
		return
	await _closed
	if run != _run:
		return
	await _return_home()
	if run != _run:
		return
	_finish()


## Ends a throw that's under way without ceremony: the fight it belonged to is
## over, or a save is loading. The die goes back where it was.
func abort() -> void:
	if not _active:
		return
	_run += 1
	if _tween and _tween.is_valid():
		_tween.kill()
	_finish()
	_closed.emit()
	_replay_done.emit()


## A tween for the next step, remembered so abort() can stop it.
func _new_tween() -> Tween:
	_tween = create_tween()
	return _tween


func _process(delta: float) -> void:
	if not _replaying:
		return
	_replay_time += delta
	_throw.replay_at(_replay_time)
	if _replay_time >= _throw.replay_seconds():
		_replaying = false
		_replay_done.emit()


func _unhandled_input(event: InputEvent) -> void:
	if not _active or not (event is InputEventKey):
		return
	# Nothing reaches the game while the card is up, as with a StoryBox.
	get_viewport().set_input_as_handled()
	if _awaiting_close and not _close_button.disabled and event.pressed and not event.echo:
		_close()


# ── Where the die comes from ────────────────────────────────────────────────

## Finds the die on screen to throw: the cube over "You" once it's there,
## otherwise the canopy's. False when there's none (it's mid-shatter, say).
func _pick_source() -> bool:
	_from_die = presentation.thrown_die() if presentation else null
	if _from_die:
		return true
	return display != null and display.can_lift()


func _source_point() -> Vector2:
	if is_instance_valid(_from_die):
		return _from_die.hover_point()
	return display.die_position() if display else _TRAY_CENTER


## The source die's picture as it leaves ([param landed] false) or comes back
## showing the thrown face: the cube's own little 3D render, or the bone die's
## flat face.
func _source_texture(landed: bool) -> Texture2D:
	if is_instance_valid(_from_die):
		return _from_die.spin_texture()
	return FateDieArt.face_texture(_face) if landed else display.shown_texture()


func _lift_source() -> void:
	if is_instance_valid(_from_die):
		_from_die.lift_out(_slot)
	elif display:
		display.set_lifted(true)


func _unlift_source() -> void:
	if display:
		display.set_lifted(false)
	if is_instance_valid(_from_die):
		# Back, unless the Reckoning's land_on already put it there.
		_from_die.modulate.a = 1.0


## How much the source's picture grows to be the thrown die's size: both draw
## the cube at the bone die's 11 pixels.
func _flight_scale() -> float:
	return float(_throw.cube_pixels()) / float(FateDieArt.SIZE)


# ── Building ────────────────────────────────────────────────────────────────

func _build() -> void:
	_root = Control.new()
	_root.size = Globals.SCREEN_SIZE
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)
	_dim = ColorRect.new()
	_dim.color = _DIM_COLOR
	_dim.size = Globals.SCREEN_SIZE
	# Swallows clicks so nothing under the dim is touched while it's up.
	_dim.mouse_filter = Control.MOUSE_FILTER_STOP
	_dim.modulate.a = 0.0
	_root.add_child(_dim)

	_snap = ShaderMaterial.new()
	_snap.shader = _SNAP_SHADER
	_throw = FateThrowDie.new()
	add_child(_throw)
	var ledger: FateLedger = Globals.fate_ledger
	if ledger:
		_throw.show_faces(ledger.die.faces)
	_throw.knocked.connect(_on_knocked)

	_view = Sprite2D.new()
	_view.texture = _throw.get_texture()
	_view.centered = false
	_view.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_view.material = _snap
	_view.position = (_TRAY_CENTER - Vector2(_throw.size) / 2.0).round()
	_view.visible = false
	_root.add_child(_view)

	_fly = Sprite2D.new()
	_fly.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_fly.visible = false
	_root.add_child(_fly)

	_build_card()


## The card the landed face comes up in: what Fate rolled and what it does
## this round, over a green Close.
func _build_card() -> void:
	var res: FateFaceResource = FateFaceCatalog.get_face(_face)
	var color: Color = res.color if res else Globals.white
	_panel = TileUnlockPopup._Panel.new()
	_panel.outline = color
	_panel.modulate.a = 0.0
	_root.add_child(_panel)

	_column = VBoxContainer.new()
	_column.custom_minimum_size.x = _CARD_WIDTH
	_column.add_theme_constant_override("separation", 3)
	_column.modulate.a = 0.0
	_root.add_child(_column)
	if res:
		_column.add_child(_label(tr("RECKONING_FATE_ROLLS").format({"face": res.display_face_name().to_upper()}), color))
		_column.add_child(_rich_text(Utils.format_text(res.display_reckoning_text(Globals.fate_ledger), true)))
	var row: CenterContainer = CenterContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_column.add_child(row)
	_close_button = _CLOSE_BUTTON.instantiate()
	row.add_child(_close_button)
	_close_button.set_button_text("STORY_BOX_CLOSE")
	_close_button.pressed_within_window.connect(_close)
	_close_button.disabled = true


func _label(text: String, color: Color) -> Label:
	var label: Label = Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.theme_type_variation = FontRoles.slot(FontRoles.SMALL, 2.0)
	label.add_theme_color_override("font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


func _rich_text(text: String) -> RichTextLabel:
	var label: RichTextLabel = RichTextLabel.new()
	label.bbcode_enabled = true
	label.fit_content = true
	label.scroll_active = false
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.custom_minimum_size.x = _CARD_WIDTH
	label.add_theme_color_override("default_color", Globals.white)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.text = text
	return label


## Lays the card out under where the die will sit, once the column has sized
## itself.
func _fit_card() -> void:
	_column.reset_size()
	_column.position = Vector2(roundf((Globals.SCREEN_SIZE.x - _column.size.x) / 2.0), _CARD_TOP)
	var around: Rect2 = Rect2(_column.position, _column.size)
	_panel.box = around.grow_individual(_CARD_PADDING.x, _CARD_PADDING.y, _CARD_PADDING.x, _CARD_PADDING.y)


# ── The throw ───────────────────────────────────────────────────────────────

## The dim comes up as the die leaves its place for where it'll be thrown from.
func _fly_out() -> void:
	var from: Vector2 = _source_point()
	_fly.texture = _source_texture(false)
	_fly.material = _snap if is_instance_valid(_from_die) else null
	_fly.position = from
	_fly.scale = Vector2.ONE
	_fly.visible = true
	var to: Vector2 = _arrival_point()
	var flight: Tween = _new_tween().set_parallel(true)
	flight.tween_property(_dim, "modulate:a", 1.0, _DIM_SECONDS)
	flight.tween_property(_fly, "position", to, _FLY_SECONDS).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	flight.tween_property(_fly, "scale", Vector2.ONE * _flight_scale(), _FLY_SECONDS).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	await flight.finished


## Where the die is thrown from, on screen.
func _arrival_point() -> Vector2:
	return (_view.position + _throw.start_point()).round()


## The die shakes in the middle of the screen, as in a hand, until the throw
## it's about to make has been worked out.
func _rattle_until_thrown(run: int) -> void:
	var at: Vector2 = _arrival_point()
	var rattled: float = 0.0
	var next_blip: float = 0.0
	while rattled < _RATTLE_MIN_SECONDS or not _throw.is_settled():
		_fly.position = at + Vector2(
			_rattling_rng.randf_range(-1.0, 1.0), _rattling_rng.randf_range(-1.0, 1.0)) * _RATTLE_PIXELS
		if rattled >= next_blip:
			next_blip += 0.2
			Events.play_sound.emit(_ROLL_SFX)
		await get_tree().create_timer(_RATTLE_STEP_SECONDS).timeout
		if run != _run:
			return
		rattled += _RATTLE_STEP_SECONDS


## The real die takes the shaken one's place, in a flash, and tumbles.
func _tumble() -> void:
	_throw.prepare_landing(_slot)
	_throw.replay_at(0.0)
	_fly.visible = false
	_view.visible = true
	_snap.set_shader_parameter(&"flash", 1.0)
	var flash: Tween = create_tween()
	flash.tween_method(func(value: float) -> void: _snap.set_shader_parameter(&"flash", value),
		1.0, 0.0, 0.25).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_replay_time = 0.0
	_replaying = true
	await _replay_done


func _on_knocked() -> void:
	Events.play_sound.emit(_ROLL_SFX)
	if _first_knock:
		_first_knock = false
		Events.camera_shake_small.emit()


## Landed: the face flares, the die slides up out of the way of the card, and
## the card comes up.
func _present(run: int) -> void:
	var color: Color = FateFaceCatalog.color_of(_face)
	var rest: Vector2 = _view.position + _throw.rest_point()
	_throw.flare(_slot, color)
	Events.play_sound.emit(_LAND_SFX)
	Juice.ring(self, rest, color, 22.0, 0.4, 4.0)
	Juice.sparkle(self, rest, color, 8, 34.0)
	await get_tree().create_timer(0.3).timeout
	if run != _run:
		return
	var slide: Tween = _new_tween()
	slide.tween_property(_view, "position", (_view.position + _PRESENT_POINT - rest).round(), _SLIDE_SECONDS) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	await slide.finished
	if run != _run:
		return
	# The card lays out once it's in the tree and has its text.
	await get_tree().process_frame
	if run != _run:
		return
	_fit_card()
	Events.play_sound.emit(_CARD_SFX)
	var fade: Tween = _new_tween().set_parallel(true)
	fade.tween_property(_panel, "modulate:a", 1.0, 0.15)
	fade.tween_property(_column, "modulate:a", 1.0, 0.2)
	await fade.finished
	if run != _run:
		return
	await get_tree().create_timer(_CLOSE_DELAY_SECONDS).timeout
	if run != _run:
		return
	Events.play_sound.emit(_POP_SFX)
	_close_button.disabled = false
	_awaiting_close = true


func _close() -> void:
	if not _awaiting_close:
		return
	_awaiting_close = false
	_close_button.disabled = true
	_closed.emit()


## The card goes, the die is flat art again and flies back to where it was
## taken from, and the dim lifts.
func _return_home() -> void:
	var from: Vector2 = (_view.position + _throw.rest_point()).round()
	# The cube over "You" is still turned to the thrown side, so its own
	# picture shows the face; the bone die's is drawn.
	_fly.texture = _source_texture(true)
	_fly.position = from
	_fly.scale = Vector2.ONE * _flight_scale()
	_view.visible = false
	_fly.visible = true
	var leave: Tween = _new_tween().set_parallel(true)
	leave.tween_property(_panel, "modulate:a", 0.0, 0.15)
	leave.tween_property(_column, "modulate:a", 0.0, 0.15)
	leave.tween_property(_dim, "modulate:a", 0.0, _DIM_OUT_SECONDS)
	leave.tween_property(_fly, "scale", Vector2.ONE, _RETURN_SECONDS).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	# The place it's going can move (the hull sways, a ship slides): aim at it
	# as it goes.
	leave.tween_method(func(t: float) -> void: _fly.position = from.lerp(_source_point(), t),
		0.0, 1.0, _RETURN_SECONDS).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	await leave.finished


## Everything put back: the source die shows, the stage is empty and ready for
## the next round's throw.
func _finish() -> void:
	_replaying = false
	_awaiting_close = false
	_unlift_source()
	_from_die = null
	for node: Node in [_root, _throw]:
		if is_instance_valid(node):
			node.queue_free()
	_root = null
	_throw = null
	_active = false
