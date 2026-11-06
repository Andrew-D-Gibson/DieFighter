class_name FateCarveChoice
extends Node2D
## Once Fate's Die is full, a new carving goes over an old face, and which one
## is the player's choice (LORE.md §5): "I've got two Ruins, so I'll take this
## Mercy job and carve over one." This card asks, once the fight that carved
## it is over. The player may also let the carving pass and keep the die as it
## is.
##
## It waits its turn behind a boss's last words (LastWords): the story beat
## finishes first, then this asks.
##
## A run nobody is playing (the AutoPilot, the Scenario Lab) answers itself:
## the new face goes over the face the die bears most.

const _MEDIUM_BUTTON: PackedScene = preload("res://Source/Systems/UI/Buttons/medium_button.tscn")
const _OPEN_SFX: SoundEffectResource = preload("res://Source/Resources/SoundEffectResources/SoundEffects/upgrade_trigger.tres")
const _PICK_SFX: SoundEffectResource = preload("res://Source/Resources/SoundEffectResources/SoundEffects/tile_dropped.tres")
const _BUTTON_TEXTURE: Texture2D = preload("res://Assets/Textures/UI/Buttons/button_medium_purple.png")
const _DIM_COLOR: Color = Color(0.027451, 0.0117647, 0.054902, 0.83)
const _WIDTH: int = 220
const _DIE_SCALE: int = 2
const _PANEL_PADDING: Vector2 = Vector2(8, 6)

var _root: Control
var _panel: TileUnlockPopup._Panel
var _column: VBoxContainer
var _info_label: RichTextLabel
var _open: bool = false


func _ready() -> void:
	z_index = 40
	hide()
	Events.fate_carve_pending.connect(func(_face: int) -> void: _try_open.call_deferred())
	Events.combat_finished.connect(func() -> void: _try_open.call_deferred())
	Events.start_scenario.connect(func() -> void: _try_open.call_deferred())
	Events.story_beat_finished.connect(func() -> void: _try_open.call_deferred())


func _try_open() -> void:
	var ledger: FateLedger = Globals.fate_ledger
	if _open or not ledger or not ledger.has_pending():
		return
	if not Globals.state_manager or Globals.state_manager.state != GameStateManager.GameState.OUT_OF_COMBAT:
		return
	if is_instance_valid(Globals.player) and Globals.player.is_jump_committed():
		return
	if LastWords.is_pending():
		return
	if not CollectionManager.is_recording():
		ledger.resolve_pending(auto_choice(ledger.die))
		_try_open.call_deferred()
		return
	_build(ledger)


## The slot a run nobody is playing carves over: the face the die bears most,
## the first of them on a tie.
static func auto_choice(die: FateDie) -> int:
	var best: int = 0
	for slot: int in FateDie.FACE_COUNT:
		if die.count(die.face_at(slot)) > die.count(die.face_at(best)):
			best = slot
	return best


func _build(ledger: FateLedger) -> void:
	_open = true
	for child: Node in get_children():
		child.queue_free()
	var face: FateFaceResource = FateFaceCatalog.get_face(ledger.next_pending())

	_root = Control.new()
	_root.size = Globals.SCREEN_SIZE
	add_child(_root)
	var dim: ColorRect = ColorRect.new()
	dim.color = _DIM_COLOR
	dim.size = Globals.SCREEN_SIZE
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	_root.add_child(dim)
	_panel = TileUnlockPopup._Panel.new()
	_panel.outline = face.color if face else Globals.purple
	_root.add_child(_panel)
	_column = VBoxContainer.new()
	_column.custom_minimum_size.x = _WIDTH
	_column.add_theme_constant_override("separation", 3)
	_root.add_child(_column)

	_label(tr("FATE_CARVE_TITLE"), 2.0, FateDieArt.BONE)
	_rich(tr("FATE_CARVE_PROMPT").format({"face": face.coloured_name() if face else ""}))

	var row: HBoxContainer = HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 4)
	_column.add_child(row)
	for slot: int in FateDie.FACE_COUNT:
		row.add_child(_slot_button(ledger, slot))

	_info_label = _rich(tr("FATE_CARVE_HINT"))
	_info_label.custom_minimum_size.y = 22
	_info_label.add_theme_color_override("default_color", Globals.purple)

	var buttons: CenterContainer = CenterContainer.new()
	_column.add_child(buttons)
	var pass_button: Button = _MEDIUM_BUTTON.instantiate()
	buttons.add_child(pass_button)
	pass_button.set_button_text("FATE_CARVE_PASS")
	OptionsMenu.set_button_texture(pass_button, _BUTTON_TEXTURE)
	pass_button.pressed_within_window.connect(_choose.bind(-1))

	_root.modulate.a = 0.0
	show()
	_play_in.call_deferred()


func _slot_button(ledger: FateLedger, slot: int) -> Control:
	var face: FateDie.Face = ledger.die.face_at(slot)
	var holder: TextureRect = TextureRect.new()
	holder.texture = FateDieArt.face_texture(face, _DIE_SCALE)
	holder.custom_minimum_size = Vector2.ONE * FateDieArt.SIZE * _DIE_SCALE
	holder.pivot_offset = holder.custom_minimum_size / 2.0
	holder.mouse_filter = Control.MOUSE_FILTER_STOP
	holder.mouse_entered.connect(func() -> void:
		holder.scale = Vector2.ONE * 1.15
		var res: FateFaceResource = FateFaceCatalog.get_face(face)
		if res:
			_info_label.text = Utils.format_text("%s: %s" % [res.coloured_name(), ledger.carved_by_text(slot)], true)
	)
	holder.mouse_exited.connect(func() -> void: holder.scale = Vector2.ONE)
	holder.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			_choose(slot)
	)
	return holder


func _label(text: String, scale: float, color: Color) -> Label:
	var label: Label = Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.theme_type_variation = FontRoles.slot(FontRoles.SMALL, scale)
	label.add_theme_color_override("font_color", color)
	_column.add_child(label)
	return label


func _rich(text: String) -> RichTextLabel:
	var label: RichTextLabel = RichTextLabel.new()
	label.bbcode_enabled = true
	label.fit_content = true
	label.scroll_active = false
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.custom_minimum_size = Vector2(_WIDTH, 0)
	label.add_theme_color_override("default_color", Globals.white)
	label.mouse_filter = Control.MOUSE_FILTER_PASS
	label.text = Utils.format_text(text, true)
	_column.add_child(label)
	return label


func _play_in() -> void:
	_column.position = ((Globals.SCREEN_SIZE - _column.size) / 2.0).round()
	var around: Rect2 = Rect2(_column.position, _column.size)
	_panel.box = around.grow_individual(_PANEL_PADDING.x, _PANEL_PADDING.y, _PANEL_PADDING.x, _PANEL_PADDING.y)
	Events.play_sound.emit(_OPEN_SFX)
	Events.glitch_burst.emit(160)
	var tween: Tween = create_tween()
	tween.tween_property(_root, "modulate:a", 1.0, 0.2)


func _choose(slot: int) -> void:
	if not _open:
		return
	_open = false
	Events.play_sound.emit(_PICK_SFX)
	Globals.fate_ledger.resolve_pending(slot)
	var tween: Tween = create_tween()
	tween.tween_property(_root, "modulate:a", 0.0, 0.2)
	tween.tween_callback(func() -> void:
		hide()
		for child: Node in get_children():
			child.queue_free()
		# Another carving may be waiting behind this one.
		_try_open.call_deferred()
	)
