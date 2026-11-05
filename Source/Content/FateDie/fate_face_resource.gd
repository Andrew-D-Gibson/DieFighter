class_name FateFaceResource
extends Resource
## One face Fate's Die can show (LORE.md §5): which faction's choices carve it,
## how it reads in the cockpit, and what it does when Fate rolls it at the
## start of a round of the Reckoning (§7).
##
## One file per face under Source/Content/FateDie/Faces/, found by
## FateFaceCatalog. The file name is the face's id (FateDie.face_id()).

@export var face: FateDie.Face = FateDie.Face.BLANK
## The face's name, coloured by the face: "Mercy".
@export var face_name: String
## What carves it, in a line, for the die's info panel.
@export_multiline var carved_by: String
## What it does when Fate rolls it in the Reckoning, in tile-text style.
@export_multiline var reckoning_text: String
## The face's accent (LORE.md §12): its faction's light colour.
@export var color: Color = Color.WHITE
## A 7x7 glyph carved into the die. Faction faces reuse their faction's badge.
@export var glyph: Texture2D
## Played at the start of a Reckoning round when this face comes up, with the
## player as actor and no die. Numbers in reckoning_text bind to its steps.
@export var reckoning_chain: EffectChain
## Played instead, with defiant_text, for a player who never paid a tithe and
## refused one (FateLedger.refused_every_tithe()): a hidden modifier of the
## fight (LORE.md §6). Left empty, the face plays the same for everyone.
@export var defiant_chain: EffectChain
@export_multiline var defiant_text: String


func display_face_name() -> String:
	return ContentText.text(self, &"face_name")


func display_carved_by() -> String:
	return ContentText.text(self, &"carved_by")


func display_reckoning_text(ledger: FateLedger = null) -> String:
	if _is_defiant(ledger):
		return TextTokens.fill(ContentText.text(self, &"defiant_text"), self)
	return TextTokens.fill(ContentText.text(self, &"reckoning_text"), self)


## The chain this face plays in the Reckoning for the run [param ledger]
## describes.
func chain_for(ledger: FateLedger) -> EffectChain:
	return defiant_chain if _is_defiant(ledger) else reckoning_chain


func _is_defiant(ledger: FateLedger) -> bool:
	return ledger != null and defiant_chain != null and ledger.refused_every_tithe()


## The face's name in its own colour, for callouts and panels.
func coloured_name() -> String:
	return "[color=#%s]%s[/color]" % [color.to_html(false), display_face_name()]


func _content_text_prefix() -> String:
	return "FATE_FACE"


func _content_text_fields() -> Array[ContentText.Field]:
	return [
		ContentText.Field.new(&"face_name", "NAME",
			"The name of one face of Fate's Die, a die the player carves through their choices (Mercy, Plunder, Duty...). One word.", 12),
		ContentText.Field.new(&"carved_by", "CARVED_BY",
			"What kind of choice carves this face into Fate's Die, in a short line for its info panel."),
		ContentText.Field.new(&"reckoning_text", "RECKONING",
			"What happens at the start of a round of the secret final fight when Fate rolls this face. Terse, like a tile's text; {name} becomes a number."),
		ContentText.Field.new(&"defiant_text", "DEFIANT",
			"The same, for a player who refused every tithe of the Rearguard: the face turns in their favour. Terse, like a tile's text; {name} becomes a number."),
	]
