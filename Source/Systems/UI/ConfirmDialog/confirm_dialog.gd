class_name ConfirmDialog
extends Node2D
## A yes/no question over a dimmed screen, on a pixel panel sized to the
## question. Confirm reads green and Cancel red, like every other carry-on /
## undo pair; a destructive question (open(..., true)) turns that round, a
## red button for the thing that can't be taken back and a calm blue Cancel.

signal confirmed()
signal cancelled()

const _GREEN_TEXTURE: Texture2D = preload("res://Assets/Textures/UI/Buttons/button_medium_green.png")
const _RED_TEXTURE: Texture2D = preload("res://Assets/Textures/UI/Buttons/button_medium_red.png")
const _BLUE_TEXTURE: Texture2D = preload("res://Assets/Textures/UI/Buttons/button_medium_blue.png")
const _GREEN: Color = Color("#7ABD33")
const _RED: Color = Color("#D03656")
const _BLUE: Color = Color("#43A6FC")
const _PANEL_PADDING: Vector2 = Vector2(8, 6)

@onready var _confirm_button: Button = $HBoxContainer/ConfirmButton
@onready var _cancel_button: Button = $HBoxContainer/CancelButton
var _panel: _Panel


func _ready() -> void:
	_panel = _Panel.new()
	add_child(_panel)
	# Over the dim, under the text and buttons.
	move_child(_panel, $ScreenDim.get_index() + 1)


## Asks [param message]. [param confirm_text] labels the confirm button (a
## translation key or plain text).
func open(message: String, destructive: bool = false, confirm_text: String = "CONFIRM") -> void:
	%MessageLabel.text = message
	_confirm_button.set_button_text(confirm_text)
	OptionsMenu.set_button_texture(_confirm_button, _RED_TEXTURE if destructive else _GREEN_TEXTURE)
	_confirm_button.hover_text_color = _RED if destructive else _GREEN
	OptionsMenu.set_button_texture(_cancel_button, _BLUE_TEXTURE if destructive else _RED_TEXTURE)
	_cancel_button.hover_text_color = _BLUE if destructive else _RED
	_panel.outline = _RED if destructive else _BLUE
	show()
	_fit_panel.call_deferred()


## Wraps the panel round the question and the buttons, once the question
## has laid itself out.
func _fit_panel() -> void:
	var around: Rect2 = %MessageLabel.get_rect().merge($HBoxContainer.get_rect())
	_panel.box = around.grow_individual(_PANEL_PADDING.x, _PANEL_PADDING.y, _PANEL_PADDING.x, _PANEL_PADDING.y)


func _on_confirm_button_pressed() -> void:
	hide()
	confirmed.emit()


func _on_cancel_button_pressed() -> void:
	hide()
	cancelled.emit()


class _Panel:
	extends Node2D

	var outline: Color = Color.WHITE:
		set(value):
			outline = value
			queue_redraw()
	var box: Rect2:
		set(value):
			# On whole pixels, so the outline stays one pixel wide.
			box = Rect2(value.position.round(), value.size.round())
			queue_redraw()

	func _draw() -> void:
		if box.has_area():
			OptionsFrame.draw_box(self, box, outline)
