class_name LocAuditSurfaces
extends RefCounted
## Every screen the localization audit checks, in report order. Each is a
## LocAuditSurface; see that class for what a surface does.
##
## A few poses reach into a scene's own methods (the codex's _pick, the
## options menu's tab buttons, a tile's info): those are the same calls a
## click makes, used because the audit has no mouse to click with.

const _INFO_SHOWER: PackedScene = preload("res://Source/Systems/UI/InfoShower/info_shower.tscn")
const _MAIN_MENU_PATH: String = "res://Source/Systems/UI/MainMenu/main_menu.tscn"
const _TILE_SCENE_PATH: String = "res://Source/Content/Tiles/tile.tscn"
const _STATUS_BADGE_PATH: String = "res://Source/Behavior/Modifiers/Statuses/StatusBadge/status_badge.tscn"
const _TUTORIAL_POPUP_PATH: String = "res://Source/Systems/TutorialManager/TutorialTextPopup/tutorial_text_popup.tscn"
const _SHOP_PATH: String = "res://Source/Systems/Game/Shop/shop.tscn"
const _REWARD_PATH: String = "res://Source/Systems/Game/RewardManager/reward.tscn"
const _ERROR_POPUPS_PATH: String = "res://Source/Systems/UI/ErrorPopupManager/error_popup_manager.tscn"

const _TILE_DIR: String = "res://Source/Content/Tiles/TileResources/"
const _ENEMY_DIR: String = "res://Source/Content/Enemies/EnemyResources/"
const _ENEMY_ACTION_DIR: String = "res://Source/Content/Enemies/EnemyActions/EnemyActionResources/"
const _HAZARD_DIR: String = "res://Source/Resources/BackgroundResources/BackgroundHazards/"
const _RULE_DIR: String = "res://Source/Resources/BackgroundResources/BackgroundModifiers/"
const _KEYWORD_DIR: String = "res://Source/Content/Keywords/KeywordResources/"
const _TUTORIAL_DIR: String = "res://Source/Systems/TutorialManager/TutorialStepResources/"
const _UI_CSV: String = "res://Localization/translations.csv"
## Content folders searched for callout effects.
const _CALLOUT_ROOTS: Array[String] = ["res://Source/Content/", "res://Source/Resources/"]


## Every surface, in the order the report lists them.
static func all() -> Array[LocAuditSurface]:
	return [
		MainMenuSurface.new(),
		TilesSurface.new(),
		EnemiesSurface.new(),
		EnemyActionsSurface.new(),
		FactionsSurface.new(),
		StatusesSurface.new(),
		KeywordsSurface.new(),
		HazardsSurface.new(),
		RulesSurface.new(),
		TutorialSurface.new(),
		ShopRewardSurface.new(),
		CalloutsSurface.new(),
		ErrorPopupsSurface.new(),
	]


## The surfaces whose id is in [param ids], or all of them for an empty list.
static func named(ids: PackedStringArray) -> Array[LocAuditSurface]:
	var chosen: Array[LocAuditSurface] = []
	for surface: LocAuditSurface in all():
		if ids.is_empty() or surface.id in ids:
			chosen.append(surface)
	return chosen


static func _item(item_id: String, label: String, extra: Dictionary = {}) -> Dictionary:
	var item: Dictionary = {"id": item_id, "label": label}
	item.merge(extra)
	return item


## UI translation keys starting with [param prefix], read off the CSV.
static func _ui_keys(prefix: String) -> Array[String]:
	var keys: Array[String] = []
	var file: FileAccess = FileAccess.open(_UI_CSV, FileAccess.READ)
	if file == null:
		return keys
	file.get_csv_line()
	while not file.eof_reached():
		var row: PackedStringArray = file.get_csv_line()
		if not row.is_empty() and row[0].begins_with(prefix):
			keys.append(row[0])
	return keys


# ── Info panel ───────────────────────────────────────────────────────────────

