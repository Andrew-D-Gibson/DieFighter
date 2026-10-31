class_name ShipSelectPopup
extends Node2D

## Picks the ship for a new run, between Play on the main menu and the opening
## cutscene. One card per ship in ShipCatalog; Launch flies the picked one.
## A coming-soon ship gets a greyed-out card that clicks, arrow keys and
## Launch all pass over.
##
## Once the tutorial has been played, Replay Tutorial sits in the top-left
## corner, out of the way of Launch and Back, and flies the ship it teaches on
## into the tutorial run. Before then Play skips this popup altogether (see
## MainMenu).

signal launched(ship: ShipResource)
## Replay Tutorial was pressed: fly [param ship] into the tutorial run.
signal tutorial_launched(ship: ShipResource)
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
	%ReplayTutorialButton.pressed_within_window.connect(_on_replay_tutorial)


## Lays out a card per ship and shows the popup, with the last ship flown
## this session already picked, unless that one is coming soon (an AutoPilot
## gauntlet can fly one): then the first ship that can be picked.
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
		card.play_entrance(0.05 * i)
		_cards.append(card)

	var remembered: ShipResource = Globals.current_ship()
	var first: ShipCard = null
	for card: ShipCard in _cards:
		if card.locked:
			continue
		if card.ship == remembered:
			first = card
			break
		if not first:
			first = card
	if first:
		_pick(first)
	%ReplayTutorialButton.visible = tutorial_card() != null
	show()


## The tutorial's ship, if it's on the row and the tutorial has been played.
func tutorial_card() -> ShipCard:
	if not Globals.tutorial_completed:
		return null
	for card: ShipCard in _cards:
		if card.ship.supports_tutorial:
			return card
	return null


func _on_replay_tutorial() -> void:
	var card: ShipCard = tutorial_card()
	if not card:
		return
	hide()
	tutorial_launched.emit(card.ship)


func _pick(card: ShipCard) -> void:
	if not card or card.locked:
		return
	_picked = card
	for other: ShipCard in _cards:
		other.is_picked = other == card


func _on_launch() -> void:
	if not _picked or _picked.locked:
		return
	hide()
	launched.emit(_picked.ship)


## The nearest card [param step] ways from the picked one that can be picked,
## wrapping round the row; the picked one itself if no other can be.
func _next_pickable(step: int) -> ShipCard:
	var index: int = _cards.find(_picked)
	for i: int in _cards.size():
		index = wrapi(index + step, 0, _cards.size())
		if not _cards[index].locked:
			return _cards[index]
	return _picked


func _on_back() -> void:
	hide()
	cancelled.emit()


func _unhandled_input(event: InputEvent) -> void:
	if not visible or _cards.is_empty():
		return
	if event.is_action_pressed(&"ui_left") or event.is_action_pressed(&"ui_right"):
		var step: int = -1 if event.is_action_pressed(&"ui_left") else 1
		_pick(_next_pickable(step))
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed(&"ui_accept"):
		_on_launch()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed(&"ui_cancel"):
		_on_back()
		get_viewport().set_input_as_handled()
