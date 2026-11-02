class_name BackgroundHazardResource
extends Resource
## A recurring environmental event that belongs to a background: the star in a
## solar flare region flares, the storm in an ion region discharges.
##
## Where a BackgroundModifierResource is true the whole time, a hazard counts
## down on a turn count the player can always see, then fires: a flare that
## wipes shields is only interesting if you knew it was coming. It lives on
## the background so the region's art can telegraph it too (HazardTelegraph).
##
## AUTHORING:
##   1. Create a BackgroundHazardResource.
##   2. Write its effect_chain like any other chain — it runs with the player
##      as actor and no activator die, so avoid die-dependent effects.
##   3. Assign it to a BackgroundResource's 'hazard' field. A background
##      carries a hazard or a global_modifier, never both: the environment
##      monitor has one screen.
##   4. Its text is English, written here; run tools/loc.sh sync to send it
##      for translation (see ContentText). Display code reads it through the
##      display_*() accessors, never the fields.

@export_category('Info')
## The hazard's name: title of its arrival card, info panel and the warning
## that goes up as it strikes. Shown in capitals.
@export var hazard_name: String
## The full rule, for the info panel the environment monitor opens. Say when
## and how it works here; the headline is what gets read at a glance.
@export_multiline var description: String

## What the hazard does, in a few words, read straight after its countdown
## ("In 2 turns: " + this). Lower case, no full stop, keyword tokens welcome.
## Keep it to one effect a player can picture: the arrival card is just this
## after its countdown, and a long one wraps. The info panel leaves it out,
## so say nothing here that the description doesn't.
@export var headline: String

## The effect named in capitals under the hazard's title on the turn it goes
## off ("SHIELDS DOWN!"). Plain text: the banner is a Label. 30 characters
## at most (the translation lint holds every language to that).
@export var banner: String

## Art for the environment monitor's screen, beside the countdown, and for the
## info panel it opens. Keep it within 9x9 so it fits next to the digit. Left
## null, the monitor shows its hazard glyph tinted to 'color'.
@export var icon: Texture2D

## Colour used for the monitor's lamp, countdown and the screen flash when it
## fires.
@export var color: Color = Color.WHITE

## When in the round the hazard goes off.
enum Timing {
	## As the player's turn starts, after their hand is rolled. Right for
	## hazards that change the board the player is about to act on.
	YOUR_TURN_STARTS,
	## As the player ends their turn, once the dice they handed over have
	## landed and before any ship uses them. Right for hazards that act on
	## dice: at turn start a fresh hand has nothing committed to disturb.
	YOUR_TURN_ENDS,
}

@export_category('Timing')
@export var timing: Timing = Timing.YOUR_TURN_STARTS

## Trigger points before the first hit, counting the coming one: 1 means the
## next turn start (YOUR_TURN_STARTS) or the end of the current turn
## (YOUR_TURN_ENDS).
@export var turns_until_first: int = 3

## Player turns between triggers after the first.
@export var turns_between: int = 3

@export_category('Behavior')
## What actually happens. Runs on the scenario's engine like any other chain.
@export var effect_chain: EffectChain


## The name, in the current language.
func display_name() -> String:
	return ContentText.text(self, &"hazard_name")


## The full rule, in the current language.
func display_description() -> String:
	return ContentText.text(self, &"description")


## The headline, in the current language. Empty when none was written.
func display_headline() -> String:
	return ContentText.text(self, &"headline")


## The banner, in the current language. Empty when none was written.
func display_banner() -> String:
	return ContentText.text(self, &"banner")


func _content_text_prefix() -> String:
	return "HAZARD"


func _content_text_fields() -> Array[ContentText.Field]:
	return [
		ContentText.Field.new(&"hazard_name", "NAME",
			"Name of a background hazard, a timed event of the region the player is in. Shown in capitals as the title of its arrival card, its info panel and the warning as it strikes."),
		ContentText.Field.new(&"description", "DESC",
			"A background hazard's full rule, in the info panel the environment monitor opens: when it goes off and what it does. Keep [color] tags, (keyword) tokens and line breaks as written."),
		ContentText.Field.new(&"headline", "HEADLINE",
			"What a background hazard does, in a few words, read straight after its countdown (HAZARD_HEADLINE: \"In 2 turns: ...\"). Lower case, no full stop. Keep [color] tags and (keyword) tokens as written."),
		ContentText.Field.new(&"banner", "BANNER",
			"Banner under a background hazard's title on the turn it goes off, naming what it just did. Capitals, plain text (no tags).", 30),
	]
