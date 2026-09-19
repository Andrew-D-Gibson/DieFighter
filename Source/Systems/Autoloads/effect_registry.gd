## EffectRegistry
## Maps (category, subtype) pairs to EffectHandler instances.
##
## The table is built from EffectCatalog, which is the single place an effect
## is described. There is no hand-maintained list here any more — adding a row
## to the catalog is what registers a handler.
##
## All handlers are stateless, so a single shared instance per handler type is
## safe and efficient.
##
## HOW EffectChain USES THIS:
##   var handler := EffectRegistry.get_handler(data.category, data.subtype)
##   await handler.apply(data, context, engine)


extends Node

# The registry: _handlers[category_int][subtype_int] = EffectHandler instance
var _handlers: Dictionary = {}


func _ready() -> void:
	_report_catalog_problems()
	_build_from_catalog()


## A catalog that disagrees with EffectEnums means some effect is half-added:
## authorable but inert, or implemented but unreachable. That used to be
## invisible until a tile mysteriously did nothing, so shout about it at boot.
func _report_catalog_problems() -> void:
	var problems: PackedStringArray = EffectCatalog.validate()
	if problems.is_empty():
		return
	push_error(
		"EffectCatalog is out of sync with EffectEnums (%d problem(s)):\n  - %s"
		% [problems.size(), "\n  - ".join(problems)]
	)


func _build_from_catalog() -> void:
	for entry: Dictionary in EffectCatalog.all():
		# Reserved ordinals exist to hold their enum position and nothing else.
		# They have no handler on purpose, so skip them rather than warn.
		if entry.get("reserved", false):
			continue

		var handler_class: Variant = entry.get("handler")
		if handler_class == null:
			continue  # already reported by _report_catalog_problems()

		var category: int = entry["category"]
		if not _handlers.has(category):
			_handlers[category] = {}
		_handlers[category][entry["subtype"] as int] = handler_class.new()


## Look up the handler for a (category, subtype) pair.
## Returns null and logs an error if no handler is registered.
func get_handler(category: int, subtype: int) -> EffectHandler:
	if _handlers.has(category) and _handlers[category].has(subtype):
		return _handlers[category][subtype]

	# Distinguish "this effect was never built" from "this effect does not
	# exist", because the fix is different for each.
	var entry: Dictionary = EffectCatalog.get_entry(category, subtype)
	var detail: String
	if entry.is_empty():
		detail = "No catalog row for it — check that the .tres wasn't authored against a stale subtype ordinal."
	elif entry.get("reserved", false):
		detail = "'%s' is a reserved ordinal with no implementation." % entry.get("label", "?")
	else:
		detail = "Its catalog row has no handler."

	push_error(
		"EffectRegistry: no handler for category=%s subtype=%d. %s"
		% [EffectEnums.Category.find_key(category), subtype, detail]
	)
	return null
