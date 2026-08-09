class_name EnemyDialogueManager
extends Node2D

const _TEXT_BLIP_SFX: SoundEffectResource = preload("res://Source/Resources/SoundEffectResources/SoundEffects/text_blip.tres")

@export var character_reveal_time: float = 0.08

var current_dialogue: String
var character_reveal_tween: Tween
var fade_tween: Tween
var fade_time: float = 1

var red_dialogue_box: Texture2D = preload("uid://dt1r6m0xqqoe7")
var green_dialogue_box: Texture2D = preload("uid://csw1kfx56jn5i")
var yellow_dialogue_box: Texture2D = preload("uid://dttgyiiq0jp7y")

var faction_textures: Dictionary[ScenarioManager.Faction, Texture2D] = {
	ScenarioManager.Faction.CIVILIAN: green_dialogue_box,
	ScenarioManager.Faction.PIRATE: red_dialogue_box,
	ScenarioManager.Faction.BOSS: red_dialogue_box,
}

static var time_last_dialogue_was_shown: int
@export var time_between_dialogues: float = 3

var fadeout_timer: Timer
@export var dialogue_time_shown: float = 4


func _ready() -> void:
	fadeout_timer = Timer.new()
	fadeout_timer.one_shot = true
	fadeout_timer.timeout.connect(hide_dialogue)
	add_child(fadeout_timer)
	

func show_dialogue(dialogue: String, faction: ScenarioManager.Faction = ScenarioManager.Faction.PIRATE) -> void:
	# Check if we just showed a dialogue, and if so, just wait
	var current_time: int = Time.get_ticks_msec()
	if time_last_dialogue_was_shown and \
	current_time < time_last_dialogue_was_shown + (time_between_dialogues * 1000):
		var time_remaining: int = (time_last_dialogue_was_shown + (time_between_dialogues * 1000)) - current_time
		await get_tree().create_timer(float(time_remaining) / 1000).timeout
	
	# Reset if we this was just called for another line of dialogue
	if character_reveal_tween:
		character_reveal_tween.kill()
	%RichTextLabel.visible_characters = 0
	%RichTextLabel.text = dialogue
	
	if dialogue == "":
		hide_dialogue()
		return

	# Record the time this dialogue was shown
	time_last_dialogue_was_shown = Time.get_ticks_msec()

	_start_fade_in()
	%Sprite2D.texture = faction_textures[faction]
		
	character_reveal_tween = get_tree().create_tween()
	character_reveal_tween.tween_method(
		_show_characters, 
		0, 
		len(dialogue), 
		character_reveal_time * len(dialogue)
	).set_trans(Tween.TRANS_LINEAR)
	
	await character_reveal_tween.finished
	
	
	
	fadeout_timer.start(dialogue_time_shown)
	
	
func hide_dialogue() -> void:
	if fade_tween:
		fade_tween.kill()

	fade_tween = get_tree().create_tween()
	fade_tween.tween_property(
		self,
		"modulate:a",
		0,
		fade_time
	).from_current()\
	.set_trans(Tween.TRANS_LINEAR)\
	.set_ease(Tween.EASE_IN_OUT)
	
	await fade_tween.finished
	hide()
	
	
func _start_fade_in() -> void:
	if fade_tween:
		fade_tween.kill()
	show()
	
	fade_tween = get_tree().create_tween()
	fade_tween.tween_property(
		self,
		"modulate:a",
		1,
		fade_time
	).from(0)\
	.set_trans(Tween.TRANS_LINEAR)\
	.set_ease(Tween.EASE_IN_OUT)
	
	
func _show_characters(num: int) -> void:
	if %RichTextLabel.visible_characters != num and RNGManager.randi_range(RNGManager.Bucket.COSMETIC, 1, 5) == 1:
		Events.play_sound.emit(_TEXT_BLIP_SFX)
		
	%RichTextLabel.visible_characters = num


func _set_text(text: String) -> void:
	%RichTextLabel.text = \
		"[wave amp=2.0 freq=2.0 connected=0]" + \
		text + \
		"[/wave]"
