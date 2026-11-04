class_name CodexPopup
extends Node2D

## The codex, opened from the main menu: every tile and enemy in the game, a
## page of them at a time. What the player has found is in colour and can be
## picked to read about it in the pane alongside; the rest are grey unknowns.
## CollectionManager remembers what's been found.

signal closed()

enum Tab { TILES, ENEMIES }

const _COLUMNS: int = 6
const _ROWS: int = 4
const _PAGE_SIZE: int = _COLUMNS * _ROWS
## Cell size plus the 1px gap between cells.
const _CELL_PITCH: float = CodexEntry.SIZE.x + 1.0

## Where the body text ends with and without an enemy's tally or the
## upgrade checkbox under it. Body lines step 11 px (13 tall, -2 separation,
## looser than the theme so inline dice icons clear the line above), and a
## RichTextLabel only starts scrolling once its text is 2 px past the box: a
## box 2 more than a whole number of steps (68, 57) either shows the last
## line whole or scrolls. Over the tally a few px of slack is left instead.
const _BODY_BOTTOM: float = 124.0
const _BODY_BOTTOM_ABOVE_STATS: float = 120.0
const _BODY_BOTTOM_ABOVE_TOGGLE: float = 113.0
## The name keeps the theme's tighter 9 px line step.
const _LINE_STEP: float = 9.0
const _CHECK_TEXTURES: Dictionary[String, Texture2D] = {
	"checked": preload("res://Assets/Textures/UI/OptionsMenu/CheckBox/check_box_checked_purple.png"),
	"unchecked": preload("res://Assets/Textures/UI/OptionsMenu/CheckBox/check_box_unchecked_purple.png"),
}
const _TOGGLE_SFX: SoundEffectResource = preload("res://Source/Resources/SoundEffectResources/SoundEffects/hover_thump.tres")
const _TILE_SHADER: Shader = preload("res://Assets/Shaders/tile.gdshader")
## A name that wraps takes a line more, and the sub-heading and body below it
## move down by as much, so nothing clips (a long German enemy name). The
## body keeps its bottom, so it stays 4 px over whole steps and scrolls.
const _NAME_BOTTOM: float = 24.0
const _SUB_TOP: float = 25.0
const _SUB_BOTTOM: float = 53.0
const _BODY_TOP: float = 56.0

const _RARITY_KEYS: Dictionary[TileResource.Rarity, String] = {
	TileResource.Rarity.COMMON: "CODEX_RARITY_COMMON",
	TileResource.Rarity.UNCOMMON: "CODEX_RARITY_UNCOMMON",
	TileResource.Rarity.RARE: "CODEX_RARITY_RARE",
}
const _RARITY_COLOURS: Dictionary[TileResource.Rarity, String] = {
	TileResource.Rarity.COMMON: "#c4c1bc",
	TileResource.Rarity.UNCOMMON: "#43a6fc",
	TileResource.Rarity.RARE: "#eed35d",
}

var _tab: Tab = Tab.TILES
var _ids: Array[String] = []
var _page: int = 0
var _entries: Array[CodexEntry] = []
## The entry last picked on each tab, so switching back finds it again.
var _picked_ids: Dictionary[Tab, String] = {}
var _warmed_up: bool = false
## Whether the tile detail pane is showing the upgraded (+) version of the picked tile.
var _show_upgraded: bool = false
var _portrait_material: ShaderMaterial = ShaderMaterial.new()
## Stands in for the portrait on the enemies tab, in the same spot.
var _ship_portrait: CodexShipPortrait = CodexShipPortrait.new()