## Surfaces shown in the shared info panel. Each item's pose ends with the
## content's own code emitting Events.show_info.
class InfoPanelSurface extends LocAuditSurface:
	var shower: Control

	func setup(stage: LocAuditStage) -> void:
		shower = LocAuditSurfaces._INFO_SHOWER.instantiate()
		stage.ui.add_child(shower)

	func subject(_stage: LocAuditStage, _item: Dictionary) -> Node:
		return shower

	func unpose(_item: Dictionary, stage: LocAuditStage) -> void:
		for child: Node in stage.world.get_children():
			child.queue_free()


class TilesSurface extends InfoPanelSurface:
	var _tile_scene: PackedScene = load(LocAuditSurfaces._TILE_SCENE_PATH)

	func _init() -> void:
		id = "tiles"
		title = "Tiles (info panel)"

	func items() -> Array[Dictionary]:
		var found: Array[Dictionary] = []
		for resource: Resource in load_dir(LocAuditSurfaces._TILE_DIR):
			var stem: String = resource.resource_path.get_file().get_basename()
			found.append(LocAuditSurfaces._item(stem, stem, {"resource": resource}))
		return found

	func pose(item: Dictionary, stage: LocAuditStage) -> void:
		# A clicked tile is what opens its panel in play.
		var tile: Node2D = _tile_scene.instantiate()
		tile.set("tile_resource", item["resource"])
		tile.position = Vector2(-100, -100)
		stage.world.add_child(tile)
		var clickable: Node = tile.get("clickable")
		if clickable:
			clickable.emit_signal(&"clicked")


class EnemyActionsSurface extends InfoPanelSurface:
	func _init() -> void:
		id = "enemy_actions"
		title = "Enemy actions (info panel)"

	## Every action any enemy can roll, plus the shared ones, once each.
	func items() -> Array[Dictionary]:
		var actions: Array[Resource] = []
		for resource: Resource in load_dir(LocAuditSurfaces._ENEMY_ACTION_DIR):
			actions.append(resource)
		for enemy: Resource in load_dir(LocAuditSurfaces._ENEMY_DIR):
			for list: Resource in enemy.get("action_options"):
				for option: Resource in list.get("actions_possible"):
					var action: Resource = option.get("base_action")
					if action and action not in actions:
						actions.append(action)
		var found: Array[Dictionary] = []
		var seen: Dictionary[String, bool] = {}
		for action: Resource in actions:
			var action_name: String = str(action.get("name"))
			if action_name.is_empty():
				continue
			var item_id: String = action.resource_path.get_file().get_basename() \
				if action.resource_path.ends_with(".tres") else action_name.to_snake_case()
			while seen.has(item_id):
				item_id += "_"
			seen[item_id] = true
			found.append(LocAuditSurfaces._item(item_id, action_name, {"resource": action}))
		return found

	func pose(item: Dictionary, _stage: LocAuditStage) -> void:
		# Clicking an intent on the targeting computer calls this.
		item["resource"].call(&"show_info")


class FactionsSurface extends InfoPanelSurface:
	func _init() -> void:
		id = "factions"
		title = "Factions (info panel)"

	func items() -> Array[Dictionary]:
		var found: Array[Dictionary] = []
		var seen: Array[Resource] = []
		for enemy: Resource in load_dir(LocAuditSurfaces._ENEMY_DIR):
			var faction: Resource = enemy.get("faction")
			if faction and faction not in seen:
				seen.append(faction)
				var stem: String = faction.resource_path.get_file().get_basename()
				found.append(LocAuditSurfaces._item(stem, stem, {"resource": faction}))
		return found

	func pose(item: Dictionary, _stage: LocAuditStage) -> void:
		Events.show_info.emit(item["resource"].call(&"info"))


