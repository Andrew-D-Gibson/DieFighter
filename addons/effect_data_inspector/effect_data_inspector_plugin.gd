## EffectDataInspectorPlugin
## ============================================================
## Replaces the raw int "subtype" field with a context-sensitive
## OptionButton whose entries match the currently-selected category.
##
## The entries come from EffectCatalog, so this plugin no longer
## keeps its own copy of the effect list. It used to, and that copy
## silently fell six effects behind the enums — they existed, worked,
## and simply could not be picked here.
##
## Field visibility (hiding irrelevant fields) is handled by
## EffectData._validate_property(), also from the catalog. This plugin
## is intentionally narrow: it does one thing — the dropdown.
## ============================================================
@tool
extends EditorInspectorPlugin


func _can_handle(object: Object) -> bool:
	return object is EffectData


func _parse_property(object: Object, _type: Variant.Type, name: String,
		_hint_type: PropertyHint, _hint_string: String,
		_usage_flags: int, _wide: bool) -> bool:

	if name != "subtype":
		return false  # let everything else render normally

	var prop := SubtypeProperty.new()
	add_property_editor("subtype", prop)
	return true  # suppress the default int spinner


# ── SubtypeProperty ───────────────────────────────────────────────────────────
# Custom EditorProperty that shows a context-sensitive OptionButton for
# EffectData.subtype.  _update_property() is called automatically by Godot
# whenever the inspected resource emits changed (which EffectData.category's
# setter does), so the dropdown rebuilds itself when category changes.

class SubtypeProperty extends EditorProperty:
	var _dropdown: OptionButton
	var _updating: bool = false

	func _init() -> void:
		_dropdown = OptionButton.new()
		_dropdown.clip_text = true
		_dropdown.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		add_child(_dropdown)
		add_focusable(_dropdown)
		_dropdown.item_selected.connect(_on_item_selected)

	func _update_property() -> void:
		_updating = true
		var obj := get_edited_object()
		var category := int(obj.get("category"))
		var current_subtype := int(obj.get("subtype"))

		_dropdown.clear()

		# Item IDs carry the real subtype ordinal, because reserved ordinals
		# are skipped — position in this list is not the stored value.
		var selected_index: int = -1
		for entry: Dictionary in EffectCatalog.selectable_entries(category):
			var subtype: int = entry["subtype"]
			_dropdown.add_item(entry["label"], subtype)
			if subtype == current_subtype:
				selected_index = _dropdown.item_count - 1

		if selected_index >= 0:
			_dropdown.select(selected_index)
		elif _dropdown.item_count > 0:
			# The stored value has no selectable entry — a reserved ordinal, or
			# content authored against an older enum. Show it rather than
			# silently snapping to something else and rewriting the resource.
			_dropdown.add_item("<unknown subtype %d>" % current_subtype, current_subtype)
			_dropdown.select(_dropdown.item_count - 1)

		_updating = false

	func _on_item_selected(index: int) -> void:
		if _updating:
			return
		emit_changed("subtype", _dropdown.get_item_id(index))
