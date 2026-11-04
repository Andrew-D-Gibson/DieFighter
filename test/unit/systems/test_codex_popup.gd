extends "res://test/helpers/die_fighter_test.gd"
## The codex page makes room for a name that wraps: the name box takes the
## second line and the page below it moves down, so nothing clips.

const _SCENE: PackedScene = preload("res://Source/Systems/UI/Codex/codex_popup.tscn")

var _codex: CodexPopup


func before_each() -> void:
	super()
	CollectionManager.clear()
	_codex = _SCENE.instantiate()
	add_child_autofree(_codex)
	_codex.open()


func after_each() -> void:
	CollectionManager.clear()
	super()


func test_a_one_line_name_keeps_the_page_where_it_was() -> void:
	_codex.get_node("%NameLabel").text = "Picket"
	_codex._make_room_for_name()
	assert_eq(_codex.get_node("%NameLabel").offset_bottom, CodexPopup._NAME_BOTTOM)
	assert_eq(_codex.get_node("%SubLabel").offset_top, CodexPopup._SUB_TOP)
	assert_eq(_codex.get_node("%BodyLabel").offset_top, CodexPopup._BODY_TOP)


func test_a_wrapped_name_pushes_the_page_down_a_line() -> void:
	var name_label: RichTextLabel = _codex.get_node("%NameLabel")
	name_label.text = "Bastion Batteries Overcharged"
	_codex._make_room_for_name()
	assert_eq(name_label.get_line_count(), 2, "the test name wraps")
	assert_eq(name_label.offset_bottom, CodexPopup._NAME_BOTTOM + CodexPopup._LINE_STEP)
	assert_lte(name_label.get_content_height(), int(name_label.size.y), "both lines show")
	assert_eq(_codex.get_node("%SubLabel").offset_top, CodexPopup._SUB_TOP + CodexPopup._LINE_STEP)
	assert_eq(_codex.get_node("%BodyLabel").offset_top, CodexPopup._BODY_TOP + CodexPopup._LINE_STEP)

	name_label.text = "Picket"
	_codex._make_room_for_name()
	assert_eq(_codex.get_node("%BodyLabel").offset_top, CodexPopup._BODY_TOP, "and back for the next page")


func test_upgrade_toggle_switches_between_base_and_upgraded_tile() -> void:
	CollectionManager.record_tile("damage")
	_codex.open()
	_codex._pick("damage")
	var base_tile: TileResource = CodexCatalog.tile_resource("damage")
	var upgraded_tile: TileResource = base_tile.upgraded_version
	var toggle: CodexButton = _codex.get_node("%UpgradeToggle")
	var name_label: RichTextLabel = _codex.get_node("%NameLabel")
	var body_label: RichTextLabel = _codex.get_node("%BodyLabel")

	assert_true(toggle.visible, "upgradeable tile shows the toggle")
	assert_false(toggle.selected, "starts on base version")
	assert_eq(name_label.text, Utils.format_text(base_tile.display_name()))

	toggle.pressed.emit()
	assert_true(toggle.selected, "toggled to upgraded version")
	assert_eq(name_label.text, Utils.format_text(upgraded_tile.display_name()))
	var no_counters: Dictionary[String, int] = {}
	assert_eq(body_label.text, Utils.format_text(Tile.fill_data_tokens(upgraded_tile.display_description(), no_counters), true))

	toggle.pressed.emit()
	assert_false(toggle.selected, "toggled back to base version")
	assert_eq(name_label.text, Utils.format_text(base_tile.display_name()))


func test_non_upgradeable_tile_hides_upgrade_toggle() -> void:
	CollectionManager.record_tile("gearbox")
	_codex.open()
	_codex._pick("gearbox")
	assert_false(_codex.get_node("%UpgradeToggle").visible, "ship-only tile with no upgrade hides the toggle")