class StatusesSurface extends InfoPanelSurface:
	var _badge_scene: PackedScene = load(LocAuditSurfaces._STATUS_BADGE_PATH)

	func _init() -> void:
		id = "statuses"
		title = "Statuses (info panel)"

	func items() -> Array[Dictionary]:
		var found: Array[Dictionary] = []
		for status_id: StringName in StatusCatalog.ids():
			found.append(LocAuditSurfaces._item(str(status_id), str(status_id), {"status": status_id}))
		return found

	func pose(item: Dictionary, stage: LocAuditStage) -> void:
		# A ship's status badge, clicked.
		var host: Node2D = Node2D.new()
		host.position = Vector2(-100, -100)
		stage.world.add_child(host)
		var status: StatusModifier = StatusCatalog.create(item["status"], host, 2)
		var badge: Node2D = _badge_scene.instantiate()
		badge.call(&"setup", status)
		host.add_child(badge)
		badge.get_node("%Clickable").emit_signal(&"clicked")


## A keyword's rule pops up over the info panel when its word is hovered.
class KeywordsSurface extends InfoPanelSurface:
	func _init() -> void:
		id = "keywords"
		title = "Keyword pop-ups"

	## Every term Keywords can define, so a new one is picked up without
	## listing it here: one per KeywordResource (and its "(you)" rule) once
	## keywords are resources, else the terms in keywords.gd's own table.
	func items() -> Array[Dictionary]:
		var terms: Array[String] = []
		for keyword: Resource in load_dir(LocAuditSurfaces._KEYWORD_DIR):
			var stem: String = keyword.resource_path.get_file().get_basename()
			terms.append_array([stem, stem + "_you"])
		var definitions: Variant = (Keywords as GDScript).get_script_constant_map().get("_DEFINITIONS", {})
		for term: Variant in (definitions as Dictionary).keys():
			terms.append(str(term))
		var found: Array[Dictionary] = []
		for term: String in terms:
			if Keywords.definition(term).is_empty():
				continue
			found.append(LocAuditSurfaces._item(term.to_snake_case(), _title(term), {"term": term}))
		return found

	## The keyword's name as the pop-up heads it, where Keywords can say.
	static func _title(term: String) -> String:
		var script: GDScript = Keywords as GDScript
		for method: Dictionary in script.get_script_method_list():
			if method["name"] == "title":
				return str(script.call(&"title", term))
		return term

	func pose(item: Dictionary, _stage: LocAuditStage) -> void:
		var info: InfoResource = InfoResource.new()
		info.title_label_text = "[color=orange]%s[/color]" % item["label"]
		Events.show_info.emit(info)
		# Hovering the word in the panel's description.
		shower.get_node("%BottomLabel").emit_signal(&"meta_hover_started", item["term"])

	func subject(_stage: LocAuditStage, _item: Dictionary) -> Node:
		return shower.get_node("%KeywordPopup")


class HazardsSurface extends InfoPanelSurface:
	func _init() -> void:
		id = "hazards"
		title = "Hazards (info panel and warning banner)"

	func items() -> Array[Dictionary]:
		var found: Array[Dictionary] = []
		for hazard: Resource in load_dir(LocAuditSurfaces._HAZARD_DIR):
			var stem: String = hazard.resource_path.get_file().get_basename()
			found.append(LocAuditSurfaces._item(stem + "_panel", stem, {"resource": hazard}))
			found.append(LocAuditSurfaces._item(stem + "_warning", stem + " warning", {"resource": hazard, "warning": true}))
		return found

	func pose(item: Dictionary, stage: LocAuditStage) -> void:
		var hazard: BackgroundHazardResource = item["resource"]
		if not item.get("warning", false):
			Events.show_info.emit(EnvironmentMonitor.hazard_info(hazard, true, 2))
			return
		shower.hide()
		# The warning puts itself on the game's root; move it onto the stage.
		var before: Array[Node] = stage.get_tree().root.get_children()
		HazardWarning.show_for(stage, hazard, 4.0)
		for node: Node in stage.get_tree().root.get_children():
			if node not in before and node is CanvasLayer:
				node.reparent(stage.viewport)
				item["warning_node"] = node

	func subject(stage: LocAuditStage, item: Dictionary) -> Node:
		if item.has("warning_node") and is_instance_valid(item["warning_node"]):
			return item["warning_node"]
		return super.subject(stage, item)

	func unpose(item: Dictionary, stage: LocAuditStage) -> void:
		if item.has("warning_node") and is_instance_valid(item["warning_node"]):
			item["warning_node"].queue_free()
		super.unpose(item, stage)


