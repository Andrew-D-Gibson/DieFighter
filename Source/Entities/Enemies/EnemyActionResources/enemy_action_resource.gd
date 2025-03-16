class_name EnemyActionResource
extends Resource

@export var name: String
@export var description: String
@export var indicator_texture: Texture2D
@export var info_texture: Texture2D
@export var intent_amount: String
@export var effect_chain: Array[EffectResource]


func show_info() -> void:
	# Don't show info if this is a blank action
	if name == '':
		return
		
	var info = InfoResource.new()
	info.title_label_text = name
	info.top_label_text = description
	info.texture = info_texture
	
	Events.show_info.emit(info)
