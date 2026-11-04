extends "res://test/helpers/die_fighter_test.gd"
## Tests for the OptionsMenu layout, hint spacing, ScrollContainers,
## map grab cursor, and tutorial bump card.

const _OPTIONS_SCENE: PackedScene = preload("res://Source/Systems/UI/OptionsMenu/options_menu.tscn")
const _MAP_SCRIPT: GDScript = preload("res://Source/Systems/Game/Map/map.gd")
const _MOUSE_CURSOR_SCRIPT: GDScript = preload("res://Source/Systems/UI/MouseCursor/mouse_cursor.gd")


func test_panel_size_expanded() -> void:
	var menu: OptionsMenu = _OPTIONS_SCENE.instantiate()
	add_child_autofree(menu)
	await wait_process_frames(1)

	assert_gte(OptionsMenu.PANEL_SIZE.y, 160.0, "Options menu panel height expanded to at least 160px")
	assert_eq(menu._frame.body_rect.size.y, OptionsMenu.PANEL_SIZE.y - OptionsMenu.TAB_HEIGHT)


func test_hint_clears_buttons_with_comfortable_padding() -> void:
	var menu: OptionsMenu = _OPTIONS_SCENE.instantiate()
	add_child_autofree(menu)
	await wait_process_frames(1)

	var hint: RichTextLabel = menu._hint_label
	var defaults_btn: Button = menu._defaults_button

	# Verify hint label has dedicated height for multiline text and autowraps
	assert_gte(hint.size.y, 20.0, "Hint label has at least 20px height for multi-line explanations")
	assert_eq(hint.autowrap_mode, TextServer.AUTOWRAP_WORD_SMART, "Hint label autowraps text")

	# Verify hint bottom clears defaults button top with >= 4px gap
	var hint_bottom: float = hint.position.y + hint.size.y
	var button_top: float = defaults_btn.position.y
	assert_gte(button_top - hint_bottom, 4.0, "Clear padding between hint label bottom and buttons top")

	# Verify pages area ends above hint label top with >= 4px gap
	for tab: OptionsMenu.Tab in menu._pages:
		var scrolls: Array = menu._page_scrolls[tab]
		for scroll: ScrollContainer in scrolls:
			var scroll_bottom: float = scroll.position.y + scroll.size.y
			assert_gte(hint.position.y - scroll_bottom, 4.0, "Clear padding between pages bottom and hint top")

	menu._on_hint_changed(tr("OPT_CONTROLLER_SCHEME_HINT"))
	await wait_process_frames(2)
	assert_lte(hint.get_content_height(), int(hint.size.y), "the controller scheme explanation fits completely")


func test_pages_wrapped_in_styled_scroll_containers() -> void:
	var menu: OptionsMenu = _OPTIONS_SCENE.instantiate()
	add_child_autofree(menu)
	await wait_process_frames(1)

	for tab: OptionsMenu.Tab in menu._pages:
		var pages: Array = menu._pages[tab]
		var scrolls: Array = menu._page_scrolls[tab]
		assert_eq(pages.size(), scrolls.size(), "Each page has a matching ScrollContainer")

		for i: int in range(pages.size()):
			var page: OptionsPage = pages[i]
			var scroll: ScrollContainer = scrolls[i]
			assert_eq(page.get_parent(), scroll, "OptionsPage is a child of ScrollContainer")
			assert_eq(scroll.horizontal_scroll_mode, ScrollContainer.SCROLL_MODE_DISABLED)
			# Only a page that overflows its box scrolls (the Game page fits).
			var overflows: bool = page.get_combined_minimum_size().y - scroll.size.y > OptionsMenu._SCROLL_SLACK
			assert_eq(scroll.vertical_scroll_mode,
				ScrollContainer.SCROLL_MODE_AUTO if overflows else ScrollContainer.SCROLL_MODE_DISABLED)
			assert_true(scroll.follow_focus, "ScrollContainer follows focus for controller navigation")

			# Styled pixel scrollbar
			var v_bar: VScrollBar = scroll.get_v_scroll_bar()
			assert_not_null(v_bar.get_theme_stylebox("scroll"))
			assert_not_null(v_bar.get_theme_stylebox("grabber"))


func test_controller_options_page_fits_and_scrolls() -> void:
	var menu: OptionsMenu = _OPTIONS_SCENE.instantiate()
	add_child_autofree(menu)
	await wait_process_frames(1)

	# Switch to Controls tab, Controller subtab
	menu._show_tab(OptionsMenu.Tab.CONTROLS)
	menu._show_page(OptionsMenu.ControlsPage.CONTROLLER, OptionsMenu.Tab.CONTROLS)
	await wait_process_frames(1)

	var scroll: ScrollContainer = menu._page_scrolls[OptionsMenu.Tab.CONTROLS][OptionsMenu.ControlsPage.CONTROLLER]
	var page: OptionsPage = menu._pages[OptionsMenu.Tab.CONTROLS][OptionsMenu.ControlsPage.CONTROLLER]
	assert_true(scroll.visible, "Controller scroll container is visible")
	assert_true(page.visible, "Controller options page is visible")

	# Scroll container bottom must not exceed hint top
	var hint: RichTextLabel = menu._hint_label
	assert_lte(scroll.position.y + scroll.size.y, hint.position.y - 4.0,
		"Controller scroll container does not collide with hint label")


func test_map_pan_cursor_grab() -> void:
	var was_scheme: InputBindings.ControlScheme = InputManager.control_scheme
	InputManager.control_scheme = InputBindings.ControlScheme.CURSOR
	var map: Map = _MAP_SCRIPT.new()
	add_child_autofree(map)
	var cursor: Sprite2D = _MOUSE_CURSOR_SCRIPT.new()
	add_child_autofree(cursor)
	await wait_process_frames(1)

	# Initially not panning: default cursor
	assert_false(map.is_panning())
	cursor._update_look()
	assert_eq(cursor.texture, cursor.default_cursor_texture)

	# When map panning starts: cursor wears grab texture
	map._panning = true
	assert_true(map.is_panning())
	cursor._update_look()
	assert_eq(cursor.texture, cursor._GRAB_TEXTURE)
	assert_eq(cursor.offset, cursor._GRAB_OFFSET)

	# When map panning ends: restored to default
	map._panning = false
	assert_false(map.is_panning())
	cursor._update_look()
	assert_eq(cursor.texture, cursor.default_cursor_texture)

	InputManager.control_scheme = was_scheme