## Background rules, as the environment monitor's panel shows them.
class RulesSurface extends InfoPanelSurface:
	func _init() -> void:
		id = "rules"
		title = "Background rules (info panel)"

	func items() -> Array[Dictionary]:
		var found: Array[Dictionary] = []
		for rule: Resource in load_dir(LocAuditSurfaces._RULE_DIR):
			var stem: String = rule.resource_path.get_file().get_basename()
			found.append(LocAuditSurfaces._item(stem, stem, {"resource": rule}))
		return found

	func pose(item: Dictionary, _stage: LocAuditStage) -> void:
		var rule: BackgroundModifierResource = item["resource"]
		# As EnvironmentMonitor._on_clicked builds it for a rule.
		var info: InfoResource = InfoResource.new()
		info.title_label_text = "[color=%s]%s[/color]" % [rule.color.to_html(false), rule.display_name().to_upper()]
		info.bottom_label_text = rule.display_description()
		info.texture = rule.icon if rule.icon else EnvironmentMonitor._DEFAULT_INFO_ICON
		Events.show_info.emit(info)


# ── Menus ────────────────────────────────────────────────────────────────────

## The main menu, its new-game confirmation and ship select, and every
## options tab.
class MainMenuSurface extends LocAuditSurface:
	var menu: Node2D

	func _init() -> void:
		id = "menus"
		title = "Main menu and options"

	func items() -> Array[Dictionary]:
		var found: Array[Dictionary] = [
			LocAuditSurfaces._item("main_menu", "Main menu"),
			LocAuditSurfaces._item("ship_select", "Ship select"),
			LocAuditSurfaces._item("confirm_new_game", "Overwrite save?"),
		]
		var tabs: Dictionary = OptionsMenuTabs.TABS
		for tab: int in tabs:
			found.append(LocAuditSurfaces._item("options_" + str(tabs[tab]).to_lower(), "Options: " + str(tabs[tab]), {"tab": tab}))
		found.append(LocAuditSurfaces._item("options_controller", "Options: Controls, controller", {"tab": 3, "page": 1}))
		return found

	func setup(stage: LocAuditStage) -> void:
		menu = (load(LocAuditSurfaces._MAIN_MENU_PATH) as PackedScene).instantiate()
		stage.world.add_child(menu)
		# Past the fade-in.
		var player: AnimationPlayer = menu.get_node_or_null("%AnimationPlayer")
		if player and player.current_animation != "":
			player.advance(player.current_animation_length)

	func pose(item: Dictionary, _stage: LocAuditStage) -> void:
		var options: Node2D = menu.get_node("%OptionsMenu")
		options.hide()
		menu.get_node("%ConfirmDialog").hide()
		menu.get_node("%ShipSelectPopup").hide()
		match item["id"]:
			"ship_select":
				menu.get_node("%ShipSelectPopup").call(&"open")
			"confirm_new_game":
				menu.get_node("%ConfirmDialog").call(&"open", TranslationServer.translate("MENU_OVERWRITE_SAVE"), true)
			"main_menu":
				pass
			_:
				options.show()
				var buttons: Array = options.get("_tab_buttons")
				buttons[item["tab"]].emit_signal(&"pressed_within_window")
				if item.has("page"):
					var sub_tabs: Dictionary = options.get("_sub_tabs")
					(sub_tabs[item["tab"]] as Object).emit_signal(&"selected", item["page"])

	func subject(stage: LocAuditStage, item: Dictionary) -> Node:
		match item["id"]:
			"ship_select":
				return menu.get_node("%ShipSelectPopup")
			"confirm_new_game":
				return menu.get_node("%ConfirmDialog")
			"main_menu":
				return stage.viewport
		return menu.get_node("%OptionsMenu")


## Option tab names for item ids, by OptionsMenu.Tab value.
class OptionsMenuTabs:
	const TABS: Dictionary = {0: "Game", 1: "Graphics", 2: "Audio", 3: "Controls", 4: "Accessibility"}


