class_name EnemyActionResource
extends Resource

@export var name: String
@export var description: String
@export var indicator_texture: Texture2D
@export var info_texture: Texture2D
@export var effect_chain: EffectChain
@export var effect_chain_v2: EffectChainV2

## Set by the EnemyActionOptionResource who creates this action.
## The raw rolled amount — used both for display (via get_intent_amount_text())
## and by effect_chain_v2's "Set to Enemy Intent" amount modifier.
@export var intent_amount: int = 0


var activating_die_number: int:
	set(new_num):
		activating_die_number = clampi(new_num, 1, 6)


## Text form of intent_amount for display, e.g. in (amount) description substitution.
## Blank when the action has no meaningful amount (e.g. a pure status effect).
func get_intent_amount_text() -> String:
	return str(intent_amount) if intent_amount != 0 else ''


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
									description.replace('(amount)', get_intent_amount_text())
	else:
		info.bottom_label_text = description.replace('(amount)', get_intent_amount_text())

	info.texture = info_texture

	Events.show_info.emit(info)
