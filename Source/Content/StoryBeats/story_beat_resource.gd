class_name StoryBeatResource
extends Resource
## A story box's worth of words (STORY_BOXES_PLAN.md): who says them, up to
## three lines the first time the player hears them, and one line for every
## time after. Kept to three on purpose (LORE.md §1, "Keep it simple"): a box
## stops the game, so it has to earn it.
##
## Read once means read in any run (CollectionManager.has_read_story_beat()).

## Over the lines: "SECTOR WARDEN, DYING".
@export var speaker: String
@export_multiline var line_1: String
@export_multiline var line_2: String
@export_multiline var line_3: String
## Said instead, alone, once the player has read the beat in an earlier run.
## Empty: the speaker has nothing more to say, and no box opens.
@export_multiline var repeat_line: String

## About what fits the box (StoryBox), five lines of text.
const _MAX_CHARS: int = 110


## What the read-memory knows this beat by: its file name.
func id() -> String:
	return resource_path.get_file().get_basename()


func display_speaker() -> String:
	return ContentText.text(self, &"speaker")


## The lines to show, in the current language: the first-time lines, or just
## the repeat line once [param read_before]. Empty when there's nothing to say.
func display_lines(read_before: bool) -> Array[String]:
	var lines: Array[String] = []
	var fields: Array[StringName] = [&"repeat_line"]
	if not read_before:
		fields = [&"line_1", &"line_2", &"line_3"]
	for field: StringName in fields:
		var text: String = ContentText.text(self, field)
		if not text.is_empty():
			lines.append(text)
	return lines


func _content_text_prefix() -> String:
	return "STORY_BEAT"


func _content_text_fields() -> Array[ContentText.Field]:
	var spoken: String = "A line in a story box: a character speaking, in their own voice, while the game pauses on them. Spoken, plain, short."
	return [
		ContentText.Field.new(&"speaker", "SPEAKER",
			"Who is speaking in a story box, in capitals over their lines: the ship's name and its state (\"SECTOR WARDEN, DYING\").", 24),
		ContentText.Field.new(&"line_1", "LINE_1", spoken, _MAX_CHARS),
		ContentText.Field.new(&"line_2", "LINE_2", spoken, _MAX_CHARS),
		ContentText.Field.new(&"line_3", "LINE_3", spoken, _MAX_CHARS),
		ContentText.Field.new(&"repeat_line", "REPEAT_LINE",
			"The one line the same character says instead, on a later run, to a player who has heard the full story box before.", _MAX_CHARS),
	]