func _ready() -> void:
	hide()
	# Loaded behind the menu rather than on open, which would stall the
	# first open for seconds; not preloaded, which would slow the menu down.
	CodexCatalog.warm_up()
	tree_exiting.connect(CodexCatalog.release)
	_portrait_material.shader = _TILE_SHADER
	%Portrait.material = _portrait_material
	%Portrait.add_sibling(_ship_portrait)
	_ship_portrait.position = %Portrait.position
	_ship_portrait.size = %Portrait.size
	%TilesTab.pressed.connect(_show_tab.bind(Tab.TILES))
	%EnemiesTab.pressed.connect(_show_tab.bind(Tab.ENEMIES))
	%PrevPage.pressed.connect(_turn_page.bind(-1))
	%NextPage.pressed.connect(_turn_page.bind(1))
	_style_upgrade_check()
	%UpgradeCheck.toggled.connect(_on_upgrade_toggled)
	# The label is part of the control: clicking it ticks the box too.
	%UpgradeToggle.gui_input.connect(_on_upgrade_row_input)
	%Grid.gui_input.connect(_on_grid_input)
	%BackButton.pressed_within_window.connect(close)
	%BackButton.set_button_text(tr("CODEX_BACK"))
	for label: RichTextLabel in [%SubLabel, %BodyLabel]:
		label.meta_hover_started.connect(_on_keyword_hover_started)
		label.meta_hover_ended.connect(_on_keyword_hover_ended)


func open() -> void:
	# Each visit starts on the base tiles.
	_show_upgraded = false
	_show_tab(_tab)
	show()


func close() -> void:
	hide()
	%KeywordPopup.hide()
	closed.emit()


func _show_tab(tab: Tab) -> void:
	_tab = tab
	%TilesTab.selected = tab == Tab.TILES
	%EnemiesTab.selected = tab == Tab.ENEMIES
	_ids = CodexCatalog.tile_ids() if tab == Tab.TILES else CodexCatalog.enemy_ids()

	var found: Array[String] = []
	found.assign(_ids.filter(_is_found))
	%FoundLabel.text = tr("CODEX_FOUND").format({"found": found.size(), "total": _ids.size()})

	var picked: String = _picked_ids.get(tab, "")
	if not found.has(picked):
		picked = found[0] if not found.is_empty() else ""
	_page = floori(maxi(_ids.find(picked), 0) / float(_PAGE_SIZE))
	_build_page()
	_pick(picked)


func _is_found(id: String) -> bool:
	return CodexCatalog.is_tile_found(id) if _tab == Tab.TILES else CollectionManager.has_enemy(id)


func _page_count() -> int:
	return maxi(ceili(_ids.size() / float(_PAGE_SIZE)), 1)


func _turn_page(step: int) -> void:
	var page: int = clampi(_page + step, 0, _page_count() - 1)
	if page == _page:
		return
	_page = page
	_build_page()


func _build_page() -> void:
	for entry: CodexEntry in _entries:
		entry.queue_free()
	_entries.clear()
	%HoverLabel.text = ""

	var first: int = _page * _PAGE_SIZE
	for i: int in range(first, mini(first + _PAGE_SIZE, _ids.size())):
		var id: String = _ids[i]
		var entry: CodexEntry = CodexEntry.new()
		%Grid.add_child(entry)
		# Enemy art is one pale colour; one grey down it reads as unknown.
		entry.setup(id, i + 1, _icon(id), _is_found(id), 0 if _tab == Tab.TILES else 1)
		var slot: int = i - first
		entry.position = Vector2(slot % _COLUMNS, floori(slot / float(_COLUMNS))) * _CELL_PITCH
		entry.is_picked = id == _picked_ids.get(_tab, "")
		entry.picked.connect(func(picked: CodexEntry) -> void: _pick(picked.id))
		entry.hovered.connect(_on_entry_hovered)
		entry.unhovered.connect(func(_entry: CodexEntry) -> void: %HoverLabel.text = "")
		_entries.append(entry)

	%PageLabel.text = "%d/%d" % [_page + 1, _page_count()]
	%PrevPage.enabled = _page > 0
	%NextPage.enabled = _page < _page_count() - 1


func _icon(id: String) -> Texture2D:
	if _tab == Tab.TILES:
		return CodexCatalog.tile_icon(CodexCatalog.tile_resource(id))
	return CodexCatalog.enemy_resource(id).targeting_computer_image


func _pick(id: String) -> void:
	_picked_ids[_tab] = id
	for entry: CodexEntry in _entries:
		entry.is_picked = entry.id == id
	_show_detail(id)


