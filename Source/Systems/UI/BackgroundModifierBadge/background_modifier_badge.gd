class_name BackgroundModifierBadge
extends Control
## Announces the permanent rule of the background the player just arrived in.
##
## Backgrounds are drawn from a random pool, so the player does not pick their
## rule — which means the rule has to announce itself, or "shields do nothing
## here" reads as a bug rather than as the terrain. A banner that covered the
## board and then left took the choice of when to read it away from the player,
## so instead the rule parks itself as a badge in clear sky and flashes until
## it has been read. Hidden entirely in plain space, so the badge appearing at
## all is itself information.
##
## Clicking it opens the ordinary InfoShower panel, the same one tiles and
## enemy intents use, so the rule is presented in the vocabulary the player
## already reads everything else in. Clicking the panel away leaves the badge
## behind, steady, as a reminder the rule is still in force.

## Used when a modifier ships no art of its own. A circled "?" is honest about
## what the badge is for: something governs this place, click to find out what.
const _DEFAULT_ICON: Texture2D = preload(
	"res://Assets/Textures/Map/EncounterIcons/unknown_encounter.png"
)

## How far the unread badge dims and swells on each pulse.
const _FLASH_MIN_ALPHA: float = 0.35
const _FLASH_SCALE: float = 1.15

## One full dim-and-brighten cycle, in seconds.
@export var flash_period: float = 1.1

@onready var _badge: TextureButton = %Badge

## The rule on screen right now, or null in plain space.
var _modifier: BackgroundModifierResource = null

var _flash_tween: Tween


func _ready() -> void:
	_badge.hide()
	_badge.pressed.connect(_on_badge_pressed)
	Events.background_modifier_applied.connect(_on_modifier_applied)


func _on_modifier_applied(modifier: BackgroundModifierResource) -> void:
	_modifier = modifier
	_stop_flashing()

	if modifier == null:
		_badge.hide()
		return

	# Deliberately untinted: modulate multiplies, so pushing the rule's colour
	# through art that has colours of its own just muddies both. The colour
	# does its work on the info panel's title, where it sits on white.
	_badge.texture_normal = modifier.icon if modifier.icon else _DEFAULT_ICON
	_badge.show()

	# Every arrival is a fresh rule to read, even when the region repeats one
	# the player has seen before, so the badge always starts unread.
	_start_flashing()


## Hands the rule to the shared info panel, which zooms the badge art up to the
## middle of the screen and dims everything behind it.
func _on_badge_pressed() -> void:
	if _modifier == null:
		return

	_stop_flashing()

	var info: InfoResource = InfoResource.new()
	info.title_label_text = "[color=%s]%s[/color]" % [
		_modifier.color.to_html(false), _modifier.modifier_name.to_upper()
	]
	info.bottom_label_text = _modifier.description
	info.texture = _badge.texture_normal
	Events.show_info.emit(info)


func _start_flashing() -> void:
	_flash_tween = create_tween().set_loops()
	_flash_tween.set_parallel()
	_flash_tween.tween_property(_badge, "modulate:a", _FLASH_MIN_ALPHA, flash_period * 0.5) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_flash_tween.tween_property(
		_badge, "scale", Vector2.ONE * _FLASH_SCALE, flash_period * 0.5
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	# chain() closes the parallel group, so the way back runs after the way out
	# rather than fighting it.
	_flash_tween.chain().tween_property(_badge, "modulate:a", 1.0, flash_period * 0.5) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_flash_tween.set_parallel()
	_flash_tween.tween_property(_badge, "scale", Vector2.ONE, flash_period * 0.5) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


## Leaves the badge solid and still: read, but still in force.
func _stop_flashing() -> void:
	if _flash_tween:
		_flash_tween.kill()
		_flash_tween = null
	_badge.modulate.a = 1.0
	_badge.scale = Vector2.ONE
