extends "res://test/helpers/die_fighter_test.gd"
## ContentText: content shows its own English field in English, its
## content.csv translation in other languages, and the English again where a
## language has no translation yet.

const SOLAR_FLARE: String = "res://Source/Resources/BackgroundResources/BackgroundHazards/solar_flare.tres"
const FATES_TITHE: String = "res://Source/Resources/BackgroundResources/BackgroundModifiers/fates_tithe.tres"
const SEIZE: String = "res://Source/Content/Enemies/EnemyActions/EnemyActionResources/seize.tres"
const DO_NOTHING: String = "res://Source/Content/Enemies/EnemyActions/EnemyActionResources/do_nothing.tres"
const CONVOY_HAULER_BETRAYED: String = "res://Source/Content/ScenarioResources/Scenarios/EVENT_Convoy/hauler_betrayed.tres"
const SEIZE_CALLOUT_KEY: String = "ENEMY_ACTION.SEIZE.EFFECT_CHAIN.EFFECTS_5.CALLOUT"
const RENAMED_DIR: String = "user://test_content_text"


func after_each() -> void:
	ContentText.clear_cache()
	super()


func test_english_reads_the_field_itself() -> void:
	var hazard: BackgroundHazardResource = load(SOLAR_FLARE)
	assert_eq(ContentText.key_for(hazard, &"headline"), "HAZARD.SOLAR_FLARE.HEADLINE")
	assert_eq(hazard.display_headline(), hazard.headline)


func test_a_translated_locale_reads_its_column_and_falls_back_to_the_field() -> void:
	var hazard: BackgroundHazardResource = load(SOLAR_FLARE)
	var german: Translation = Translation.new()
	german.locale = "de"
	german.add_message(&"HAZARD.SOLAR_FLARE.NAME", &"Sonneneruption")
	ContentText._translations["de"] = german
	var previous: String = TranslationServer.get_locale()
	TranslationServer.set_locale("de")
	var name_text: String = hazard.display_name()
	var banner_text: String = hazard.display_banner()
	TranslationServer.set_locale(previous)
	assert_eq(name_text, "Sonneneruption")
	assert_eq(banner_text, hazard.banner, "untranslated: the English")


func test_a_resource_built_in_code_has_no_key_and_shows_its_field() -> void:
	var hazard: BackgroundHazardResource = BackgroundHazardResource.new()
	hazard.hazard_name = "Test Flare"
	assert_eq(ContentText.key_for(hazard, &"hazard_name"), "")
	assert_eq(hazard.display_name(), "Test Flare")


func test_keys_name_the_file_and_field() -> void:
	var rule: BackgroundModifierResource = load(FATES_TITHE)
	assert_eq(ContentText.key_for(rule, &"modifier_name"), "BG_MODIFIER.FATES_TITHE.NAME")
	assert_eq(ContentText.key_for(rule, &"color"), "", "not a text field")


func test_pseudo_stretches_the_live_field() -> void:
	var hazard: BackgroundHazardResource = BackgroundHazardResource.new()
	hazard.banner = "SHIELDS DOWN!"
	var previous: String = TranslationServer.get_locale()
	TranslationServer.set_locale(Localization.PSEUDO_LOCALE)
	var banner_text: String = hazard.display_banner()
	TranslationServer.set_locale(previous)
	assert_eq(banner_text, "«SHIIEELDS DOOWN!»")


func test_a_region_rule_reads_its_own_fields_in_english() -> void:
	var rule: BackgroundModifierResource = load(FATES_TITHE)
	assert_eq(rule.display_name(), "Fate's Tithe")
	assert_eq(rule.display_description(), rule.description)


# ── Embedded text, copies and the content types converted after the pilot ────

## Runs [param read] with the game in German, [param german] standing in for
## content.de.translation.
func _in_german(german: Dictionary, read: Callable) -> Variant:
	var translation: Translation = Translation.new()
	translation.locale = "de"
	for key: String in german:
		translation.add_message(StringName(key), StringName(german[key]))
	ContentText._translations["de"] = translation
	var previous: String = TranslationServer.get_locale()
	TranslationServer.set_locale("de")
	var result: Variant = read.call()
	TranslationServer.set_locale(previous)
	return result


func _callout_of(action: EnemyActionResource) -> EffectData:
	for data: EffectData in action.effect_chain.effects:
		if data.subtype == EffectEnums.AudioVisualSubtype.CALLOUT and data.category == EffectEnums.Category.AUDIO_VISUAL:
			return data
	return null


