class_name AttitudeDisplay
extends Node2D
## How the targeted ship feels about the player, shown on the targeting
## computer: a tiny face beside the target's portrait, and the screen's bezel
## and portrait frame tinted to match (red hostile, grey neutral, green
## friendly). With nothing targeted the tints come off and the computer shows
## its own purple.
##
## Above the face sits the ship's faction badge (EnemyResource.faction), so the
## player reads who a ship is and how it feels about them in one place. A ship
## with no faction shows no badge.
##
## This used to be a face hung off every ship's health bar. On the computer it
## reads once, for the ship the player is about to give a die to, which is
## the only one whose mood changes what a die does.

## Bezel (the screen's outline) and portrait frame shades per attitude: the
## light and middle steps of each palette ramp, as the purple art they cover
## uses the light and dark steps of its own.
const _BEZEL_COLOURS: Dictionary[Enemy.Attitude, Color] = {
	Enemy.Attitude.FRIENDLY: Color("7abd33"),
	Enemy.Attitude.NEUTRAL: Color("c4c1bc"),
	Enemy.Attitude.AGGRESSIVE: Color("d03656"),
}
const _FRAME_COLOURS: Dictionary[Enemy.Attitude, Color] = {
	Enemy.Attitude.FRIENDLY: Color("659c2a"),
	Enemy.Attitude.NEUTRAL: Color("8e8b85"),
	Enemy.Attitude.AGGRESSIVE: Color("90263c"),
}

## A change of heart on the ship already targeted blinks the face and tints,
## so a civilian turning hostile mid-fight isn't missed.
const _BLINKS: int = 3
const _BLINK_SECONDS: float = 0.08

## The ship shown, and the attitude it was showing, so a redraw for the same
## ship in the same mood doesn't blink.
var _shown_ship: Enemy
var _shown_attitude: Enemy.Attitude = Enemy.Attitude.AGGRESSIVE
var _blink_tween: Tween


func _ready() -> void:
	clear()


## Shows [param ship]'s attitude, or clears the display for no ship.
func show_ship(ship: Enemy) -> void:
	if not is_instance_valid(ship):
		clear()
		return
	var attitude: Enemy.Attitude = attitude_of(ship)
	var changed_mood: bool = ship == _shown_ship and attitude != _shown_attitude
	_shown_ship = ship
	_shown_attitude = attitude

	%FactionIcon.texture = faction_icon(ship)
	%BezelTint.modulate = bezel_colour(attitude)
	%ImageFrameTint.modulate = frame_colour(attitude)
	%Face.frame = face_frame(attitude)
	visible = true
	if changed_mood:
		_blink()


func clear() -> void:
	_shown_ship = null
	%FactionIcon.texture = null
	if _blink_tween:
		_blink_tween.kill()
	_blink_tween = null
	_set_lit(true)
	visible = false


## A ship with no scenario state (test fixtures, a bare spawn) has no reason
## to be friendly, so it reads as hostile, as the fight would treat it.
static func attitude_of(ship: Enemy) -> Enemy.Attitude:
	if ship.scenario_state == null:
		return Enemy.Attitude.AGGRESSIVE
	return ship.scenario_state.attitude


static func faction_icon(ship: Enemy) -> Texture2D:
	if ship.enemy_resource == null or ship.enemy_resource.faction == null:
		return null
	return ship.enemy_resource.faction.icon


static func bezel_colour(attitude: Enemy.Attitude) -> Color:
	return _BEZEL_COLOURS[attitude]


static func frame_colour(attitude: Enemy.Attitude) -> Color:
	return _FRAME_COLOURS[attitude]


## The face sheet holds one glyph per attitude, in the enum's order.
static func face_frame(attitude: Enemy.Attitude) -> int:
	return int(attitude)


func _blink() -> void:
	if _blink_tween:
		_blink_tween.kill()
	_blink_tween = create_tween()
	for i: int in range(_BLINKS):
		_blink_tween.tween_callback(_set_lit.bind(false))
		_blink_tween.tween_interval(_BLINK_SECONDS)
		_blink_tween.tween_callback(_set_lit.bind(true))
		_blink_tween.tween_interval(_BLINK_SECONDS)


## Hides the face and tints without dropping the display, so the purple art
## underneath flashes through between blinks.
func _set_lit(lit: bool) -> void:
	for part: CanvasItem in [%BezelTint, %ImageFrameTint, %Face]:
		part.visible = lit