## The hovered entry's number and name, or "???" until it's found.
func _on_entry_hovered(entry: CodexEntry) -> void:
	var entry_name: String = tr("CODEX_UNKNOWN")
	if entry.found:
		entry_name = _entry_name(entry.id)
	%HoverLabel.text = "[color=#8e8b85]#%03d[/color] %s" % [entry.number, entry_name]


func _entry_name(id: String) -> String:
	if _tab == Tab.TILES:
		return Utils.format_text(CodexCatalog.tile_resource(id).display_name())
	return Utils.format_text("[color=red]%s[/color]" % CodexCatalog.enemy_resource(id).display_name())


func _show_detail(id: String) -> void:
	%KeywordPopup.hide()
	var has_entry: bool = not id.is_empty()
	for node: CanvasItem in [%NameLabel, %SubLabel, %BodyLabel]:
		node.visible = has_entry
	%Portrait.visible = has_entry and _tab == Tab.TILES
	_ship_portrait.visible = has_entry and _tab == Tab.ENEMIES
	%StatsLabel.visible = has_entry and _tab == Tab.ENEMIES
	%EmptyLabel.visible = not has_entry
	if not has_entry:
		%UpgradeToggle.visible = false
		%EmptyLabel.text = tr("CODEX_EMPTY_TILES" if _tab == Tab.TILES else "CODEX_EMPTY_ENEMIES")
		return

	if _tab == Tab.TILES:
		var base_tile: TileResource = CodexCatalog.tile_resource(id)
		var has_upgrade: bool = base_tile != null and base_tile.upgraded_version != null
		%UpgradeToggle.visible = has_upgrade
		%UpgradeCheck.set_pressed_no_signal(_show_upgraded)
		var shown_tile: TileResource = base_tile.upgraded_version if (_show_upgraded and has_upgrade) else base_tile
		%NameLabel.text = Utils.format_text(shown_tile.display_name())
		_make_room_for_name()
		_show_tile(shown_tile, has_upgrade)
	else:
		%UpgradeToggle.visible = false
		%NameLabel.text = _entry_name(id)
		_make_room_for_name()
		_show_enemy(id, CodexCatalog.enemy_resource(id))
	ColorSymbolBadge.attach_to_rect(%Portrait)
	%BodyLabel.scroll_to_line(0)


func _on_upgrade_toggled(on: bool) -> void:
	Events.play_sound.emit(_TOGGLE_SFX)
	_show_upgraded = on
	_show_detail(_picked_ids.get(_tab, ""))


func _on_upgrade_row_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		%UpgradeCheck.button_pressed = not %UpgradeCheck.button_pressed
		get_viewport().set_input_as_handled()


## The Options menu's checkbox art, exactly its size (see OptionsPage.check()).
func _style_upgrade_check() -> void:
	var box: CheckBox = %UpgradeCheck
	for state: String in ["checked", "unchecked"]:
		box.add_theme_icon_override(state, _CHECK_TEXTURES[state])
		box.add_theme_icon_override(state + "_disabled", _CHECK_TEXTURES[state])
	var empty: StyleBoxEmpty = StyleBoxEmpty.new()
	for state: String in ["normal", "hover", "pressed", "hover_pressed", "disabled", "focus"]:
		box.add_theme_stylebox_override(state, empty)


## A body that scrolls gets a blank line after its last, so scrolled to the
## bottom that line clears the box's edge and whatever sits under it.
func _pad_scrolling_body() -> void:
	var body: RichTextLabel = %BodyLabel
	if body.get_content_height() > body.size.y:
		body.text += "\n "


func _make_room_for_name() -> void:
	var extra: float = _LINE_STEP * maxi(0, %NameLabel.get_line_count() - 1)
	%NameLabel.offset_bottom = _NAME_BOTTOM + extra
	%SubLabel.offset_top = _SUB_TOP + extra
	%SubLabel.offset_bottom = _SUB_BOTTOM + extra
	%BodyLabel.offset_top = _BODY_TOP + extra


