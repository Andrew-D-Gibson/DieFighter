class_name OverloadGauge
extends Node2D
## How close a ship with a breaker is to overloading: the dice it holds,
## against what it takes to trip it. Fills yellow to orange as the player hands
## it dice, and flashes red once its next turn will be an overload.
##
## Polls rather than listening: board-wide effects (REROLL_ALL, a flip) change
## the faces of dice already in a ship's hand without the ship hearing of it.

const _BAR_WIDTH: int = 24
const _BAR_HEIGHT: int = 3
const _OUTLINE: Color = Color("#040217")
const _EMPTY: Color = Color("#262523")
const _FLASH_TIME: float = 0.25

@export var label: Label

var enemy: Enemy

var _shown_heat: int = -1
var _shown_threshold: int = -1
var _flash_on: bool = false
var _flash_clock: float = 0.0


func _process(delta: float) -> void:
	if not is_instance_valid(enemy):
		return
	var heat: int = enemy.held_heat()
	var threshold: int = enemy.overload_threshold
	if heat != _shown_heat or threshold != _shown_threshold:
		if heat > _shown_heat and _shown_heat >= 0:
			Juice.bump(self, 0.3, 0.2)
		_shown_heat = heat
		_shown_threshold = threshold
		label.text = "%d/%d" % [heat, threshold]
		_update_label_color()
		queue_redraw()

	if enemy.is_overloaded():
		_flash_clock += delta
		if _flash_clock >= _FLASH_TIME:
			_flash_clock = 0.0
			_flash_on = not _flash_on
			_update_label_color()
			queue_redraw()
	elif _flash_on:
		_flash_on = false
		_update_label_color()
		queue_redraw()


func _draw() -> void:
	var left: float = -_BAR_WIDTH / 2.0
	draw_rect(Rect2(left - 1, -1, _BAR_WIDTH + 2, _BAR_HEIGHT + 2), _OUTLINE)
	draw_rect(Rect2(left, 0, _BAR_WIDTH, _BAR_HEIGHT), _EMPTY)
	if _shown_threshold <= 0:
		return
	var fraction: float = _fraction()
	var fill: int = roundi(_BAR_WIDTH * fraction)
	if fill > 0:
		draw_rect(Rect2(left, 0, fill, _BAR_HEIGHT), _fill_color(fraction))


func _update_label_color() -> void:
	var fraction: float = _fraction()
	label.add_theme_color_override("font_color", _fill_color(fraction) if fraction > 0 else Globals.white)


func _fraction() -> float:
	if _shown_threshold <= 0:
		return 0.0
	return clampf(float(_shown_heat) / float(_shown_threshold), 0.0, 1.0)


func _fill_color(fraction: float) -> Color:
	if fraction >= 1.0:
		return Globals.white if _flash_on else Globals.red
	return Globals.orange if fraction >= 0.6 else Globals.yellow
