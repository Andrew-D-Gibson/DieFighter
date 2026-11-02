class_name KeywordResource
extends Resource
## One game term (Feed, Burn, Echo...): the rule that pops up when its label
## is hovered, and the tokens that write it into descriptions.
##
## Each keyword is a file in Source/Content/Keywords/KeywordResources/, and
## its file name is its id ("feed_across"), which is what the hover meta and
## every lookup use, so the title and labels can be translated freely. A
## status is a StatusResource, this plus its colour, icons and script.
## Keywords loads the folder; see keywords.gd for how text uses them.

## The term as the hover pop-up and a status's badge, callouts and info panel
## name it: "Feed across", "Burn".
@export var title: String
## What the term does, shown in the pop-up after the title. Numbers the game
## applies are {placeholders} filled from _text_tokens(), never typed in.
@export_multiline var rule: String
## The rule for a status that works differently on the player's ship, read
## through the "<id>_you" term (Keywords.PLAYER_SUFFIX). Empty when the
## status reads the same on either side.
@export_multiline var player_rule: String
## Every spelling of the term that descriptions can write.
@export var tokens: Array[KeywordToken] = []


## The id lookups use: the file name.
func id() -> String:
	return resource_path.get_file().get_basename()


## The title, in the current language.
func display_title() -> String:
	return ContentText.text(self, &"title")


## The rule, in the current language, its numbers filled in.
func display_rule() -> String:
	return TextTokens.fill(ContentText.text(self, &"rule"), self)


## The player-side rule, in the current language, its numbers filled in.
## Empty when there's none.
func display_player_rule() -> String:
	return TextTokens.fill(ContentText.text(self, &"player_rule"), self)


## The numbers the rules' {placeholders} stand for, by name. A keyword whose
## rule repeats a number the game applies overrides this to read it from the
## code that applies it (a StatusResource asks its script). The same hook
## TextTokens reads off any root resource.
func _text_tokens() -> Dictionary:
	return {}


func _content_text_prefix() -> String:
	return "KEYWORD"


func _content_text_fields() -> Array[ContentText.Field]:
	return [
		ContentText.Field.new(&"title", "TITLE",
			"A game term, in title case. Shown before its rule in the pop-up when a keyword in tile or enemy text is hovered (\"Burn: ...\"); a status's title is also its name on its badge's info panel and in capitals in callouts (\"+3 BURN\")."),
		ContentText.Field.new(&"rule", "RULE",
			"What a game term means, in the pop-up when the keyword is hovered, after its title. Terse. Keep [color] tags as written; each {placeholder} is a number the game fills in."),
		ContentText.Field.new(&"player_rule", "PLAYER_RULE",
			"What a status does when it sits on the player's ship rather than an enemy (\"you\" is the player). Shown in the same hover pop-up, titled \"<term> (you)\". Keep [color] tags as written; each {placeholder} is a number the game fills in."),
	]
