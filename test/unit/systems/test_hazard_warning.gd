extends "res://test/helpers/die_fighter_test.gd"
## HazardWarning: the hazard's name slammed up as it builds, with the effect in
## plain words under it, and the effect outlasting the name once it strikes.

var hazard: BackgroundHazardResource


func before_each() -> void:
	super()
	hazard = BackgroundHazardResource.new()
	hazard.hazard_name = "Solar Flare"
	hazard.banner = "SHIELDS DOWN! 3 DAMAGE TO ALL"


## The one just shown: added last, behind any another test left waiting for
## a strike.
func _show() -> HazardWarning:
	HazardWarning.show_for(self, hazard, 1.0)
	var children: Array[Node] = get_tree().root.get_children()
	children.reverse()
	for child: Node in children:
		if child is HazardWarning:
			return autofree(child)
	return null


func test_it_names_the_hazard_and_its_effect() -> void:
	var warning: HazardWarning = _show()
	assert_not_null(warning)
	assert_string_contains(warning._label.text, "SOLAR FLARE")
	assert_eq(warning._effect_label.text, "SHIELDS DOWN! 3 DAMAGE TO ALL")


func test_a_hazard_without_a_banner_shows_just_its_name() -> void:
	hazard.banner = ""
	var warning: HazardWarning = _show()
	assert_null(warning._effect_label)


func test_the_effect_outlasts_the_name_at_the_strike() -> void:
	var warning: HazardWarning = _show()
	# The strike comes once the build-up's warning beats are done.
	await wait_seconds(1.1)
	Events.hazard_struck.emit(hazard)
	await wait_seconds(0.8)
	assert_true(is_instance_valid(warning))
	assert_lt(warning._label.modulate.a, 0.1, "the name has burst away")
	assert_gt(warning._effect_label.modulate.a, 0.9, "the effect is still up to be read")
	await wait_seconds(HazardWarning._EFFECT_LINGER_SECONDS)
	assert_false(is_instance_valid(warning), "gone once the effect has been read")
