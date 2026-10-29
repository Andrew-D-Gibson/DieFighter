extends "res://test/helpers/die_fighter_test.gd"
## The error pop-up sizes itself to its message, so long refusals wrap inside
## the box instead of spilling out of it.

const POPUP_SCENE: PackedScene = preload("res://Source/Systems/UI/ErrorPopupManager/ErrorTextPopup/error_text_popup.tscn")


func _show(message: String) -> ErrorTextPopup:
	var popup: ErrorTextPopup = add_child_autofree(POPUP_SCENE.instantiate())
	popup.set_message(message)
	return popup


## Every line fits across the box and every line fits down it.
func _assert_fits(popup: ErrorTextPopup, message: String) -> void:
	await wait_process_frames(2)
	assert_lte(popup.get_content_width(), int(popup.size.x), "%s: fits across" % message)
	assert_lte(popup.get_content_height(), int(popup.size.y), "%s: fits down" % message)
	assert_lte(popup.size.x, popup.max_width, "%s: no wider than the cap" % message)


func test_a_short_message_stays_on_one_line_in_the_usual_box() -> void:
	var popup: ErrorTextPopup = _show("TILE LOCKED")
	await _assert_fits(popup, "TILE LOCKED")
	assert_eq(popup.get_line_count(), 1)
	assert_eq(popup.size, popup.custom_minimum_size)


func test_not_enough_engine_charge_wraps_inside_the_box() -> void:
	var popup: ErrorTextPopup = _show("NOT ENOUGH ENGINE CHARGE")
	await _assert_fits(popup, "NOT ENOUGH ENGINE CHARGE")
	assert_eq(popup.get_line_count(), 2)


func test_every_refusal_fits() -> void:
	var activation: ActivationResource = ActivationResource.new()
	for key: String in activation.failed_activation_messages.values():
		var message: String = TranslationServer.translate(key)
		assert_ne(message, key, "%s has English text" % key)
		var popup: ErrorTextPopup = _show(message)
		await _assert_fits(popup, message)
		popup.queue_free()
