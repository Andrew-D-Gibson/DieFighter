class_name StatusResource
extends KeywordResource
## A keyword that is also a status (Burn, Jammed...): the one file that holds
## everything about the status except its behaviour. Its title is the
## status's name, its rule what the badge's info panel explains, its tokens
## how text writes it, and below, the colour and icons its badge, callouts
## and flashes use and the script that does what the rule says.
##
## Lives in Source/Content/Keywords/KeywordResources/ with the other keywords;
## its file name is the status's id (StatusModifier.status_id), the id effects
## apply it by. StatusCatalog finds every status here, so adding one is a
## StatusModifier script plus one of these.
##
## Rule numbers are written as {placeholders} and filled from the script's
## rule_values() (see StatusModifier.rule_values()), so the text can't drift
## from the code that applies them.

## The StatusModifier subclass that does what the rule says.
@export var modifier_script: Script
## The status's palette colour, for its badge's count, its info panel title,
## its callouts and the flashes as it lands and acts.
@export_enum("orange", "red", "blue", "green", "yellow", "purple") var color: String = "orange"
## 11x11, for the badge on a ship's status bar.
@export var icon: Texture2D
## 24x24, for the info panel. The badge icon stands in when empty.
@export var info_icon: Texture2D


## The colour as drawn: the palette's current value for [member color].
func palette_color() -> Color:
	return Globals.get(color) as Color


## A fresh status run by [member modifier_script], reading this file for
## everything it shows. Null (with an error) if the script isn't a
## StatusModifier.
func create_modifier() -> StatusModifier:
	var status: StatusModifier = modifier_script.new() as StatusModifier if modifier_script else null
	if status == null:
		push_error("StatusResource %s: modifier_script is not a StatusModifier" % id())
		return null
	status.definition = self
	return status


func _rule_values() -> Dictionary:
	if modifier_script == null:
		return {}
	return modifier_script.call(&"rule_values")
