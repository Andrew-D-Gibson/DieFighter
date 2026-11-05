class_name FateVectorChoice
extends Node2D
## Gate 3 of the secret fight (LORE.md §6): past the last boss, for a player
## who knows the secret and carved every face, there are two jump vectors.
## Forward, to the front and the normal ending. Back, toward Fate. Fate's Die
## rattles in the cockpit while the card is up.
##
## A run nobody is playing (the AutoPilot) always goes forward.

enum Vector { FORWARD, BACK }

signal chosen(vector: Vector)

const _MEDIUM_BUTTON: PackedScene = preload("res://Source/Systems/UI/Buttons/medium_button.tscn")
const _FORWARD_TEXTURE: Texture2D = preload("res://Assets/Textures/UI/Buttons/button_medium_blue.png")
const _BACK_TEXTURE: Texture2D = preload("res://Assets/Textures/UI/Buttons/button_medium_purple.png")
const _OPEN_SFX: SoundEffectResource = preload("res://Source/Resources/SoundEffectResources/SoundEffects/die_dread_thunk.tres")
const _DIM_COLOR: Color = Color(0.027451, 0.0117647, 0.054902, 0.86)
const _WIDTH: int = 230
const _PANEL_PADDING: Vector2 = Vector2(8, 6)

var _root: Control
var _column: VBoxContainer
var _panel: TileUnlockPopup._Panel
var _done: bool = false


## Opens the card over everything, under [param parent], and returns it; await
## its [signal chosen].
static func open_in(parent: Node) -> FateVectorChoice:
	var card: FateVectorChoice = FateVectorChoice.new()
	parent.add_child(card)
	card.global_position = Vector2.ZERO
	if not CollectionManager.is_recording():
		card._choose.call_deferred(Vector.FORWARD)
		return card
	card._build()
	return card


func _build() -> void:
	z_index = 40
	_root = Control.new()
	_root.size = Globals.SCREEN_SIZE
	add_child(_root)
	var dim: ColorRect = ColorRect.new()
	dim.color = _DIM_COLOR
	dim.size = Globals.SCREEN_SIZE
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	_root.add_child(dim)
	_panel = TileUnlockPopup._Panel.new()
	_panel.outline = Globals.purple
	_root.add_child(_panel)
	_column = VBoxContainer.new()
	_column.custom_minimum_size.x = _WIDTH
	_column.add_theme_constant_override("separation", 4)
	_root.add_child(_column)

	var strip: TextureRect = TextureRect.new()
	strip.texture = FateDieArt.strip_texture(Globals.fate_ledger.die)
	strip.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	_column.add_child(strip)

	_add_text(tr("FATE_VECTOR_TITLE"), 2.0, Globals.purple)
	_add_rich(tr("FATE_VECTOR_BODY"))

	var row: HBoxContainer = HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 10)
	_column.add_child(row)
	_add_button(row, "FATE_VECTOR_FORWARD", _FORWARD_TEXTURE, Globals.blue, Vector.FORWARD)
	_add_button(row, "FATE_VECTOR_BACK", _BACK_TEXTURE, Globals.purple, Vector.BACK)

	_root.modulate.a = 0.0
	Events.play_sound.emit(_OPEN_SFX)
	Events.glitch_burst.emit(260)
	Events.camera_shake_small.emit()
	_play_in.call_deferred()


func _add_text(text: String, scale: float, color: Color) -> void:
	var label: Label = Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.theme_type_variation = FontRoles.slot(FontRoles.SMALL, scale)
	label.add_theme_color_override("font_color", color)
	_column.add_child(label)


func _add_rich(text: String) -> void:
	var label: RichTextLabel = RichTextLabel.new()
	label.bbcode_enabled = true
	label.fit_content = true
	label.scroll_active = false
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.custom_minimum_size = Vector2(_WIDTH, 0)
	label.add_theme_color_override("default_color", Globals.white)
	label.text = Utils.format_text(text, true)
	_column.add_child(label)


func _add_button(row: Container, key: String, texture: Texture2D, hover: Color, vector: Vector) -> void:
	var button: Button = _MEDIUM_BUTTON.instantiate()
	row.add_child(button)
	button.set_button_text(key)
	OptionsMenu.set_button_texture(button, texture)
	button.hover_text_color = hover
	button.pressed_within_window.connect(_choose.bind(vector))


func _play_in() -> void:
	_column.position = ((Globals.SCREEN_SIZE - _column.size) / 2.0).round()
	var around: Rect2 = Rect2(_column.position, _column.size)
	_panel.box = around.grow_individual(_PANEL_PADDING.x, _PANEL_PADDING.y, _PANEL_PADDING.x, _PANEL_PADDING.y)
	var tween: Tween = create_tween()
	tween.tween_property(_root, "modulate:a", 1.0, 0.25)


func _choose(vector: Vector) -> void:
	if _done:
		return
	_done = true
	chosen.emit(vector)
	if _root == null:
		queue_free()
		return
	var tween: Tween = create_tween()
	tween.tween_property(_root, "modulate:a", 0.0, 0.2)
	tween.tween_callback(queue_free)
