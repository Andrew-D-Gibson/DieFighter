class_name EnemyActionResource
extends Resource

@export var name: String
@export var description: String
@export var indicator_texture: Texture2D
@export var info_texture: Texture2D
@export var effect_chain: EffectChain
@export var effect_chain_v2: EffectChainV2

## Set by the EnemyActionOptionResource who creates this action
## Used by the targeting computer to display the amount
@export var intent_amount: String


var activating_die_number: int:
	set(new_num):
		activating_die_number = clampi(new_num, 1, 6)


func show_info() -> void:
	# Don't show info if this is a blank action
	if name == '':
		return
		
	var info: InfoResource = InfoResource.new()
	info.title_label_text = name
	
	if activating_die_number:
		info.bottom_label_text = "[color=yellow]Enemy uses (die_" + \
									str(activating_die_number) + \
									") -> " + \
									description.replace('(amount)', intent_amount)
	else:
		info.bottom_label_text = description.replace('(amount)', intent_amount)
		
	info.texture = info_texture
	
	Events.show_info.emit(info)
