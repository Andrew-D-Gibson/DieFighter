class_name LocAuditSurface
extends RefCounted
## One kind of screen the localization audit poses, item by item: a menu's
## tabs, or the info panel for every tile. Subclasses are in
## LocAuditSurfaces.
##
## Screens are driven the way the game drives them (Events.show_info with what
## the content's own code builds, a button's signal), not rebuilt here, so the
## photos show whatever the game's display code reads, whichever way content
## text is wired.

## Folder name in the report, and how the item ids are prefixed.
var id: String = ""
## Heading in the report.
var title: String = ""
## Whether tweens may run fast while posing (the info panel's art zooms in
## for half a second). Floating callouts fade with time, so they don't.
var fast: bool = true


## The things to pose, each {id: String, label: String} plus whatever the
## surface needs to pose it.
func items() -> Array[Dictionary]:
	return []


## Puts what every item shares on [param stage] (an info panel, a menu).
func setup(_stage: LocAuditStage) -> void:
	pass


## Shows [param item] on [param stage]. May await.
func pose(_item: Dictionary, _stage: LocAuditStage) -> void:
	pass


## The part of the stage to check and photograph for [param item]: only the
## labels under it are checked, and the photo is cropped to it.
func subject(stage: LocAuditStage, _item: Dictionary) -> Node:
	return stage.viewport


## Clears up after [param item], before the next is posed.
func unpose(_item: Dictionary, _stage: LocAuditStage) -> void:
	pass


## Shows [param resource]'s [param property] the way the game shows content
## text: through ContentText when the property is declared content text, the
## field itself (an English string, or a key a label translates) when not.
static func display_text(resource: Resource, property: StringName) -> String:
	if resource == null or not property in resource:
		return ""
	if ContentText.field_of(resource, property) != null:
		return ContentText.text(resource, property)
	return str(resource.get(property))


## Every .tres under [param dir], loaded, in file order. None if there's no
## such folder.
static func load_dir(dir: String, recursive: bool = false) -> Array[Resource]:
	var found: Array[Resource] = []
	if not DirAccess.dir_exists_absolute(dir):
		return found
	for path: String in Utils.list_resource_paths(dir, recursive):
		var resource: Resource = load(path)
		if resource:
			found.append(resource)
	return found
