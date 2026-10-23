class_name ScenarioLabUI
extends RefCounted
## Builders for the Scenario Lab's code-built controls, styled like the other
## dev tools (TilePalette) so they read as one set.

const FONT: Font = preload("res://Assets/Fonts/m5x7/m5x7.ttf")

const PANEL_COLOR: Color = Color(0.144, 0.3416, 0.6, 0.843137)
const ENTRY_COLOR: Color = Color(0.09, 0.22, 0.42, 0.85)
const MUTED_COLOR: Color = Color(0.72, 0.8, 0.9)
const SEEN_COLOR: Color = Color(0.48, 0.74, 0.2)
const UNSEEN_COLOR: Color = Color(0.95, 0.62, 0.36)
const CURRENT_COLOR: Color = Color(0.93, 0.83, 0.36)

const BODY_SIZE: int = 24
const HEADING_SIZE: int = 32
const TITLE_SIZE: int = 40


static func label(text: String, font_size: int = BODY_SIZE, color: Color = Color.WHITE) -> Label:
	var result := Label.new()
	result.text = text
	result.mouse_filter = Control.MOUSE_FILTER_IGNORE
	result.add_theme_font_override("font", FONT)
	result.add_theme_font_size_override("font_size", font_size)
	result.add_theme_color_override("font_color", color)
	return result


## A label that wraps to its container's width instead of widening it.
static func wrapped_label(text: String, font_size: int = BODY_SIZE, color: Color = Color.WHITE) -> Label:
	var result: Label = label(text, font_size, color)
	result.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	result.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	result.custom_minimum_size.x = 1
	return result


static func button(text: String, on_pressed: Callable, font_size: int = BODY_SIZE) -> Button:
	var result := Button.new()
	result.text = text
	result.focus_mode = Control.FOCUS_NONE
	result.add_theme_font_override("font", FONT)
	result.add_theme_font_size_override("font_size", font_size)
	result.pressed.connect(on_pressed)
	return result


static func style(color: Color, margin: float = 6.0) -> StyleBoxFlat:
	var result := StyleBoxFlat.new()
	result.bg_color = color
	result.set_content_margin_all(margin)
	return result


static func panel(color: Color = PANEL_COLOR, margin: float = 12.0) -> PanelContainer:
	var result := PanelContainer.new()
	result.add_theme_stylebox_override("panel", style(color, margin))
	return result


static func row(separation: int = 8) -> HBoxContainer:
	var result := HBoxContainer.new()
	result.add_theme_constant_override("separation", separation)
	return result


static func column(separation: int = 4) -> VBoxContainer:
	var result := VBoxContainer.new()
	result.add_theme_constant_override("separation", separation)
	return result


## A vertical scroll that never scrolls sideways, so wrapped labels wrap.
static func vertical_scroll() -> ScrollContainer:
	var result := ScrollContainer.new()
	result.size_flags_vertical = Control.SIZE_EXPAND_FILL
	result.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	return result


static func clear_children(node: Node) -> void:
	for child: Node in node.get_children():
		node.remove_child(child)
		child.queue_free()
