class_name HazardIndicator
extends RichTextLabel
## Shows the current scenario's hazard and how many turns until it fires.
##
## This label is the hazard's entire justification. A solar flare that wipes the
## board without warning is a dice roll; one you watched count down for two
## turns while you decided whether to spend on shields is a decision. Hidden
## whenever the scenario has no hazard.

## How long the label stays in its "it just went off" state.
const _TRIGGER_FLASH_SECONDS: float = 1.2

## Countdown value at or below which the label starts reading as urgent.
const _URGENT_AT: int = 1


func _ready() -> void:
	Events.hazard_armed.connect(_on_countdown)
	Events.hazard_countdown_changed.connect(_on_countdown)
	Events.hazard_triggered.connect(_on_triggered)
	hide()


func _on_countdown(hazard: ScenarioHazardResource, turns_remaining: int) -> void:
	if hazard == null:
		hide()
		return

	show()
	var tint: Color = hazard.color if turns_remaining > _URGENT_AT else Globals.red
	var turn_word: String = "TURN" if turns_remaining == 1 else "TURNS"
	text = "[center][color=%s]%s  IN %d %s[/color][/center]" % [
		tint.to_html(false), hazard.hazard_name.to_upper(), turns_remaining, turn_word
	]


func _on_triggered(hazard: ScenarioHazardResource) -> void:
	if hazard == null:
		return

	show()
	text = "[center][color=%s][shake rate=22.0 level=14 connected=1]%s[/shake][/color][/center]" % [
		hazard.color.to_html(false), hazard.hazard_name.to_upper()
	]

	# The countdown signal for the reset lands in the same frame, so hold the
	# banner briefly before letting it be overwritten.
	await get_tree().create_timer(_TRIGGER_FLASH_SECONDS).timeout
	if Globals.hazard_manager and Globals.hazard_manager.has_hazard():
		_on_countdown(Globals.hazard_manager.current_hazard,
			Globals.hazard_manager.turns_remaining)
