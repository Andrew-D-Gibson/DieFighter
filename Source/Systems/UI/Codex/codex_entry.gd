class_name CodexEntry
extends Control

## One cell of the codex grid: a tile's or an enemy's art, in colour once
## found, in grey before. Only a found entry can be picked.

signal picked(entry: CodexEntry)
signal hovered(entry: CodexEntry)
signal unhovered(entry: CodexEntry)

const SIZE: Vector2 = Vector2(26, 26)

const _HOVER_SFX: SoundEffectResource = preload("res://Source/Resources/SoundEffectResources/SoundEffects/hover_thump.tres")
const _PICK_SFX: SoundEffectResource = preload("res://Source/Resources/SoundEffectResources/SoundEffects/tile_dropped.tres")
const _LOCKED_SHADER: Shader = preload("res://Assets/Shaders/codex_locked.gdshader")

const _BACKGROUND: Color = Color("#0f0c2e")
const _BORDER: Color = Color("#251c6b")
const _BORDER_HOVER: Color = Color("#463c91")
const _BORDER_PICKED: Color = Color("#eed35d")

## The entry's id in ContentRegistry, and its number in the codex (from 1).
var id: String
var number: int
var found: bool = false
var is_picked: bool = false:
	set(value):
		is_picked = value
		queue_redraw()

var _hovered: bool = false


## [param darken] steps a locked entry's greys down the ramp, for art that's
## all one pale colour and would otherwise read as found.
func setup(entry_id: String, entry_number: int, icon: Texture2D, is_found: bool, darken: int = 0) -> void:
	id = entry_id
	number = entry_number
	found = is_found
	custom_minimum_size = SIZE
	size = SIZE
	mouse_filter = Control.MOUSE_FILTER_STOP

	var art: TextureRect = TextureRect.new()
	art.texture = icon
	art.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	art.position = Vector2.ONE
	art.size = SIZE - Vector2.ONE * 2
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if not found:
		var material: ShaderMaterial = ShaderMaterial.new()
		material.shader = _LOCKED_SHADER
		material.set_shader_parameter(&"darken", darken)
		art.material = material
	add_child(art)
	# Only once found: a locked entry is grey, so its family stays hidden too.
	if found:
		ColorSymbolBadge.attach_to_rect(art)

	mouse_entered.connect(func() -> void:
		_hovered = true
		if found and not is_picked:
			Events.play_sound.emit(_HOVER_SFX)
		hovered.emit(self)
		queue_redraw()
	)
	mouse_exited.connect(func() -> void:
		_hovered = false
		unhovered.emit(self)
		queue_redraw()
	)


func _gui_input(event: InputEvent) -> void:
	if not found:
		return
	if event is InputEventMouseButton and event.pressed \
	and event.button_index == MOUSE_BUTTON_LEFT:
		if not is_picked:
			Events.play_sound.emit(_PICK_SFX)
		picked.emit(self)
		accept_event()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, SIZE), _BACKGROUND)
	var border: Color = _BORDER
	if is_picked:
		border = _BORDER_PICKED
	elif _hovered and found:
		border = _BORDER_HOVER
	draw_rect(Rect2(Vector2(0.5, 0.5), SIZE - Vector2.ONE), border, false, 1.0)
