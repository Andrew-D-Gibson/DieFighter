class_name ChoiceScenarioResource
extends ScenarioResourceBase

@export var text: String
@export var choices: Dictionary[ChoiceResource, ScenarioResource]

func play() -> void:
	assert(len(choices) == 6)
	Events.show_choice_dialogue.emit(text, choices.keys())
	var choice: int = await Events.choice_made
	
	var scenario = choices[choices.keys()[choice]]
	scenario.play()