## Each enemy's codex page: its name, hull, description and actions.
class EnemiesSurface extends LocAuditSurface:
	var menu: Node2D
	var codex: Node

	func _init() -> void:
		id = "enemies"
		title = "Enemies (codex page)"

	func items() -> Array[Dictionary]:
		var found: Array[Dictionary] = []
		for enemy_id: String in CodexCatalog.enemy_ids():
			found.append(LocAuditSurfaces._item(enemy_id, enemy_id))
		return found

	func setup(stage: LocAuditStage) -> void:
		menu = (load(LocAuditSurfaces._MAIN_MENU_PATH) as PackedScene).instantiate()
		stage.world.add_child(menu)
		codex = menu.get_node("%CodexPopup")
		codex.call(&"open")
		codex.call(&"_show_tab", 1)	# CodexPopup.Tab.ENEMIES

	func pose(item: Dictionary, _stage: LocAuditStage) -> void:
		# What clicking the enemy's entry in the grid does.
		codex.call(&"_pick", item["id"])

	func subject(_stage: LocAuditStage, _item: Dictionary) -> Node:
		return codex


# ── Tutorial, shop, callouts ─────────────────────────────────────────────────

class TutorialSurface extends LocAuditSurface:
	var _popup_scene: PackedScene = load(LocAuditSurfaces._TUTORIAL_POPUP_PATH)
	var _popup: Node2D

	func _init() -> void:
		id = "tutorial"
		title = "Tutorial cards"

	func items() -> Array[Dictionary]:
		var found: Array[Dictionary] = []
		for step: Resource in load_dir(LocAuditSurfaces._TUTORIAL_DIR):
			var stem: String = step.resource_path.get_file().get_basename()
			found.append(LocAuditSurfaces._item(stem, stem, {"resource": step}))
		return found

	func pose(item: Dictionary, stage: LocAuditStage) -> void:
		var step: Resource = item["resource"]
		_popup = _popup_scene.instantiate()
		stage.world.add_child(_popup)
		_popup.call(&"setup", display_text(step, &"tutorial_text"), step.get("text_position"), null, true)
		# A click finishes the typing.
		_popup.get_node("%CompleteTextButton").emit_signal(&"pressed")

	func subject(_stage: LocAuditStage, _item: Dictionary) -> Node:
		return _popup

	func unpose(_item: Dictionary, _stage: LocAuditStage) -> void:
		if is_instance_valid(_popup):
			_popup.queue_free()


## The shop's shelf labels and the salvage offer's heading.
class ShopRewardSurface extends LocAuditSurface:
	var _node: Node2D

	func _init() -> void:
		id = "shop_reward"
		title = "Shop and salvage"

	func items() -> Array[Dictionary]:
		return [
			LocAuditSurfaces._item("shop", "Shop", {"path": LocAuditSurfaces._SHOP_PATH, "at": Vector2(122, 43)}),
			LocAuditSurfaces._item("reward", "Salvage offer", {"path": LocAuditSurfaces._REWARD_PATH, "at": Vector2(160, 70)}),
		]

	func pose(item: Dictionary, stage: LocAuditStage) -> void:
		_node = (load(item["path"]) as PackedScene).instantiate()
		_node.position = item["at"]
		stage.world.add_child(_node)
		_node.show()
		_node.modulate.a = 1.0
		if _node.has_method(&"_refresh_reroll"):
			_node.call(&"_refresh_reroll")

	func subject(_stage: LocAuditStage, _item: Dictionary) -> Node:
		return _node

	func unpose(_item: Dictionary, _stage: LocAuditStage) -> void:
		if is_instance_valid(_node):
			_node.queue_free()


