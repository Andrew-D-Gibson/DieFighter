class_name BackgroundModifierResource
extends Resource
## A permanent rule that applies for as long as the player sits in a given
## background.
##
## Unlike a BackgroundHazardResource, which counts down and then fires, a
## background modifier never triggers — it is simply true the whole time. That
## makes the background itself a strategic choice rather than scenery: taking
## the route past the pulsar means planning a fight without shields.
##
## The rule is registered on the scenario's engine as an ordinary Modifier, so
## it flows through the same before/after pipeline as tile and enemy effects
## and composes with them for free.
##
## AUTHORING (one script + one .tres per rule; nothing to register):
##   1. Write the rule as a Modifier subclass under
##      Source/Behavior/Modifiers/BackgroundModifiers/ (or reuse one) and set
##      it as 'modifier_script'.
##   2. Any number the rule needs goes in 'parameters' ({&"cap": 3}): each
##      entry is set on the new modifier by property name, and fills the same
##      {name} in the text, so the rule and its words can't disagree.
##   3. Write the name, description and callout the player sees, and assign
##      the resource to a BackgroundResource's 'global_modifier' field.
##   4. The text is English, written here; run tools/loc.sh sync to send it
##      for translation (see ContentText). Display code reads it through the
##      display_*() accessors, never the fields.

@export_category('Info')
## Shown on the banner in caps. Keep it short — it reads as a place name.
@export var modifier_name: String

## One line of bbcode explaining the rule, in the same '[color=red]' shorthand
## the rest of the game's text uses. {name}s fill from 'parameters'.
@export_multiline var description: String

## The word or two floated off the environment monitor when the rule bites
## ("NO SHIELDS", "MAX {cap}"). Capitals, very short; {name}s fill from
## 'parameters'. Empty for no callout.
@export var callout: String

## Tint for the rule's name on the info panel. Should match the background's
## own palette.
@export var color: Color = Color.WHITE

## Art for the targeting computer's environment monitor and the info panel it opens.
## Left null, the monitor shows a hazard glyph tinted to 'color', which still
## reads correctly — its whole job is to say "something governs this place,
## click me".
@export var icon: Texture2D

## Played when the rule bites. Left null, the monitor's own chime
## (EnvironmentMonitor._TRIGGER_SFX).
@export var trigger_sfx: SoundEffectResource

@export_category('Behavior')
## The Modifier subclass that enforces the rule. Built fresh per scenario by
## create_modifier(); it must construct with no arguments.
@export var modifier_script: GDScript

## The rule's numbers, by the modifier property each one sets (Doldrums:
## {&"cap": 3} sets AmountCapModifier.cap). The same names are {placeholders}
## in the description and callout.
@export var parameters: Dictionary[StringName, Variant] = {}


## Builds a fresh Modifier for the rule. Called once per scenario, because
## modifiers are registered on that scenario's engine and die with it.
func create_modifier() -> Modifier:
	if modifier_script == null:
		push_error("BackgroundModifierResource %s: no modifier_script" % resource_path)
		return null
	var mod: Modifier = modifier_script.new() as Modifier
	if mod == null:
		push_error("BackgroundModifierResource %s: %s is not a Modifier" % [
			resource_path, modifier_script.resource_path
		])
		return null

	for parameter: StringName in parameters:
		if parameter in mod:
			mod.set(parameter, parameters[parameter])
		else:
			push_error("BackgroundModifierResource %s: %s has no property '%s'" % [
				resource_path, modifier_script.resource_path, parameter
			])

	# The banner and the rule should never be able to disagree about what this
	# background is called. (English here: the Modifier's name is for logs;
	# anything it shows the player asks this resource.)
	if not modifier_name.is_empty():
		mod.modifier_name = modifier_name
	# A modifier that names its rule to the player (OncePerTurnModifier's tile
	# info line) declares a 'rule' property to be handed this resource.
	if &"rule" in mod:
		mod.set(&"rule", self)
	return mod


## The name, in the current language.
func display_name() -> String:
	return _display(&"modifier_name")


## The rule, in the current language, its {placeholders} filled.
func display_description() -> String:
	return _display(&"description")


## The callout, in the current language, its {placeholders} filled. Empty
## when none was written.
func display_callout() -> String:
	return _display(&"callout")


## The numbers this rule's {placeholders} stand for: its parameters
## ({"cap": 3}). The same hook TextTokens reads off any root resource.
func _text_tokens() -> Dictionary:
	var values: Dictionary = {}
	for parameter: StringName in parameters:
		values[String(parameter)] = parameters[parameter]
	return values


func _display(property: StringName) -> String:
	return TextTokens.fill(ContentText.text(self, property), self)


func _content_text_prefix() -> String:
	return "BG_MODIFIER"


func _content_text_fields() -> Array[ContentText.Field]:
	return [
		ContentText.Field.new(&"modifier_name", "NAME",
			"Name of a region's permanent rule (a background modifier), e.g. a nebula that blocks shields. Shown in capitals as the title of its arrival card and info panel, and inside tile info lines."),
		ContentText.Field.new(&"description", "DESC",
			"A region's permanent rule in one line, on its arrival card and info panel. Keep [color] tags, (keyword) tokens and {placeholders} as written; {cap} becomes a number."),
		ContentText.Field.new(&"callout", "CALLOUT",
			"Word or two floated off the environment monitor when a region's permanent rule changes something (NO SHIELDS, MAX {cap}). Capitals, very short, shouted. {cap} becomes a number; keep it.", 12),
	]
