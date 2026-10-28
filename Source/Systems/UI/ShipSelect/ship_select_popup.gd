class_name ShipSelectPopup
extends Node2D

## Picks the ship for a new run, between Play on the main menu and the opening
## cutscene. One card per ship in ShipCatalog; Launch flies the picked one.

signal launched(ship: ShipResource)
signal cancelled()

const _MEDIUM_BUTTON: PackedScene = preload("res://Source/Systems/UI/Buttons/medium_button.tscn")
const _CARD_GAP: float = 5.0
const _CARD_TOP: float = -66.0

var _cards: Array[ShipCard] = []
var _picked: ShipCard


func _ready() -> void:
	hide()
	%LaunchButton.pressed_within_window.connect(_on_launch)
	%BackButton.pressed_within_window.connect(_on_back)


## Lays out a card per ship and shows the popup, with the last ship flown
## this session already picked.
func open() -> void:
	for card: ShipCard in _cards:
		card.queue_free()
	_cards.clear()

	var ships: Array[ShipResource] = ShipCatalog.all()
	var row_width: float = ships.size() * ShipCard.SIZE.x + (ships.size() - 1) * _CARD_GAP
	for i: int in ships.size():
		var card: ShipCard = ShipCard.new()
		%Cards.add_child(card)
		card.setup(ships[i])
		card.position = Vector2(
			-row_width / 2.0 + i * (ShipCard.SIZE.x + _CARD_GAP), _CARD_TOP
		).floor()
		card.picked.connect(_pick)
		_cards.append(card)

	var remembered: ShipResource = Globals.current_ship()
	var first: ShipCard = _cards[0] if not _cards.is_empty() else null
	for card: ShipCard in _cards:
		if card.ship == remembered:
			first = card
	if first:
		_pick(first)
	show()


func _pick(card: ShipCard) -> void:
	_picked = card
	for other: ShipCard in _cards:
		other.is_picked = other == card


func _on_launch() -> void:
	if not _picked:
		return
	hide()
	launched.emit(_picked.ship)


func _on_back() -> void:
	hide()
	cancelled.emit()


func _unhandled_input(event: InputEvent) -> void:
	if not visible or _cards.is_empty():
		return
	if event.is_action_pressed(&"ui_left") or event.is_action_pressed(&"ui_right"):
		var step: int = -1 if event.is_action_pressed(&"ui_left") else 1
		var index: int = wrapi(_cards.find(_picked) + step, 0, _cards.size())
		_pick(_cards[index])
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed(&"ui_accept"):
		_on_launch()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed(&"ui_cancel"):
		_on_back()
		get_viewport().set_input_as_handled()
