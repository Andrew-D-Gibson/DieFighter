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


## Parts of [member texture] that explain themselves when the pointer rests on
## them (each face of Fate's Die), in the texture's own pixels. Parallel to
## [member hotspot_texts]; add them with [method add_hotspot].
@export var hotspot_rects: Array[Rect2] = []
@export var hotspot_texts: Array[String] = []


func has_upgrade() -> bool:
	return not upgrade_bottom_label_text.is_empty()


func add_hotspot(rect: Rect2, text: String) -> void:
	hotspot_rects.append(rect)
	hotspot_texts.append(text)


## The text of the hotspot under [param texture_point] (in the texture's
## pixels), or "" when there is none.
func hotspot_text_at(texture_point: Vector2) -> String:
	for i: int in mini(hotspot_rects.size(), hotspot_texts.size()):
		if hotspot_rects[i].has_point(texture_point):
			return hotspot_texts[i]
	return ""
