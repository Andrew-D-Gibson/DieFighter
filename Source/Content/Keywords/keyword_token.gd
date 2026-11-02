class_name KeywordToken
extends Resource
## One way of writing a keyword in a description: "(feed_right)" shows as an
## orange "Feed right" that pops up Feed's rule. Lives inside its
## KeywordResource. The sub-resource id in the .tres names its content.csv
## key (KEYWORD.FEED.FEED_RIGHT.LABEL), so give a new one a readable id.

## What a description writes, brackets included: "(feed_right)".
@export var token: String
## What the player reads in its place.
@export var label: String
## The palette colour the label is drawn in. Keywords are orange unless the
## word belongs to another colour's rule (holograms are blue).
@export_enum("orange", "red", "blue", "green", "yellow", "purple") var color: String = "orange"
## Points at the keyword's player-side rule (KeywordResource.player_rule), for
## text describing what a status does to the player.
@export var player_side: bool = false


## The label, in the current language.
func display_label() -> String:
	return ContentText.text(self, &"label")


func _content_text_prefix() -> String:
	return "KEYWORD"


func _content_text_fields() -> Array[ContentText.Field]:
	return [
		ContentText.Field.new(&"label", "LABEL",
			"A keyword as it reads inside tile and enemy text (\"Feed right\", \"stolen\"), drawn in colour and hoverable for its rule. Match the case the English uses: lower case labels sit mid-sentence."),
	]