func test_an_embedded_callout_is_keyed_by_its_place_in_the_file() -> void:
	var seize: EnemyActionResource = load(SEIZE)
	assert_eq(ContentText.key_for(_callout_of(seize), &"callout"), SEIZE_CALLOUT_KEY)
	assert_eq(ContentText.key_for(seize, &"name"), "ENEMY_ACTION.SEIZE.NAME")


## Godot may renumber sub-resource ids when it re-saves a file; the key must
## not notice.
func test_renumbered_sub_resource_ids_keep_the_same_keys() -> void:
	var text: String = FileAccess.get_file_as_string(SEIZE)
	var ids: RegEx = RegEx.create_from_string(r'\[sub_resource type="Resource" id="([^"]+)"\]')
	var renamed: int = 0
	for found: RegExMatch in ids.search_all(text):
		var id: String = found.get_string(1)
		text = text.replace('"%s"' % id, '"Renumbered_%d"' % renamed)
		renamed += 1
	assert_gt(renamed, 3)
	# No uid: two files claiming one uid would confuse the loader.
	var header_uid: RegEx = RegEx.create_from_string(r' uid="uid://[a-z0-9]+"\]')
	text = header_uid.sub(text, "]")
	DirAccess.make_dir_recursive_absolute(RENAMED_DIR)
	var copy_path: String = RENAMED_DIR.path_join("seize.tres")
	var file: FileAccess = FileAccess.open(copy_path, FileAccess.WRITE)
	file.store_string(text)
	file.close()

	var copy: EnemyActionResource = load(copy_path)
	assert_true(_callout_of(copy).resource_path.contains("Renumbered_"))
	assert_eq(ContentText.key_for(_callout_of(copy), &"callout"), SEIZE_CALLOUT_KEY)
	DirAccess.remove_absolute(copy_path)


## Rolled actions are deep copies, which lose the file path keys are made
## from; copy() keeps them, for the action and every callout in its chain.
func test_a_copied_action_and_its_callouts_still_translate() -> void:
	var seize: EnemyActionResource = load(SEIZE)
	var rolled: EnemyActionResource = seize.copy()
	assert_eq(rolled.resource_path, "")
	var texts: Array = _in_german({"ENEMY_ACTION.SEIZE.NAME": "Kapern", SEIZE_CALLOUT_KEY: "GESTOHLEN"},
		func() -> Array: return [rolled.display_name(), _callout_of(rolled).display_callout(), rolled.copy().display_name()])
	assert_eq(texts, ["Kapern", "GESTOHLEN", "Kapern"], "a copy of a copy too")


func test_an_option_rolls_an_action_that_translates() -> void:
	var option: EnemyActionOptionResource = EnemyActionOptionResource.new()
	option.base_action = load(SEIZE)
	var rolled: EnemyActionResource = option.get_action()
	assert_eq(ContentText.key_for(rolled, &"description"), "ENEMY_ACTION.SEIZE.DESC")


func test_english_callouts_and_info_read_as_before() -> void:
	var seize: EnemyActionResource = (load(SEIZE) as EnemyActionResource).copy()
	assert_eq(_callout_of(seize).display_callout(), "STOLEN")
	seize.activating_die_number = 3
	var shown: Array[InfoResource] = []
	var grab: Callable = func(info: InfoResource) -> void: shown.append(info)
	Events.show_info.connect(grab)
	seize.show_info()
	Events.show_info.disconnect(grab)
	assert_eq(shown.size(), 1)
	assert_eq(shown[0].title_label_text, "Seize")
	assert_eq(shown[0].bottom_label_text, "[color=yellow]Uses (die_3) -> %s[/color]" % seize.description)


func test_a_silenced_slot_keeps_the_name_and_says_it_was_silenced() -> void:
	var seize: EnemyActionResource = (load(SEIZE) as EnemyActionResource).copy()
	var silenced: EnemyActionResource = (load(DO_NOTHING) as EnemyActionResource).copy()
	silenced.silenced_action = seize
	silenced.name = seize.name
	assert_eq(silenced.display_name(), "Seize")
	assert_eq(silenced.get_description_text(), "Silenced: does nothing this turn")
	var german_name: String = _in_german({"ENEMY_ACTION.SEIZE.NAME": "Kapern"}, silenced.display_name)
	assert_eq(german_name, "Kapern", "the cancelled action's name, not Do Nothing's")


func test_ship_states_name_their_folder() -> void:
	var state: ScenarioShipState = load(CONVOY_HAULER_BETRAYED)
	assert_eq(ContentText.key_for(state, &"dialogue"), "SHIP_STATE.EVENT_CONVOY.HAULER_BETRAYED.DIALOGUE")
	assert_eq(state.display_dialogue(), state.dialogue)
