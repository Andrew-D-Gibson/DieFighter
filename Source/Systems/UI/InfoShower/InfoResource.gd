class_name InfoResource
extends Resource

@export var title_label_text: String = ''
@export var top_label_text: String = ''
@export var texture: Texture2D = null
@export var bottom_label_text: String = ''

## Asides that read off to the right of the art, such as a rule's sum and its
## current value, so the description under the art stays one centred block.
## Left empty, the column isn't shown.
@export var side_label_text: String = ''

## What the thing becomes once upgraded, shown beside it. Left empty, the
## panel shows the thing alone.
@export var upgrade_title_text: String = ''
@export var upgrade_texture: Texture2D = null
@export var upgrade_bottom_label_text: String = ''
## How to get there, written over the arrow between the two.
@export var upgrade_caption_text: String = ''


func has_upgrade() -> bool:
	return not upgrade_bottom_label_text.is_empty()
