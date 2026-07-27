## EffectDataInspectorPlugin
## ============================================================
## Replaces the raw int "subtype" field with a context-sensitive
## OptionButton whose entries match the correct *Subtype enum for
## the currently-selected category.
##
## Field visibility (hiding irrelevant fields) is handled by
## EffectData._validate_property(), not here.  This plugin is
## intentionally narrow: it does one thing — the dropdown.
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

	# Maps Category int → ordered list of display names.
	# Order MUST stay in sync with each EffectEnums.*Subtype enum.
	static var SUBTYPE_NAMES: Dictionary = {
		EffectEnums.Category.TARGETING: [
			"Target All Enemies",
			"Target Player",
			"Target Random Enemy",
			"Target All Ships",
			"Target All Other Ships",
			"Target Random Ship",
			"Target Random Tile",
			"Target Surrounding Tiles",
			"Target With Targeting Computer",
			"Target Tile With Offset",
			"Target Effect Source",
			"Target Self",
		],
		EffectEnums.Category.ATTRIBUTE_CHANGE: [
			"Damage",
			"Heal",
			"Shield",
			"Change Engine Charge",
		],
		EffectEnums.Category.AMOUNT_MODIFIER: [
			"Multiply",
			"Add Adjacent Tiles",
			"Add Tile Data",
			"Negate",
			"Set to Engine Charge",
		],
		EffectEnums.Category.DICE_CONTROL: [
			"Change Activator Value",
			"Reroll Activator",
			"Reroll All",
			"Flip Ones and Sixes",
			"Give Die to Player",
			"Give Die to Target",
			"Give Die Away",
			"Keep Die with Tile",
			"Spawn Holographic Die",
			"Receive Die from Target",
		],
		EffectEnums.Category.AUDIO_VISUAL: [
			"Spawn Hit Particles",
			"Spawn Explosion Particles",
			"Animate Die to Tile",
			"Attack Tween",
			"Shake Dice",
			"Play Sound",
			"Wait",
		],
		EffectEnums.Category.TILE_CONTROL: [
			"Activate Self",
			"Activate Targeted Tiles",
			"Move Tile with Offset",
			"Push Tile in Direction",
			"Pull Row Tiles to Column",
			"Add Amplifier Status",
			"Lockout Tile",
			"Add Uses Remaining",
			"Increment Tile Data",
			"Set Tile Data",
		],
		EffectEnums.Category.SCENARIO_CONTROL: [
			"Open Shop",
			"Close Shop",
			"Jump",
			"Flee",
			"Move Ship",
		],
		EffectEnums.Category.CONDITIONAL: [
			"If Activator Odd",
			"If Enemy Targeted",
			"If Engine Charged",
			"If Die Value in Range",
		],
		EffectEnums.Category.REPETITION: [
			"Add Repetitions",
		],
		EffectEnums.Category.UTILITY: [
			"Destroy Source",
			"Print Debug",
		],
	}

	func _init() -> void:
		_dropdown = OptionButton.new()
		_dropdown.clip_text = true
		_dropdown.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		add_child(_dropdown)
		add_focusable(_dropdown)
		_dropdown.item_selected.connect(_on_item_selected)

	func _update_property() -> void:
		_updating = true
		var obj     := get_edited_object()
		var cat     := int(obj.get("category"))
		var cur_sub := int(obj.get("subtype"))

		_dropdown.clear()
		var names: Array = SUBTYPE_NAMES.get(cat, [])
		for i: int in names.size():
			_dropdown.add_item(names[i], i)

		if _dropdown.item_count > 0:
			_dropdown.select(clampi(cur_sub, 0, _dropdown.item_count - 1))

		_updating = false

	func _on_item_selected(index: int) -> void:
		if _updating:
			return
		emit_changed("subtype", index)
