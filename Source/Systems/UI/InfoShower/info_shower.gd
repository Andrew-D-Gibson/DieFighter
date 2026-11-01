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
	%CurrentLabel.text = Utils.format_text(info.bottom_label_text, true)
	%UpgradeCaption.text = Utils.format_text(info.upgrade_caption_text)
	%UpgradeName.text = Utils.format_text(info.upgrade_title_text)
	%UpgradeLabel.text = Utils.format_text(info.upgrade_bottom_label_text, true)
	%UpgradeTexture.texture = info.upgrade_texture
	ColorSymbolBadge.attach_to_rect(%UpgradeTexture)
	return %CurrentTexture


func _set_side_margins(margin: int) -> void:
	$MarginContainer.add_theme_constant_override(&"margin_left", margin)
	$MarginContainer.add_theme_constant_override(&"margin_right", margin)



func _process(_delta: float) -> void:
	if %KeywordPopup.visible:
		_place_keyword_popup()


func _on_keyword_hover_started(meta: Variant) -> void:
	var rule: String = Keywords.definition(str(meta))
	if rule.is_empty():
		return
	%KeywordLabel.text = Utils.format_text("[color=orange]%s[/color]: %s" % [meta, rule])
	# Shrink back to the new text's size before placing, or a long rule's
	# height lingers on a short one.
	%KeywordPopup.reset_size()
	%KeywordPopup.show()
	_place_keyword_popup()


func _on_keyword_hover_ended(_meta: Variant) -> void:
	%KeywordPopup.hide()


## Sits below-right of the cursor, flipped back inside the screen at the edges.
func _place_keyword_popup() -> void:
	var offset: Vector2 = Vector2(32, 32)
	var popup_size: Vector2 = %KeywordPopup.size
	var pos: Vector2 = get_local_mouse_position() + offset
	pos.x = minf(pos.x, size.x - popup_size.x - offset.x)
	if pos.y + popup_size.y > size.y - offset.y:
		pos.y = get_local_mouse_position().y - popup_size.y - offset.y
	%KeywordPopup.position = pos


## Escape closes the info shower and nothing else. InputManager, an autoload,
## opens the pause menu on the same action, and autoloads sit ahead of the
## game scene in the tree, so they hear unhandled input after this does:
## marking it handled here keeps the pause menu shut.
func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("PauseMenu"):
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
