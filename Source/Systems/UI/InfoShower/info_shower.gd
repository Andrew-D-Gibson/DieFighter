extends Control

## Side margins of the panel's content. A comparison has two descriptions to
## fit side by side, so it takes more of the screen's width.
const _SOLO_MARGIN: int = 288
const _COMPARISON_MARGIN: int = 96

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	self.visible = false
	
	Events.show_info.connect(_show_info)
	Events.close_info.connect(hide)
	

func _show_info(info: InfoResource) -> void:
	if not info:
		return
		
	%TitleLabel.text = Utils.format_text(info.title_label_text)
	%TopLabel.text = Utils.format_text(info.top_label_text, true)
	%KeywordPopup.hide()
	self.visible = true

	var art: TextureRect = _show_comparison(info) if info.has_upgrade() else _show_solo(info)
	art.texture = info.texture
	art.modulate.a = 0
	if not info.has_upgrade():
		await _widen_if_too_tall()
	%TweenableTextureDisplay.texture = info.texture
	ColorSymbolBadge.attach_to_rect(art)
	ColorSymbolBadge.attach_to_rect(%TweenableTextureDisplay)
	%TweenableTextureDisplay.hide()

	var starting_pos: Vector2 = get_global_mouse_position()
	# Where the art lands depends on the layout just picked, which the
	# containers only settle at the end of this frame.
	await get_tree().process_frame
	var texture_final_pos: Vector2 = art.global_position - global_position \
		+ (art.size - %TweenableTextureDisplay.size) / 2.0
	%TweenableTextureDisplay.show()

	var texture_zoom_tween: Tween = get_tree().create_tween()
	texture_zoom_tween.set_parallel()
	var tween_time: float = 0.5	
	texture_zoom_tween.tween_property(
		%TweenableTextureDisplay,
		"scale",
		Vector2(1,1),
		tween_time
	).from(Vector2(0.25,0.25))\
	.set_trans(Tween.TRANS_CUBIC)\
	.set_ease(Tween.EASE_OUT)
	
	texture_zoom_tween.tween_property(
		%TweenableTextureDisplay,
		"position",
		texture_final_pos,
		tween_time
	).from(starting_pos)\
	.set_trans(Tween.TRANS_CUBIC)\
	.set_ease(Tween.EASE_OUT)
	
	await texture_zoom_tween.finished
	%TweenableTextureDisplay.hide()
	art.modulate.a = 1


## The usual layout: the art, and its description under it. Returns the art's
## rect.
func _show_solo(info: InfoResource) -> TextureRect:
	_set_side_margins(_SOLO_MARGIN)
	%TopLabel.show()
	%Comparison.hide()
	%TextureDisplay.get_parent().show()
	%BottomLabel.get_parent().show()
	%BottomLabel.text = Utils.format_text(info.bottom_label_text, true)
	%SideLabel.visible = not info.side_label_text.is_empty()
	%SideLabel.text = Utils.format_text(info.side_label_text, true)
	return %TextureDisplay


## The thing as it is on the left, what it becomes once upgraded on the right,
## and how to get there on the arrow between. Returns the left art's rect.
func _show_comparison(info: InfoResource) -> TextureRect:
	_set_side_margins(_COMPARISON_MARGIN)
	# Two descriptions with a name over each need the height an empty
	# activation line would hold.
	%TopLabel.visible = not info.top_label_text.is_empty()
	%TextureDisplay.get_parent().hide()
	%BottomLabel.get_parent().hide()
	%Comparison.show()
	%CurrentName.text = Utils.format_text(info.title_label_text)
	# Both columns are taken, so an aside joins the current description.
	var current_text: String = info.bottom_label_text
	if not info.side_label_text.is_empty():
		current_text += "\n\n" + info.side_label_text
	%CurrentLabel.text = Utils.format_text(current_text, true)
	%UpgradeCaption.text = Utils.format_text(info.upgrade_caption_text)
	%UpgradeName.text = Utils.format_text(info.upgrade_title_text)
	%UpgradeLabel.text = Utils.format_text(info.upgrade_bottom_label_text, true)
	%UpgradeTexture.texture = info.upgrade_texture
	ColorSymbolBadge.attach_to_rect(%UpgradeTexture)
	return %CurrentTexture


## A long name and description (a long language's, usually) can stand
## taller than the screen in the solo layout's narrow column, cutting off the
## title above and the text below. Widening the column to the comparison's
## margins re-wraps them into fewer lines at the same size.
func _widen_if_too_tall() -> void:
	# fit_content labels measure their new text during the frame.
	await get_tree().process_frame
	# The content itself, not its margins: long English text already eats
	# into the top and bottom margins and still fits on screen.
	var content: Control = $MarginContainer/VBoxContainer
	if content.get_combined_minimum_size().y > size.y:
		_set_side_margins(_COMPARISON_MARGIN)


func _set_side_margins(margin: int) -> void:
	$MarginContainer.add_theme_constant_override(&"margin_left", margin)
	$MarginContainer.add_theme_constant_override(&"margin_right", margin)



## Spatial terms need a diagram; other keywords keep the existing info behavior.
func _on_keyword_hover_started(meta: Variant) -> void:
	var term: String = str(meta)
	if not preload("res://Source/Systems/UI/InfoShower/keyword_diagram.gd").supports(term):
		%KeywordPopup.hide()
		return
	%KeywordLabel.text = Utils.format_text("[color=orange]%s[/color]: %s" % [Keywords.title(term), Keywords.definition(term)])
	preload("res://Source/Systems/UI/InfoShower/keyword_diagram.gd").configure(%KeywordPopup, %KeywordLabel, term, 4.0)
	%KeywordPopup.reset_size()
	%KeywordPopup.show()
	_place_keyword_popup()


func _process(_delta: float) -> void:
	if visible and %KeywordPopup.visible:
		_place_keyword_popup()


func _place_keyword_popup() -> void:
	var popup_size: Vector2 = %KeywordPopup.size
	var cursor: Vector2 = get_local_mouse_position()
	var pos: Vector2 = cursor + Vector2(32, 32)
	if pos.y + popup_size.y > size.y - 16.0:
		pos.y = cursor.y - popup_size.y - 32.0
	pos.x = clampf(pos.x, 16.0, maxf(16.0, size.x - popup_size.x - 16.0))
	pos.y = clampf(pos.y, 16.0, maxf(16.0, size.y - popup_size.y - 16.0))
	%KeywordPopup.position = pos.floor()


func _on_keyword_hover_ended(_meta: Variant) -> void:
	%KeywordPopup.hide()


## Escape closes the info shower and nothing else. InputManager, an autoload,
## opens the pause menu on the same action, and autoloads sit ahead of the
## game scene in the tree, so they hear unhandled input after this does:
## marking it handled here keeps the pause menu shut.
func _unhandled_input(event: InputEvent) -> void:
	if visible and (event.is_action_pressed("PauseMenu") or event.is_action_pressed(&"cursor_back") or event.is_action_pressed(&"ui_cancel")):
		get_viewport().set_input_as_handled()
		_close()


func _on_screen_dim_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == 1:
		_close()


## The player dismissing the info, as opposed to the game closing it through
## close_info, which isn't announced.
func _close() -> void:
	Events.info_graphic_closed.emit()
	hide()
