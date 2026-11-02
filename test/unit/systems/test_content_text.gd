extends "res://test/helpers/die_fighter_test.gd"
## ContentText: content shows its own English field in English, its
## content.csv translation in other languages, and the English again where a
## language has no translation yet.

const SOLAR_FLARE: String = "res://Source/Resources/BackgroundResources/BackgroundHazards/solar_flare.tres"
const FATES_TITHE: String = "res://Source/Resources/BackgroundResources/BackgroundModifiers/fates_tithe.tres"


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
