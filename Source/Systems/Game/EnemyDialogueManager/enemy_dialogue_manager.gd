class_name EnemyDialogueManager
extends Node2D

@export var character_reveal_time: float = 0.02

var current_dialogue: String
var reveal_tween: Tween

var red_dialogue_box: Texture2D = preload("uid://dt1r6m0xqqoe7")
var green_dialogue_box: Texture2D = preload("uid://csw1kfx56jn5i")
var yellow_dialogue_box: Texture2D = preload("uid://dttgyiiq0jp7y")

var faction_textures: Dictionary[ScenarioManager.Faction, Texture2D] = {
	ScenarioManager.Faction.CIVILIAN: green_dialogue_box,
	ScenarioManager.Faction.PIRATE: red_dialogue_box,
	ScenarioManager.Faction.BOSS: red_dialogue_box,
}


func show_dialogue(dialogue: String, faction: ScenarioManager.Faction = ScenarioManager.Faction.PIRATE) -> void:
	# Reset if we just showed another dialogue
	if reveal_tween:
		reveal_tween.kill()
	%RichTextLabel.text = ""
	
	if dialogue == "":
		hide()
		return
		
	_start_fade_in()
	%Sprite2D.texture = faction_textures[faction]
	current_dialogue = dialogue
		
	reveal_tween = get_tree().create_tween()
	reveal_tween.tween_method(
		_show_characters, 
		0, 
		len(current_dialogue), 
		character_reveal_time * len(current_dialogue)
	).set_trans(Tween.TRANS_LINEAR)
	
	
func _start_fade_in() -> void:
	show()
	
	var fade_in_time: float = 1
	var fade_in_tween: Tween = get_tree().create_tween()
	fade_in_tween.tween_property(
		self,
		"modulate:a",
		1,
		fade_in_time
	).from(0)\
	.set_trans(Tween.TRANS_LINEAR)\
	.set_ease(Tween.EASE_IN_OUT)
	
	
func _show_characters(num: int) -> void:
	_set_text(current_dialogue.substr(0, num))


func _set_text(text: String) -> void:
	%RichTextLabel.text = \
		"[wave amp=2.0 freq=2.0 connected=0]" + \
		text + \
		"[/wave]"