func _show_tile(tile: TileResource, has_upgrade: bool = false) -> void:
	%Portrait.texture = CodexCatalog.tile_icon(tile)
	_portrait_material.set_shader_parameter(&"upgraded", tile.is_upgrade)
	var lines: Array[String] = [
		"[color=%s]%s[/color]" % [_RARITY_COLOURS[tile.rarity], tr(_RARITY_KEYS[tile.rarity])],
	]
	if tile.uses_per_turn > 0:
		lines.append(tr("CODEX_TILE_USES").format({"uses": tile.uses_per_turn}))
	%SubLabel.text = Utils.format_text("\n".join(lines), true)
	var no_counters: Dictionary[String, int] = {}
	%BodyLabel.text = Utils.format_text(Tile.fill_data_tokens(tile.display_description(), no_counters), true)
	%BodyLabel.offset_bottom = _BODY_BOTTOM_ABOVE_TOGGLE if has_upgrade else _BODY_BOTTOM
	_pad_scrolling_body()


func _show_enemy(id: String, enemy: EnemyResource) -> void:
	_ship_portrait.show_ship(enemy)
	var stats: Array[String] = [
		"[color=red]%s[/color]" % tr("CODEX_HULL").format({"health": enemy.max_health}),
	]
	if enemy.starting_shields > 0:
		stats.append("[color=blue]%s[/color]" % tr("CODEX_SHIELDS").format({"shields": enemy.starting_shields}))
	%SubLabel.text = Utils.format_text("\n".join(stats), true)

	var sections: Array[String] = []
	var blurb: String = enemy.display_description()
	if not blurb.is_empty():
		sections.append(blurb)
	if enemy.overload_threshold > 0:
		sections.append(tr("CODEX_OVERLOAD").format({"threshold": enemy.overload_threshold}))
	var actions: Array[String] = CodexCatalog.enemy_action_lines(enemy)
	if not actions.is_empty():
		sections.append("[color=orange]%s[/color]\n%s" % [tr("CODEX_ACTIONS"), "\n".join(actions)])
	%BodyLabel.text = Utils.format_text("\n\n".join(sections), true)
	%BodyLabel.offset_bottom = _BODY_BOTTOM_ABOVE_STATS
	_pad_scrolling_body()

	var met: String = tr("CODEX_MET").format({"met": CollectionManager.times_encountered(id)})
	var destroyed: String = tr("CODEX_DESTROYED").format({"destroyed": CollectionManager.times_destroyed(id)})
	%StatsLabel.text = Utils.format_text("[color=red]%s[/color]   [color=green]%s[/color]" % [met, destroyed])


## The mouse wheel turns pages over the grid.
func _on_grid_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_turn_page(-1)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_turn_page(1)


func _on_keyword_hover_started(meta: Variant) -> void:
	var rule: String = Keywords.definition(str(meta))
	if rule.is_empty():
		return
	%KeywordLabel.text = Utils.format_text("[color=orange]%s[/color]: %s" % [Keywords.title(str(meta)), rule])
	preload("res://Source/Systems/UI/InfoShower/keyword_diagram.gd").configure(%KeywordPopup, %KeywordLabel, str(meta), 1.0)
	# Shrink back to the new text's size first, or a long rule's height
	# lingers on a short one.
	%KeywordPopup.reset_size()
	%KeywordPopup.show()
	_place_keyword_popup()


func _on_keyword_hover_ended(_meta: Variant) -> void:
	%KeywordPopup.hide()


func _process(_delta: float) -> void:
	if not _warmed_up:
		_warmed_up = CodexCatalog.collect_loaded()
	if visible and %KeywordPopup.visible:
		_place_keyword_popup()


## Below-right of the cursor, kept on screen.
func _place_keyword_popup() -> void:
	var popup_size: Vector2 = %KeywordPopup.size
	var pos: Vector2 = get_local_mouse_position() + Vector2(6, 6)
	pos.x = clampf(pos.x, -158.0, maxf(-158.0, 158.0 - popup_size.x))
	if pos.y + popup_size.y > 88.0:
		pos.y = get_local_mouse_position().y - popup_size.y - 4.0
	pos.y = clampf(pos.y, -88.0, maxf(-88.0, 88.0 - popup_size.y))
	%KeywordPopup.position = pos.floor()


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed(&"ui_left"):
		_turn_page(-1)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed(&"ui_right"):
		_turn_page(1)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed(&"ui_cancel"):
		close()
		get_viewport().set_input_as_handled()