## Every callout an effect floats off a ship, and the coded ones (Evaded,
## Overload, ...), drawn the way JuiceEvent draws them.
class CalloutsSurface extends LocAuditSurface:
	var _holder: Node2D
	var _anchor: Node2D

	func _init() -> void:
		id = "callouts"
		title = "Callouts"
		fast = false

	func items() -> Array[Dictionary]:
		var found: Array[Dictionary] = []
		var seen: Dictionary[String, bool] = {}
		for key: String in LocAuditSurfaces._ui_keys("CALLOUT_"):
			seen[key] = true
			found.append(LocAuditSurfaces._item(key.to_lower(), key, {"key": key}))
		var effects: Array[Resource] = []
		for root: String in LocAuditSurfaces._CALLOUT_ROOTS:
			for resource: Resource in load_dir(root, true):
				_collect_callouts(resource, effects, {})
		for effect: Resource in effects:
			var text: String = LocAuditSurfaces.callout_text(effect)
			if text.is_empty() or seen.has(text):
				continue
			seen[text] = true
			var item_id: String = text.to_snake_case().validate_filename().left(40)
			found.append(LocAuditSurfaces._item("fx_" + item_id, text, {"effect": effect}))
		return found

	func setup(stage: LocAuditStage) -> void:
		_holder = Node2D.new()
		stage.world.add_child(_holder)
		_anchor = Node2D.new()
		_anchor.position = Vector2(160, 100)
		_holder.add_child(_anchor)

	func pose(item: Dictionary, _stage: LocAuditStage) -> void:
		var text: String
		if item.has("key"):
			text = TranslationServer.translate(item["key"])
		else:
			text = LocAuditSurfaces.callout_text(item["effect"])
		text = text.replace("{amount}", "12").replace("{die}", "6")
		Juice.callout(_anchor, text, Globals.yellow, false)

	func subject(_stage: LocAuditStage, _item: Dictionary) -> Node:
		return _holder

	func unpose(_item: Dictionary, _stage: LocAuditStage) -> void:
		for child: Node in _holder.get_children():
			if child != _anchor:
				child.queue_free()

	## Finds every CALLOUT effect inside [param value], however deep.
	static func _collect_callouts(value: Variant, found: Array[Resource], seen: Dictionary) -> void:
		if value is Array:
			for element: Variant in value:
				_collect_callouts(element, found, seen)
			return
		if not value is Resource:
			return
		var resource: Resource = value
		if seen.has(resource.get_instance_id()):
			return
		seen[resource.get_instance_id()] = true
		if resource is EffectData:
			var data: EffectData = resource
			if data.category == EffectEnums.Category.AUDIO_VISUAL \
					and data.subtype == EffectEnums.AudioVisualSubtype.CALLOUT and resource not in found:
				found.append(resource)
		for property: Dictionary in resource.get_property_list():
			if property["usage"] & PROPERTY_USAGE_STORAGE and property["type"] in [TYPE_OBJECT, TYPE_ARRAY]:
				_collect_callouts(resource.get(property["name"]), found, seen)


## The words a CALLOUT effect floats: its callout field once callouts are
## content text, else its string_param.
static func callout_text(effect: Resource) -> String:
	for field: ContentText.Field in ContentText.fields_of(effect):
		if str(field.property).contains("callout"):
			var text: String = ContentText.text(effect, field.property)
			if not text.is_empty():
				return text
	return str(effect.get("string_param"))


## The pop-ups a refused tile or move shows (ERROR_* keys).
class ErrorPopupsSurface extends LocAuditSurface:
	var _manager: Node

	func _init() -> void:
		id = "errors"
		title = "Error pop-ups"
		fast = false

	func items() -> Array[Dictionary]:
		var found: Array[Dictionary] = []
		for key: String in LocAuditSurfaces._ui_keys("ERROR_"):
			found.append(LocAuditSurfaces._item(key.to_lower(), key, {"key": key}))
		return found

	func setup(stage: LocAuditStage) -> void:
		_manager = (load(LocAuditSurfaces._ERROR_POPUPS_PATH) as PackedScene).instantiate()
		stage.world.add_child(_manager)

	func pose(item: Dictionary, _stage: LocAuditStage) -> void:
		Events.error_text_popup.emit(TranslationServer.translate(item["key"]), Vector2(160, 100))

	# Each pop-up replaces the last, as it does in play.
	func subject(_stage: LocAuditStage, _item: Dictionary) -> Node:
		return _manager
